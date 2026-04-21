# Home directories
if [[ "$HOME" == */ ]]; then HOME=${HOME:0:-1}; fi

# XDG Base Directory Specification
export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state

# Application specific data files
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"
export WGETRC="$XDG_CONFIG_HOME/wgetrc"
alias wget='wget --hsts-file="$XDG_CACHE_HOME/wget-hsts"'
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"

# ZSH HOME
export ZSH=$HOME/dotfiles/zsh

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
SPACESHIP_PROMPT_ASYNC=false # https://github.com/spaceship-prompt/spaceship-prompt/issues/1193

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
source $ZSH/plugins/extract/extract.plugin.zsh
source $ZSH/plugins/expand-multiple-dots.zsh
source $ZSH/plugins/slash-spliter-keybindings.zsh

# environment variables
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
export PATH=$PATH:$HOME/local/bin

# cuda
export CUDA_HOME=/usr/local/cuda-12.8   # change cuda version here
if [ $LD_LIBRARY_PATH ]; then
   export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
else
    export LD_LIBRARY_PATH=$CUDA_HOME/lib64
fi
if [ $PATH ]; then
    export PATH=$CUDA_HOME/bin:$PATH
else
    export PATH=$CUDA_HOME/bin
fi
# export TORCH_CUDA_ARCH_LIST=8.9  # for 4090
# export TORCH_CUDA_ARCH_LIST=8.6  # for A6000
export TORCH_CUDA_ARCH_LIST="8.9;12.0"  # for 4090 + A6000Pro

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('$HOME/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
        . "$HOME/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export PATH="$PATH:$HOME/.local/bin"
export NPM_GLOBAL="$HOME/.npm-global"
export PATH="$NPM_GLOBAL/bin:$PATH"
export NODE_PATH="$NPM_GLOBAL/lib/node_modules:$NODE_PATH"

# source local private configuration (not committed to git) if exists
# should contains opencode configs and mihomo provider configs
if [ -f ~/private/.zshrc.local ]; then
    source ~/private/.zshrc.local
fi

# aliases
alias cl='clear'
alias ll='ls -alF'
alias la='ls -al'
alias l='ls -CF'
alias rsync='rsync -avzh --info=progress2 --partial' # human-readable rsync with progress, compression and partial files

# advcp / advmv if in PATH
if command -v advcp >/dev/null 2>&1; then
    alias cp='advcp -g'
fi
if command -v advmv >/dev/null 2>&1; then
    alias mv='advmv -g'
fi

# tmux aliases and functions
alias tls='tmux ls'
alias tk='tmux kill-session -t' # tkill <session-name>
tnew() {  # tnew <session-name>
    if [ -n "$1" ]; then
        tmux new -s "$1"
    else
        echo "Usage: tnew <session-name>"
    fi
}
tat() {  # tat <session-name>
    if [ $# -eq 0 ]; then  # no args, list availabel sessions
        if tmux has-session 2>/dev/null; then
            echo "No session name provided. Available sessions:"
            tmux list-sessions -F '#S'
        else
            echo "No tmux sessions found. Creating new session..."
            tmux new
        fi
    else
        tmux attach -t "$1"
    fi
}
trn() {  # trn <old-session-name> <new-session-name>
    if [ $# -eq 2 ]; then
        tmux rename-session -t "$1" "$2"
    else
        echo "Usage: trn <old-session-name> <new-session-name>"
    fi
}

# Proxy helpers (system_proxy / unset_proxy / test_proxy)
SYSTEM_PROXY_PORT=20170
SYSTEM_PROXY_PORT_BACKUP=20171
if [ -f "$ZSH/lib/proxy.zsh" ]; then
    source "$ZSH/lib/proxy.zsh"
fi

# v2raya launcher is kept in .zshrc (not part of the 3 proxy helper functions)
v2raya_lite_launch() {
    # v2raya launch with no sudo (litely), make sure you are in tmux!
    if [ "$1" = "--v2ray" ]; then  # use v2ray core if specified
        export V2RAYA_V2RAY_BIN="$HOME/local/v2ray/v2ray"
        export V2RAYA_V2RAY_CONFDIR="$HOME/local/v2ray"
        export V2RAYA_V2RAY_ASSETSDIR="$HOME/local/v2ray"
        ~/local/v2raya/v2raya --lite
        return
    fi
    export V2RAYA_V2RAY_BIN="$HOME/local/xray/xray"
    export V2RAYA_V2RAY_CONFDIR="$HOME/local/xray"
    export V2RAYA_V2RAY_ASSETSDIR="$HOME/local/xray"
    ~/local/v2raya/v2raya --lite
}
mihomo_launch() {
    echo "Initializing Mihomo env..."

    local mihomo_dir="$HOME/local/mihomo"
    local config_path="$mihomo_dir/config.yaml"
    local generator="$ZSH/lib/mihomo_gen.zsh"

    # Call external generator script to create config.yaml
    if [ -f "$generator" ]; then
        echo "Generating Mihomo configuration..."
        source "$generator" "$config_path"
    else
        echo "Error: Configuration generator not found at $generator"
        return 1
    fi

    ulimit -n 65535 2>/dev/null

    echo "Launching Mihomo Core, serving in http://127.0.0.1:2017/ui ..."
    ~/local/mihomo/mihomo -d ~/local/mihomo
}

# comvenient ps
pinfo() {
    local force_name=0  # Check if the first argument is the force flag '-n'
    if [[ "$1" == "-n" ]]; then
        force_name=1
        shift # Move to the actual search term
    fi
    if [[ -z "$1" ]]; then  # Check if a search term was provided
        echo "💡 Usage: pinfo [-n] <process_name_or_pid>"
        echo "   Example 1 (Auto name):  pinfo nginx"
        echo "   Example 2 (Auto PID):   pinfo 1234"
        echo "   Example 3 (Force name): pinfo -n 1234"
        return 1
    fi
    # Check if input is purely digits AND force_name flag is NOT set
    if [[ "$1" =~ ^[0-9]+$ && $force_name -eq 0 ]]; then
        ps -fww -p "$1"
    else  # Handle the echo output based on how we got here
        if [[ $force_name -eq 1 ]]; then
            echo "🔍 Forced name search for: '$1' ..."
        fi
        ps -efww | head -n 1  # Print the ps header for readability
        ps -efww | grep -i "$1" | grep -v "grep"  # Search process by name, ignore case, and exclude grep itself
    fi
}

# opencode with proxy (use --no-proxy or --no_proxy to force skipping system proxy)
opencode() {
    local skip_proxy=0
    local -a args=()
    for arg in "$@"; do
        if [[ $arg == --no-proxy || $arg == --no_proxy ]]; then
            skip_proxy=1
        else
            args+=("$arg")
        fi
    done

    local help_re='^(help|-h|--help|version|-v|--version|completion|models|providers|auth|agent|mcp|acp|stats|session|export|import|github|db|uninstall|debug|attach)$'
    if [[ -z "${args[1]-}" || ! "${args[1]}" =~ $help_re ]]; then
        [[ $skip_proxy -eq 0 ]] && echo "Setting opencode with proxy..."
    fi

    if [[ $skip_proxy -eq 1 ]]; then
        (command opencode "${args[@]}")
    else
        (system_proxy > /dev/null 2>&1; command opencode "${args[@]}")
    fi
}

# bun completions
[ -s "/home/mf/.bun/_bun" ] && source "/home/mf/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

. "$HOME/.local/share/../bin/env"

# limit MAX_JOBS in memory-bound servers
export MAX_JOBS=8
