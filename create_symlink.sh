#!/bin/bash

DOTFILES="$HOME/dotfiles"

# Color definitions
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# Tool detection: a candidate is either a command name (checked via PATH) or an absolute path (checked for existence)
check_tool() {
  local c
  for c in "$@"; do
    case "$c" in
      /*) [ -e "$c" ] && return 0 ;;
      *)  command -v "$c" >/dev/null 2>&1 && return 0 ;;
    esac
  done
  return 1
}

# Link list, each line is fully self-contained: source|target|required-tool|candidates
#   tool column empty      -> always create
#   candidates column empty -> default to the tool name itself (a simple command check)
#   candidates are ;-separated command names and/or absolute paths
read -r -d '' PAIRS <<EOF
$DOTFILES/zsh/.zshrc|$HOME/.zshrc||
$DOTFILES/bash/.bashrc|$HOME/.bashrc||
$DOTFILES/bash/.profile|$HOME/.profile||
$DOTFILES/.tmux.conf|$HOME/.tmux.conf|tmux|
$DOTFILES/.gitconfig|$HOME/.gitconfig||
$DOTFILES/.condarc|$HOME/.condarc|conda|conda;$HOME/miniconda3;$HOME/anaconda3;/opt/miniconda3;/opt/anaconda3;/opt/conda
$DOTFILES/npm/npmrc|$HOME/.config/npm/npmrc|npm|npm;node
$DOTFILES/config/btop/btop.conf|$HOME/.config/btop/btop.conf|btop|
$DOTFILES/config/btop/themes|$HOME/.config/btop/themes|btop|
$DOTFILES/config/opencode|$HOME/.config/opencode|opencode|
$DOTFILES/config/pip|$HOME/.config/pip|pip|pip;pip3
$DOTFILES/config/wgetrc|$HOME/.config/wgetrc|wget|
$DOTFILES/config/fish|$HOME/.config/fish|fish|
$DOTFILES/config/pi/models.json|$HOME/.pi/agent/models.json|pi|
$DOTFILES/config/pi/extensions/pi-permission-system/config.json|$HOME/.pi/agent/extensions/pi-permission-system/config.json|pi|
$DOTFILES/config/pi/extensions/pi-model-fix/config.json|$HOME/.pi/agent/extensions/pi-model-fix/config.json|pi|
$DOTFILES/config/pi/extensions/pi-custom-header/config.json|$HOME/.pi/agent/extensions/pi-custom-header/config.json|pi|
$DOTFILES/config/pi/extensions/pi-crd233/pi-crd233.json|$HOME/.pi/agent/extensions/pi-crd233/pi-crd233.json|pi|
$DOTFILES/config/pi/extensions/pi-crd233/pi-crd233.private.json|$HOME/.pi/agent/extensions/pi-crd233/pi-crd233.private.json|pi|
$DOTFILES/config/pi/pi-vcc-config.json|$HOME/.pi/agent/pi-vcc-config.json|pi|
EOF

# Iterate lines in PAIRS
while IFS='|' read -r source target tool candidates; do
  # Skip empty lines
  [ -z "$source" ] && continue

  # 0. Skip if the required tool is not installed
  if [ -n "$tool" ]; then
    if [ -z "$candidates" ]; then
      cand=("$tool")
    else
      IFS=';' read -ra cand <<< "$candidates"
    fi
    if ! check_tool "${cand[@]}"; then
      printf "%b\n" "${YELLOW}Warning:${RESET} $tool not detected, skipping - $target"
      continue
    fi
  fi

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
