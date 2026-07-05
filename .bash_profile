#
# ~/.bash_profile
#

#XDG_DIRS
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

#Scripts directory
export PATH="$PATH:$HOME/.local/bin"

#History
export HISTSIZE=1000
export HISTFILE="${XDG_STATE_HOME}"/bash/history
export HISTFILESIZE=$HISTSIZE
export HISTCONTROL=ignoredups:erasedups:ignorespace
shopt -s histappend

#Other .directories
export CUDA_CACHE_PATH="${XDG_CACHE_HOME:-$HOME/.cache}"/nv
