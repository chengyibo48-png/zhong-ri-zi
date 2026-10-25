param([string]$GamePath = (Join-Path $PSScriptRoot "ZhongRiZi.exe"))
$ErrorActionPreference = "Stop"
$gameExecutable = [IO.Path]::GetFullPath($GamePath)
if (-not (Test-Path -LiteralPath $gameExecutable -PathType Leaf)) { throw "未找到游戏，请先保存 ZhongRiZi.exe。" }
$desktopDirectory = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopDirectory "种日子.lnk"
$shortcutShell = New-Object -ComObject WScript.Shell
if (Test-Path -LiteralPath $shortcutPath) {
    $existingShortcut = $shortcutShell.CreateShortcut($shortcutPath)
    if ($existingShortcut.TargetPath -ne $gameExecutable) {
        $shortcutPath = Join-Path $desktopDirectory "种日子（Godot版）.lnk"
    }
}
$shortcut = $shortcutShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $gameExecutable
$shortcut.WorkingDirectory = Split-Path $gameExecutable
$shortcut.Description = "种日子 · 双击开始你的田园生活"
$iconPath = Join-Path (Split-Path $gameExecutable) "app_icon.ico"
$shortcut.IconLocation = if (Test-Path -LiteralPath $iconPath) { $iconPath + ",0" } else { $gameExecutable + ",0" }
$shortcut.Save()
Write-Output ("已添加桌面图标：" + $shortcutPath)
