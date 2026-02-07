# Script to create symlinks for Windows environment
# Run this with PowerShell (Admin privileges might be required unless Developer Mode is on)

$ErrorActionPreference = "Stop"

# Variables
$User = $env:USERNAME
$Dotfiles = Join-Path $Home "dotfiles"
$PowerShellProfile = if ($PROFILE) { $PROFILE } else { Join-Path "D:\文档\PowerShell" "Microsoft.PowerShell_profile.ps1" }

# Color definitions
function Write-Green ($text) { Write-Host "Created: $text" -ForegroundColor Green }
function Write-Yellow ($text) { Write-Host "Warning: $text" -ForegroundColor Yellow }
function Write-Blue ($text) { Write-Host "Skipping: $text" -ForegroundColor Cyan }
function Write-End ($text) { Write-Host $text -ForegroundColor Green }

# List of symlink pairs (source|target)
$Pairs = @"
$Dotfiles\.gitconfig|$Home\.gitconfig
$Dotfiles\.condarc|$Home\.condarc
$Dotfiles\config\npm\npmrc_win|$Home\.npmrc
$Dotfiles\.wslconfig|$Home\.wslconfig
$Dotfiles\posh\Microsoft.PowerShell_profile.ps1|$PowerShellProfile
$Dotfiles\config|$Home\.config
"@

# Iterate lines in Pairs
$Pairs -split "`r?`n" | ForEach-Object {
    $Line = $_.Trim()
    if ([string]::IsNullOrWhiteSpace($Line)) { return }

    $Parts = $Line -split '\|'
    $Source = $Parts[0]
    $Target = $Parts[1]

    # 1. Check if Source exists
    if (-not (Test-Path -Path $Source)) {
        Write-Yellow "Source does not exist - $Source"
        return
    }

    # 2. Check if Target exists (Common check before distinguishing type)
    if (Test-Path -Path $Target) {
        $Item = Get-Item -Path $Target -Force

        # Check if it is a Symbolic Link
        if ($Item.LinkType -eq "SymbolicLink") {
            Write-Blue "Symlink already exists - $Target -> $($Item.Target)"
        }
        else {
            # It exists but is NOT a symlink (Regular File or Directory)
            Write-Yellow "Target exists (Regular File/Dir) - $Target"
        }
        return
    }

    # 3. Create symlink
    try {
        # Check if parent directory exists (e.g. for PowerShell profile), create if needed
        $ParentDir = Split-Path -Path $Target -Parent
        if (-not (Test-Path -Path $ParentDir)) {
            New-Item -ItemType Directory -Path $ParentDir | Out-Null
        }

        New-Item -ItemType SymbolicLink -Path $Target -Value $Source | Out-Null
        Write-Green "$Target -> $Source"
    }
    catch {
        Write-Host "Error creating link: $_ when creating link from $Source to $Target" -ForegroundColor Red
    }
}

Write-End "`nSymlink setup completed!"
