#!/bin/bash

PALETTE_DIR=~/setup/palettes

readColors() {
	grep -E '^[A-Za-z_][A-Za-z0-9_]*=#[0-9A-Fa-f]{6}$' "$PALETTE_DIR/$1.colors" | awk -F'=' '{print $2}'
}

replaceColors() {
	old_colors=( $(readColors "$1") )
	new_colors=( $(readColors "$2") )

	# check if the palettes have the same size
	if [ "${#old_colors[@]}" != "${#new_colors[@]}" ]; then
		echo "palettes don't have the same size: old_palette_size=${#old_colors[@]} , new_palette_size=${#new_colors[@]}" >&2
		return 1
	fi

	# every old hex as one alternation, for the file search below
	old_hexes=$(IFS='|'; echo "${old_colors[*]}")

	# Two passes, built as one sed program. Every old hex goes to a unique
	# @@index@@ token first, then each token to its new hex. A single pass
	# would let one role's replacement be re-replaced by a later role whose
	# old hex happens to equal it.
	sed_args=()
	for i in "${!old_colors[@]}"
	do
		sed_args+=(-e "s/${old_colors[$i]}/@@${i}@@/Ig")
	done
	for i in "${!new_colors[@]}"
	do
		sed_args+=(-e "s/@@${i}@@/${new_colors[$i]}/g")
	done

	# Target all files except the palette definitions, git internals and
	# binaries. tmux is excluded too: it consumes no palette role, but its
	# message-style uses #000000, which collides with any palette that puts
	# an ordinary color in a role and would be rewritten by mistake. .agents
	# holds skill docs, whose worked examples quote fixed hexes that must not
	# follow the live palette.
	grep -rlIEi "$old_hexes" ~/setup \
		--exclude-dir=.git \
		--exclude-dir=palettes \
		--exclude-dir=tmux \
		--exclude-dir=.agents \
		--exclude=update_palette.sh |
	while IFS= read -r file
	do
		sed -i '' "${sed_args[@]}" "$file"
		echo "  updated $file"
	done
}

isColors() {
    [[ "$1" == *.colors ]]
}

# Accept the palette as an argument; fall back to prompting.
palette=$1
if [ -z "$palette" ]; then
	read -p "Enter color palette you want to change to: " palette
fi

#echo $palette

palette_found=false
for a in $(ls ~/setup/palettes)
do
	if [ "$(echo "$a" | awk -F'.' '{print $1}')" = "$palette" ] && isColors "$a"; then
		palette_found=true
		break
	fi
done

if [ "$palette_found" = false ]; then
	echo "$palette cannot be found, available palette:"
	for p in $(ls ~/setup/palettes)
	do
		if ! isColors $p; then
			continue
		fi
			printf '%s\n' "$(echo "$p" | awk -F'.' '{print $1}')"
	done
	exit 1
fi

echo "palette has been found in $palette.colors"

# From here on, stdout goes nowhere: the swap's progress lines and the output
# of herdr and recompute_shimmers.py are not shown. fd 3 keeps the real
# terminal so the final clear can still reach it. Errors still show, because
# they go to stderr.
exec 3>&1 >/dev/null

CURRENT_FILE="$PALETTE_DIR/current_pallete.txt"

# First run: nothing is recorded yet, so there is no "from" palette to swap
# away from. Adopt the named one and stop.
if [ ! -s "$CURRENT_FILE" ]; then
	echo "$palette" > "$CURRENT_FILE"
	echo "no palette was recorded; current_pallete.txt now says $palette, nothing swapped"
	exit 0
fi

current=$(cat "$CURRENT_FILE")

if [ "$current" = "$palette" ]; then
	echo "$palette is already the current palette, nothing to do"
	exit 0
fi

echo "swapping $current -> $palette"

if ! replaceColors "$current" "$palette"; then
	echo "swap failed, current_pallete.txt left at $current" >&2
	exit 1
fi

# Claude Code's shimmers are lightened variants of their bases, not palette
# roles, so the hex swap above cannot carry them - it would leave the spinner
# pulsing to the previous palette's color. Recompute from the new bases.
python3 "$PALETTE_DIR/recompute_shimmers.py" \
	"$HOME/setup/claude/.claude/themes/theme.json"

echo "$palette" > "$CURRENT_FILE"
echo "current palette is now $palette"
# Snapshot what was actually written into the configs. Editing a live palette's
# .colors file afterwards leaves the configs holding hexes that exist in no
# file, which no later swap can reach; `palette.py sync` diffs against this to
# repair that. Without the snapshot it has nothing to compare to.
cp "$PALETTE_DIR/$palette.colors" "$PALETTE_DIR/.applied.colors"
# Validate before pushing the rewritten config into the running server, so a
# malformed file is caught here rather than by the multiplexer.
if herdr config check; then
	herdr server reload-config
else
	echo "herdr config check failed; not reloading. The swap already wrote the files." >&2
	exit 1
fi

# Print "<pane_id> <foreground process names>" for every herdr pane, so each
# step below can pick the panes whose foreground program it knows how to drive.
# Keys sent to a pane go to that program, so the same key means different
# things in nvim and in zsh.
listPaneForegrounds() {
	herdr pane list | python3 -c '
import json, sys
for pane in json.load(sys.stdin)["result"]["panes"]:
    print(pane["pane_id"])
' | while IFS= read -r pane
	do
		fg=$(herdr pane process-info --pane "$pane" | python3 -c '
import json, sys
info = json.load(sys.stdin)["result"]["process_info"]
print(" ".join(p["name"] for p in info["foreground_processes"]))
')
		echo "$pane $fg"
	done
}

# A running nvim keeps the highlights it loaded at startup, so the new hexes in
# init.lua only show after a restart. Type :restart! into every pane whose
# foreground process is nvim. Esc first, so a pane left in insert or cmdline
# mode still receives the command. The ! skips the unsaved-changes prompt, so
# unsaved edits in those buffers are discarded. nvim running over ssh in a pane
# is not detected (the foreground is ssh).
restartNvimPanes() {
	listPaneForegrounds | while read -r pane fg
	do
		if [ "$fg" = "nvim" ]; then
			herdr pane send-keys "$pane" esc > /dev/null &&
			herdr pane send-text "$pane" ":restart!" > /dev/null &&
			herdr pane send-keys "$pane" enter > /dev/null &&
			echo "  restarted nvim in $pane"
		fi
	done
}

# Clean up every pane sitting at an idle zsh prompt. zsh runs in emacs mode
# (bindkey -e): ctrl+u is kill-whole-line (wipes the typed input) and ctrl+l
# is clear-screen (wipes the screen and redraws the prompt).
clearShellPanes() {
	listPaneForegrounds | while read -r pane fg
	do
		if [ "$fg" = "zsh" ]; then
			herdr pane send-keys "$pane" ctrl+u > /dev/null &&
			herdr pane send-keys "$pane" ctrl+l > /dev/null
		fi
	done
}

restartNvimPanes
clearShellPanes
# The invoking pane runs this script in the foreground, not zsh, so
# clearShellPanes skips it. Clear it directly, but only when fd 3 is a real
# terminal: under a capturing runner the escape codes would print as text.
[ -n "$HERDR_PANE_ID" ] && [ -t 3 ] && clear >&3
