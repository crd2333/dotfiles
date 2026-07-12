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


# Load local/private configurations (not tracked by git)
#   bypass local should contains user-specific environment variables (maybe configs for different machines)
#   outer private should contains something more secret, like opencode web auth configs and proxy provider configs
[[ -f "$ZSH/.zshrc.local" ]] && source "$ZSH/.zshrc.local"
[[ -f "$HOME/private/.zshrc.local" ]] && source "$HOME/private/.zshrc.local"


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


# Make history appears only once and shared by all terminals
setopt histignorealldups sharehistory
setopt HIST_FIND_NO_DUPS


# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
export HISTFILE=$ZSH/.zsh_history


# Use modern completion system
fpath=(~/dotfiles/zsh/completions $fpath)
autoload -Uz compinit
compinit


# Styles
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


# Extensions setting
source $ZSH/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
source $ZSH/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fpath=($ZSH/plugins/zsh-completions/src $fpath)
source $ZSH/plugins/extract/extract.plugin.zsh
source $ZSH/plugins/expand-multiple-dots.zsh
source $ZSH/plugins/slash-spliter-keybindings.zsh


# Proxy helpers (system_proxy / unset_proxy / test_proxy)
[[ -f "$ZSH/lib/proxy.zsh" ]] && source "$ZSH/lib/proxy.zsh"


# ===== Environment Variables =====
if [ -f "$HOME/.local/bin/env" ]; then
    . "$HOME/.local/bin/env"  # load env variables from ~/.local/bin/env
fi
export PATH="$HOME/.local/bin${PATH:+:$PATH}"  # user-level local bin
export PATH="$HOME/.bun/bin${PATH:+:$PATH}"  # bun
export PATH="$HOME/opt/texlive/2026/bin/x86_64-linux${PATH:+:$PATH}"  # texlive

# cuda
export CUDA_HOME=/usr/local/cuda-12.8   # change cuda version here
export PATH="$CUDA_HOME/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# Set TORCH_CUDA_ARCH_LIST based on the local GPU architecture if nvidia-smi is available
if command -v nvidia-smi >/dev/null 2>&1; then
    LOCAL_CUDA_ARCHS=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | sort -u | paste -sd ";" -)
    if [ -n "$LOCAL_CUDA_ARCHS" ]; then
        export TORCH_CUDA_ARCH_LIST="$LOCAL_CUDA_ARCHS"
    fi
fi

# ONNX Runtime
if [ -d "$HOME/opt/onnxruntime/current-gpu" ]; then
    export ONNXRUNTIME_ROOT=$HOME/opt/onnxruntime/current-gpu
    export LD_LIBRARY_PATH="$ONNXRUNTIME_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$("$HOME/miniconda3/bin/conda" "shell.zsh" "hook" 2> /dev/null)"
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

# node (system/nvm)
export NVM_DIR="$HOME/.config/nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    \. "$NVM_DIR/nvm.sh"                                                # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
    unset NPM_CONFIG_PREFIX  # disable global prefix when nvm is present
else  # use system node, redirect global npm packages to home directory to avoid permission issues
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    export PATH="$NPM_CONFIG_PREFIX/bin${PATH:+:$PATH}"
    export NODE_PATH="$NPM_CONFIG_PREFIX/lib/node_modules${NODE_PATH:+:$NODE_PATH}"
fi

# limit MAX_JOBS in memory-bound servers
export MAX_JOBS=8


# ===== Aliases =====
alias cl='clear'
alias ll='ls -alF'
alias la='ls -al'
alias l='ls -CF'
alias rsync='rsync -avzh --info=progress2 --partial' # human-readable rsync with progress, compression and partial files
alias nuke_ssh="pkill -9 -u $USER sshd"  # force kill all ssh sessions of the current user, useful when you are locked out due to some ssh config issues
alias download='npx degit' # e.g. download user/repo#branch local_name

# add aliases for cc-switch, cc, advcp, advmv if in PATH
command -v cc-switch >/dev/null 2>&1 && alias ccs='cc-switch'
command -v claude >/dev/null 2>&1 && alias cc='claude'
command -v codex >/dev/null 2>&1 && alias cx='codex'
command -v advcp >/dev/null 2>&1 && alias cp='advcp -g' # override default cp with advcp and enable progress bar
command -v advmv >/dev/null 2>&1 && alias mv='advmv -g'

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


