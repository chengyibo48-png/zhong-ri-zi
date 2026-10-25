const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,F=ZRZFarming,D=ZRZData,rows=[];
const variants=['empty','tilled','removed','fallow','compacted','growing','ripe','overripe','sick','poor','dense','pests','seedless','offseason','greenhouse','seasonal-cover','deep','row','cross','buffs'];
for(const crop of Object.keys(D.crops))for(const variant of variants){
 const s=C.initial(),index=variant==='cross'?24:7,p=s.plots[index],b=s.farm.beds[index];s.seed=crop;s.stamina=variant==='buffs'?1:2;
 Object.assign(p,{tilled:true,crop,growth:D.crops[crop].days,watered:false});Object.assign(b,{health:100,condition:95,fertility:80,moisture:20,pests:0,disease:0});
 if(['empty','tilled','removed','fallow','compacted','seedless','offseason','greenhouse','seasonal-cover','deep','row','cross'].includes(variant)){p.crop=null;p.growth=0;}
 if(variant==='empty')p.tilled=false;
 if(variant==='removed')b.removed=true;
 if(variant==='fallow')b.fallow=true;
 if(variant==='compacted')b.compacted=55.5;
 if(variant==='growing')p.growth=D.crops[crop].days*.28;
 if(variant==='overripe')b.ripeDays=4;
 if(variant==='sick')b.health=21.5;
 if(variant==='poor'){b.condition=30;b.fertility=59.5;b.health=69.5;}
 if(variant==='dense'){b.density='dense';s.farm.density='dense';b.kind='heirloom';}
 if(variant==='pests'){b.pests=50.5;b.disease=49.5;}
 if(variant==='seedless')s.bag[F.seedId(crop,s.farm.seedKind)]=0;else s.bag[F.seedId(crop,s.farm.seedKind)]=10;
 if(['offseason','greenhouse','seasonal-cover'].includes(variant)){const season=[0,1,2,3].find(x=>!D.crops[crop].seasons.includes(x));s.day=(season??0)*28;}
 if(['greenhouse','seasonal-cover'].includes(variant))s.farm.facilities=[{anchor:index,type:'greenhouse',durability:100,enabled:true,level:0}];
 if(variant==='seasonal-cover'){s.farm.seedKind='seasonal';s.bag[F.seedId(crop,'seasonal')]=10;}
 if(variant==='deep'){s.toolkit.tools.hoe.level=2;s.toolkit.tools.hoe.branch='care';b.compacted=20;b.fertility=90;}
 if(['row','cross'].includes(variant)){for(const id of ['hoe','water','sickle']){s.toolkit.tools[id].level=2;s.toolkit.tools[id].shape=variant;s.toolkit.tools[id].branch='broad';}for(let i=0;i<s.plots.length;i++){s.plots[i].tilled=false;s.plots[i].crop=null;}}
 if(variant==='buffs'){s.skills.farming.choice='gentle';s.buffs.laborDay=s.day;s.kitchen.buff={kind:'暖胃',until:s.day*1440+s.minutes+100};s.toolkit.tools.sickle.level=1;s.toolUpgrades.hoe=true;s.toolUpgrades.water=true;}
 const point={kind:'plot',index},samples=['seed','hoe','water','hand','sickle','axe'].map(tool=>({tool,expected:ZRZFeedback.describe(s,point,tool)}));
 const fields=['version','day','minutes','stamina','seed','plots','farm','bag','toolkit','skills','buffs','toolUpgrades','kitchen'];
 rows.push({crop,variant,index,before:Object.fromEntries(fields.map(k=>[k,s[k]])),samples,stage:F.stage(s,index),preview:F.preview(s,index)});
}
fs.writeFileSync(process.argv[2],JSON.stringify(require('./export_world_precision.cjs')({rows})));console.log('Exported '+rows.length+' plot states and '+rows.length*6+' original descriptions');
