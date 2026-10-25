param([switch]$Additional)
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE 'AppData\Local\Temp'))
$archive = [IO.Path]::GetFullPath((Join-Path $project '.build\temp-archive\20261014'))
if ([IO.Path]::GetPathRoot($archive) -ne 'D:\') { throw 'Archive must be on D drive' }
if (-not $archive.StartsWith($project + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Archive outside project' }
$active = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -match '^(python|Godot.*|ZhongRiZi)\.exe$' -and
    $_.CommandLine -match 'verify_migration\.py|run_isolated\.py|verify_windows_package\.py|verify_actual_exe\.py|zrz-(verify|check|package|actual-exe)-'
})
if ($active.Count) { throw 'Project checks are still using temporary data' }
$pattern = if ($Additional) { '^zrz-(art-import|art-render|export-check|fine-runtime|gameplay-gpu|hud-package|hud-preview|native-start|profile|release-start)-' } else { '^zrz-(verify|check|package|actual-exe)-' }
$dirs = @(Get-ChildItem -LiteralPath $sourceRoot -Directory -Force | Where-Object { $_.Name -match $pattern })
New-Item -ItemType Directory -Path $archive -Force | Out-Null
$manifests = Join-Path $archive '_manifests'
New-Item -ItemType Directory -Path $manifests -Force | Out-Null
$receiptName = if ($Additional) { 'temp-migration-extra-20261014.json' } else { 'temp-migration-20261014.json' }
$receiptPath = Join-Path $project ('artifacts\' + $receiptName)
$rows = [Collections.Generic.List[object]]::new()
$before = (Get-PSDrive C).Free
$totalBytes = 0L
$totalFiles = 0
foreach ($dir in $dirs) {
    $source = [IO.Path]::GetFullPath($dir.FullName)
    $destination = [IO.Path]::GetFullPath((Join-Path $archive $dir.Name))
    if ([IO.Path]::GetDirectoryName($source) -ne $sourceRoot -or $dir.Name -notmatch $pattern) { throw 'Unexpected source directory' }
    if ([IO.Path]::GetDirectoryName($destination) -ne $archive) { throw 'Unexpected destination directory' }
    $entries = @(Get-ChildItem -LiteralPath $source -Recurse -Force)
    if (($dir.Attributes -band [IO.FileAttributes]::ReparsePoint) -or @($entries | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw "Reparse point in $source" }
    $files = @($entries | Where-Object { -not $_.PSIsContainer })
    $expected = @($files | ForEach-Object {
        [pscustomobject]@{path=$_.FullName.Substring($source.Length + 1);bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    })
    if (-not (Test-Path -LiteralPath $destination)) {
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    }
    $copied = @(Get-ChildItem -LiteralPath $destination -File -Recurse -Force)
    if ($copied.Count -ne $files.Count) { throw "Copy file count differs: $source" }
    foreach ($item in $expected) {
        $target = Join-Path $destination $item.path
        if ((Get-Item -LiteralPath $target).Length -ne $item.bytes -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.sha256) { throw "Copy verification failed: $target" }
    }
    $manifest = [pscustomobject]@{source=$source;destination=$destination;files=$expected}
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $manifests ($dir.Name + '.json')) -Encoding UTF8
    # Both absolute paths were checked above; remove only after every file matches.
    Remove-Item -LiteralPath $source -Recurse -Force
    $size = 0L
    foreach ($item in $expected) { $size += $item.bytes }
    $totalBytes += $size
    $totalFiles += $files.Count
    $rows.Add([pscustomobject]@{name=$dir.Name;files=$files.Count;bytes=$size;sha256_verified=$true})
    if ($rows.Count % 50 -eq 0 -or $rows.Count -eq $dirs.Count) {
        [pscustomobject]@{source_root=$sourceRoot;archive=$archive;directories=$rows.Count;files=$totalFiles;bytes=$totalBytes;c_free_before=$before;c_free_after=(Get-PSDrive C).Free;complete=($rows.Count -eq $dirs.Count);items=@($rows.ToArray())} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
        Write-Output ("Moved {0}/{1}, {2:N2} GiB; all files SHA-256 verified" -f $rows.Count,$dirs.Count,($totalBytes / 1GB))
    }
}
Write-Output "Receipt: $receiptPath"
