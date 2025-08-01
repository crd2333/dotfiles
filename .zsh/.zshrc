# ZSH HOME
export ZSH=$HOME/.zsh

# Set up the prompt and 'ls' colors
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi
source $ZSH/themes/spaceship-prompt/spaceship.zsh-theme
SPACESHIP_PROMPT_ORDER=(
  conda         # conda virtualenv section
  user          # Username section
  dir           # Current directory section
  # host          # Hostname section
  git           # Git section (git_branch + git_status)
  # hg            # Mercurial section (hg_branch  + hg_status)
  docker         # Docker section
  docker_compose # Docker section
  exec_time     # Execution time
  line_sep      # Line break
  # vi_mode       # Vi-mode indicator
  jobs          # Background jobs indicator
  exit_code     # Exit code section
  char          # Prompt character
)
SPACESHIP_USER_SHOW=always
SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_CHAR_SYMBOL="❯"
SPACESHIP_CHAR_SUFFIX=" "
SPACESHIP_PROMPT_ASYNC=false # 暂时的无奈之举

# make history appears only once and shared by all terminals
setopt histignorealldups sharehistory
setopt HIST_FIND_NO_DUPS

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
export HISTFILE=$ZSH/.zsh_history

# Use modern completion system
autoload -Uz compinit
compinit

# styles
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

# extensions setting
source $ZSH/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
source $ZSH/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fpath=($ZSH/plugins/zsh-completions/src $fpath)
source $ZSH/plugins/zsh-extract/extract.plugin.zsh
source $ZSH/plugins/myself/expand-multiple-dots.zsh
source $ZSH/plugins/myself/slash-spliter-keybindings.zsh

# 环境变量
if [ $PATH ]; then
    export PATH=$PATH:/usr/bin
else
    export PATH=/usr/bin
fi
if [ $LD_LIBRARY_PATH ]; then
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib
else
    export LD_LIBRARY_PATH=/usr/lib
fi
# cuda
# export CUDA_HOME=/usr/local/cuda-11.1   # change cuda version here, a soft link to cuda-11.1 by default
# if [ $LD_LIBRARY_PATH ]; then
#    export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
# else
#     export LD_LIBRARY_PATH=$CUDA_HOME/lib64
# fi
# if [ $PATH ]; then
#     export PATH=$CUDA_HOME/bin:$PATH
# else
#     export PATH=$CUDA_HOME/bin
# fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/crd233/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/crd233/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/crd233/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/crd233/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# aliases
alias cl='clear'
alias ll='ls -alF'
alias la='ls -al'
alias l='ls -CF'
alias system_proxy='export http_proxy=http://127.0.0.1:8080; export https_proxy=http://127.0.0.1:8080; export all_proxy=socks5://127.0.0.1:1080'
alias unset_proxy='unset http_proxy; unset https_proxy; unset all_proxy'

