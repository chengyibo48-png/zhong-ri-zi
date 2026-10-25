from pathlib import Path
import json,hashlib,shutil
from PIL import Image
R=Path(__file__).resolve().parents[1]
B=R/'artifacts/optimization-20261014'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,obj):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,im):
 if p.exists() and not (B/'before'/p.relative_to(R)).exists():
  backup=B/'before'/p.relative_to(R);backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,backup)
 p.parent.mkdir(parents=True,exist_ok=True);im.save(p,optimize=True)
from life_atlas import normalize
manifest_path=R/'data/world_art_manifest.json';m=read(manifest_path)
if not(B/'before/data/world_art_manifest.json').exists():
 (B/'before/data').mkdir(parents=True,exist_ok=True);shutil.copy2(manifest_path,B/'before/data/world_art_manifest.json')
receipts_path=B/'generation-receipts.json';receipts=read(receipts_path) if receipts_path.exists() else []
for job in read(B/'generation-jobs.json')['jobs']:
 src=Path(job['source']);key=job['id'].split('/')[-1];kind=job['kind'];master=B/'masters'/f'{kind}-{key}.png';master.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,master)
 cell=(256,160) if kind=='pet' else (256,192)
 if kind=='prop':
  raw=Image.open(src).convert('RGBA');bbox=raw.getchannel('A').point(lambda v:255 if v>=16 else 0).getbbox()
  if not bbox or raw.getchannel('A').getextrema()[0]!=0:raise ValueError('Prop has no valid transparent silhouette')
  left,top,right,bottom=bbox;bounds=(max(0,left-3),max(0,top-3),min(raw.width,right+3),min(raw.height,bottom+3));sheet=raw.crop(bounds);ratio=512/max(sheet.size);sheet=sheet.resize((max(1,round(sheet.width*ratio)),max(1,round(sheet.height*ratio))),Image.Resampling.LANCZOS);boxes=[{'sourceBounds':list(bounds),'extraction':'complete transparent object/group'}]
 elif kind=='terrain':sheet=Image.open(src).convert('RGBA').resize((512,512),Image.Resampling.LANCZOS);boxes=[]
 else:sheet,boxes=normalize(src,job['cols'],job['rows'],cell,job.get('sourceRows'))
 if kind=='pet':
  rel=f'art/world/pets/fine/{key}-actions.png';out=R/rel;save(out,sheet)
  row=m['entries'][job['id']];row.update(actionAtlas='res://'+rel,actionFrames=['idle','walk_a','walk_b','feeding','petting','sleeping'],actionFrameSize=[256,160],directions=['down','left','right','up'],baseReady=True,artBatch='optimization-20261014',status='partial')
  if key=='dog':
   base,_=normalize(src,4,6,(256,128));base=base.crop((0,0,1024,128));save(R/'art/world/pets/dog.png',base)
   row.update(frameSize=[256,128],frames=1,anchor=[128,122],worldHeight=job['height'],spriteHeight=112)
 elif kind=='wildlife':
  rel=f'art/world/wildlife/{key}.png';out=R/rel;save(out,sheet);row=m['entries'][job['id']]
  row.update(baseReady=True,path='res://'+rel,frameSize=[256,192],frames=6,columns=3,worldHeight=job['height'],actionFrames=['idle','walk_a','walk_b','foraging','flight_up','flight_down'],artBatch='optimization-20261014',status='partial')
 elif kind=='forage':
  rel=f'art/world/forage/fine/{key}-seasons.png';out=R/rel;save(out,sheet);row=m['entries'][job['id']]
  row.update(seasonalAtlas='res://'+rel,seasonalFrameSize=[256,192],seasonalStages=['harvested','regrowing','mature'],seasonNames=['spring','summer','autumn','winter'],artBatch='optimization-20261014',status='partial')
 elif kind=='prop':
  rel=f'art/world/props/{key}.png';out=R/rel;save(out,sheet)
  world=read(R/'data/world.json');world=world.get('world',world);assets=world.get('tiles',{}).get('assets',{});observed=[p for p in world.get('village',{}).get('allProps',[])+world.get('tiles',{}).get('objects',[]) if p.get('kind')==key]
  import statistics
  widths=[float(p.get('w',assets.get(key,{}).get('w',48))) for p in observed];heights=[float(p.get('h',assets.get(key,{}).get('h',40))) for p in observed]
  w=statistics.median([v for v in widths if v>0]) if any(v>0 for v in widths) else 64 if key=='wall' else 48;h=statistics.median([v for v in heights if v>0]) if any(v>0 for v in heights) else 28 if key=='wall' else 40
  names={'bambooBundle':'竹捆','grainMat':'晒粮席','haybale':'草捆','hayrack':'草料架','jars':'陶罐组','loom':'织机','netCoil':'渔网卷','plants':'草丛','scale':'杆秤','seedTray':'育苗盘','stones':'碎石组','teaCrate':'茶箱','washstone':'洗衣石','weather':'气象桩','woodpile':'柴堆','wall':'矮石墙'}
  row=m['entries'].setdefault(job['id'],{'name':names.get(key,key),'requiredChecks':['material_detail','seasonal_variants','placement','collision_alignment'],'reviewed':['material_detail'],'verifiedChecks':[]})
  row.update(path='res://'+rel,baseReady=True,status='partial',worldRect=[-w/2,-h,w,h],fitLayout=True,fitSourceSize=True,sourceVisibleRect=list(bounds),sceneInstances=len(observed),artBatch='optimization-20261014',visualTier='independent_painted_base')
 elif kind=='terrain':
  rel=f'art/world/terrain/{key}.png' ;out=R/rel;save(out,sheet);row=m['entries'][job['id']]
  row.update(path='res://'+rel,baseReady=True,artBatch='optimization-20261014',status='partial',usage='Painted bank-edge/snow-cover detail blended by ground shader; physics metadata retained.')
 else:raise ValueError(kind)
 row['artReview']='Generated poses statically reviewed, transparent cells normalized with a common scale; runtime review pending.'
 receipt={**job,'master':str(master),'sourceSha256':sha(master),'runtimePath':'res://'+rel,'runtimeSha256':sha(out),'dimensions':list(sheet.size),'cells':boxes,'status':'imported_pending_runtime_review'}
 receipts=[x for x in receipts if x['id']!=job['id']]+[receipt]
