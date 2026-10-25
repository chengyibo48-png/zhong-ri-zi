const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const rows=[],copy=x=>JSON.parse(JSON.stringify(x)),C=ZRZCore;
for(const n of ZRZData.npcs)for(const id of [...new Set([n.likes[0],'wood','greens'])])for(const variant of ['base','repeated','cap','repeatedCap','birthday','already','missing','far']){
 const s=C.initial();s.day=variant==='birthday'?n.birthday-1:10;s.minutes=600;ZRZNpc.ensure(s);s.player.x=2831;s.player.y=1652;s.village.interior=null;s.village.npc[n.id]={x:2831+(variant==='far'?81:0),y:1652,room:null};C.add(s,id,3);
 if(variant.includes('Cap')||variant==='cap')s.relations[n.id].points=98;
 if(variant.startsWith('repeated'))s.lastGifts[n.id]=id;
 if(variant==='already')s.relations[n.id].gifted=s.day;
 if(variant==='missing')C.consume(s,{[id]:s.bag[id]});
 const before=copy(s),result=C.gift(s,n.id,id);
 rows.push({id,npc:n.id,variant,before,result,expected:{bag:s.bag,relations:s.relations,lastGifts:s.lastGifts,skills:s.skills,gifts:s.stats.gifts,lots:s.kitchen.lots,people:s.neighbors.people[n.id],history:s.neighbors.history}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Gift source rows: '+rows.length);
