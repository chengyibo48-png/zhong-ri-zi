"""Remove duplicated version strings from delivery scripts, retaining old reports."""
import ast,io,re,shutil,tokenize
from pathlib import Path
project=Path(__file__).resolve().parents[1]
backup=project/'artifacts/continuation-20261014/before';backup.mkdir(parents=True,exist_ok=True)
names=['finalize_release.py','finish_web_package.py','export_mobile.py','verify_mobile_packages.py','configure_mobile_exports.py']
for name in names:
    path=project/'tools'/name
    text=path.read_text(encoding='utf8')
    if 'from release_config import' in text: continue
    shutil.copy2(path,backup/name)
    tokens=[]
    for token in tokenize.generate_tokens(io.StringIO(text).readline):
        if token.type==tokenize.STRING and '0.26.0' in token.string:
            raw=token.string.replace('0.26.0','{VERSION}').replace('20261014-{VERSION}','{RELEASE_DATE}-{VERSION}').replace('version/code=260','version/code={VERSION_CODE}')
            token=token._replace(string='f'+raw)
        tokens.append(token)
    text=tokenize.untokenize(tokens)
    text=text.replace('from pathlib import Path','from pathlib import Path\nfrom release_config import VERSION, VERSION_CODE, RELEASE_DATE',1)
    if name=='verify_mobile_packages.py':
        text=text.replace('quality-20261014/mobile-package-verification.json','continuation-20261014/mobile-package-verification.json')
        text=text.replace('and f"versionName=\'{VERSION}\'" in metadata','and f"versionName=\'{VERSION}\'" in metadata and f"versionCode=\'{VERSION_CODE}\'" in metadata')
    if name=='finalize_release.py':
        text=text.replace('from pathlib import Path','from verify_migration import fingerprint\nfrom pathlib import Path',1)
        text=text.replace("'engine':'4.7.2-stable.ed1daf0bf'","'engine':'4.7.2-stable.ed1daf0bf','production_sha256':fingerprint()")
    ast.parse(text)
    path.write_text(text,encoding='utf8')
path=project/'tools/build_windows.ps1'
text=path.read_text(encoding='utf8')
if '$releaseVersion' not in text:
    shutil.copy2(path,backup/path.name)
    marker='$enginePath=[IO.Path]::GetFullPath($GodotPath)'
    config='\n$presetText=Get-Content -LiteralPath (Join-Path $projectPath "export_presets.cfg") -Raw -Encoding UTF8\n$releaseMatch=[regex]::Match($presetText,\'application/file_version="(\\d+\\.\\d+\\.\\d+)\\.\\d+"\')\nif(-not $releaseMatch.Success){throw "Package version missing"}\n$releaseVersion=$releaseMatch.Groups[1].Value'
    text=text.replace(marker,marker+config,1).replace('version="0.26.0"','version=$releaseVersion')
    path.write_text(text,encoding='utf8')
presets=project/'export_presets.cfg'
text=presets.read_text(encoding='utf8')
shutil.copy2(presets,backup/presets.name)
text=text.replace('0.26.0','0.26.1').replace('version/code=260','version/code=261')
presets.write_text(text,encoding='utf8')
print('Shared delivery version configured: 0.26.1 / Android code 261')
