"""Native v38 acceptance entry; every run uses an isolated user directory."""
from pathlib import Path
import argparse,os,re,subprocess,tempfile,time,json
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--engine',type=Path,default=root/'.build/export-engine/Godot_console.exe');parser.add_argument('--visual',action='store_true');parser.add_argument('--output',type=Path);parser.add_argument('--normal-routes',action='store_true');args=parser.parse_args()
output=args.output or root/'artifacts/village-growth-20261030/verification';output.mkdir(parents=True,exist_ok=True);(output.parent/'.gdignore').write_text('')
suite=[('core','village_growth_check.gd'),('transactions','village_transaction_check.gd'),('content','village_content_check.gd'),('layout','village_layout_check.gd'),('audio-save','village_audio_save_check.gd'),('fishing','fishing_tension_smoke.gd'),('outfits','wardrobe_art_smoke.gd'),('story-settlements','village_story_settlement.gd'),('animal-lifecycles','village_animal_lifecycle.gd')]
if args.normal_routes:suite += [('normal-'+kind,'village_normal_route.gd') for kind in ['plant','fish','animal','neighbor']]
if args.visual:suite += [('ui','village_house_ui.gd'),('animal-models','animal_whole_review.gd')]
results=[]
for name,script in suite:
 scratch=Path(tempfile.mkdtemp(prefix='isolated-',dir=output));env=os.environ.copy()
 for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
  path=scratch/key if key not in ['TEMP','TMP'] else scratch;path.mkdir(parents=True,exist_ok=True);env[key]=str(path)
 env['ZRZ_ART_OUTPUT']=str(output)
 if name.startswith('normal-'):env['ZRZ_ROUTE']=name.removeprefix('normal-')
 cmd=[str(args.engine),'--path',str(root),'--script','res://tools/'+script]
 if name not in ['ui','animal-models']:cmd.insert(1,'--headless')
 start=time.monotonic();log=output/(name+'.log')
 with log.open('wb') as stream:
  process=subprocess.Popen(cmd,cwd=root,env=env,stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
  while process.poll() is None:
   text=log.read_text(encoding='utf8',errors='replace')
   if time.monotonic()-start>(600 if name.startswith('normal-') else 240) or re.search(r'SCRIPT ERROR:|(?m:^ERROR:)',text):process.kill();break
   time.sleep(.2)
  code=process.wait()
 text=log.read_text(encoding='utf8',errors='replace');ok=code==0 and not re.search(r'SCRIPT ERROR:|(?m:^ERROR:)',text)
 results.append({'name':name,'nativeScript':script,'ok':bool(ok),'seconds':round(time.monotonic()-start,2)})
 print(name,'PASS' if ok else 'FAIL',flush=True)
 if not ok:print(text[-5000:]);break
(output/'acceptance.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf8')
raise SystemExit(0 if len(results)==len(suite) and all(r['ok'] for r in results) else 1)
