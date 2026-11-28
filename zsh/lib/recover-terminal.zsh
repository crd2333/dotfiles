# Sourced from zsh/.zshrc. The helper retries with sudo only if needed.
recover-terminal() {
    command "$ZSH/lib/recover-terminal.py" "$@"
}
