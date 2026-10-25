const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const variants=['ready','poor','wood9','bamboo3','empty','lock-wood','lock-bamboo','done','busy','busy-done','busy-poor','locked-busy','locked-done','no-canal','no-canal-done','locked-no-canal','quality','full','cap','town'];
for(const id of [...Object.keys(D.upgrades),'missing'])for(const variant of [...variants,...(id==='irrigation'?['occupied-first','existing-sprinkler','no-space']:[])]){
 let s=C.initial();s.day=10;s.minutes=600;s.money=1000;s.projects.canal=true;s.bag.wood=30;s.bag.bamboo=30;K.ensure(s);
 if(variant==='poor'||variant==='busy-poor')s.money=0;
 if(variant==='wood9')s.bag.wood=9;if(variant==='bamboo3')s.bag.bamboo=3;
 if(variant==='empty')s.bag={};
 if(variant==='lock-wood'||variant.startsWith('locked-'))s.economy.locked=['wood'];
 if(variant==='lock-bamboo')s.economy.locked=['bamboo'];
 if(D.upgrades[id]&&(variant==='done'||variant.endsWith('-done'))){s.upgrades[id]=true;if(id==='room')s.building.house=2;if(id==='kitchen')s.building.house=1;}
 if(variant.includes('busy'))s.building.jobs=[{id:'house',level:s.building.house+1,readyDay:s.day+1}];
 if(variant.includes('no-canal'))s.projects.canal=false;
 if(variant==='quality'){s.quality.wood=[10,10,10];s.quality.bamboo=[10,10,10];}
 if(variant==='full'){s.journal=Array.from({length:60},(_,i)=>({day:10,text:'旧日志'+i}));s.eventLog=Array.from({length:200},(_,i)=>({day:10,text:'旧事件'+i}));}
 if(variant==='cap')s.skills.craft.xp=99998;
 if(variant==='town'){s.scene='town';s.player.y=500;}
 if(variant==='occupied-first')s.farm.facilities=[{type:'fence',anchor:0,durability:80,enabled:true},{type:'scarecrow',anchor:0,durability:90,enabled:true}];
 if(variant==='existing-sprinkler')s.farm.facilities=[{type:'sprinkler',anchor:0,durability:75,enabled:false}];
 if(variant==='no-space')s.farm.facilities=s.plots.flatMap((_,anchor)=>[{type:'fence',anchor,durability:80,enabled:true},{type:'scarecrow',anchor,durability:90,enabled:true}]);
 if(['occupied-first','existing-sprinkler','no-space'].includes(variant))ZRZTools.ensure(s);
 const input=copy(s);try{s=C.load(copy(s));}catch(error){rows.push({id,variant,before:input,invalidLoad:true,sourceError:error.message});continue;}
 const before=copy(s),result=C.upgrade(s,id);
 rows.push({id,variant,before,result,expected:{bag:s.bag,quality:s.quality,upgrades:s.upgrades,skills:s.skills,furniture:s.furniture,building:s.building,water:s.farm.water,facilities:s.farm.facilities,barns:s.ranch.barns,waterReserve:s.waterReserve,journal:s.journal,eventLog:s.eventLog,lots:s.kitchen.lots,money:s.money}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Legacy upgrade cases: '+rows.length);
