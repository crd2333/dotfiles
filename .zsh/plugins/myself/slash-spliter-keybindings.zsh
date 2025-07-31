# key-bindings
backward-word-dir () {
    local WORDCHARS=${WORDCHARS/\/}
    zle backward-word
}
forward-word-dir () {
    local WORDCHARS=${WORDCHARS/\/}
    zle forward-word
}
backward-kill-word-dir () {
    local WORDCHARS=${WORDCHARS/\/}   # use '/' to split
    zle backward-kill-word
}
forward-kill-word-dir () {
    local WORDCHARS=${WORDCHARS/\/}
    zle kill-word
}
zle -N backward-word-dir
zle -N forward-word-dir
zle -N backward-kill-word-dir
zle -N forward-kill-word-dir
bindkey '\e[1;5D' backward-word-dir      # Ctrl + 左键：向前跳一个单词
bindkey '\e[1;5C' forward-word-dir       # Ctrl + 右键：向后跳一个单词
bindkey '\e[1;5A' beginning-of-line      # Ctrl + 上键：跳至行首
bindkey '\e[1;5B' end-of-line            # Ctrl + 下键：跳至行尾
bindkey '^H'      backward-kill-word-dir # Ctrl + Backspace：删除至一个单词
bindkey '\e[3;5~' forward-kill-word-dir  # Ctrl + Delete：删除至下一个单词
