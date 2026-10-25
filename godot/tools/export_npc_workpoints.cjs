const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const s=ZRZCore.initial();s.day=1;s.minutes=600;
const workpoints=Object.fromEntries(ZRZData.npcs.map(n=>{let plan=ZRZNpc.activity(s,n.id);if(plan.key!=='work'){s.minutes=930;plan=ZRZNpc.activity(s,n.id);s.minutes=600;}if(plan.key!=='work')throw Error(n.id+' work plan missing');return[n.id,{...plan.target,label:ZRZNpc.profiles[n.id].work}];}));
const data=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));data.npc.workpoints=workpoints;fs.writeFileSync(process.argv[2],JSON.stringify(data,null,2)+'\n');console.log('Preserved full source targets for '+Object.keys(workpoints).length+' NPCs');
