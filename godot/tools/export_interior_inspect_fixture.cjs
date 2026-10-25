const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,V=ZRZVillage,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const snapshot=s=>({memories:s.village.memories,relations:s.relations,journal:s.journal,eventLog:s.eventLog,bag:s.bag,money:s.money,stamina:s.stamina,minutes:s.minutes,bubbles:V.stateRuntime(s).bubble});
for(const house of V.houses)for(const point of V.roomObjects(house,C.initial()).filter(p=>p.kind==='egg'))for(const variant of ['first','repeat','cap','log-cap']){
 let s=C.initial();s.day=27;s.minutes=601;s.village.interior=house.id;s.player={x:480,y:550,direction:'up'};
 if(variant==='repeat')s.village.memories[point.id]=s.day-1;
 if(variant==='cap'&&house.owner)s.relations[house.owner].points=100;
 if(variant==='log-cap'){s.journal=Array.from({length:60},(_,i)=>({day:s.day,text:'旧记录'+i}));s.eventLog=Array.from({length:200},(_,i)=>({day:s.day,text:'旧记录'+i}));}
 s=C.load(copy(s));const before=copy(s),result=V.inspect(s,point);rows.push({house:house.id,point,variant,before,result,expected:copy(snapshot(s))});
}
{const s=C.load(C.initial()),point={id:'missing',kind:'egg',x:400,y:400,index:0,name:'动手看看 · 旧物'},before=copy(s),result=V.inspect(s,point);rows.push({house:null,point,variant:'outdoors',before,result,expected:copy(snapshot(s))});}
fs.writeFileSync(process.argv[2],rows.map(r=>JSON.stringify(r)).join('\n')+'\n');console.log('Interior inspect source cases: '+rows.length);
