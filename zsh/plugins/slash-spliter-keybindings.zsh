# key-bindings

if [[ -z ${SPLIT_CHARS+x} ]]; then
    SPLIT_CHARS=( '/' '-' '.' )
fi

# Helper: return WORDCHARS with all SPLIT_CHARS removed
remove_split_chars() {
    local wc="$WORDCHARS"
    local ch
    for ch in "${SPLIT_CHARS[@]}"; do
        wc=${wc//${ch}/}
    done
    printf '%s' "$wc"
}

backward-word-dir () {
    local WORDCHARS=$(remove_split_chars)
    zle backward-word
}
forward-word-dir () {
    local WORDCHARS=$(remove_split_chars)
    zle forward-word
}
backward-kill-word-dir () {
    local WORDCHARS=$(remove_split_chars)
    zle backward-kill-word
}
forward-kill-word-dir () {
    local WORDCHARS=$(remove_split_chars)
    zle kill-word
}

zle -N backward-word-dir
zle -N forward-word-dir
zle -N backward-kill-word-dir
zle -N forward-kill-word-dir

# hint: use `showkey -a` to see what the sequence is
bindkey '\e[1;5D' backward-word-dir      # Ctrl + 左键：向前跳一个单词
bindkey '\e[1;5C' forward-word-dir       # Ctrl + 右键：向后跳一个单词
bindkey '\e[1;5A' beginning-of-line      # Ctrl + 上键：跳至行首
bindkey '\e[1;5B' end-of-line            # Ctrl + 下键：跳至行尾
bindkey '^H'      backward-kill-word-dir # Ctrl + Backspace：删除至一个单词
bindkey '^W'      backward-kill-word-dir # Ctrl + Backspace：VSCode terminal 触发的快捷键不一样
bindkey '\e[3;5~' forward-kill-word-dir  # Ctrl + Delete：删除至下一个单词
