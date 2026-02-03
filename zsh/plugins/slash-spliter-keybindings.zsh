# this script enhances word navigation and deletion in zsh by additionally treating
# certain characters (like '/', '-', and '.') as word boundaries by replacing WORDCHARS temporarily

if [[ -z ${SPLIT_CHARS+x} ]]; then
    SPLIT_CHARS=( '/' '-' '.' )
fi

# cache original and modified WORDCHARS at load time to avoid recomputing
ORIGINAL_WORDCHARS=${WORDCHARS}
MOD_WORDCHARS=$ORIGINAL_WORDCHARS
for c in "${SPLIT_CHARS[@]}"; do
    MOD_WORDCHARS=${MOD_WORDCHARS//${c}/}
done

backward_edge_case() {
    # special-case fix for edge cases.
    # zle backward-word: `(word)+(non-word)+|` -> `|(word)+(non-word)`
    # 1. the cursor is right after spaces and split chars, we will jump all these non-words as a group and also jumps a word group
    #    check prefixes: " --", " ./", " ../".
    [[ $LBUFFER == *' --' || $LBUFFER == *' ./' || $LBUFFER == *' ../' ]]
}
forward_edge_case() {
    # special-case fix for edge cases.
    # zle forward-word: `|(word)+(non-word)+` -> `(word)+(non-word)+|`
    # no edge cases found yet, but a placeholder for future use
    return 1
}

backward-word-split () {
    (( CURSOR > 0 )) || return
    if ! backward_edge_case; then
        local WORDCHARS=$MOD_WORDCHARS
    fi
    zle backward-word
}
forward-word-split () {
    (( CURSOR < ${#BUFFER} )) || return
    if ! forward_edge_case; then
        local WORDCHARS=$MOD_WORDCHARS
    fi
    zle forward-word
}
backward-kill-word-split () {
    (( CURSOR > 0 )) || return
    if ! backward_edge_case; then
        local WORDCHARS=$MOD_WORDCHARS
    fi
    zle backward-kill-word
}
forward-kill-word-split () {
    (( CURSOR < ${#BUFFER} )) || return
    if ! forward_edge_case; then
        local WORDCHARS=$MOD_WORDCHARS
    fi
    zle kill-word
}

zle -N backward-word-split
zle -N forward-word-split
zle -N backward-kill-word-split
zle -N forward-kill-word-split

# hint: use `showkey -a` to see what the sequence is
# VSCode terminal (denoted as A) may have different behavior than Windows Terminal (denoted as B). Other terminals may also differ
bindkey '\e[1;5D' backward-word-split      # jump left for a word: (`CTRL + ←` for A/B, `ALT + ←` for A)
bindkey '^[[1;3D' backward-word-split      # jumpt left for a word: (`ALT + ←` for B)
bindkey '\e[1;5C' forward-word-split       # jump right for a word: (`CTRL + →` for A/B, `ALT + →` for A)
bindkey '^[[1;3C' forward-word-split       # jump right for a word: (`ALT + →` for B)
bindkey '^[[1;5A' beginning-of-line        # jump to beginning: (`ALT + ↑` for A, `CTRL + ↑` for B)
bindkey '^[[1;3A' beginning-of-line        # jump to beginning: (`ALT + ↑` for B)
bindkey '^[[1;5B' end-of-line              # jump to end: (`ALT + ↓` for A, `CTRL + ↓` for B)
bindkey '^[[1;3B' end-of-line              # jump to end: (`ALT + ↓` for B)
bindkey '^W'      backward-kill-word-split # delete to left for a word: (`CTRL + backspace` for A)
bindkey '^H'      backward-kill-word-split # delete to left for a word: (`CTRL + backspace` for B)
bindkey '^[^?'    backward-kill-word-split # delete to left for a word: (`ALT + backspace` for A/B)
bindkey '^[d'     forward-kill-word-split  # delete to right for a word: (`CTRL + delete` for A)
bindkey '^[[3;5~' forward-kill-word-split  # delete to right for a word: (`CTRL + delete` for B)
bindkey '^[[3;3~' forward-kill-word-split  # delete to right for a word: (`ALT + delete` for A/B)
