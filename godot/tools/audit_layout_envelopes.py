from pathlib import Path
import json,collections,sys
P=Path(__file__).resolve().parents[1]
w=json.loads((P/'data/world.json').read_text(encoding='utf8'));m=json.loads((P/'data/world_art_manifest.json').read_text(encoding='utf8'))['entries'];plan=json.loads((P/'data/world_layout.json').read_text(encoding='utf8'))
def hit(a,b):return a[0]<b[0]+b[2] and a[0]+a[2]>b[0] and a[1]<b[1]+b[3] and a[1]+a[3]>b[1]
nodes=[]
for source,rows in [('village',w['village']['allProps']),('tiles',w['tiles']['objects'])]:
 for i,p in enumerate(rows):
  key=f'{source}:{i}';k=p.get('kind',p.get('type',''));placement=plan['props'].get(key)
  if placement:x,y,r=placement['x'],placement['y'],placement['rect']
  else:
   x,y=p['x'],p['y'];entry=m.get('props/'+k,{})
   if k=='house':
    h=next((h for h in w['village']['houses'] if (h['x'],h['y'])==(x,y)),None)
    entry=m.get('buildings/'+h['id'],{}) if h else {};x+=p.get('w',48)/2;y+=p.get('h',56)
    r=plan['houseRects'].get(h['id'],entry.get('worldRect')) if h else None
   else:r=entry.get('worldRect')
   if not r:
    a=w['tiles']['assets'].get(k,{});wid=p.get('w',a.get('w',48));hei=p.get('h',a.get('h',56));r=[-wid/2,-hei,wid,hei]
  if key in plan.get('fixedSceneryPositions',{}):x,y=plan['fixedSceneryPositions'][key]['x'],plan['fixedSceneryPositions'][key]['y']
  if key in plan.get('fixedVisualRects',{}):r=plan['fixedVisualRects'][key]['rect']
  nodes.append({'id':key,'kind':k,'planned':bool(placement),'box':[x+r[0],y+r[1],r[2],r[3]]})
pairs=[]
for i,a in enumerate(nodes):
 for b in nodes[i+1:]:
  if hit(a['box'],b['box']):pairs.append({'a':a,'b':b,'classification':'fixed-authored-envelope-review' if not a['planned'] and not b['planned'] else 'unexpected-planned-overlap'})
counts=collections.Counter('/'.join(sorted([r['a']['kind'],r['b']['kind']])) for r in pairs)
result={'scope':'conservative visual envelope audit, includes structural/foliage overlap; not every pair is a physics obstruction','nodes':len(nodes),'planned_overlap_pairs':sum(r['classification']=='unexpected-planned-overlap' for r in pairs),'fixed_envelope_pairs':len(pairs),'kinds':dict(counts),'pairs':pairs}
(Path(sys.argv[1]) if len(sys.argv)>1 else P/'artifacts/map-layout-envelope-audit-20261010.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({k:v for k,v in result.items() if k!='pairs'},ensure_ascii=False))
