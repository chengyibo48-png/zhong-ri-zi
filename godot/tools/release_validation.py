"""Run release validation in isolated saves, retaining this release's own evidence."""
import json,os,re,subprocess,sys,time,tempfile,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/release-20261017'
ENGINE=ROOT/'.build/export-engine/Godot.exe'
HEADLESS=['ui_quest_rules','ui_quest_content','ui_quest_seasons','ui_quest_walk','ranch_overhaul_smoke','kitchen_smoke','economy_smoke','farming_soil_smoke','farming_redesign_smoke','fishing_overhaul_smoke','fishing_content_integration','farm_grid_7x7_smoke']
GPU=['ui_quest_gpu','ui_quest_extra_gpu','ui_quest_touch','ui_quest_extra_touch','ui_quest_all_touch','ui_quest_map_gpu','ui_quest_final_capture']
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 checks=OUT/'checks';checks.mkdir(exist_ok=True)
 for name in HEADLESS+GPU:
  text=(ROOT/'tools'/f'{name}.gd').read_text(encoding='utf8')
  folders=set(re.findall(r'res://artifacts/([^/"\n]+)',text))
  for folder in folders:
   (OUT/'evidence'/folder).mkdir(parents=True,exist_ok=True)
   text=text.replace('res://artifacts/'+folder+'/', 'res://artifacts/release-20261017/evidence/'+folder+'/')
  for other in GPU:text=text.replace('res://tools/'+other+'.gd','res://artifacts/release-20261017/checks/'+other+'.gd')
  (checks/f'{name}.gd').write_text(text,encoding='utf8')
 gpu_only="--gpu" in sys.argv
 results=[x for x in json.loads((OUT/"tests.json").read_text(encoding="utf8")) if x["name"] in HEADLESS] if gpu_only else []
 for name in (GPU if gpu_only else HEADLESS+GPU):
  start=time.monotonic()
  tmp=ROOT/'.build/runtime-tmp';tmp.mkdir(exist_ok=True)
  with tempfile.TemporaryDirectory(prefix='release-',dir=tmp) as t:
   env=os.environ.copy();env.update({k:str(Path(t)/k) for k in ['APPDATA','LOCALAPPDATA','TEMP','TMP']})
   for k in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:Path(env[k]).mkdir()
   env.pop('ZRZ_FORCE_TOUCH',None)
   if 'touch' in name:env['ZRZ_FORCE_TOUCH']='1'
   cmd=[str(ENGINE),'--path',str(ROOT),'--script',str(checks/f'{name}.gd')]
   if name in HEADLESS:cmd.insert(1,'--headless')
   print('RUN '+name,flush=True)
   try:
    p=subprocess.run(cmd,env=env,cwd=ROOT,capture_output=True,timeout=260,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    log=(p.stdout+p.stderr).decode('utf8',errors='replace');code=p.returncode
   except subprocess.TimeoutExpired as e:
    log=((e.stdout or b'')+(e.stderr or b'')).decode('utf8',errors='replace')+'\nTIMEOUT';code=124
   (OUT/f'{name}.log').write_text(log,encoding='utf8')
   counts=re.findall(r'(\d+) passed, (\d+) failed',log)
   ok=code==0 and bool(counts) and all(int(f)==0 for _,f in counts) and not re.search(r'SCRIPT ERROR:|(?m:^ERROR:)|TIMEOUT|WARNING: ObjectDB|resources still in use',log)
   row=dict(name=name,passed=int(counts[-1][0]) if counts else 0,failed=int(counts[-1][1]) if counts else 1,exitCode=code,ok=ok,seconds=round(time.monotonic()-start,1),logSha256=hashlib.sha256((OUT/f'{name}.log').read_bytes()).hexdigest())
   results.append(row);(OUT/'tests.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf8')
   print(json.dumps(row),flush=True)
   if not ok:print(log[-8000:]);return 1
 print('RELEASE_TESTS_PASSED '+str(sum(x['passed'] for x in results)),flush=True)
 return 0
if __name__=='__main__':sys.exit(main())
