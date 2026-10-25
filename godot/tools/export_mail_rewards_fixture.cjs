const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
function run(s,id,kind){const before=copy(s),result=kind==='mail'?C.mail(s,id):C.claimAchievement(s,id);rows.push({kind,id,before,result,expected:{bag:copy(s.bag),lots:copy(s.kitchen.lots),discovered:copy(s.discovered),mailRead:copy(s.mailRead),achievements:copy(s.achievements),furniture:copy(s.furniture),eventLog:copy(s.eventLog||[]),journal:copy(s.journal||[])}});}
for(const id of Object.keys(D.items))for(let variant=0;variant<4;variant++){
 const s=C.initial();K.ensure(s);if(variant===0)delete s.bag[id];else C.add(s,id,2);
 if(s.kitchen.lots.bag[id])for(const lot of s.kitchen.lots.bag[id])lot.age=3;
 s.letters=[{id:'test',from:'禾溪邻里',title:'随信礼物',text:'带给你的东西',gift:{[id]:variant===2?0:3}}];
 if(variant===3)s.mailRead.push('test');run(s,'test','mail');
}
for(const variant of ['missing','no-gift','empty-gift','mixed']){
 const s=C.initial();s.letters=[{id:'test',from:'邻居',title:'问候',text:'明天见'}];
 if(variant==='empty-gift')s.letters[0].gift={};
 if(variant==='mixed')s.letters[0].gift={rice:3,wood:2,cabbage:1};
 run(s,variant==='missing'?'missing':'test','mail');
}
for(const a of D.achievements)for(const variant of ['below','ready','claimed','above']){
 const s=C.initial();s.stats[a.stat]=a.target+(variant==='below'?-1:variant==='above'?5:0);
 if(variant==='claimed')s.achievements.push(a.id);
 run(s,a.id,'achievement');
}
run(C.initial(),'missing','achievement');
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Mail and achievement source cases: '+rows.length);
