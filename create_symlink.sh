#!/bin/zsh
#!/bin/bash

USER=$(whoami)
DOTFILES="/home/$USER/dotfiles"
HOME_DIR="/home/$USER"

# Color definitions (ANSI)
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# List of symlink pairs (source|target)
read -r -d '' PAIRS <<EOF
$DOTFILES/zsh/.zshrc|$HOME_DIR/.zshrc
$DOTFILES/.tmux.conf|$HOME_DIR/.tmux.conf
$DOTFILES/.gitconfig|$HOME_DIR/.gitconfig
$DOTFILES/.condarc|$HOME_DIR/.condarc
$DOTFILES/config|$HOME_DIR/.config
EOF

# Iterate lines in PAIRS
while IFS='|' read -r source target; do
  # skip empty lines
  [ -z "$source" ] && continue

  # Skip if source doesn't exist OR target already exists
  if [ ! -e "$source" ] || [ -e "$target" ] || [ -L "$target" ]; then
    if [ ! -e "$source" ]; then
      printf "%b\n" "${YELLOW}Warning:${RESET} Source does not exist - $source"
    else
      printf "%b\n" "${BLUE}Skipping:${RESET} Target already exists - $target"
    fi
    continue
  fi

  # Create symlink
  ln -s "$source" "$target"
  printf "%b\n" "${GREEN}Created:${RESET} $target -> $source"
done <<< "$PAIRS"

printf "%b\n" "${GREEN}Symlink setup completed!${RESET}"
