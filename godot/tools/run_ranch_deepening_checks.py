"""Native Godot gate; independent of the legacy npm/JavaScript suite. Never exports."""
from pathlib import Path
import argparse,os,subprocess,tempfile,time,json,re
ROOT=Path(__file__).resolve().parents[1]
UNIT=['ranch_nurture_smoke','ranch_deepening_reliability','ranch_meadow_smoke','ranch_fishing_regression','save_atomic_smoke','ranch_quest_regression','five_stage_contact_smoke']
GPU=['animal_layers_render','ranch_deepening_render','ranch_meadow_render','ranch_touch_render','ranch_birth_render']
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--godot',type=Path,default=ROOT/'.build/export-engine/Godot_console.exe');parser.add_argument('--gpu',action='store_true');parser.add_argument('--movies',action='store_true');parser.add_argument('--only',nargs='+');parser.add_argument('--output',type=Path,default=ROOT/'artifacts/ranch-native-gate');args=parser.parse_args()
 output=args.output.resolve();output.mkdir(parents=True,exist_ok=True);(output/'.gdignore').touch();results=[]
 checks=args.only or UNIT+(GPU if args.gpu else [])
 for name in checks:
  if name not in UNIT+GPU:parser.error('Unknown check: '+name)
  started=time.monotonic();log=output/(name+'.log');scratch=Path(tempfile.mkdtemp(prefix='isolated-',dir=output));env=os.environ.copy()
  for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
   target=scratch/key if key not in ['TEMP','TMP'] else scratch;target.mkdir(parents=True,exist_ok=True);env[key]=str(target)
  env['ZRZ_FORCE_TOUCH']='1' if name=='ranch_touch_render' else '0';env['ZRZ_RANCH_MOVIES']='1' if args.movies else '0';env['ZRZ_ART_OUTPUT']=str(output);env['ZRZ_REVIEW_STAGE']='gate'
  cmd=[str(args.godot),'--path',str(ROOT),'--script','res://tools/'+name+'.gd']
  if name not in GPU:cmd.insert(1,'--headless')
  code=-1
  with log.open('wb') as stream:
   proc=subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
   while proc.poll() is None:
    text=log.read_text(encoding='utf8',errors='replace')
    if time.monotonic()-started>300 or re.search(r'SCRIPT ERROR:|(?m:^ERROR:)',text):proc.kill();break
    time.sleep(.2)
   code=proc.wait()
  text=log.read_text(encoding='utf8',errors='replace');ok=code==0 and not re.search(r'SCRIPT ERROR:|(?m:^ERROR:)|(?m:^FAIL )',text)
  results.append({'check':name,'ok':ok,'exit':code,'seconds':round(time.monotonic()-started,2),'log':str(log)})
  (output/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf8');print(name,'PASS' if ok else 'FAIL',flush=True)
  if not ok:return 1
 return 0
if __name__=='__main__':raise SystemExit(main())
