#!/bin/bash

USER=$(whoami)
DOTFILES="/home/$USER/dotfiles"
HOME_DIR="/home/$USER"

# Array of symlinks to create
declare -A LINKS=(
    ["$DOTFILES/.zsh/.zshrc"]="$HOME_DIR/.zshrc"
    ["$DOTFILES/.tmux.conf"]="$HOME_DIR/.tmux.conf"
    ["$DOTFILES/.gitconfig"]="$HOME_DIR/.gitconfig"
    ["$DOTFILES/.condarc"]="$HOME_DIR/.condarc"
    ["$DOTFILES/config"]="$HOME_DIR/.config"
)

for source in "${!LINKS[@]}"; do
    target="${LINKS[$source]}"

    # Skip if source doesn't exist OR target already exists
    if [ ! -e "$source" ] || [ -e "$target" ] || [ -L "$target" ]; then
        if [ ! -e "$source" ]; then
            echo "Warning: Source does not exist - $source"
        else
            echo "Skipping: Target already exists - $target"
        fi
        continue
    fi

    # Create symlink
    ln -s "$source" "$target"
    echo "Created: $target -> $source"
done

echo "Symlink setup completed!"