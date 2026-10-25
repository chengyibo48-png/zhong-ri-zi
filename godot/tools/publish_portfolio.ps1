$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidence=Join-Path $project 'artifacts/release-20261017'
$stage=[IO.Path]::GetFullPath((Join-Path $project 'build/portfolio-0.29.0'))
$portfolioRoot=[IO.Path]::GetFullPath('D:/作品集')
$target=[IO.Path]::GetFullPath((Join-Path $portfolioRoot '种日子-游戏作品集'))
if((Split-Path $target) -ne $portfolioRoot -or (Split-Path $stage) -ne (Join-Path $project 'build')){throw 'Unexpected target'}
$backup=Get-Content -LiteralPath (Join-Path $evidence 'portfolio-backup.json') -Raw | ConvertFrom-Json
if((Get-FileHash -LiteralPath $backup.archive).Hash.ToLowerInvariant() -ne $backup.archiveSha256){throw 'Backup hash mismatch'}
if((Get-FileHash -LiteralPath $backup.priorGameRetained).Hash.ToLowerInvariant() -ne $backup.priorGameSha256){throw 'Retained prior game mismatch'}
$tests=Get-Content -LiteralPath (Join-Path $evidence 'tests.json') -Raw | ConvertFrom-Json
if($tests.Count -ne 19 -or @($tests | Where-Object {-not $_.ok}).Count -gt 0){throw 'Release tests incomplete'}
# Merge files; never remove the existing portfolio tree.
Get-ChildItem -LiteralPath $stage -Force | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force}
$manifest=Get-Content -LiteralPath (Join-Path $target '核心源码与说明/文件校验清单.json') -Raw | ConvertFrom-Json
foreach($file in $manifest.files){
 $path=[IO.Path]::GetFullPath((Join-Path $target $file.path))
 if(-not $path.StartsWith($target+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe manifest path'}
 if((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -ne $file.sha256){throw ('New file mismatch '+$file.path)}
}
$removed=@()
$stale=Get-Content -LiteralPath (Join-Path $evidence 'portfolio-stale-files.json') -Raw | ConvertFrom-Json
foreach($file in $stale){
 $path=[IO.Path]::GetFullPath($file.path)
 if(-not $path.StartsWith($target+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe stale path'}
 if(Test-Path -LiteralPath $path -PathType Leaf){
  if((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -ne $file.sha256){throw 'Stale file changed; preserve it'}
  Remove-Item -LiteralPath $path -Force
  $removed+=@{path=$path;bytes=$file.bytes;retained=$file.retained}
 }
}
$light=Join-Path $project 'build/种日子-游戏作品集-轻量投递版.zip'
$lightTarget=Join-Path $portfolioRoot '种日子-游戏作品集-轻量投递版.zip'
Copy-Item -LiteralPath $light -Destination $lightTarget -Force
if((Get-FileHash -LiteralPath $light).Hash -ne (Get-FileHash -LiteralPath $lightTarget).Hash){throw 'Light archive mismatch'}
$removed | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'portfolio-cleanup.json') -Encoding utf8
Write-Output ('Merged and verified portfolio; removed '+$removed.Count+' backed-up obsolete files.')
