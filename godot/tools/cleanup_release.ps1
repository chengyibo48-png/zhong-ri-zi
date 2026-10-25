$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidence=Join-Path $project 'artifacts/release-20261017'
if(Test-Path -LiteralPath (Join-Path $evidence 'cleanup-completed.json')){throw 'This one-shot cleanup is already complete; do not reuse the old plan.'}
$plan=Get-Content -LiteralPath (Join-Path $evidence 'cleanup-plan.json') -Raw | ConvertFrom-Json
$permitted=@('.build/temp-archive','.build/mobile-project','.build/web-project','.build/browser-profile-continuation','.build/downloads','build/portfolio-0.29.0','build/ZhongRiZi-Windows.zip','build/种日子-游戏作品集-轻量投递版.zip') | ForEach-Object {[IO.Path]::GetFullPath((Join-Path $project $_))}
$runtime=[IO.Path]::GetFullPath((Join-Path $project '.build/runtime-tmp'))
$validated=@()
foreach($row in $plan){
 $path=[IO.Path]::GetFullPath($row.path)
 $runtimeFixture=(Split-Path $path) -eq $runtime -and (Split-Path $path -Leaf).StartsWith('zrz-verify-')
 if(-not $path.StartsWith($project+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or ($permitted -notcontains $path -and -not $runtimeFixture)){throw ('Unexpected cleanup target '+$path)}
 if(Test-Path -LiteralPath $path){
  $item=Get-Item -LiteralPath $path -Force
  if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Refuse top-level reparse point'}
 }
 $validated+=@{path=$path;bytes=$row.bytes;files=$row.files;reason=$row.reason}
}
$deleted=@()
foreach($row in $validated){
 if(Test-Path -LiteralPath $row.path){
  Remove-Item -LiteralPath $row.path -Recurse -Force
  if(Test-Path -LiteralPath $row.path){throw ('Cleanup incomplete '+$row.path)}
  $deleted+=$row
  $deleted | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'cleanup-completed.json') -Encoding utf8
  Write-Output ('Removed '+$row.path)
 }
}
Write-Output ('Cleanup bytes: '+(($deleted | Measure-Object bytes -Sum).Sum))
