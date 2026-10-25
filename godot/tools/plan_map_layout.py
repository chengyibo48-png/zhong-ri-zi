"""Plan scenery in world units. No image pixels or legacy save data are edited."""
from pathlib import Path
import json, math, hashlib, collections
P=Path(__file__).resolve().parents[1]
w=json.loads((P/'data/world.json').read_text(encoding='utf8'));m=json.loads((P/'data/world_art_manifest.json').read_text(encoding='utf8'))['entries'];systems=json.loads((P/'data/systems.json').read_text(encoding='utf8'));v=w['village']
def hit(a,b,pad=0):return a[0]<b[0]+b[2]+pad and a[0]+a[2]>b[0]-pad and a[1]<b[1]+b[3]+pad and a[1]+a[3]>b[1]-pad
def rect_prop(row):
 k=row.get('kind',row.get('type',''));r=m.get('props/'+k,{}).get('worldRect')
 if r:
  r=list(r)
  if k=='fence':
   ratio=min(88,max(28,row.get('w',48)))/r[2];r=[q*ratio for q in r]
  return r
 a=w['tiles']['assets'].get(k,{});wid=row.get('w',a.get('w',48));hei=row.get('h',a.get('h',56));return [-wid/2,-hei,wid,hei]
def shifted(r,x,y):return [x+r[0],y+r[1],r[2],r[3]]
plan={'version':1,'purpose':'original village layout, functional reservations and collision-consistent painted scenery','source_world_sha256':hashlib.sha256((P/'data/world.json').read_bytes()).hexdigest(),'houseRects':{},'collisionOverrides':[{'source':[2198,2489,169,72],'rect':[2205,2489,145,72],'reason':'grain-store wall no longer intersects compost-room wall'},{'source':[2358,2514,154,60],'rect':[2365,2514,140,60],'reason':'compost-room wall respects shared gap'}],'props':{},'groundZones':[],'reservations':[],'regional_identity':{'farm':'家门、田埂、厨房与杂货的日常小环线','town':'服务街与居民支巷','bamboo':'手艺、林下采集与遮荫小径','river':'桥头、渡口与村史馆','mountain':'梯田、茶屋与山泉探索','pasture':'畜舍、粮仓与饲草区'}}
for hid,left,width in [('building-pasture-18',2205,150),('building-pasture-19',2360,150)]:
 h=next(h for h in v['houses'] if h['id']==hid);r=m['buildings/'+hid]['worldRect'];plan['houseRects'][hid]=[left-(h['x']+h['w']/2),r[1],width,r[3]]
previous=json.loads((P/'data/world_layout.json').read_text(encoding='utf8'))
plan['fixedVisualRects']=previous.get('fixedVisualRects',{})
plan['fixedSceneryPositions']=previous.get('fixedSceneryPositions',{})
reserve=[]
def add(r,why):reserve.append(r);plan['reservations'].append({'rect':r,'reason':why})
fixed=[]
for h in v['houses']:
 r=plan['houseRects'].get(h['id'],m['buildings/'+h['id']]['worldRect']);box=shifted(r,h['x']+h['w']/2,h['y']+h['h']);fixed.append((h['id'],box));add([box[0]-6,box[1]-6,box[2]+12,box[3]+12],'building '+h['id']);d=h['door'];add([d['x']-22,d['y']-12,44,54],'entrance '+h['id'])
assert not [(a[0],b[0]) for i,a in enumerate(fixed) for b in fixed[i+1:] if hit(a[1],b[1])], 'fixed building art must be separate'
for rid,mp in v['maps'].items():
 o=v['offsets'][rid]
 for road in mp.get('paths',[]):add([road['x']+o['x']-6,road['y']+o['y']-6,road['w']+12,road['h']+12],'path '+rid)
 for water in mp.get('water',[]):add([water['x']+o['x']-8,water['y']+o['y']-8,water['w']+16,water['h']+16],'water '+rid)
for r in v['corridors']:add([r['x']-6,r['y']-6,r['w']+12,r['h']+12],'regional corridor')
for zone,rect in [('main',[2685,1698,262,168]),('extended',[1993,3120,530,174])]:
 add([rect[0]-18,rect[1]-18,rect[2]+36,rect[3]+36],'farm field '+zone)
 plan['groundZones'].append({'id':zone,'rect':rect,'atlasColumn':4,'reason':'grass ground beneath crop rows; no stone road through beds'})
for identity,rect in [('farm-west-loop',[2640,1688,32,232]),('farm-south-loop',[2640,1888,330,32])]:
 add([rect[0]-6,rect[1]-6,rect[2]+12,rect[3]+12],'new daily walk loop '+identity)
 plan['groundZones'].append({'id':identity,'rect':rect,'atlasColumn':6,'reason':'walk along crop rows, linking original house-side and south paths'})
