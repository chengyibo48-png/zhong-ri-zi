const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,T=ZRZTools,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
function base(id,level){const s=C.initial();s.day=10;s.minutes=600;s.money=1000;s.bag.wood=30;s.bag.bamboo=30;s.bag.wool=10;K.ensure(s);if(T.defs[id])s.toolkit.tools[id].level=level;return s;}
function add(s,op,id,variant,field='',value=''){const before=copy(s),quote=T.quote(s,id),result=op==='upgrade'?T.upgrade(s,id):T.configure(s,id,field,value);rows.push({op,id,variant,field,value,before,quote,result,expected:{bag:s.bag,quality:s.quality,toolkit:s.toolkit,toolUpgrades:{hoe:false,water:false,gather:false,rod:false,...s.toolUpgrades},journal:s.journal,eventLog:s.eventLog,lots:s.kitchen.lots,money:s.money,minutes:s.minutes,stamina:s.stamina}});}
for(const id of [...Object.keys(T.defs),'missing'])for(const level of [0,1,2])for(const variant of ['ready','poor','empty','locked','stamina0','stamina1','gentle','full','late','workshop','day6','day7','xp7','xp8','quality','warm','expired']){
 const s=base(id,level);
 if(variant==='poor')s.money=0;if(variant==='empty'){s.bag={};K.ensure(s);}if(variant==='locked')s.economy.locked=['wood','bamboo','wool'];
 if(variant==='stamina0')s.stamina=0;if(variant==='stamina1')s.stamina=1;if(variant==='gentle'){s.skills.farming.choice='gentle';s.stamina=1;}
 if(variant==='full'){s.journal=Array.from({length:60},(_,i)=>({day:10,text:'旧日志'+i}));s.eventLog=Array.from({length:200},(_,i)=>({day:10,text:'旧事件'+i}));}
 if(variant==='late')s.minutes=1315;
 if(variant==='workshop'){s.day=0;s.building.levels.workshop=1;}
 if(variant==='day6'||variant==='day7')s.day=Number(variant.slice(3));
 if(variant==='xp7'||variant==='xp8'){s.day=0;if(T.defs[id])s.toolkit.tools[id].xp=Number(variant.slice(2));}
 if(variant==='quality'){s.quality.wood=[10,10,10];s.quality.bamboo=[10,10,10];s.quality.wool=[3,3,4];}
 if(variant==='warm'||variant==='expired'){s.stamina=1;s.kitchen.buff={kind:'暖胃',until:s.day*1440+s.minutes+(variant==='warm'?1:0)};}
 add(s,'upgrade',id,level+'/'+variant);
}
for(const id of [...Object.keys(T.defs),'missing'])for(const level of [0,1,2])for(const [field,value] of [['branch','broad'],['branch','care'],['branch','bad'],['shape','single'],['shape','row'],['shape','cross'],['shape','bad'],['missing','row']]){
 const s=base(id,level);if(level===2&&['hoe','water','sickle'].includes(id))s.toolkit.tools[id].shape='cross';
 add(s,'configure',id,String(level),field,value);
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Tool transactions: '+rows.length);
