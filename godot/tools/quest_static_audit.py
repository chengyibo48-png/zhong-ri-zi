"""Validate authored quest content without starting or mutating the game."""
from pathlib import Path
import argparse,json
def audit(root):
 content=json.loads((root/'data/content.json').read_text(encoding='utf8'))
 quest=json.loads((root/'data/quests.json').read_text(encoding='utf8'))
 items=content['items'];people={n['id']:n for n in content['npcs']};errors=[];rewards=[]
 def need(ok,message):
  if not ok:errors.append(message)
 guides={d['id']:d for d in quest['guides']}
 need(len(guides)==40,'40 unique guide identities')
 for id,d in guides.items():
  seen=set();p=id
  while p:
   need(p not in seen,'dependency cycle '+id)
   if p in seen or p not in guides:break
   seen.add(p);p=guides[p].get('previous','')
   need(not p or p in guides,'missing prerequisite '+p)
  for item,qty in d['reward'].items():need(item in items and 0<qty<=1,'minimal real tutorial supply '+item)
  rewards.append({'id':id,'money':0,'items':d['reward']})
 need(set(content['arcs'])==set(people),'all and only 24 resident identities')
 titles=set();responses=set();nodes=0
 for id,arc in content['arcs'].items():
  need(len(arc)==(5 if people[id]['tier']=='romance' else 4),'chain length '+id)
  need(any(d.get('activity') for d in arc),'actual cooperation '+id)
  for i,d in enumerate(arc):
   nodes+=1;need(d['title'] not in titles,'repeated title '+d['title']);titles.add(d['title'])
   need(d['points']==i*10,'relation threshold '+d['id']);need(len(d['choices'])==2,'two choices '+d['id'])
   for reply in d['choices']:
    need(reply['reply'] not in responses,'reused response '+d['id']);responses.add(reply['reply'])
   for item,qty in d['needs'].items():need(item in items and qty==1,'real low-burden story material '+item)
   if people[id]['age']<18:
    need(not d['needs'] and d['kind']=='story','no adult-role or material burden for child '+id)
    need(not d.get('activity') or d['activity']['kind']=='read','safe child observation '+id)
   rewards.append({'id':'story:'+id+':'+str(i),'relation':5,'money':sum(int(items[k].get('price',0))*v for k,v in d['needs'].items()),'deductions':d['needs']})
  need(all(d.get('memorial') for d in arc[-1]['choices']),'both endings leave a memorial '+id)
 need(nodes==104 and len(responses)==208,'104 nodes 208 individual responses')
 for d in content['orders']+content['favors']:
  base=sum(int(items[k].get('price',0))*v for k,v in d['needs'].items())
  expected=int(base*1.15)+{'simple':25,'processed':30,'cross':40}[d['complexity']]
  need(d['money']==expected,'commission formula '+str(d['id']))
  rewards.append({'id':str(d['id']),'money':expected,'items':d.get('reward',{}),'deductions':d['needs']})
 for project,d in content['projects'].items():
  for item,qty in d['needs'].items():need(item in items and item in ['wood','bamboo'] and 0<qty<=14,'nonrare project input '+project)
 for recipe in content['recipes']+content['processingRecipes']:
  need(recipe['id'] in items,'recipe output '+recipe['id'])
  for item in recipe.get('needs',{}):need(item in items,'missing recipe ingredient '+item)
 return {'ok':not errors,'errors':errors,'residents':len(people),'story_nodes':nodes,'choice_responses':len(responses),'guides':len(guides),'reward_table':rewards}
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path);args=parser.parse_args();result=audit(Path(__file__).resolve().parents[1])
 if args.output:args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
 print(json.dumps({k:v for k,v in result.items() if k!='reward_table'},ensure_ascii=False));raise SystemExit(0 if result['ok'] else 1)
