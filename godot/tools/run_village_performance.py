"""Run real-time GPU benchmarks sequentially with isolated save directories."""
from pathlib import Path
import os,subprocess,time,re,json,statistics
from project_temporary import temporary_directory
p=Path(__file__).resolve().parents[1];o=p/'artifacts/release-20261030-v030/performance';o.mkdir(parents=True,exist_ok=True)
cases=[('rooms','village_house_benchmark.gd',420,{'HOUSE_BARN_STRESS':'0'}),('barn','village_house_benchmark.gd',180,{'HOUSE_BARN_STRESS':'1'}),('meadow','village_meadow_benchmark.gd',180,{}),('fishing','village_fishing_benchmark.gd',330,{})]
for name,script,limit,options in cases:
 with temporary_directory(prefix='zrz-release-perf-') as temp:
  env=os.environ.copy();env.update(options,TEMP=temp,TMP=temp,APPDATA=str(Path(temp)/'appdata'),LOCALAPPDATA=str(Path(temp)/'localappdata'),ZRZ_ART_OUTPUT=str(o),HOUSE_PERF_LABEL='release',ZRZ_REVIEW_STAGE='release')
  log=o/(name+'.log');start=time.monotonic()
  with log.open('wb') as f:
   child=subprocess.Popen([str(p/'.build/export-engine/Godot_console.exe'),'--path',str(p),'--script','res://tools/'+script],cwd=p,env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
   while child.poll() is None:
    text=log.read_text('utf8',errors='replace')
    if time.monotonic()-start>limit or re.search(r'SCRIPT ERROR:|(?m:^ERROR:)',text):child.kill();break
    time.sleep(.5)
   code=child.wait()
  text=log.read_text('utf8',errors='replace')
  if code or re.search(r'SCRIPT ERROR:|(?m:^ERROR:)',text):raise RuntimeError(name+' FAILED '+text[-2000:])
  print(name,'completed',round(time.monotonic()-start,1),flush=True)
rows=[]
for stem,field in [('house-performance','room'),('house-barn-performance','room'),('ranch-meadow-performance','scenario'),('fishing-performance','scenario')]:
 before=json.loads((o/(stem+'-before.json')).read_text('utf8'));after=json.loads((o/(stem+'-release.json')).read_text('utf8'))
 if isinstance(before,dict):before=before['measurements'];after=after['measurements']
 for name in sorted({r[field] for r in after}):
  left=[r for r in before if r[field]==name];right=[r for r in after if r[field]==name];assert len(left)==len(right)==3
  row={'suite':stem,'scenario':name,'trials':3,'warmup_seconds':5,'sample_seconds':20,'metrics':{}}
  for metric in ['p50','p95']:
   key=metric if metric in right[0] else metric+'_ms'
   ratios=[r[key]/l[key]-1 for l,r in zip(left,right)]
   row['metrics'][metric]={'before_ms':statistics.median(r[key] for r in left),'after_ms':statistics.median(r[key] for r in right),'trial_ratios':ratios,'stable_regression':sum(v>.10 for v in ratios)>=2}
  row['ok']=not any(v['stable_regression'] for v in row['metrics'].values());rows.append(row)
(o/'comparison.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
print('PERFORMANCE_GATE',all(r['ok'] for r in rows),flush=True)
raise SystemExit(0 if all(r['ok'] for r in rows) else 1)
