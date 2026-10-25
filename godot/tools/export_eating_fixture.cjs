const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const rows=[],copy=x=>JSON.parse(JSON.stringify(x)),C=ZRZCore;
for(const [id,item] of Object.entries(ZRZData.items))if(item.energy>0)for(const variant of ['fresh','aged','quality','home','full','missing']){
 const s=C.initial();s.day=10;s.minutes=650;s.stamina=variant==='full'?100:20;C.add(s,id,3);ZRZKitchen.ensure(s);
 if(variant==='aged'||variant==='home')for(const lot of s.kitchen.lots.bag[id]||[])lot.age=ZRZKitchen.shelf(id)*.6;
 if(variant==='quality')s.quality[id]=[0,0,s.bag[id]];
 if(variant==='home')s.skills.cooking.choice='home';
 s.buffs.laborDay=10;s.kitchen.buff={kind:'暖胃',until:16000};
 if(variant==='missing')C.consume(s,{[id]:s.bag[id]});
 const before=copy(s),result=C.eat(s,id);
 rows.push({id,variant,before,result,expected:{bag:s.bag,stamina:s.stamina,lots:s.kitchen.lots,buff:s.kitchen.buff,laborDay:s.buffs.laborDay}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Eating source rows: '+rows.length);
