const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum'])require('../../src/'+name+'.js');
const rows=[];
for(let day=0;day<112;day++)for(const item of Object.keys(ZRZForage.defs))for(const variant of ['base','collected','full','pressure','axe']){
 const s=ZRZCore.initial();s.day=day;
 const p={id:'status-'+item,kind:'gather',item,event:''};
 if(variant==='collected')s.collected[p.id]=day;
 if(variant==='full')s.forage.mode='full';
 if(variant==='pressure')s.forage.patches[p.id]={lastDay:day-2,readyDay:day+2,pressure:5};
 if(variant==='axe')s.toolkit.tools.axe.level=2;
 rows.push({day,point:p,variant,forage:s.forage,collected:s.collected,toolkit:s.toolkit,expected:ZRZForage.status(s,p),description:ZRZForage.describe(s,p)});
}
fs.writeFileSync(process.argv[2],JSON.stringify(rows));
console.log('Exported '+rows.length+' authoritative forage status samples');
