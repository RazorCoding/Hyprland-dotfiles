autoload -Uz compinit
compinit
# If not running interactively, don't do anything
[[ -o interactive ]] || return

# Auto start Hyprland on TTY1
if [[ -z "$DISPLAY" && "$(tty)" == "/dev/tty1" ]]; then
  exec start-hyprland
fi

alias hx='helix'
alias ls='ls --color=auto'

# Initialize Starship
eval "$(starship init zsh)"

# History file
HISTFILE=~/.zsh_history
HISTSIZE=1000000
SAVEHIST=1000000

# Record everything immediately
setopt APPEND_HISTORY        # append instead of overwrite
setopt INC_APPEND_HISTORY    # write to file instantly


# opencode
export PATH=/home/USER/.opencode/bin:$PATH
