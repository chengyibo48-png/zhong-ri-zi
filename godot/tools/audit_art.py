"""Inventory the real project's art targets. Never count descriptions as assets."""
import json
import sys
from collections import Counter
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def read(name): return json.loads((ROOT/'data'/name).read_text(encoding='utf-8'))
def write(path,data): path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
world,content,systems=read('world.json'),read('content.json'),read('systems.json')
path=ROOT/'data/world_art_manifest.json'
manifest=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'version':1,'style':'warm_hand_painted_countryside','entries':{}}
entries=manifest['entries']
def add(key,name,checks,**extra):
 entries.setdefault(key,{'name':name,'path':'res://art/world/'+key+'.png','status':'missing','requiredChecks':checks,**extra})
for house in world['village']['houses']:
 add('buildings/'+house['id'],house['name'],['unique_design','transparent_background','door_alignment','collision_alignment','occlusion','night_lighting'],worldRect=[-house['w']*.5,-house['h'],house['w'],house['h']],door=house['door'],owner=house.get('owner'),theme=house.get('theme'),region=house.get('region'))
for kind in sorted({p.get('kind',p.get('type','prop')) for p in world['village']['allProps']+world['tiles']['objects']}):add('props/'+kind,kind,['material_detail','seasonal_variants','placement','collision_alignment'])
crops=content['crops']
for cid,crop in crops.items() if isinstance(crops,dict) else ((x['id'],x) for x in crops):add('crops/'+cid,crop['name'],['seedling','growing','mature','wilted','pest_feedback','harvest_alignment'])
for cid,row in systems.get('forage',{}).get('defs',{}).items():add('forage/'+cid,row.get('name',cid),['base_material','regrowth_states','seasonal_variants','interaction_alignment'])
for species,row in systems['ranch']['species'].items():add('animals/'+species,row.get('name',species),['idle','walking','feeding','sleeping','product_action','interaction_alignment'])
for group,ids in {'terrain':['soil','grass','stone_path','sand','shore','water','wet_soil','snow'],'effects':['rain','snow','fog','wind','harvest','watering','building','leaves','chimney_smoke'],'ui':['panel','button','focus','tooltip','notification','cursor','minimap_pin','quality_badge','reward_badge','loading']}.items():
 for cid in ids:add(group+'/'+cid,cid,['in_game_visual_review','legibility','performance'])
# Every existing interior needs its own composition and verified entrance/interaction alignment.
for hid,layout in systems['interiors']['layouts'].items():
 add('interiors/'+hid,layout['h']['name']+'室内',['floor_wall_detail','distinct_composition','door_alignment','furniture_occlusion','interaction_alignment'],houseId=hid)
add('interiors/player_home','玩家住宅室内',['all_upgrade_levels','custom_furniture','door_alignment','interaction_alignment'])
for kind in sorted({r['kind'] for layout in systems['interiors']['layouts'].values() for r in layout['rows']}):
 add('interior_props/'+kind,kind,['unique_material','placement','interaction_alignment','occlusion'])
for row in systems['museum']['wildlife']:
 add('wildlife/'+row['id'],row['name'],['idle','movement','season_weather_visibility','observation_alignment'])
for pid,label in [('cat','猫'),('dog','狗')]:
 add('pets/'+pid,label,['idle','walking','feeding','petting','sleeping','interaction_alignment'])
if "--update-registry" in sys.argv:
 write(path,manifest)
rows=[]
def physical(row):
 p=ROOT/row.get('path','').removeprefix('res://')
 if not p.is_file():return {'exists':False,'validated':False}
 with Image.open(p) as im:
  alpha=im.convert('RGBA').getchannel('A')
  return {'exists':True,'size':list(im.size),'transparent':alpha.getextrema()[0]==0,'validated':row.get('status')=='ready'}
for label,registry in [('icons',read('item_art_manifest.json')['entries']),('world',entries)]:
 for key,row in registry.items():
  # House props route to individual building entries in WorldArt.key_for.
  if label=='world' and key=='props/house':continue
  rows.append({'category':label,'id':key,'name':row['name'],'status':row.get('status','missing'),**physical(row)})
actors=read('character_art_manifest.json')['actors'];clips=[]
for actor,row in actors.items():
 for clip,spec in row['clips'].items():clips.append({'actor':actor,'clip':clip,'actor_complete':row.get('ready',False),'clip_ready':spec.get('ready',False),'frame_count':int(spec.get('frames',0))*len(spec.get('directions',[])),**physical(spec)})
portraits=[]
for actor,row in actors.items():
 for emotion,path in row.get('portraits',{}).items():
  spec={'path':path,'status':'ready' if row.get('portraitReady',{}).get(emotion,False) else 'missing'}
  portraits.append({'actor':actor,'emotion':emotion,**physical(spec)})
summary={}
for label,registry in [('icons',read('item_art_manifest.json')['entries']),('world',entries)]:
 for group in sorted({key.split('/')[0] for key in registry}):
  subset=[r for r in rows if r['category']==label and r['id'].startswith(group+'/')]
  summary[label+'/'+group]={'required':len(subset),'ready_png':sum(r['exists'] and r['validated'] for r in subset),'partial_png':sum(r['exists'] and r['status']=='partial' for r in subset)}
summary['world/animals']['base_direction_frames']=sum(int(v.get('frames',0))*len(v.get('directions',[])) for k,v in entries.items() if k.startswith('animals/') and v.get('baseReady') and (ROOT/v.get('path','').removeprefix('res://')).is_file())
summary['characters']={'actors':len(actors),'complete_actors':sum(bool(x.get('ready')) for x in actors.values()),'required_clips':len(clips),'ready_clips':sum(x['exists'] and x['clip_ready'] for x in clips),'ready_frames':sum(x['frame_count'] for x in clips if x['exists'] and x['clip_ready']),'required_portraits':len(portraits),'ready_portraits':sum(x['exists'] and x['validated'] for x in portraits)}
ground=manifest.get('groundAtlas',{})
summary['world/ground_columns']={'required':10,'partial_png':sum(bool(v.get('baseReady')) and (ROOT/v['path'].removeprefix('res://')).is_file() for v in ground.values()),'seasonal_tiles':sum(16 for v in ground.values() if bool(v.get('baseReady')) and (ROOT/v['path'].removeprefix('res://')).is_file())}
report={'aliases':{'props/house':'buildings/<authored_house_id>'},'scope':'all original village props and fixed tile objects, actual PNG presence and declared art readiness; does not replace visual/playability review','summary':summary,'assets':rows,'clips':clips,'portraits':portraits}
write(ROOT/'artifacts/art-resource-audit.json',report)
print(json.dumps(summary,ensure_ascii=False))
