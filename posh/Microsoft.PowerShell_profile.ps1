Import-Module DirColors
Import-Module PSReadLine  # 这个工具主要做命令提示管理等操作，默认集成在了 PowerShell 中，不需要安装
Set-PSReadLineOption -PredictionSource History # 设置预测文本来源为历史记录
Set-PSReadlineKeyHandler -Chord Tab -Function MenuComplete # 类似 zsh 的带菜单补全
Set-PSReadlineKeyHandler -Chord Ctrl+x,Ctrl+X -Function DeleteLine # 清空整行

# 下面这些都已集成在 powershell7 中了
# Set-PSReadlineKeyHandler -Key Tab -Function Complete  # 设置 Tab 键补全
# Set-PSReadLineKeyHandler -Key "Ctrl+z" -Function Undo  # 设置 Ctrl+Z 为撤销
# Set-PSReadLineKeyHandler -Key UpArrow -ScriptBlock {
# [Microsoft.PowerShell.PSConsoleReadLine]::HistorySearchBackward()
# [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
# } # 设置向上键为后向搜索历史记录，并将光标移动到行尾
# Set-PSReadLineKeyHandler -Key DownArrow -ScriptBlock {
# [Microsoft.PowerShell.PSConsoleReadLine]::HistorySearchForward()
# [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
# } # 设置向下键为前向搜索历史纪录，并将光标移动到行尾

# Set-PSReadLineOption -BellStyle Audible -DingTone 1221 -DingDuration 60 # 设置为以 1221 Hz 发出 60 毫秒的可听觉蜂鸣声
Set-PSReadLineOption -Colors @{
#   Command            = 'Magenta'
#   Number             = 'Green'
#   Member             = 'Green'
#   Operator           = 'Yellow'
#   Type               = 'Green'
#   Variable           = 'Yellow'
  Parameter          = 'Green'
#   ContinuationPrompt = 'Green'
#   Default            = 'Green'
  InlinePrediction   = "#438a55"
}

# 别名设置
set-alias -Name cl -Value clear
set-alias -Name vi -Value vim
set-alias -Name la -Value "Get-ChildItem -Force"
set-alias -Name conda -Value (Join-Path $HOME 'dotfiles\posh\conda_posh_lazy.ps1') # lazy load conda initialization

# 函数设置
function work {
    Set-Location -Path "D:\documents"
}
function site {
    Set-Location -Path "D:\documents\site"
}
function countSize {
    Get-ChildItem -Directory | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        [PSCustomObject]@{
            Folder = $_.Name
            "Size(GB)" = "{0:N2}" -f ($size / 1GB)
        }
    } | Sort-Object -Property "Size(GB)" -Descending
}

# 网络代理设置
$env:HTTP_PROXY="http://127.0.0.1:7890/"
$env:HTTPS_PROXY="http://127.0.0.1:7890/"  # 注意，极有可能这里就是 http，不需要改成 https

$ompTheme = Join-Path $HOME 'dotfiles\posh\tokyo_modified.omp.json'
oh-my-posh init pwsh --config $ompTheme | Invoke-Expression  # 设置主题，可以去 https://ohmyposh.dev/docs/themes 找

# 设置字符编码为 UTF-8，我也不知道为什么要做两个设置，但是这样才能正常显示中文
[Console]::OutputEncoding = [System.Text.Encoding]::Default
chcp 65001 > $null


#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module
# Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58


# temp
function Set-TrellisEnv {
    $projectPath = "e:\v37_py311_trellis_stableprojectorz"
    $venvPath = "$projectPath\code\venv"

    if (Test-Path "$venvPath\Scripts\Activate.ps1") {
        & "$venvPath\Scripts\Activate.ps1"
        Write-Host "Trellis Python environment activated" -ForegroundColor Green
        Write-Host "Python version: $(python --version)" -ForegroundColor Cyan
    } else {
        Write-Host "Virtual environment not found at $venvPath" -ForegroundColor Red
    }
}
Set-Alias -Name trellis -Value Set-TrellisEnv