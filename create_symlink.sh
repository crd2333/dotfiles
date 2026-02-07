#!/bin/bash

USER=$(whoami)
DOTFILES="/home/$USER/dotfiles"
HOME_DIR="/home/$USER"

# Color definitions
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# List of symlink pairs (source|target)
read -r -d '' PAIRS <<EOF
$DOTFILES/zsh/.zshrc|$HOME_DIR/.zshrc
$DOTFILES/bash/.bashrc|$HOME_DIR/.bashrc
$DOTFILES/bash/.profile|$HOME_DIR/.profile
$DOTFILES/.tmux.conf|$HOME_DIR/.tmux.conf
$DOTFILES/.gitconfig|$HOME_DIR/.gitconfig
$DOTFILES/.condarc|$HOME_DIR/.condarc
$DOTFILES/config/npm/npmrc|$HOME_DIR/.npmrc
$DOTFILES/config|$HOME_DIR/.config
EOF

# Iterate lines in PAIRS
while IFS='|' read -r source target; do
  # Skip empty lines
  [ -z "$source" ] && continue

  # 1. Check if Source exists
  if [ ! -e "$source" ]; then
    printf "%b\n" "${YELLOW}Warning:${RESET} Source does not exist - $source"
    continue
  fi

  # 2. Check if Target is already a Symlink (Specific Check)
  # -L checks if the file exists and is a symbolic link
  if [ -L "$target" ]; then
    printf "%b\n" "${BLUE}Skipping:${RESET} Symlink already exists - $target -> $(readlink "$target")"
    continue
  fi

  # 3. Check if Target exists but is NOT a Symlink (Regular file or Directory)
  if [ -e "$target" ]; then
    printf "%b\n" "${YELLOW}Skipping:${RESET} Target exists (Regular File/Dir) - $target"
    continue
  fi

  # 4. Create symlink
  ln -s "$source" "$target"
  printf "%b\n" "${GREEN}Created:${RESET} $target -> $source"

done <<< "$PAIRS"

printf "%b\n" "${GREEN}Symlink setup completed!${RESET}"
