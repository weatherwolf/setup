# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


# Timezone for the shell (drives the p10k clock and `date`)
export TZ='Europe/Amsterdam'

# Set up the prompt

autoload -Uz promptinit
promptinit
#prompt adam1

setopt histignorealldups sharehistory

# Use emacs keybindings even if our EDITOR is set to vi
bindkey -e

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

# Use modern completion system
autoload -Uz compinit
compinit

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
source ~/powerlevel10k/powerlevel10k.zsh-theme
export PATH="$HOME/.local/bin:$PATH"

## Source - https://stackoverflow.com/a/77056042
## Posted by Gairfowl
## Retrieved 2026-06-24, License - CC BY-SA 4.0
#PROMPT='[$(TZ=UTC strftime %T)][%*] %% '

alias gs="git status"
alias ga="git add ."
alias gc="git commit -m"
alias gb="git branch"
alias gd="git diff"
alias gch="git checkout"
alias jb="cd ~/Fyrm/jordex-boekingen"
alias jm="cd ~/Fyrm/mcp-jit"
alias vd="uv run --with visidata --with openpyxl -- vd"
alias fman='print -rl -- ${(k)commands} ${(k)builtins} | fzf | xargs man'

c_gs_review() {
  local d
  d=$(git diff --staged) || return
  [[ -z $d ]] && { echo "cr: no staged changes" >&2; return 1 }
  print -r -- "$d" | claude -p 'review this code for bugs and security issues'
}

c_gs_message() {
  local d
  d=$(git diff --staged) || return
  [[ -z $d ]] && { echo "cgd: no staged changes" >&2; return 1 }
  print -r -- "$d" | claude -p 'write a conventional commit message for these changes'
}

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Machine-specific overrides (untracked; create per machine as needed).
# Put work-only aliases, env vars, or paths here instead of editing this file.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Added by sonarqube-cli installer
export PATH="$HOME/.local/share/sonarqube-cli/bin:$PATH"

# Load SonarQube token if present (file is gitignored / lives outside this repo)
[ -f "$HOME/.config/sonar/env" ] && source "$HOME/.config/sonar/env"
