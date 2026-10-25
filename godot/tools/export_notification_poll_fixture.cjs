const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback'])require('../../src/'+name+'.js');
const rows=[],days=[0,1];
days[0]=Array.from({length:200},(_,i)=>i).find(d=>!ZRZEnvironment.profile(d+1).extreme);
days[1]=Array.from({length:200},(_,i)=>i).find(d=>ZRZEnvironment.profile(d+1).extreme);
for(let mask=0;mask<64;mask++){
 const s=ZRZCore.initial();s.day=days[(mask>>5)&1];s.minutes=600.75;ZRZNpc.ensure(s);
 s.feedback={version:1,next:1,rows:[],days:[],seen:[],prefs:{pace:'normal',motion:'full',floating:'normal',seconds:5,quiet:false}};
 for(const a of s.animals){a.hunger=100;a.illness=0;}
 for(const p of Object.values(s.neighbors.people))p.event=null;
 s.kitchen.jobs=[];s.economy.jobs=[];
 if(mask&1)s.kitchen.jobs=[{key:'k1',id:'pickles',station:'pickle',qty:2,grade:0,ready:0},{key:'k2',id:'pickles',station:'pickle',qty:1,grade:0,ready:0}];
 if(mask&2)s.economy.jobs=[{key:'t1',id:'cabbage',qty:2,price:20,channel:'coop',ready:0}];
 if(mask&4){s.animals[0].hunger=30;if(s.animals[1])s.animals[1].illness=20;}
 if(mask&8){s.plots[0].crop='cabbage';s.farm.beds[0].health=25;}
 if(mask&16){s.neighbors.people[ZRZData.npcs[0].id].event={day:s.day,status:'offered'};s.neighbors.people[ZRZData.npcs[1].id].event={day:s.day,status:'offered'};}
 for(const repeat of [false,true]){
  const before=structuredClone(s),added=ZRZFeedback.poll(s),after=structuredClone(s.feedback);
  const first=added.slice().sort((a,b)=>b.priority-a.priority)[0];
  const notification=first?[first.title+' · '+first.text+(added.length>1?'（另有 '+(added.length-1)+' 条，回响里可查看）':''),first.priority]:null;
  rows.push({mask,repeat,before,after,notification});
 }
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Actual source poll transactions '+rows.length);
