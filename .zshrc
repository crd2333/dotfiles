# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="ys"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# plugins=(
	#git
	#z
	#incr
        #docker
	#zsh-autosuggestions
	#zsh-syntax-highlighting
# )

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/crd233/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/crd233/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/home/crd233/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/crd233/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# >>> Contents below are managed by crd233 >>>
# 环境变量
export PATH=$PATH:/home/crd233/anaconda3/bin
export PATH=$PATH:/usr/bin
export PATH=$PATH:/home/crd233/.local/bin
export PATH=$PATH:/usr/sbin
export PATH=$PATH:/usr/local/cuda-11.8/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda-11.8/lib64
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

# 热键绑定
bindkey -s '\eo'   'cd ..\n'           #按下ALT+O ：cd ..
bindkey -s '\e;'   'ls -l\n'   	       #按下 ALT+；：ls -l
bindkey '\e[1;3D' backward-word        #ALT+左键：向后跳一个单词
bindkey '\e[1;3C' forward-word         #ALT+右键：前跳一个单词
bindkey '\e[1;3A' beginning-of-line    #ALT+上键：跳至行首
bindkey '\e[1;3B' end-of-line          #ALT+下键：跳至行尾

# 网络设置
host_ip=$(cat /etc/resolv.conf |grep "nameserver" |cut -f 2 -d " ")
export http_proxy="http://$host_ip:7890"
export https_proxy="http://$host_ip:7890"

# 脚本、工具与命令
# thefuck
eval $(thefuck --alias fuck)
# ranger
export RANGER_LOAD_DEFAULT_RC=FALSE
alias ranger='ranger --choosedir=$HOME/.rangerdir; LASTDIR=`cat $HOME/.rangerdir`; cd "$LASTDIR"'
# zoxide
eval "$(zoxide init zsh)"
# zinit
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
source "${ZINIT_HOME}/zinit.zsh"
# wsl进入回到初始目录
cd ~

# alias
alias rollabyte="xxd -p -l1 /dev/urandom"
alias gpt="cd ~/Projects/gpt_academic; python main.py"
alias cl="clear"
alias cat="bat"
alias ls="exa"
alias la="exa -al"
alias ra="ranger"
alias 'cd ...'="cd ../../"
alias 'cd ....'="cd ../../../"
alias copilot='gh copilot' # GitHub Copilit 扩展
alias gcs='gh copilot suggest'
alias gce='gh copilot explain'
alias cdd="cd /mnt/d/下载" # cd to 'downlowd' dir

# <<< Contents upward are managed by crd233 <<<

# >>> zinit 加载主题与插件 >>>
# Theme
zinit ice depth='1' # git clone depth
zinit light romkatv/powerlevel10k

# 快速目录跳转
zinit ice lucid wait='1'
zinit light skywind3000/z.lua

# 语法高亮
zinit ice lucid wait='0' atinit='zpcompinit'
zinit light zdharma/fast-syntax-highlighting

# 自动建议
zinit ice lucid wait='0' atload='_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions

# 更好的历史搜索
zinit ice lucid wait='0'
zinit load zdharma-continuum/history-search-multi-word
zinit load zsh-users/zsh-history-substring-search
zinit ice wait='0' atload='_history_substring_search_config'

# 提醒存在 alias
zinit ice lucid wait='0'
zinit load MichaelAquilina/zsh-you-should-use

# extract 代替 tar 解压
zinit ice lucid wait='0'
zinit load le0me55i/zsh-extract

# 加载 oh-my-zsh 框架及部分插件
zinit snippet OMZ::lib/completion.zsh
zinit snippet OMZ::lib/history.zsh
zinit snippet OMZ::lib/key-bindings.zsh
zinit snippet OMZ::lib/theme-and-appearance.zsh
zinit snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh
zinit snippet OMZ::plugins/sudo/sudo.plugin.zsh # sudo 上一条命令
zinit snippet OMZ::plugins/copybuffer/copybuffer.plugin.zsh # 复制缓冲区内容
zinit snippet OMZ::plugins/copyfile/copyfile.plugin.zsh # 复制文件内容
zinit snippet OMZ::plugins/copypath/copypath.plugin.zsh # 复制文件路径
zinit ice lucid wait='1'
zinit snippet OMZ::plugins/git/git.plugin.zsh

# <<< zinit 加载主题与插件 <<<

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