# ===== Custom Launchers =====
# v2raya launcher is kept in .zshrc (not part of the 3 proxy helper functions)
v2raya_lite_launch() {
    # v2raya launch with no sudo (litely), make sure you are in tmux!
    if [ "$1" = "--v2ray" ]; then  # use v2ray core if specified
        export V2RAYA_V2RAY_BIN="$HOME/opt/v2ray/v2ray"
        export V2RAYA_V2RAY_CONFDIR="$HOME/opt/v2ray"
        export V2RAYA_V2RAY_ASSETSDIR="$HOME/opt/v2ray"
        ~/opt/v2raya/v2raya --lite
        return
    fi
    export V2RAYA_V2RAY_BIN="$HOME/opt/xray/xray"
    export V2RAYA_V2RAY_CONFDIR="$HOME/opt/xray"
    export V2RAYA_V2RAY_ASSETSDIR="$HOME/opt/xray"
    ~/opt/v2raya/v2raya --lite
}
mihomo_launch() {
    echo "Initializing Mihomo env..."

    local mihomo_dir="$HOME/opt/mihomo"
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
    ~/opt/mihomo/mihomo -d ~/opt/mihomo
}


# CPA launcher with ephemeral config in /dev/shm and secret injection from env variable
cpa_launch() {
    (  # Wrap the entire execution in a subshell `(...)`
        echo "Init CLIProxyAPI ephemeral env (/dev/shm)..."

        local cpa_dir="$HOME/cliproxyapi"
        local persist_config="$cpa_dir/config.yaml"

        # 1. Secure memory allocation
        local run_dir
        run_dir=$(mktemp -d -p /dev/shm cpa_run.XXXXXX) || { echo "Failed to create temp dir"; return 1; }
        local ephemeral_config="$run_dir/config.yaml"

        export CPA_SECRET="${CPA_SECRET:-'123456'}"

        # 2. Define a dedicated cleanup function inside the subshell
        cleanup() {
            trap - EXIT INT TERM
            echo -e "\n[Sync] Exiting. Syncing runtime config to disk..."
            if [ -f "$ephemeral_config" ]; then
                # Strip secret and save back to disk
                sed 's/^\([[:space:]]*secret-key:\).*/\1 ""/' "$ephemeral_config" > "$persist_config.tmp"
                mv "$persist_config.tmp" "$persist_config"
            fi
            rm -rf "$run_dir"
            echo "[Clean] Ephemeral workspace destroyed."
        }

        # Bind the cleanup function to signals
        trap cleanup EXIT INT TERM

        # 3. Inject secret into memory config
        sed "s/^\([[:space:]]*secret-key:\).*/\1 \"${CPA_SECRET}\"/" "$persist_config" > "$ephemeral_config"
        chmod 600 "$ephemeral_config"

        # 4. Extract top-level port and print clickable link
        local cpa_port
        cpa_port=$(grep -m 1 -E '^port:[[:space:]]*[0-9]+' "$ephemeral_config" | awk '{print $2}')
        cpa_port="${cpa_port:-8317}"

        echo -e "\n--> CPA Management Center ready at: http://localhost:${cpa_port}/management.html\n"

        # 5. Launch CPA core
        cd "$cpa_dir" || exit 1
        ./cli-proxy-api --config "$ephemeral_config"
    )
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


# codex with proxy (use --no-proxy or --no_proxy to force skipping system proxy)
codex() {
    local skip_proxy=0
    local -a args=()
    for arg in "$@"; do
        if [[ $arg == --no-proxy || $arg == --no_proxy ]]; then
            skip_proxy=1
        else
            args+=("$arg")
        fi
    done

    local help_re='^(help|-h|--help|version|-v|-V|--version|completion|login|logout|mcp|plugin|mcp-server|app-server|remote-control|sandbox|debug|apply|a|exec-server|features)$'
    if [[ -z "${args[1]-}" || ! "${args[1]}" =~ $help_re ]]; then
        [[ $skip_proxy -eq 0 ]] && echo "Setting codex with proxy..."
    fi

    if [[ $skip_proxy -eq 1 ]]; then
        (command codex "${args[@]}")
    else
        (system_proxy > /dev/null 2>&1; command codex "${args[@]}")
    fi
}
