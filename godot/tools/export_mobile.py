"""Build browser and signed Android artifacts using project-local dependencies."""
import argparse,json,os,subprocess,shutil
from pathlib import Path
from release_config import VERSION, VERSION_CODE, RELEASE_DATE
from project_temporary import temporary_directory
project=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('target',choices=['Web','Android']);parser.add_argument('--variant',action='store_true');args=parser.parse_args()
source=project/'.build'/('web-project' if args.target=='Web' else 'mobile-project') if args.variant else project
if args.variant:
    for folder in ['scripts','scenes','data']:shutil.copytree(project/folder,source/folder,dirs_exist_ok=True)
    shutil.copy2(project/'project.godot',source/'project.godot')
    presets=(project/'export_presets.cfg').read_text(encoding='utf8').replace('res://.build/templates/',str(project/'.build/templates').replace('\\','/')+'/')
    (source/'export_presets.cfg').write_text(presets,encoding='utf8')
env=os.environ.copy()
if args.target=='Android':
    private=json.loads((project/'.build/android-signing/release-signing.json').read_text(encoding='utf8'))
    env['GODOT_ANDROID_KEYSTORE_RELEASE_PATH']=str(project/'.build/android-signing/zhongrizi.keystore')
    env['GODOT_ANDROID_KEYSTORE_RELEASE_USER']=private['alias']
    env['GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD']=private['password']
output=project/'build'/('web/index.html' if args.target=='Web' else f'android/ZhongRiZi-{VERSION}.apk')
log=project/'artifacts'/os.environ.get('ZRZ_EXPORT_LOG','quality-export-'+args.target.lower()+'-20261014.log')
with temporary_directory(prefix='zrz-export-') as temporary, log.open('wb') as stream:
    env.update(TEMP=temporary,TMP=temporary,APPDATA=str(Path(temporary)/'appdata'),LOCALAPPDATA=str(Path(temporary)/'localappdata'))
    result=subprocess.run([str(project/'.build/export-engine/Godot.exe'),'--headless','--path',str(source),'--export-release',args.target,str(output)],env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=1800,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
content=log.read_text(encoding='utf8',errors='replace')
print(content[-5000:])
if result.returncode or 'SCRIPT ERROR:' in content or '\nERROR:' in content:raise SystemExit(result.returncode or 1)
print('EXPORTED '+str(output))
