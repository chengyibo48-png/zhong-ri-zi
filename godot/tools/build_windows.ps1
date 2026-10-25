param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [string]$PythonPath="python"
)
$ErrorActionPreference="Stop"
$projectPath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$enginePath=[IO.Path]::GetFullPath($GodotPath)
$presetText=Get-Content -LiteralPath (Join-Path $projectPath "export_presets.cfg") -Raw -Encoding UTF8
$releaseMatch=[regex]::Match($presetText,'application/file_version="(\d+\.\d+\.\d+)\.\d+"')
if(-not $releaseMatch.Success){throw "Package version missing"}
$releaseVersion=$releaseMatch.Groups[1].Value
$temporaryRoot=[IO.Path]::GetFullPath((Join-Path $projectPath ".build/runtime-tmp"))
$exportTemporary=[IO.Path]::GetFullPath((Join-Path $temporaryRoot ("zrz-windows-export-"+[guid]::NewGuid().ToString("N"))))
if(-not $exportTemporary.StartsWith($temporaryRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "Unexpected temporary target"}
New-Item -ItemType Directory -Path $exportTemporary -Force | Out-Null
$previousTemporary=@{TEMP=$env:TEMP;TMP=$env:TMP}
try {
$env:TEMP=$exportTemporary
$env:TMP=$exportTemporary
if(-not (Test-Path -LiteralPath $enginePath -PathType Leaf)){throw "Godot executable not found"}
$version=(& $enginePath --headless --version | Out-String).Trim()
if($LASTEXITCODE -ne 0 -or -not $version.StartsWith("4.7.2.")){throw "This preset requires Godot 4.7.2"}
$templatePath=Join-Path $projectPath ".build/templates/windows_release_x86_64.exe"
if(-not (Test-Path -LiteralPath $templatePath)){
    & $PythonPath (Join-Path $PSScriptRoot "fetch_windows_template.py") (Split-Path $templatePath)
    if($LASTEXITCODE -ne 0){throw "Official Windows template download failed"}
}
$outputPath=Join-Path $projectPath "build/windows"
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
$buildLog=Join-Path $projectPath "build/windows-export.log"
$errorLog=Join-Path $projectPath "build/windows-export-error.log"
$exportArgs=@("--headless","--path",('"'+$projectPath+'"'),"--export-release",'"Windows Desktop"')
$exportProcess=Start-Process -FilePath $enginePath -ArgumentList $exportArgs -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $buildLog -RedirectStandardError $errorLog
if(Test-Path -LiteralPath $errorLog){Get-Content -LiteralPath $errorLog | Add-Content -LiteralPath $buildLog}
if($exportProcess.ExitCode -ne 0 -or (Select-String -LiteralPath $buildLog -Pattern "SCRIPT ERROR:|^ERROR:" -Quiet)){
    Get-Content -LiteralPath $buildLog -Tail 30
    throw "Godot Windows export failed"
}
# Resource data is embedded in the EXE. Remove only the obsolete named build file.
$obsoletePack=[IO.Path]::GetFullPath((Join-Path $outputPath "ZhongRiZi.pck"))
if((Split-Path $obsoletePack) -ne [IO.Path]::GetFullPath($outputPath)){throw "Unexpected build target"}
if(Test-Path -LiteralPath $obsoletePack){Remove-Item -LiteralPath $obsoletePack}
Copy-Item -LiteralPath (Join-Path $projectPath "art/app_icon.ico") -Destination (Join-Path $outputPath "app_icon.ico") -Force
Copy-Item -LiteralPath (Join-Path $projectPath "art/fonts/LICENSE-Noto-CJK.txt") -Destination (Join-Path $outputPath "LICENSE-Noto-CJK.txt") -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "install_desktop_shortcut.ps1") -Destination (Join-Path $outputPath "install_desktop_shortcut.ps1") -Force
@('@echo off', 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_desktop_shortcut.ps1"', 'if errorlevel 1 pause') | Set-Content -LiteralPath (Join-Path $outputPath "添加桌面快捷方式.cmd") -Encoding ascii
$instructions=@('《种日子》Windows 单机游戏', '', '双击 ZhongRiZi.exe 即可游玩。游戏资源已包含在 EXE 内，无需 Godot 或联网。', '首次双击“开始游戏.cmd”：自动创建桌面“种日子”图标，并启动游戏。以后直接双击桌面图标。', '也可以只双击“添加桌面快捷方式.cmd”来创建图标。', '添加快捷方式后，请保留本目录的位置；它不是将游戏复制到别处的安装程序。', '', '分享给别人：直接发送 ZhongRiZi.exe，对方保存后双击即可运行。', '完整 ZIP 另外附带许可证、版权声明、说明和快捷方式工具。', '', 'WASD 移动；E 互动；1–8 切换工具；B 背包；M 地图；J 任务手记；Tab 生活菜单。', '存档属于各自电脑。当前存档格式为 33，不提供旧版迁移；更新前请先导出个人存档。')
[IO.File]::WriteAllLines((Join-Path $outputPath "使用说明.txt"), $instructions, [Text.UTF8Encoding]::new($true))
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "start_game.cmd") -Destination (Join-Path $outputPath "开始游戏.cmd") -Force
$entries=@(Get-ChildItem -LiteralPath $outputPath -File | Where-Object { $_.Name -ne "manifest.json" } | ForEach-Object {
    @{name=$_.Name;bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
})
@{name="种日子 · Godot Windows";version=$releaseVersion;engine=$version;architecture="x86_64";save_schema=33;quest_schema=1;old_save_migration=$false;files=$entries} |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputPath "manifest.json") -Encoding utf8
$archivePath=Join-Path $projectPath "build/ZhongRiZi-Windows.zip"
Compress-Archive -Path (Join-Path $outputPath "*") -DestinationPath $archivePath -Force
Write-Output ("Windows build: "+$archivePath)
} finally {
    $env:TEMP=$previousTemporary.TEMP
    $env:TMP=$previousTemporary.TMP
    $resolvedTemporary=[IO.Path]::GetFullPath($exportTemporary)
    if((Split-Path $resolvedTemporary) -ne $temporaryRoot){throw "Unexpected temporary cleanup target"}
    if(Test-Path -LiteralPath $resolvedTemporary){Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force}
}
