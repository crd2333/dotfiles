# The protected SSH dispatcher invokes this after normal profiles have loaded.
# Environment policy lives in dotfiles and is shared with both Pi launch paths.
. (Join-Path $HOME 'dotfiles\posh\lib\dev-env.ps1')