# Reconcile imported state artwork without confusing replaced attempts with missing work.
old_path=R/'artifacts/continuation-art-20261013/generation-receipts.json';old=read(old_path)
accepted={(x['id'],x['state']):x for x in old if x.get('status')=='imported_static_review_only'}
previous=read(B/'before/data/world_art_manifest.json')
cleared=[k+'/'+state for k,v in previous['entries'].items() for state in v.get('pendingPaintedStates',[]) if state not in m['entries'][k].get('pendingPaintedStates',[])]
for (identity,state),receipt in accepted.items():
 row=m['entries'][identity];path=receipt.get('runtimePath','');disk=R/path.removeprefix('res://')
 if row.get('states',{}).get(state)==path and disk.is_file() and sha(disk)==receipt['runtimeSha256']:
  if state in row.get('pendingPaintedStates',[]):row['pendingPaintedStates'].remove(state);cleared.append(identity+'/'+state)
  if 'pendingPaintedStates' in row:row['plannedPaintedStatesImported']=not row['pendingPaintedStates']
for x in old:
 replacement=accepted.get((x['id'],x['state']))
 if replacement and x.get('status') in ['generated_pending_static_review','rejected_pending_repair']:
  x['supersededByRuntimePath']=replacement['runtimePath'];x['status']='rejected_superseded' if x['status'].startswith('rejected') else 'alternative_superseded'
backup=B/'before/artifacts/continuation-art-20261013/generation-receipts.json'
if not backup.exists():backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(old_path,backup)
write(old_path,old);write(manifest_path,m);write(receipts_path,receipts);write(B/'state-reconciliation.json',{'clearedPendingStates':sorted(set(cleared)),'supersededAttempts':sum('supersededByRuntimePath' in x for x in old),'pendingVariants':[{ 'id':k,'states':v['pendingPaintedStates']} for k,v in m['entries'].items() if v.get('pendingPaintedStates')]})
print(f'Imported {len(receipts)} generated atlases. Reconciled {len(cleared)} stale pending-state flags.')
