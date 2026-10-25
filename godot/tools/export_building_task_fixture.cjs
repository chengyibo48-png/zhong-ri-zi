const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','kitchen-view','building','tools','economy','scenes','environment','forage','interiors'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,B=ZRZBuild,T=ZRZTools,rows=[],destinations=[];
function prepared(){const s=C.initial();s.day=60;s.money=10000;s.stamina=100;s.minutes=600;s.upgrades.yard=true;s.projects.canal=true;for(const id of Object.keys(D.items))s.bag[id]=100;s.economy.locked=[];return s;}
function add(task,variant,setup=()=>{}){
 const s=prepared();setup(s);
 if(variant==='poor')s.money=0;
 if(variant==='materials')s.bag={};
 if(variant==='energy')s.stamina=0;
 if(variant==='protected')s.economy.locked=Object.keys(D.items);
 if(variant==='gentle')s.skills.farming.choice='gentle';
 if(variant==='reuse')s.skills.craft.choice='reuse';
 if(variant==='premium'){for(const id of ['wood','bamboo','wool'])s.quality[id]=[60,30,10];}
 if(variant==='saving'){s.building.levels.workshop=2;s.building.modes.workshop='craft';}
 if(variant==='busy')s.building.jobs=[{id:'house',level:1,readyDay:s.day+1}];
 if(variant==='full')s.building.jobs=['granary','workshop','well','nursery'].map(id=>({id,level:1,readyDay:s.day+1}));
 if(variant==='before-autumn')s.day=55;
 if(variant==='no-yard')s.upgrades.yard=false;
 if(variant==='no-canal')s.projects.canal=false;
 if(variant==='duplicate'){s.upgrades[task.id]=true;if(task.id==='room')s.building.house=2;if(task.id==='kitchen')s.building.house=1;}
 if(variant==='locked-level'){s.day=0;s.toolkit.tools[task.id].level=1;}
 const before=JSON.parse(JSON.stringify(s)),preview=B.preview(s,task),unchanged=JSON.stringify(s)===JSON.stringify(before),destination=B.destination(s,task),result=B.perform(s,task);
 const expected={money:s.money,stamina:s.stamina,minutes:s.minutes,bag:s.bag,quality:s.quality,furniture:s.furniture,building:s.building,upgrades:s.upgrades,skills:s.skills,toolkit:s.toolkit,toolUpgrades:{hoe:false,water:false,gather:false,rod:false,...s.toolUpgrades},waterReserve:s.waterReserve,water:s.farm.water,facilities:s.farm.facilities,journal:s.journal,barns:structuredClone(s.ranch.barns)};
 rows.push({task,variant,before,preview,unchanged,destination,result,expected});
}
for(const id of Object.keys(B.projects))for(const variant of ['normal','poor','materials','energy','protected','gentle','busy','full','no-yard'])add({op:'project',id},variant);
for(const id of Object.keys(B.projects))for(let level=1;level<=B.projects[id].max;level++)add({op:'project',id},'level-'+level,s=>{if(id==='house')s.building.house=level;else if(id==='orchard')s.building.land.orchard=!!level;else s.building.levels[id]=level;});
for(const id of Object.keys(B.defs))for(const variant of ['normal','materials','energy','protected','premium','reuse','saving','before-autumn','no-yard'])add({op:'craft',id,n:3},variant);
for(const n of [0,-1,1,10,11,1.5])add({op:'craft',id:'bench',n},'normal');
for(const id of Object.keys(D.upgrades))for(const variant of ['normal','poor','materials','protected','busy','duplicate','no-canal'])add({op:'legacy',id},variant);
for(const id of Object.keys(T.defs))for(const variant of ['normal','poor','materials','energy','protected','gentle','locked-level'])add({op:'tool',id},variant);
// Isolate only the original building next-day wrapper from all other day systems.
C.nextDay=s=>{s.day++;return {ok:true};};
delete require.cache[require.resolve('../../src/building.js')];require('../../src/building.js');
const weatherProfiles=[];for(let day=0;day<448;day++)for(const minutes of [390,600,1080,1320])weatherProfiles.push({day,minutes,expected:ZRZEnvironment.profile(day,minutes)});
const daily=[];
function dailyCase(label,setup){const s=prepared();s.bag={rice:100};s.storage={rice:100};s.kitchen.lots={bag:{rice:[{qty:100,age:3}]},storage:{rice:[{qty:100,age:3}]}};s.farm.water=0;s.farm.facilities=[{type:'sprinkler',anchor:0,durability:70,enabled:true,level:0}];s.farm.beds[0].fertility=50.25;s.plots[0].crop=null;setup(s);const before=JSON.parse(JSON.stringify(s));C.nextDay(s);daily.push({label,before,expected:{day:s.day,building:s.building,upgrades:s.upgrades,water:s.farm.water,facilities:s.farm.facilities,bag:s.bag,fertility:s.farm.beds[0].fertility,bagAge:s.kitchen.lots.bag.rice[0].age,storageAge:s.kitchen.lots.storage.rice[0].age,journal:s.journal,discovered:s.discovered}});}
for(const [id,p] of Object.entries(B.projects))for(let level=1;level<=p.max;level++)dailyCase(id+'/'+level,s=>{if(id==='house')s.building.house=level-1;else if(id==='orchard')s.building.land.orchard=!!(level-1);else s.building.levels[id]=level-1;s.building.jobs=[{id,level,readyDay:s.day+1}];});
dailyCase('future-job',s=>s.building.jobs=[{id:'house',level:1,readyDay:s.day+2}]);
dailyCase('four-completions',s=>s.building.jobs=['granary','workshop','well','nursery'].map(id=>({id,level:1,readyDay:s.day+1})));
for(const level of [1,2])for(const mode of ['craft','tools'])dailyCase('workshop/'+level+'/'+mode,s=>{s.building.levels.workshop=level;s.building.modes.workshop=mode;});
for(const level of [1,2])for(const mode of ['soil','seed'])for(const day of [6,7,27,55])dailyCase('nursery/'+level+'/'+mode+'/'+day,s=>{s.day=day;s.building.levels.nursery=level;s.building.modes.nursery=mode;});
for(const mode of ['fresh','supply'])for(const cold of [false,true])dailyCase('granary/'+mode+'/'+cold,s=>{s.building.levels.granary=2;s.building.modes.granary=mode;s.kitchen.cold=cold;});
const weatherDays={};for(let day=0;day<112;day++)weatherDays[C.weather(day)]??=day;
for(const level of [1,2])for(const mode of ['rain','spring'])for(const [weather,day] of Object.entries(weatherDays))dailyCase('well/'+level+'/'+mode+'/'+weather,s=>{s.day=day;s.building.levels.well=level;s.building.modes.well=mode;});
fs.writeFileSync(process.argv[2],JSON.stringify({source:prepared(),rows,daily,weatherProfiles},null,2));
console.log('Exported '+rows.length+' original building/craft/legacy/tool transactions');
