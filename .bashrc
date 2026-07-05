#
# ~/.bashrc
#

fastfetch

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

#Bindings
bind 'TAB:menu-complete'
bind 'set show-all-if-ambiguous on'
bind 'set menu-complete-display-prefix on'
bind 'set completion-ignore-case on'

shopt -s autocd

#Aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias c='clear'
alias n='nvim'

alias home='cd ~'
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'

#persistant history through different sessions
PROMPT_COMMAND="history -a"

#Prompt
export STARSHIP_CONFIG=~/.config/starship/starship.toml
eval "$(starship init bash)"
