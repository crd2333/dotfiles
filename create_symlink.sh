#!/bin/bash

USER=$(whoami)
DOTFILES="$HOME/dotfiles"

# Color definitions
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# List of symlink pairs (source|target)
read -r -d '' PAIRS <<EOF
$DOTFILES/zsh/.zshrc|$HOME/.zshrc
$DOTFILES/bash/.bashrc|$HOME/.bashrc
$DOTFILES/bash/.profile|$HOME/.profile
$DOTFILES/.tmux.conf|$HOME/.tmux.conf
$DOTFILES/.gitconfig|$HOME/.gitconfig
$DOTFILES/.condarc|$HOME/.condarc
$DOTFILES/npm/npmrc|$HOME/.config/npm/npmrc
$DOTFILES/config/btop/btop.conf|$HOME/.config/btop/btop.conf
$DOTFILES/config/btop/themes|$HOME/.config/btop/themes
$DOTFILES/config/opencode|$HOME/.config/opencode
$DOTFILES/config/pip|$HOME/.config/pip
$DOTFILES/config/wgetrc|$HOME/.config/wgetrc
$DOTFILES/config/fish|$HOME/.config/fish
$DOTFILES/config/pi/models.json|$HOME/.pi/agent/models.json
$DOTFILES/config/pi/extensions/pi-permission-system/config.json|$HOME/.pi/agent/extensions/pi-permission-system/config.json
$DOTFILES/config/pi/extensions/pi-model-fix/config.json|$HOME/.pi/agent/extensions/pi-model-fix/config.json
$DOTFILES/config/pi/extensions/pi-custom-header/config.json|$HOME/.pi/agent/extensions/pi-custom-header/config.json
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

  # 4. Ensure target dir exists
  target_dir=$(dirname "$target")
  if [ ! -d "$target_dir" ]; then
    mkdir -p "$target_dir"
  fi

  # 5. Create symlink
  if ln -s "$source" "$target"; then
    printf "%b\n" "${GREEN}Created:${RESET} $target -> $source"
  else
    printf "%b\n" "${RED}Error:${RESET} Failed to create symlink - $target"
  fi

done <<< "$PAIRS"

printf "%b\n" "${GREEN}Symlink setup completed!${RESET}"
