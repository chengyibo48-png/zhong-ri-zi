const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const rows=[],C=ZRZCore,F=ZRZFeedback;
for(const variant of ['empty','tilled','growing','ripe','dry','wet','deep','seedless'])for(const stamina of [0,1,2,100])for(const tool of ['hand','hoe','seed','water','sickle','axe']){
 const s=C.initial();s.player.x=100;s.player.y=100;s.player.direction='down';s.stamina=stamina;s.seed='radish';
 const p=s.plots[7],b=s.farm.beds[7];Object.assign(p,{tilled:variant!=='empty',crop:null,growth:0});b.moisture=variant==='wet'?100:20;
 if(['growing','ripe'].includes(variant)){p.crop='radish';p.growth=variant==='ripe'?ZRZData.crops.radish.days:1;}
 if(variant==='deep'){s.toolkit.tools.hoe.level=2;s.toolkit.tools.hoe.branch='care';b.compacted=30;}
 s.bag[ZRZFarming.seedId('radish',s.farm.seedKind)]=variant==='seedless'?0:10;
 const points=[{kind:'plot',index:7,x:100,y:120},{kind:'tea',id:'tea',name:'茶桌',x:100,y:119},{kind:'tools',id:'tools',name:'工具台',x:100,y:115},{kind:'build-piece',id:'water',service:'water',name:'水井',x:100,y:114},{kind:'rest',id:'rest',name:'座椅',scenery:true,story:'歇一歇',x:100,y:140},{kind:'plot',index:7,id:'distant',x:100,y:153}];
 const selection=new F.Selection(),steps=[];
 for(const hover of [null,points[0],null]){
  const chosen=selection.choose(s,points,hover,tool);
  steps.push({hover,expected:F.targetKey(chosen),order:selection.options.map(F.targetKey),options:selection.options.map(p=>({key:F.targetKey(p),score:p.score,ready:F.describe(s,p,tool).ready}))});
 }
 const fields=['version','day','minutes','stamina','seed','plots','farm','bag','toolkit','skills','buffs','toolUpgrades','kitchen','money'];
 rows.push({variant,stamina,tool,points,steps,before:Object.fromEntries(fields.map(k=>[k,s[k]]))});
}
fs.writeFileSync(process.argv[2],JSON.stringify(require('./export_world_precision.cjs')({rows})));console.log('Exported '+rows.length+' states, '+rows.length*3+' original selection steps');