for name,z in systems['building']['zones'].items():
 if name!='home':add([z['x']-12,z['y']-12,z['cols']*z['size']+24,z['rows']*z['size']+24],'player building zone '+name)
for p in v.get('outdoorActions',[])+v.get('chores',[]):
 if isinstance(p,dict) and 'x' in p and 'y' in p:add([p['x']-18,p['y']-20,36,40],'outdoor interaction')
for key in ['workpoints']:
 for p in systems['npc'].get(key,{}).values():
  if isinstance(p,dict) and 'x' in p and 'y' in p:add([p['x']-16,p['y']-18,32,36],'NPC workpoint')
add([2506,1688,72,65],'general counter');add([2760,1648,68,54],'kitchen station')
plan['fixtures']={'general_counter':[2512,1709,60,26],'kitchen_stove':[2765,1655,56,40]}
for p in systems['economy'].get('handover',[]):add([p['x']-42,p['y']-64,84,98],'business handover')
fixed_solids=v['solids']+w['tiles'].get('collisions',[])
eligible={'pot','jar','basket','flowers','shrub','bench','bamboo','drying','rack','laundry','haystack','cart','fence','plants','jars','teaCrate','seedTray','grainMat','hayrack','bambooBundle','netCoil'}
scales={'pot':.68,'jar':.72,'basket':.65,'flowers':.8,'shrub':.8,'bench':.85,'bamboo':.85,'drying':.85,'rack':.85,'laundry':.85,'haystack':.85,'cart':.85,'fence':.9}
objects=[]
for source,rows in [('village',v['allProps']),('tiles',w['tiles'].get('objects',[]))]:
 for index,row in enumerate(rows):
  kind=row.get('kind',row.get('type',''));r=rect_prop(row)
  movable=kind in eligible and not w['tiles']['assets'].get(kind,{}).get('box') and kind!='house'
  if movable:
   scale=scales.get(kind,1) if m.get('props/'+kind,{}).get('baseReady') else 1
   r=[a*scale for a in r]
   objects.append((source+':'+str(index),row,r))
  elif kind!='house':
   position=plan['fixedSceneryPositions'].get(source+':'+str(index),row)
   r=plan['fixedVisualRects'].get(source+':'+str(index),{}).get('rect',r)
   reserve.append(shifted(r,position['x'],position['y']))
def region(row):
 if row.get('region') in v['offsets']:return row['region']
 x,y=row['x'],row['y'];return next(r['id'] for r in v['regions'] if r['x']<=x<r['x']+1920 and r['y']<=y<r['y']+1152)
occupied=[];moved=0;max_distance=0
for identity,row,r in sorted(objects,key=lambda p:p[2][2]*p[2][3],reverse=True):
 rid=region(row);o=v['offsets'][rid];x0,y0=row['x'],row['y']
 candidates=[(x0,y0)]
 for radius in range(16,385,16):
  for dx in range(-radius,radius+1,16):
   for dy in [-radius,radius]:candidates.append((x0+dx,y0+dy))
  for dy in range(-radius+16,radius,16):
   for dx in [-radius,radius]:candidates.append((x0+dx,y0+dy))
 candidates.sort(key=lambda p:(p[0]-x0)**2+(p[1]-y0)**2)
 chosen=None
 for x,y in candidates:
  box=shifted(r,x,y)
  if box[0]<o['x']+18 or box[1]<o['y']+18 or box[0]+box[2]>o['x']+1902 or box[1]+box[3]>o['y']+1134:continue
  if any(hit(box,b,3) for b in reserve+fixed_solids+occupied):continue
  chosen=(x,y,box);break
 if chosen is None:raise RuntimeError('No safe local placement for '+identity+' '+str(row))
 x,y,box=chosen;distance=math.hypot(x-x0,y-y0);moved+=distance>0;max_distance=max(max_distance,distance)
 occupied.append(box);plan['props'][identity]={'x':x,'y':y,'rect':r,'source':[x0,y0],'kind':row.get('kind',row.get('type')),'region':rid}
plan['summary']={'planned_decorations':len(objects),'relocated_decorations':moved,'maximum_relocation_world_pixels':max_distance,'decor_overlap_pairs':0,'building_visual_overlap_pairs':0,'original_houses':len(v['houses']),'original_props':len(v['allProps'])+len(w['tiles'].get('objects',[])),'functional_doors_moved':0,'logical_plot_positions_moved':0}
(P/'data/world_layout.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps(plan['summary'],ensure_ascii=False))
