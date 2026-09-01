# Script to create symlinks for Windows environment
# Run this with PowerShell (Admin privileges might be required unless Developer Mode is on)

$ErrorActionPreference = "Stop"

# Variables
$User = $env:USERNAME
$Dotfiles = Join-Path $Home "dotfiles"
$PowerShellProfile = if (Test-Path -LiteralPath $PROFILE) {
    $PROFILE
} else {
    "D:\文档\PowerShell\Microsoft.PowerShell_profile.ps1"
}

# Color definitions
function Write-Green ($text) { Write-Host "Created: $text" -ForegroundColor Green }
function Write-Yellow ($text) { Write-Host "Warning: $text" -ForegroundColor Yellow }
function Write-Blue ($text) { Write-Host "Skipping: $text" -ForegroundColor Cyan }
function Write-End ($text) { Write-Host $text -ForegroundColor Green }

# List of symlink pairs (source|target)
$Pairs = @"
$Dotfiles\.gitconfig|$Home\.gitconfig
$Dotfiles\.condarc|$Home\.condarc
$Dotfiles\npm\npmrc_win|$Home\.npmrc
$Dotfiles\.wslconfig|$Home\.wslconfig
$Dotfiles\posh\Microsoft.PowerShell_profile.ps1|$PowerShellProfile
$Dotfiles\config\btop\themes|$Home\.config\btop\themes
$Dotfiles\config\opencode|$Home\.config\opencode
$Dotfiles\config\pip|$Home\.config\pip
$Dotfiles\config\wgetrc|$Home\.config\wgetrc
$Dotfiles\config\fish|$Home\.config\fish
$Dotfiles\config\pi\models.json|$Home\.pi\agent\models.json
$Dotfiles\config\pi\extensions\pi-permission-system\config.json|$Home\.pi\agent\extensions\pi-permission-system\config.json
$Dotfiles\config\pi\extensions\pi-model-fix\config.json|$Home\.pi\agent\extensions\pi-model-fix\config.json
$Dotfiles\config\pi\extensions\pi-custom-header\config.json|$Home\.pi\agent\extensions\pi-custom-header\config.json
"@

# Iterate lines in Pairs
$Pairs -split "`r?`n" | ForEach-Object {
$Line = $_.Trim()
    if ([string]::IsNullOrWhiteSpace($Line)) { return }

    $Parts = $Line -split '\|'
    $Source = $Parts[0].Trim()
    $Target = $Parts[1].Trim()

    # 1. Check if Source exists
    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Yellow "Source does not exist - $Source"
        return
    }

    # 2. Check Target (using Get-Item to correctly identify Broken Links)
    $TargetItem = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue

    if ($TargetItem) {  # Check if it is a Symbolic Link or Junction
        if ($TargetItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            $LinkTarget = if ($TargetItem.Target) { $TargetItem.Target -join "" } else { "Unknown Target" }
            Write-Blue "Symlink already exists - $Target -> $LinkTarget"
        }
        else {  # It exists but is NOT a link (Regular File or Directory)
            Write-Yellow "Target exists (Regular File/Dir) - $Target"
        }
        return
    }

    # 3. Create symlink
    try {  # Ensure target parent directory exists
        $ParentDir = Split-Path -Parent $Target
        if ($ParentDir -and (-not (Test-Path -LiteralPath $ParentDir))) {
            New-Item -ItemType Directory -Path $ParentDir -Force | Out-Null
        }

        New-Item -ItemType SymbolicLink -Path $Target -Value $Source -Force | Out-Null
        Write-Green "$Target -> $Source"
    }
    catch {
        Write-Host "Error: Failed creating link $Target -> $Source ($($_.Exception.Message))" -ForegroundColor Red
    }
}

Write-End "`nSymlink setup completed!"
