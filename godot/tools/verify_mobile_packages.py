"""Check exact browser ZIP bytes, Android signatures, alignment and package metadata."""
import hashlib,json,os,subprocess,zipfile
from pathlib import Path
from release_config import VERSION, VERSION_CODE, RELEASE_DATE
project=Path(__file__).resolve().parents[1]
release=project/f'build/releases/{RELEASE_DATE}-{VERSION}'
web=project/'build/web';archive=release/f'种日子-Web-{VERSION}.zip'
manifest=json.loads((web/'manifest.json').read_text(encoding='utf8'))
with zipfile.ZipFile(archive) as z:
    assert set(z.namelist())=={'manifest.json',*(row['name'] for row in manifest['files'])}
    for row in manifest['files']:
        data=z.read(row['name'])
        assert len(data)==row['bytes'] and hashlib.sha256(data).hexdigest()==row['sha256']
        assert data==(web/row['name']).read_bytes()
    assert 'variant/thread_support' not in z.read('index.html').decode() # HTML config is authoritative below.
    assert 'const GODOT_THREADS_ENABLED = false;' in z.read('index.html').decode()
apk=project/f'build/android/ZhongRiZi-{VERSION}.apk'
sdk=project/'.build/android-sdk/build-tools/35.0.1'
env=os.environ.copy();env['JAVA_HOME']=str(project/'.build/jdk17');env['PATH']=str(project/'.build/jdk17/bin')+os.pathsep+env['PATH']
def command(args):
    result=subprocess.run(args,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    content=result.stdout.decode('utf8',errors='replace')
    if result.returncode:raise RuntimeError(content)
    return content
signature=command(['cmd','/c',str(sdk/'apksigner.bat'),'verify','--verbose','--print-certs',str(apk)])
alignment=command([str(sdk/'zipalign.exe'),'-c','-P','16','-v','4',str(apk)])
metadata=command([str(sdk/'aapt2.exe'),'dump','badging',str(apk)])
assert "name='org.zhongrizi.game'" in metadata and f"versionName='{VERSION}'" in metadata and f"versionCode='{VERSION_CODE}'" in metadata
with zipfile.ZipFile(apk) as z:
    names=z.namelist()
    assert any(name.startswith('lib/arm64-v8a/') for name in names)
    assert any(name.startswith('lib/armeabi-v7a/') for name in names)
    assert not any(name.startswith(('assets/.build/','assets/artifacts/','assets/tools/')) for name in names)
    assert 'assets/art/fonts/LICENSE-Noto-CJK.txt' in names
receipt={'web_zip':str(archive),'web_files_verified':len(manifest['files']),'apk':str(apk),'apk_bytes':apk.stat().st_size,'apk_sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'signature':signature,'alignment_verified':True,'metadata':metadata,'scope':'Packaging, signature and ABI checks only; not physical Android or iPhone certification.'}
(project/os.environ.get('ZRZ_PACKAGE_RECEIPT','artifacts/continuation-20261014/mobile-package-verification.json')).write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf8')
print('MOBILE_PACKAGES_VERIFIED '+str(len(manifest['files']))+' web files, signed Android APK, 16 KiB alignment')
