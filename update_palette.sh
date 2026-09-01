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
		echo "palettes don't have the same size: old_palette_size=${#old_colors[@]} , new_palette_size=${#new_colors[@]}"
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
	# an ordinary color in a role and would be rewritten by mistake.
	grep -rlIEi "$old_hexes" ~/setup \
		--exclude-dir=.git \
		--exclude-dir=palettes \
		--exclude-dir=tmux \
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
	echo "swap failed, current_pallete.txt left at $current"
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
	echo "herdr config check failed; not reloading. The swap already wrote the files."
	exit 1
fi
