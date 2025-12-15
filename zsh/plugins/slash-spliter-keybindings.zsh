# this script enhances word navigation and deletion in zsh by additionally treating
# certain characters (like '/', '-', and '.') as word boundaries by replacing WORDCHARS temporarily

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

# Helper: return 0 if char is one of SPLIT_CHARS
is_split_char() {
    local ch="$1"
    [[ $SPLIT_CHARS_JOINED = *"$ch"* ]]
}

# Precompute caches: joined split-chars and modified WORDCHARS
ORIGINAL_WORDCHARS=${WORDCHARS}
SPLIT_CHARS_JOINED=$(printf '%s' "${SPLIT_CHARS[@]}")
MOD_WORDCHARS=$ORIGINAL_WORDCHARS
for c in "${SPLIT_CHARS[@]}"; do
    MOD_WORDCHARS=${MOD_WORDCHARS//${c}/}
done

backward-word-dir () {
    (( CURSOR > 0 )) || return
    local left=${BUFFER:$((CURSOR-1)):1}
    if is_split_char "$left"; then
        zle backward-word
    else
        local WORDCHARS=$MOD_WORDCHARS
        zle backward-word
    fi
}
forward-word-dir () {
    (( CURSOR < ${#BUFFER} )) || return
    local right=${BUFFER:$((CURSOR)):1}
    if is_split_char "$right"; then
        zle forward-word
    else
        local WORDCHARS=$MOD_WORDCHARS
        zle forward-word
    fi
}
backward-kill-word-dir () {
    (( CURSOR > 0 )) || return
    local left=${BUFFER:$((CURSOR-1)):1}
    if is_split_char "$left"; then
        zle backward-kill-word
    else
        local WORDCHARS=$MOD_WORDCHARS
        zle backward-kill-word
    fi
}
forward-kill-word-dir () {
    (( CURSOR < ${#BUFFER} )) || return
    local right=${BUFFER:$((CURSOR)):1}
    if is_split_char "$right"; then
        zle kill-word
    else
        local WORDCHARS=$MOD_WORDCHARS
        zle kill-word
    fi
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
