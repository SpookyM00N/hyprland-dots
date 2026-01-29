#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

bind 'TAB:menu-complete'
bind 'set show-all-if-ambiguous on'
bind 'set menu-complete-display-prefix on'
bind 'set completion-ignore-case on'

shopt -s autocd

#Aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias c='clear'

#Prompt

#History
export HISTSIZE=1000
export HISTFILE=~/.bash_history
export HISTFILESIZE=$HISTSIZE
export HISTCONTROL=ignoredups:erasedups:ignorespace
shopt -s histappend

#persistant history through different sessions
PROMPT_COMMAND="history -a"

fastfetch

#Prompt
export STARSHIP_CONFIG=~/.config/starship/starship.toml
eval "$(starship init bash)"
