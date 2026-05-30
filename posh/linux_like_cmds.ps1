# Linux-like useful functions

# ln creates hard/soft link in linux
function ln {
    [CmdletBinding()]
    param(
        [Switch]$s,
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Source,
        [Parameter(Position = 1, Mandatory = $false)]
        [string]$Target
    )

    process {
        if ([string]::IsNullOrWhiteSpace($Target)) { # without target, treat as same name with source
            $Target = Join-Path (Get-Location) (Split-Path $Source -Leaf)
        }

        $fullSource = Resolve-Path -Path $Source -ErrorAction SilentlyContinue
        if ($null -eq $fullSource) { $fullSource = $Source }
        $isFolder = Test-Path -Path $fullSource -PathType Container

        if ($s) { # soft link
            New-Item -ItemType SymbolicLink -Path $Target -Value $fullSource
        } else { # hard link
            if ($isFolder) { # hard link for folder is not supported, fallback to junction
                Write-Host "Detected directory, creating Junction..." -ForegroundColor Cyan
                New-Item -ItemType Junction -Path $Target -Value $fullSource
            } else {
                New-Item -ItemType HardLink -Path $Target -Value $fullSource
            }
        }
    }
}


# helper function to determine file type and return colored name
function Get-FormattedName {
    param($Item, [switch]$ShowTarget)
    $reset = $PSStyle.Reset
    $name = $Item.Name
    $color = $PSStyle.Foreground.White

    # folder -> bright blue
    if ($Item.PSIsContainer) {
        $color = $PSStyle.Foreground.BrightBlue
    }
    # executable files -> green
    if ($Item.Extension -match '\.(exe|bat|cmd|ps1|vbs|lnk|sh|py|bin)$') {
        $color = $PSStyle.Foreground.BrightGreen
    }
    # compressed files -> red
    if ($Item.Extension -match '\.(zip|7z|rar|tar|gz|bz2|xz|iso|deb|rpm)$') {
        $color = $PSStyle.Foreground.BrightRed
    }
    # media files -> magenta
    if ($Item.Extension -match '\.(jpg|jpeg|png|gif|bmp|webp|svg|mp4|mkv|avi|flv|mp3|wav|flac|ogg)$') {
        $color = $PSStyle.Foreground.Magenta
    }
    # symlink / junction -> cyan
    if ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        $color = $PSStyle.Foreground.Cyan
        if ($ShowTarget) {
            $target = $Item.LinkTarget
            if ($null -eq $target) {
                $target = (Get-Item $Item.FullName).Target
            }
            $name += " -> $($PSStyle.Foreground.BrightCyan)$target$reset"
        }
    }
    return "$color$name$reset"
}


# ===== ls/ll/la =====
if (Test-Path Alias:ls) { Remove-Item Alias:ls -Force }

# helper function to calculate display width of a string
function Get-DisplayWidth {
    param([string]$Text)
    $width = 0
    foreach ($char in $Text.ToCharArray()) { # Chinese characters are usually double width
        if ([int]$char -gt 127) { $width += 2 } else { $width += 1 }
    }
    return $width
}

# helper function to format colored file name as table cell
function Out-WideGrid {
    param($Items)
    if (-not $Items) { return }

    # get console width, calculate the maximum display width among all items, and determine how many columns can fit in the console
    $consoleWidth = $Host.UI.RawUI.WindowSize.Width
    $maxDisplayWidth = ($Items | ForEach-Object { Get-DisplayWidth $_.Name } | Measure-Object -Maximum).Maximum + 3
    $columns = [Math]::Floor($consoleWidth / $maxDisplayWidth)
    if ($columns -lt 1) { $columns = 1 }

    $i = 0
    foreach ($item in $Items) {
        $formatted = Get-FormattedName $item
        $visualWidth = Get-DisplayWidth $item.Name
        $i++

        if ($i -eq $columns) { # last column, write and newline
            Write-Host "$formatted"
            $i = 0
        } else { # not last column, write and padding spaces to align
            $padding = " " * ($maxDisplayWidth - $visualWidth)
            Write-Host "$formatted$padding" -NoNewline
        }
    }
    if ($i -ne 0) { Write-Host "" }
}

function ls {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments=$true)]$Args)
    # filter out hidden files (note: windows use hidden attribute, not name starting with a dot)
    $items = Get-ChildItem @Args | Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::Hidden) -eq 0 }
    Out-WideGrid $items
}

function ll {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments=$true)]$Args)
    $items = Get-ChildItem -Force @Args
    if ($items) {
        $items | Format-Table `
            @{Expression={$_.Mode}; Label="Mode"; Width=7},
            @{Expression={$_.LastWriteTime.ToString("yyyy/MM/dd HH:mm")}; Label="LastWriteTime"; Width=18},
            @{Expression={if($_.PSIsContainer){""}else{$_.Length}}; Label="Length"; Width=10},
            @{Expression={Get-FormattedName $_ -ShowTarget}; Label="Name"} -AutoSize
    }
}

Set-Alias -Name la -Value ll  # la


# custom tree implementation
function tree {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path = ".",
        [int]$L = [int]::MaxValue, # depth limit, default to unlimited
        [Switch]$d                 # only show directories
    )

    $resolvedPath = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $resolvedPath) { $resolvedPath = $Path }
    $rootItem = Get-Item $resolvedPath

    Write-Host "$($PSStyle.Foreground.BrightCyan + $PSStyle.Bold)$(Split-Path $resolvedPath -Leaf)$($PSStyle.Reset)"

    function Show-TreeInner {  # core recursive function to display tree structure
        param($CurrentFolder, [int]$CurrentDepth, [int]$MaxDepth, [string]$Indent, [bool]$DirsOnly)

        if ($CurrentDepth -gt $MaxDepth) { return }

        $items = Get-ChildItem -LiteralPath $CurrentFolder.FullName -ErrorAction SilentlyContinue |
            Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::Hidden) -eq 0 }

        if ($DirsOnly) { $items = $items | Where-Object { $_.PSIsContainer } }

        $items = @($items)
        $count = $items.Count

        for ($i = 0; $i -lt $count; $i++) {
            $item = $items[$i]
            $isLast = ($i -eq ($count - 1))
            $branch = $isLast ? "└── " : "├── "

            $coloredName = Get-FormattedName $item
            Write-Host "$Indent$branch$coloredName"

            if ($item.PSIsContainer) {
                $suffix = $isLast ? "    " : "│   "
                Show-TreeInner -CurrentFolder $item -CurrentDepth ($CurrentDepth + 1) -MaxDepth $MaxDepth -Indent ($Indent + $suffix) -DirsOnly $DirsOnly
            }
        }
    }

    Show-TreeInner -CurrentFolder $rootItem -CurrentDepth 1 -MaxDepth $L -Indent "" -DirsOnly $d
}
