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
export PATH=$PATH:$HOME/local/bin

# cuda
export CUDA_HOME=/usr/local/cuda-12.1   # change cuda version here
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

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('$HOME/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "${__conda_setup}"
else
    if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
        . "$HOME/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# aliases
alias cl='clear'
alias ll='ls -alF'
alias la='ls -al'
alias l='ls -CF'

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

# system_proxy / unset_proxy as functions
SYSTEM_PROXY_HTTP_PORT=20171
SYSTEM_PROXY_SOCKS_PORT=20170
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
system_proxy() {
    export http_proxy="http://127.0.0.1:${SYSTEM_PROXY_HTTP_PORT}"
    export https_proxy="http://127.0.0.1:${SYSTEM_PROXY_HTTP_PORT}"
    export all_proxy="socks5://127.0.0.1:${SYSTEM_PROXY_SOCKS_PORT}"
    echo "System proxy set: http/https -> 127.0.0.1:${SYSTEM_PROXY_HTTP_PORT}, socks -> 127.0.0.1:${SYSTEM_PROXY_SOCKS_PORT}"
}
unset_proxy() {
    unset http_proxy https_proxy all_proxy
    echo "System proxy environment variables unset"
}
test_proxy() {
    # Color definitions
    local GREEN='\033[0;32m'
    local RED='\033[0;31m'
    local YELLOW='\033[0;33m'
    local NC='\033[0m' # No Color

    # Check if proxy environment variables are set
    if [[ -z "$http_proxy" ]] || [[ -z "$https_proxy" ]]; then
        echo -e "${YELLOW}[Warning] Proxy environment variables are NOT set.${NC}"
        return 1
    fi

    echo "Testing proxy connection..."
    echo "Current Proxy: $http_proxy"

    # Target URL for testing
    local target="https://www.google.com"

    # Test connection using curl with custom output format
    # -s: Silent mode (don't show progress meter)
    # -o /dev/null: Discard the response body
    # --connect-timeout 5: Set a 5-second timeout to avoid hanging
    # -w: Write out specific metrics
    local result=$(curl -s -o /dev/null -w "%{http_code}:%{time_namelookup}:%{time_connect}:%{time_appconnect}:%{time_total}" --connect-timeout 5 "$target")

    # Capture curl exit status
    local curl_exit_code=$?

    if [ $curl_exit_code -ne 0 ]; then
        echo -e "${RED}[Error] Connection Failed! (curl exit code: $curl_exit_code)${NC}"
        echo "Possible reasons: Proxy down, Firewall blocking, or DNS failure."
        return 1
    fi

    # Parse the metrics from the result string
    local http_code=$(echo "$result" | cut -d':' -f1)
    local time_dns=$(echo "$result" | cut -d':' -f2)
    local time_tcp=$(echo "$result" | cut -d':' -f3)
    local time_ssl=$(echo "$result" | cut -d':' -f4)
    local time_total=$(echo "$result" | cut -d':' -f5)

    # Check for success status codes (200 OK, 301/302 Redirects)
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "301" ]] || [[ "$http_code" == "302" ]]; then
        echo -e "${GREEN}[Success] Connection to Google established!${NC}"
        echo "-------------------------------------"
        echo -e "HTTP Status   : ${GREEN}$http_code${NC}"
        echo -e "DNS Lookup    : ${YELLOW}${time_dns}s${NC}"
        echo -e "TCP Connect   : ${YELLOW}${time_tcp}s${NC}"
        echo -e "SSL Handshake : ${YELLOW}${time_ssl}s${NC}"
        echo -e "Total Time    : ${GREEN}${time_total}s${NC}"
        echo "-------------------------------------"

        # Optional: Verify external IP to ensure traffic is actually routed through proxy
        echo -e "Verifying external IP via proxy..."
        local ext_ip=$(curl -s --connect-timeout 3 http://ifconfig.me)
        echo -e "External IP   : ${GREEN}$ext_ip${NC}"
    else
        echo -e "${RED}[Fail] HTTP Status Code: $http_code${NC}"
    fi
}
