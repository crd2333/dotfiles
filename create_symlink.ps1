# Script to create symlinks for Windows environment
# Run this with PowerShell (Admin privileges might be required unless Developer Mode is on)

$ErrorActionPreference = "Stop"

# Variables
$Dotfiles = Join-Path $Home "dotfiles"
# $PROFILE always points to the correct per-user location, even if the file does not exist yet
$PowerShellProfile = $PROFILE

# Color definitions
function Write-Green ($text) { Write-Host "Created: $text" -ForegroundColor Green }
function Write-Yellow ($text) { Write-Host "Warning: $text" -ForegroundColor Yellow }
function Write-Blue ($text) { Write-Host "Skipping: $text" -ForegroundColor Cyan }
function Write-End ($text) { Write-Host $text -ForegroundColor Green }

# --- Tool detection helpers ---
function Test-Installed($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}
# a candidate is either a command name or an absolute path (drive-letter prefix); any match counts as installed
function Test-Tool($candidates) {
    foreach ($c in $candidates) {
        $c = [Environment]::ExpandEnvironmentVariables($c)
        if ($c -match '^[A-Za-z]:\\') {
            if (Test-Path -LiteralPath $c) { return $true }
        } elseif (Test-Installed $c) {
            return $true
        }
    }
    return $false
}

if (Test-Installed pwsh -and $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Yellow "Running under Windows PowerShell 5.1: `$PROFILE points to the 5.1 location. Run this script with pwsh to link the pwsh 7 profile."
}

# --- npmrc variant: multi-drive (D:\NodeJS) vs single-drive ($HOME\NodeJS) ---
$npmrcWin = if (Test-Path -LiteralPath 'D:\NodeJS') {
    Join-Path $Dotfiles 'npm\npmrc_win_multidrive'
} else {
    Join-Path $Dotfiles 'npm\npmrc_win_singledrive'
}

# --- Link list, each line is fully self-contained: source|target|required-tool|candidates ---
#   tool column empty  -> always create
#   candidates column empty -> default to the tool name itself (a simple command check)
#   candidates are ;-separated command names and/or absolute paths (%VAR% expanded)
$Pairs = @"
$Dotfiles\.gitconfig|$Home\.gitconfig|
$Dotfiles\.condarc|$Home\.condarc|conda|conda;%USERPROFILE%\miniconda3;%USERPROFILE%\anaconda3;%USERPROFILE%\Miniconda3;%USERPROFILE%\Anaconda3;D:\MiniConda;C:\miniconda3;C:\ProgramData\miniconda3
$npmrcWin|$Home\.npmrc|node|node;nvm;npm
$Dotfiles\.wslconfig|$Home\.wslconfig|wsl|wsl;wsl.exe
$Dotfiles\posh\Microsoft.PowerShell_profile.ps1|$PowerShellProfile|pwsh|
$Dotfiles\config\btop\themes|$Home\.config\btop\themes|btop|
$Dotfiles\config\opencode|$Home\.config\opencode|opencode|
$Dotfiles\config\pip|$Home\.config\pip|pip|pip;pip3
$Dotfiles\config\wgetrc|$Home\.config\wgetrc|wget|
$Dotfiles\config\fish|$Home\.config\fish|fish|
$Dotfiles\config\pi\models.json|$Home\.pi\agent\models.json|pi|
$Dotfiles\config\pi\extensions\pi-permission-system\config.json|$Home\.pi\agent\extensions\pi-permission-system\config.json|pi|
$Dotfiles\config\pi\extensions\pi-model-fix\config.json|$Home\.pi\agent\extensions\pi-model-fix\config.json|pi|
$Dotfiles\config\pi\extensions\pi-custom-header\config.json|$Home\.pi\agent\extensions\pi-custom-header\config.json|pi|
$Dotfiles\config\pi\extensions\pi-crd233\pi-crd233.json|$Home\.pi\agent\extensions\pi-crd233\pi-crd233.json|pi|
$Dotfiles\config\pi\extensions\pi-crd233\pi-crd233.private.json|$Home\.pi\agent\extensions\pi-crd233\pi-crd233.private.json|pi|
$Dotfiles\config\pi\pi-vcc-config.json|$Home\.pi\agent\pi-vcc-config.json|pi|
"@

# Iterate lines in Pairs
$Pairs -split "`r?`n" | ForEach-Object {
    $Line = $_.Trim()
    if ([string]::IsNullOrWhiteSpace($Line)) { return }

    $Parts = $Line -split '\|'
    $Source = $Parts[0].Trim()
    $Target = $Parts[1].Trim()
    $Tool = if ($Parts.Count -gt 2) { $Parts[2].Trim() } else { '' }
    $Candidates = if ($Tool -and $Parts.Count -gt 3 -and $Parts[3].Trim()) { $Parts[3].Trim() -split ';' } else { @($Tool) }

    # 0. Skip if the required tool is not installed
    if ($Tool -and -not (Test-Tool $Candidates)) {
        Write-Yellow "$Tool not detected, skipping - $Target"
        return
    }

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
