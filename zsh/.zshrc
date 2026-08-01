# Timezone for the shell (drives the starship clock and `date`)
export TZ='Europe/Amsterdam'

# herdr reads its config from a platform-specific dir by default (~/.config on
# Linux, ~/Library/Application Support on macOS). Pin it to the tracked path so
# the one symlinked config.toml is used on both. Harmless if herdr is absent.
export HERDR_CONFIG_PATH="$HOME/.config/herdr/config.toml"

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
command -v dircolors >/dev/null 2>&1 && eval "$(dircolors -b)"
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

## Source - https://stackoverflow.com/a/77056042
## Posted by Gairfowl
## Retrieved 2026-06-24, License - CC BY-SA 4.0
#PROMPT='[$(TZ=UTC strftime %T)][%*] %% '

alias gs="git status"
alias ga="git add -u"
alias gc="git commit -m"
alias gb="git branch"
alias gd="git diff"
alias gch="git checkout"
alias jb="cd ~/Fyrm/jordex-boekingen"
alias jm="cd ~/Fyrm/mcp-jit"
alias vd="uv run --with visidata --with openpyxl -- vd"
alias fman='print -rl -- ${(k)commands} ${(k)builtins} | fzf | xargs man'
mkcd() { mkdir -p "$1" && cd "$1"}

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

# starship prompt. Config lives in ~/.config/starship.toml (tracked in the setup
# repo). Must be initialized after anything else that touches PROMPT/precmd.
# (No equivalent of p10k's transient prompt: starship 1.26.0's zsh init does not
# define enable_transience, so calling it just errors on every shell start.)
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# Machine-specific overrides (untracked; create per machine as needed).
# Put work-only aliases, env vars, or paths here instead of editing this file.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Added by sonarqube-cli installer
export PATH="$HOME/.local/share/sonarqube-cli/bin:$PATH"

# Load SonarQube token if present (file is gitignored / lives outside this repo)
[ -f "$HOME/.config/sonar/env" ] && source "$HOME/.config/sonar/env"
export PATH="$HOME/.local/bin:$PATH"

prettyjson() {
	file="$1"
	tmp="$(mktemp)"

	jq . $file > $tmp && mv $tmp $file
}
# aikido-endpoint-cert-config-start
# Allow Node.js tooling to trust the SafeChain MITM CA while preserving public roots.
export NODE_EXTRA_CA_CERTS="/Library/Application Support/AikidoSecurity/EndpointProtection/run/endpoint-protection-node-combined-ca.pem"
# aikido-endpoint-cert-config-end
# aikido-endpoint-pip-cert-config-start
# Allow Python package managers to trust the SafeChain MITM CA while preserving user-provided roots.
export PIP_CERT="/Library/Application Support/AikidoSecurity/EndpointProtection/run/endpoint-protection-pip-combined-ca.pem"
export REQUESTS_CA_BUNDLE="/Library/Application Support/AikidoSecurity/EndpointProtection/run/endpoint-protection-pip-combined-ca.pem"
export POETRY_CERTIFICATES_PYPI_CERT="/Library/Application Support/AikidoSecurity/EndpointProtection/run/endpoint-protection-pip-combined-ca.pem"
export UV_SYSTEM_CERTS=true
# aikido-endpoint-pip-cert-config-end
# aikido-endpoint-ruby-cert-config-start
# Allow Ruby Bundler to trust the SafeChain MITM CA while preserving public roots.
export BUNDLE_SSL_CA_CERT="/Library/Application Support/AikidoSecurity/EndpointProtection/run/endpoint-protection-ruby-combined-ca.pem"
# aikido-endpoint-ruby-cert-config-end
# aikido-endpoint-curl-cert-config-v2-start
# Allow curl and other OpenSSL-linked tools to trust the SafeChain MITM CA while preserving the system roots.
export SSL_CERT_FILE="/Library/Application Support/AikidoSecurity/EndpointProtection/run/endpoint-protection-openssl-combined-ca.pem"
export CURL_CA_BUNDLE="/Library/Application Support/AikidoSecurity/EndpointProtection/run/endpoint-protection-openssl-combined-ca.pem"
# aikido-endpoint-curl-cert-config-v2-end
