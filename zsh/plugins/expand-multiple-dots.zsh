# Inspired by http://stackoverflow.com/a/41420448/4757
# Modified to be compatible with zsh-autosuggestions plugin

# Core function that expands multiple dots notation
# Transforms patterns like "..." to "../.." and "...." to "../../.." etc.
function expand-multiple-dots() {
    local MATCH
    # Match three or more consecutive dots at start of line or after space
    if [[ $LBUFFER =~ '(^| )\.\.\.+' ]]; then
        # Replace each "..." pattern with "../.." using zsh parameter expansion
        LBUFFER=$LBUFFER:fs%\.\.\.%../..%
    fi
}

# Handle Tab completion with dot expansion
# First expands dots, then triggers normal completion
function expand-multiple-dots-then-expand-or-complete() {
    zle expand-multiple-dots
    zle expand-or-complete
}

# Register the functions as ZLE widgets
zle -N expand-multiple-dots
zle -N expand-multiple-dots-then-expand-or-complete

# Bind Tab key to the enhanced completion function
bindkey '^I' expand-multiple-dots-then-expand-or-complete

# Use ZLE hook to expand dots before line execution.
# This approach preserves the native `Enter` key behavior while still providing the functionality,
# ensuring compatibility with plugins like zsh-autosuggestions that depend on the original accept-line widget
function zle-line-finish() {
    expand-multiple-dots
}
zle -N zle-line-finish
