from pathlib import Path
import os,sys,subprocess,time
root=Path(__file__).resolve().parents[1]
out=root/'artifacts/fishing-overhaul-20261017'
out.mkdir(parents=True,exist_ok=True)
env=os.environ.copy()
for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
 p=out/'sandbox'/str(os.getpid())/key;p.mkdir(parents=True,exist_ok=True);env[key]=str(p)
args=sys.argv[1:]
name='import' if '--editor' in args else next((Path(x).stem for x in args if x.endswith('.gd')),'run')
def decode(raw):
 try:return raw.decode('utf-8')
 except UnicodeDecodeError:return raw.decode('gb18030',errors='replace')
try:
 result=subprocess.run([str(root/'.build/export-engine/Godot.exe'),'--path',str(root),*args],env=env,capture_output=True,timeout=230)
 text=decode(result.stdout)+decode(result.stderr)
 (out/(name+'.log')).write_text(text,encoding='utf-8')
 print(text[-14000:]);print('EXIT',result.returncode)
 sys.exit(result.returncode or (1 if 'ERROR:' in text else 0))
except subprocess.TimeoutExpired as e:
 text=(e.stdout or b'').decode('utf-8',errors='replace')+(e.stderr or b'').decode('utf-8',errors='replace')
 (out/(name+'.log')).write_text(text,encoding='utf-8');print(text[-12000:]);print('TIMEOUT');sys.exit(1)
