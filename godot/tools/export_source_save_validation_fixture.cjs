const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','actions','characters','ui-art','visual-fx','museum'])require('../../src/'+name+'.js');
const rows=[];
function add(label,setup){const before=ZRZCore.initial();setup(before);let error='',expected=null;try{const normalized=ZRZCore.load(before);expected={kitchen:normalized.kitchen,economy:normalized.economy,toolkit:normalized.toolkit,fishing:normalized.fishing,farm:normalized.farm,building:normalized.building,environment:normalized.environment,forage:normalized.forage,ranch:normalized.ranch,animals:normalized.animals};}catch(e){error=e.message;}rows.push({label,before,error,expected});}
for(const [key,values] of Object.entries({day:[-1,.5,100001,'2',true,null],money:[-1,1000000001,'3',null],stamina:[-1,101,'2',null],minutes:[359,1321,'360',null],scene:['unknown',null,2],worldRevision:[1,5,'4',null]}))for(const value of values)add(key+'/'+JSON.stringify(value),s=>s[key]=value);
for(const [id,n] of [['unknown',1],['wood',-1],['wood',.5],['wood',1000000],['wood','2']])add('bag/'+id+'/'+n,s=>s.bag[id]=n);
for(const [key,values] of Object.entries({crop:['unknown',4],growth:[-1,13,'1',null],soil:[-1,3,'2',null]}))for(const value of values)add('plot/'+key+'/'+JSON.stringify(value),s=>s.plots[0][key]=value);
add('valid',()=>{});add('bounds',s=>{s.money=1000000000;s.minutes=1320;s.stamina=0;});
for(const value of [null,true,4,{},[],"3",3.5])add('version/'+JSON.stringify(value),s=>s.version=value);
for(const field of ['storage','quality','storageQuality','partners','seasonEvents','animalCare','lastGifts','resourcePressure'])for(const value of [[],"bad",true])add(field+'/'+JSON.stringify(value),s=>s[field]=value);
for(const field of ['storage','quality','storageQuality'])add(field+'/unknown',s=>s[field].unknown=field==='storage'?1:[0,0,0]);
for(const value of [[-1,0,0],[.5,0,0],[100,0,0],[0],[0,0,0,0],"bad"])add('quality/'+JSON.stringify(value),s=>s.quality.cabbage=value);
for(const value of [null,{},['unknown']])add('recipes/'+JSON.stringify(value),s=>s.knownRecipes=value);
const romance=ZRZData.npcs.find(n=>n.tier==='romance').id;
for(const setup of [s=>s.stories[romance].step=-1,s=>s.stories[romance].step=100,s=>s.stories[romance].choices=[0],s=>s.stories[romance].lastDay=1,s=>{s.stories[romance].step=1;s.stories[romance].choices=[true];}])add('stories/'+rows.length,setup);
for(const value of ['married',true,2])add('partner/status/'+JSON.stringify(value),s=>s.partners[romance]=value);
add('marriage/numeric-spouse',s=>s.marriage.spouse=3);
add('partner/nonromance',s=>s.partners.granny='dating');
for(const setup of [s=>s.marriage=null,s=>s.marriage.spouse='granny',s=>s.marriage.spouse=romance,s=>s.marriage.day=1,s=>s.marriage.weekly=[],s=>s.marriage.memories={},s=>delete s.marriage.spouse])add('marriage/'+rows.length,setup);
for(const field of ['projects','toolUpgrades']){add(field+'/unknown',s=>s[field].unknown=true);const id=Object.keys(ZRZData[field])[0];for(const value of [0,1,'true',null])add(field+'/value/'+JSON.stringify(value),s=>s[field][id]=value);}
for(const value of [null,{},[{id:'unknown',slot:0}],[{id:Object.keys(ZRZData.furniture)[0],slot:24}],Array.from({length:25},(_,slot)=>({id:Object.keys(ZRZData.furniture)[0],slot})),[{id:Object.keys(ZRZData.furniture)[0],slot:0},{id:Object.keys(ZRZData.furniture)[0],slot:0}]])add('layout/'+rows.length,s=>s.layouts=value);
for(const value of [-1,100000,.5,'1'])add('furniture/'+JSON.stringify(value),s=>s.furniture[Object.keys(ZRZData.furniture)[0]]=value);
for(const id of Object.keys(ZRZData.skillChoices))for(const setup of [s=>delete s.skills[id],s=>s.skills[id].xp=-1,s=>s.skills[id].xp=100000,s=>s.skills[id].choice='invalid'])add('skill/'+id+'/'+rows.length,setup);
for(const field of ['chapters','yearPlans']){add(field+'/bad-key',s=>s[field].bad=0);add(field+'/bad-value',s=>s[field][field==='chapters'?'0-0':'0']=field==='chapters'?2:3);}
for(const field of ['archives','achievements'])for(const value of [null,{},['unknown']])add(field+'/'+JSON.stringify(value),s=>s[field]=value);
for(const setup of [s=>s.appearance=null,s=>s.appearance.shirt=4,s=>s.appearance.skin=3,s=>s.pet=null,s=>s.pet.type='horse',s=>s.pet.name=3,s=>s.pet.bond=101,s=>s.pet.patted=1])add('appearance-pet/'+rows.length,setup);
for(const setup of [s=>s.letters=[{id:'a',day:0,title:'a',from:'a',text:'x'.repeat(2000)}],s=>s.letters=[{id:'a',day:0,title:'a',from:'a',text:'🌾'.repeat(1000)}],s=>s.letters=[{id:'x'.repeat(81),day:0,title:'a',from:'a',text:'a'}],s=>s.letters=[{id:'a',day:1,title:'a',from:'a',text:'a'}]])add('letter/'+rows.length,setup);
for(const value of [-1,31,.5,true,'2'])add('plot/care/'+JSON.stringify(value),s=>s.plots[0].care=value);
for(const [field,values] of Object.entries({id:['unknown'],qty:[0,401,.5,'2'],readyDay:[-1,4,.5,'1'],station:['invalid'],farmGrade:[0,4,.5,null]}))for(const value of values)add('processing/'+field+'/'+JSON.stringify(value),s=>{s.processing=[{id:'pickles',qty:2,readyDay:1,station:'腌菜坛',[field]:value}];});
add('valid/empty-fallbacks',s=>{for(const key of ['storage','quality','storageQuality','partners','seasonEvents','animalCare','lastGifts','resourcePressure'])s[key]=false;});
add('valid/primitive-entries',s=>{s.projects=true;s.toolUpgrades=[];s.furniture=[];s.chapters=true;s.yearPlans=[];});
add('valid/skill-limits',s=>{for(const [id,choices] of Object.entries(ZRZData.skillChoices)){s.skills[id].xp=99999;s.skills[id].choice=choices[0][0];}});
add('valid/letter-utf16-limit',s=>s.letters=[{id:'a',day:0,title:'a',from:'a',text:'🌾'.repeat(999)}]);
add('valid/legacy-layout',s=>s.layouts=[{id:Object.keys(ZRZData.furniture)[0],slot:23}]);
add('valid/quality-zero',s=>s.quality.wood=[0,0]);
for(const [field,values] of Object.entries({version:[0,2,true,'1'],nextId:[0,1000000001,.5],cold:[0,null],equipment:[[],null],mastery:[[],null],lots:[[],null],jobs:[{},null],experiments:[{},null]}))for(const value of values)add('kitchen/'+field+'/'+JSON.stringify(value),s=>s.kitchen[field]=value);
for(const [field,values] of Object.entries({level:[-1,3,.5],clean:[-1,101,'50']}))for(const value of values)add('equipment/'+field+'/'+value,s=>s.kitchen.equipment.stove[field]=value);
add('equipment/missing',s=>delete s.kitchen.equipment.stove);
for(const lots of [[{qty:0,age:0}],[{qty:1,age:-1}],[{qty:1,age:3651}],[{qty:999999,age:0}],null])add('food-lots/'+JSON.stringify(lots),s=>s.kitchen.lots.bag.cabbage=lots);
add('food-lots/nonfood',s=>s.kitchen.lots.bag.wood=[]);
add('mastery/unknown',s=>s.kitchen.mastery.unknown=1);add('mastery/bounds',s=>s.kitchen.mastery.cabbage=10000);
for(const value of ['cabbage','wood+cabbage','cabbage+cabbage+cabbage',2])add('experiment/'+value,s=>s.kitchen.experiments=[value]);
for(const buff of [{kind:'invalid',until:400},{kind:'暖胃',until:-1},{kind:'暖胃',until:1000000000001}])add('buff/'+JSON.stringify(buff),s=>s.kitchen.buff=buff);
function kitchenJob(s){const r=ZRZKitchen.processing[0];s.kitchen.nextId=2;s.kitchen.jobs=[{key:1,id:r.out,station:r.stationId,qty:1,grade:0,start:390,ready:400,weatherDelay:0,cooking:false,recipe:r.id}];return s.kitchen.jobs[0];}
add('valid/kitchen-job',s=>kitchenJob(s));
for(const [field,values] of Object.entries({key:[0,2,.5],id:['unknown'],station:['unknown'],qty:[0,401],grade:[-1,4],start:[-1,1000000000001],ready:[389,1000000000001],weatherDelay:[-1,1000000],cooking:[0,null],recipe:['unknown',3,true,null,{},[]]}))for(const value of values)add('kitchen-job/'+field+'/'+value,s=>kitchenJob(s)[field]=value);
add('kitchen-job/duplicate',s=>{kitchenJob(s);s.kitchen.jobs.push(structuredClone(s.kitchen.jobs[0]));});
for(const [field,values] of Object.entries({version:[0,2,true,'1'],rep:[-1,100000],nextId:[0,1000000001],locked:[{},['unknown'],['wood','wood']],pinned:[{},['unknown'],['wood','wood']],daily:[null,[]],claimed:[{},['0-0','0-0'],['1-0'],['0-3']],jobs:[{},null],receipts:[{},null],ledger:[{},null]}))for(const value of values)add('economy/'+field+'/'+JSON.stringify(value),s=>s.economy[field]=value);
add('daily/date',s=>s.economy.daily.day=1);add('daily/item',s=>s.economy.daily.bought.unknown=1);add('daily/quantity',s=>s.economy.daily.bought.wood=6);
function economicJob(s){s.economy.nextId=2;s.economy.jobs=[{id:'cabbage',key:1,day:0,qty:1,price:30,grades:[1,0,0,0],lots:[{qty:1,age:0}],channel:'coop',theme:'breakfast',ready:900}];return s.economy.jobs[0];}
add('valid/economic-job',s=>economicJob(s));
for(const [field,values] of Object.entries({id:['unknown'],key:[0,2],day:[-1,1],qty:[0,1000000],price:[-1,1000000001],grades:[[0,0,0,0],[1,0,0],[2,0,0,0]],lots:[[],[{qty:0,age:0}],[{qty:1,age:3651}]],channel:['unknown'],theme:['unknown'],ready:[-1,2881]}))for(const value of values)add('economic-job/'+field+'/'+JSON.stringify(value),s=>economicJob(s)[field]=value);
add('economic-job/duplicate-lists',s=>{economicJob(s);s.economy.receipts=structuredClone(s.economy.jobs);});
add('economic-job/two-stalls',s=>{economicJob(s).channel='stall';s.economy.nextId=3;s.economy.jobs.push({...structuredClone(s.economy.jobs[0]),key:2});});
for(const [field,values] of Object.entries({id:['unknown'],day:[-1,1],qty:[0,1000000],money:[-1000000001,1000000001],kind:['unknown']}))for(const value of values)add('ledger/'+field+'/'+value,s=>s.economy.ledger=[{id:'wood',day:0,qty:1,money:1,kind:'现售',[field]:value}]);
add('valid/absent-extensions',s=>{delete s.kitchen;delete s.economy;});add('valid/false-extensions',s=>{s.kitchen=false;s.economy=false;});
for(const value of [null,0,''])add('valid/falsy-extensions/'+JSON.stringify(value),s=>{s.kitchen=value;s.economy=value;});
add('valid/falsy-extra-stock',s=>{ZRZCore.add(s,'rice',8);s.kitchen=false;s.economy=0;});
for(const [field,values] of Object.entries({version:[0,2,true,'1'],tools:[null,[],{}],stock:[{},null,Array(145).fill({})],selected:['invalid'],overlay:[0,null]}))for(const value of values)add('toolkit/'+field+'/'+JSON.stringify(value),s=>s.toolkit[field]=value);
for(const id of Object.keys(ZRZTools.defs))for(const [field,values] of Object.entries({level:[-1,3,'2'],xp:[-1,100000,.5],branch:['invalid',null],shape:['invalid','row','cross']}))for(const value of values)add('tool/'+id+'/'+field+'/'+JSON.stringify(value),s=>s.toolkit.tools[id][field]=value);
for(const [field,values] of Object.entries({type:['unknown'],level:[-1,2,.5],durability:[-1,101,'50'],enabled:[0,null]}))for(const value of values)add('tool-stock/'+field+'/'+JSON.stringify(value),s=>s.toolkit.stock=[{type:'sprinkler',level:0,durability:100,enabled:true,[field]:value}]);
add('facility/level-without-toolkit',s=>{s.toolkit=null;s.farm.facilities=[{type:'sprinkler',anchor:0,durability:100,enabled:true,level:2}];});
add('valid/tools-full',s=>{for(const id of Object.keys(s.toolkit.tools))s.toolkit.tools[id]={level:2,xp:99999,branch:'broad',shape:'cross'};s.toolkit.stock=[{type:'sprinkler',durability:100,enabled:true}];});
for(const value of [null,false,0,''])add('valid/toolkit-falsy-upgrades/'+JSON.stringify(value),s=>{s.toolkit=value;s.toolUpgrades={hoe:true,gather:true};});
add('valid/toolkit-absent-upgrades',s=>{delete s.toolkit;s.toolUpgrades={water:true};});
for(const value of [null,false,0,''])add('fishing/falsy/'+JSON.stringify(value),s=>s.fishing=value);
for(const [field,values] of Object.entries({version:[0,2,true,'1'],mode:['invalid',1],bait:['invalid',1],release:[0,null],waters:[[],null,'bad'],records:[[],null,'bad']}))for(const value of values)add('fishing/'+field+'/'+JSON.stringify(value),s=>s.fishing[field]=value);
for(const row of [{day:-1,casts:0},{day:1,casts:0},{day:0,casts:201},{day:0,casts:.5}])add('fishing-water/'+JSON.stringify(row),s=>s.fishing.waters.river=row);
add('fishing-water/unknown',s=>s.fishing.waters.unknown={day:0,casts:0});
for(const [field,values] of Object.entries({count:[-1,1000001,.5],best:[-1,101,'2'],grade:[-1,4],waters:[null,['unknown'],Array(6).fill('river')]}))for(const value of values)add('fish-record/'+field+'/'+JSON.stringify(value),s=>s.fishing.records.fish={count:1,best:18,grade:0,waters:['river'],[field]:value});
for(const [field,values] of Object.entries({day:[-1,1],water:['unknown'],fish:['unknown',1],length:[-1,101],grade:[-1,4],released:[0,null]}))for(const value of values)add('last-fish/'+field+'/'+JSON.stringify(value),s=>s.fishing.last={day:0,water:'river',fish:'fish',length:18,grade:0,released:false,[field]:value});
add('last-fish/failed-reason',s=>s.fishing.last={day:0,water:'river',fish:null,reason:'bad'});add('last-fish/missing-fish',s=>s.fishing.last={day:0,water:'river',reason:'错过咬钩窗口'});
add('valid/fish-history',s=>{s.fishing.waters.river={day:0,casts:200};s.fishing.records.fish={count:1000000,best:100,grade:3,waters:Array(5).fill('river')};s.fishing.last={day:0,water:'river',fish:'fish',length:100,grade:3,released:true};});
add('valid/fish-failure',s=>s.fishing.last={day:0,water:'river',fish:null,reason:'错过咬钩窗口'});add('valid/fishing-absent',s=>delete s.fishing);add('valid/fishing-primitive-maps',s=>{s.fishing.waters=true;s.fishing.records=1;});
for(const [field,values] of Object.entries({version:[0,2,true,'1'],beds:[[],{}],facilities:[{},Array(145).fill({})],water:[-1,121,'2'],threshold:[19,66],seedKind:['bad'],density:['bad'],collection:[[],null,{unknown:1},{cabbage:0},{cabbage:5}]}))for(const value of values)add('farm/'+field+'/'+JSON.stringify(value),s=>s.farm[field]=value);
for(const field of ['fertility','moisture','health','pests','disease','weeds','compacted','condition','penalty'])for(const value of [-1,101,'2'])add('bed/'+field+'/'+value,s=>s.farm.beds[0][field]=value);
for(const [field,values] of Object.entries({type:['bad'],kind:['bad'],density:['bad'],ripeDays:[-1,100001],ticks:[-1,100001],stress:[-1,1000],slow:[-1,6],fertilized:[-2,1],treated:[-2,1],removed:[0],fallow:[0]}))for(const value of values)add('bed/'+field+'/'+value,s=>s.farm.beds[0][field]=value);
for(const companion of [{crop:'bad',kind:'normal',growth:0},{crop:'cabbage',kind:'bad',growth:0},{crop:'cabbage',kind:'normal',growth:1000}])add('companion/'+JSON.stringify(companion),s=>s.farm.beds[0].companion=companion);
for(const [field,values] of Object.entries({type:['bad'],anchor:[-1,72,.5],durability:[-1,101],enabled:[0]}))for(const value of values)add('farm-facility/'+field+'/'+value,s=>s.farm.facilities=[{type:'sprinkler',anchor:0,durability:100,enabled:true,[field]:value}]);
add('farm-facility/duplicate',s=>s.farm.facilities=[{type:'sprinkler',anchor:0,durability:100,enabled:true},{type:'sprinkler',anchor:0,durability:100,enabled:true}]);
for(const [field,values] of Object.entries({version:[0,2,true,'1'],house:[-1,4,.5],land:[null,[]],levels:[null,[]],modes:[null,[]],revision:[-1,1000000001],nextId:[0,1000000001],jobs:[{},Array(5).fill({})],layout:[{}],claimed:[{},['bad']],style:['bad'],roomUse:['bad'],showcase:['unknown']}))for(const value of values)add('building/'+field+'/'+JSON.stringify(value),s=>s.building[field]=value);
add('building/orchard-type',s=>s.building.land.orchard=1);add('building/claimed-duplicate',s=>s.building.claimed=Array(2).fill(Object.keys(ZRZBuild.milestones)[0]));
for(const id of Object.keys(ZRZBuild.modes)){add('building-level/'+id,s=>s.building.levels[id]=3);add('building-mode/'+id,s=>s.building.modes[id]='bad');}
for(const job of [{id:'bad',level:1,readyDay:1},{id:'house',level:4,readyDay:1},{id:'house',level:2,readyDay:1},{id:'house',level:1,readyDay:2}])add('building-job/'+JSON.stringify(job),s=>s.building.jobs=[job]);
add('building-job/duplicate',s=>s.building.jobs=[{id:'house',level:1,readyDay:1},{id:'house',level:1,readyDay:1}]);
add('valid/building-job',s=>s.building.jobs=[{id:'house',level:1,readyDay:1}]);add('valid/building-explicit-zero',s=>{s.upgrades.room=true;s.building.house=0;});
for(const value of [null,false,0,''])add('valid/building-falsy-upgrades/'+JSON.stringify(value),s=>{s.building=value;s.upgrades.room=true;});
add('valid/farm-properties',s=>{s.farm.beds[0].fertility=37.25;s.farm.beds[0].moisture=65.5;s.farm.beds[0].companion={crop:'cabbage',kind:'normal',growth:0};});
add('valid/farm-fractions',s=>{s.farm.water=37.5;s.farm.threshold=40.25;s.farm.overlay='yes';for(const id of ['ripeDays','ticks','stress','slow'])s.farm.beds[0][id]=.25;s.farm.beds[0].fertilized=-.5;s.farm.beds[0].treated=-.25;});
for(const value of [[],{},0,1,''])add('valid/farm-boolean-coercion/'+JSON.stringify(value),s=>{s.farm.autoSeed=value;s.farm.overlay=value;});
for(const [field,values] of Object.entries({key:[0],type:['bad'],zone:['bad'],cell:[-1],rotation:[4]}))for(const value of values)add('building-layout/'+field+'/'+value,s=>{s.building.nextId=2;s.building.layout=[{key:1,type:'bench',zone:'home',cell:3,rotation:0,[field]:value}];});
add('valid/building-layout',s=>{s.building.house=3;s.building.nextId=2;for(let cell=0;cell<ZRZBuild.zones.home.cols*ZRZBuild.zones.home.rows;cell++){const p={key:1,type:'bench',zone:'home',cell,rotation:0};if(ZRZBuild.checkLayout(s,[p]).ok){s.building.layout=[p];return;}}throw Error('No legal source layout');});
for(const [zone,z] of Object.entries(ZRZBuild.zones))for(let cell=0;cell<z.cols*z.rows;cell++)add('building-space/'+zone+'/'+cell,s=>{s.upgrades.yard=true;s.building.house=3;s.building.land.orchard=true;s.building.nextId=2;s.building.layout=[{key:1,type:'bench',zone,cell,rotation:0}];});
add('building-space/overlap',s=>{s.building.house=3;s.building.nextId=3;s.building.layout=[{key:1,type:'pot',zone:'home',cell:3,rotation:0},{key:2,type:'pot',zone:'home',cell:3,rotation:0}];});
for(const slot of [0,5,23])add('valid/legacy-with-modern-building/'+slot,s=>{s.upgrades.yard=true;s.layouts=[{id:'bench',slot}];});
// Exercise every independent load wrapper's rejection and missing/falsy distinctions.
for(const value of [null,false,0,'',[],{},true,2])add('ranch/root/'+JSON.stringify(value),s=>s.ranch=value);
for(const [key,values]of Object.entries({version:[0,2,true,'1'],nextId:[0,1000001,.5],policy:['bad',null],zone:[-1,2,false],feed:['bad',null],grass:[null,[],[0,101]],stores:[null,[]],barns:[null,{}],births:[null,{}],rehomed:[null,{}],notices:[null,{}],collection:[null,[],{wood:0},{wood:5}]}))for(const v of values)add('ranch/'+key+'/'+JSON.stringify(v),s=>s.ranch[key]=v);
for(const id of Object.keys(ZRZRanch.barns)){
 for(const [key,values]of Object.entries({built:[0,null],space:[-1,4,.5],comfort:[4],protection:[4],efficiency:[4],clean:[-1,101,'50'],durability:[-1,101],waste:[-1,100,.5],lastClean:[-2,1],autoFeed:[0],autoClean:[null],autoCollect:['yes']}))for(const v of values)add('barn/'+id+'/'+key+'/'+JSON.stringify(v),s=>s.ranch.barns[id][key]=v);
 add('barn/missing/'+id,s=>delete s.ranch.barns[id]);
}
for(const key of ['feed','hay','grainFeed','healthFeed','bedding'])for(const v of [-1,10000,.5,'1'])add('ranch-store/'+key+'/'+v,s=>s.ranch.stores[key]=v);
for(const [key,values]of Object.entries({id:['bad','livestock-1.5',3],type:['bad'],breed:['bad'],trait:['bad'],sex:['bad'],name:[3,'🌾'.repeat(7)],species:['bad'],product:['bad'],age:[-1,100001,.5],generation:[-1,100001],progress:[-1,11],qualityStock:[null,[29,0,0,0],[20,20,0,0],[0,0,0]],feathers:[-1,21],retired:[0],rest:[null],lost:['yes'],care:[null,{}],parents:[null,['a','b','c'],['🌾'.repeat(21)]]}))for(const v of values)add('animal/'+key+'/'+JSON.stringify(v),s=>s.animals[0][key]=v);
for(const key of ['bond','hunger','health','mood','clean','stress','illness','warning','feedQuality'])for(const v of [-1,101,'50'])add('animal/'+key+'/'+v,s=>s.animals[0][key]=v);
for(const key of ['feed','pet','clean','treat','breed'])for(const v of [-21,1,.5])add('animal-care/'+key+'/'+v,s=>s.animals[0].care[key]=v);
add('animal/duplicate',s=>s.animals.push(structuredClone(s.animals[0])));
for(const [key,values]of Object.entries({x:[23,3817,'100'],y:[37,3817],room:['unknown',false],inside:[null,{}]}))for(const v of values)add('animal-position/'+key+'/'+JSON.stringify(v),s=>s.animals[0].position[key]=v);
for(const key of ['x','y'])for(const v of [0,1000,'400'])add('animal-inside/'+key+'/'+v,s=>s.animals[0].position.inside[key]=v);
for(const key of ['hunger','energy','training'])for(const v of [-1,101,'50'])add('ranch-pet/'+key+'/'+v,s=>s.ranch.pet[key]=v);
for(const [key,values]of Object.entries({mode:['bad'],fed:[-2,1],trained:[-2,1],position:[null,{}]}))for(const v of values)add('ranch-pet/'+key+'/'+JSON.stringify(v),s=>s.ranch.pet[key]=v);
for(const v of [{day:1,text:'bad'},{day:0,text:'🌾'.repeat(151)},{day:0,text:3},null])add('ranch-notice/'+JSON.stringify(v),s=>s.ranch.notices=[v]);
function birth(s){s.ranch.births=[{id:'birth-1',type:'hen',mother:null,father:null,breed:'local',total:4,remaining:3}];return s.ranch.births[0];}
add('valid/birth',s=>birth(s));
for(const [key,values]of Object.entries({id:[3,null],type:['bad'],breed:['bad'],total:[0,11,.5],remaining:[-1,5],mother:['missing'],father:['missing']}))for(const v of values)add('birth/'+key+'/'+JSON.stringify(v),s=>birth(s)[key]=v);
add('birth/duplicate',s=>{birth(s);s.ranch.births.push(structuredClone(s.ranch.births[0]));});
for(const key of ['mother','father'])add('birth/missing-'+key,s=>delete birth(s)[key]);
add('rehomed/duplicate-live-id',s=>s.ranch.rehomed=[{animal:structuredClone(s.animals[0]),fee:0,day:0}]);
for(const [key,values]of Object.entries({fee:[-1,100001,.5],day:[-1,1],animal:[null,{}]}))for(const v of values)add('rehomed/'+key+'/'+JSON.stringify(v),s=>{const a=structuredClone(s.animals[0]);a.id='livestock-10';s.ranch.rehomed=[{animal:a,fee:0,day:0,[key]:v}];});
add('valid/rehomed',s=>{const a=structuredClone(s.animals.pop());a.id='livestock-10';s.ranch.rehomed=[{animal:a,fee:100000,day:0}];});
add('valid/animal-name-utf16',s=>s.animals[0].name='🌾'.repeat(6));
for(const v of [null,false,0,'',[],{},true,2])add('environment/root/'+JSON.stringify(v),s=>s.environment=v);
for(const v of [0,2,true,'1'])add('environment/version/'+JSON.stringify(v),s=>s.environment.version=v);
for(const v of [null,{},[{day:1,kind:'晴'}],[{day:0,kind:'雨'}],[{day:0,kind:'晴'},{day:0,kind:'晴'}],Array(15).fill({day:0,kind:'晴'})])add('environment/history/'+JSON.stringify(v),s=>s.environment.history=v);
add('valid/environment-empty',s=>s.environment.history=[]);
add('valid/environment-season',s=>{s.day=100;s.environment.history=[36,39,46,50,52,98,100].map(day=>({day,kind:ZRZCore.weather(day)}));});
for(const v of [null,false,0,'',[],{},true,2])add('forage/root/'+JSON.stringify(v),s=>s.forage=v);
for(const [key,values]of Object.entries({version:[0,2,true],mode:['bad'],xp:[-1,1000001,.5],discovered:[null,['bad']],patches:[null,[],{bad:{lastDay:0,readyDay:0,pressure:0}}],finds:[{},false,Array(15).fill({})]}))for(const v of values)add('forage/'+key+'/'+JSON.stringify(v),s=>s.forage[key]=v);
const point=ZRZForage.rawPoints(ZRZCore.initial())[0];
function patch(s){s.forage.patches[point.id]={lastDay:0,readyDay:1,pressure:0};return s.forage.patches[point.id];}
for(const [key,values]of Object.entries({lastDay:[-1,1,.5],readyDay:[-1,9,.5],pressure:[-1,9,.5],lastCare:[null,-1,1,.5]}))for(const v of values)add('forage-patch/'+key+'/'+JSON.stringify(v),s=>patch(s)[key]=v);
for(const v of [null,false,{}])add('forage-patch/root/'+JSON.stringify(v),s=>s.forage.patches[point.id]=v);
for(const [key,values]of Object.entries({id:['bad'],item:['bad'],day:[-1,1,.5],qty:[0,7,.5],grade:[-1,2,true],weather:['雨',3]}))for(const v of values)add('forage-find/'+key+'/'+JSON.stringify(v),s=>s.forage.finds=[{id:point.id,item:point.item,day:0,qty:2,grade:0,weather:ZRZCore.weather(0),[key]:v}]);
for(const v of [null,undefined])add('valid/forage-finds-default/'+v,s=>{if(v===undefined)delete s.forage.finds;else s.forage.finds=v;});
add('valid/forage-duplicate-discovery',s=>s.forage.discovered=[point.id,point.id]);
add('valid/forage-patch',s=>{patch(s).readyDay=8;s.forage.finds=[{id:point.id,item:point.item,day:0,qty:6,grade:1,weather:ZRZCore.weather(0)}];});
for(const v of [null,false,0,'',[],{},true,2])add('neighbors/root/'+JSON.stringify(v),s=>s.neighbors=v);
for(const [key,values]of Object.entries({version:[0,2,true],day:[-1,1,.5],people:[null,[],{}],history:[null,{},Array(161).fill({})]}))for(const v of values)add('neighbors/'+key+'/'+JSON.stringify(v),s=>s.neighbors[key]=v);
const person=ZRZData.npcs[0].id;
for(const [key,values]of Object.entries({introduced:[0,null],recent:[null,Array(13).fill('a'),['🌾'.repeat(51)]],last:[{},true],event:[{},true]}))for(const v of values)add('neighbor-person/'+key+'/'+JSON.stringify(v),s=>s.neighbors.people[person][key]=v);
function record(){return {id:person,key:'test',day:0,minute:390,text:'hello',choice:'',category:'日常',emotion:'calm'};}
for(const [key,values]of Object.entries({id:['bad'],key:[3,'🌾'.repeat(51)],day:[-1,1,.5],minute:[-1,1321,.5],text:[3,'🌾'.repeat(1101)],choice:[3,'🌾'.repeat(101)],category:['bad'],emotion:['bad']}))for(const v of values)add('neighbor-history/'+key+'/'+JSON.stringify(v),s=>s.neighbors.history=[{...record(),[key]:v}]);
function event(s){s.neighbors.people[person].event={day:0,status:'offered',method:null,completed:null};return s.neighbors.people[person].event;}
for(const [key,values]of Object.entries({day:[-1,1,.5],status:['bad','done'],method:['bad','join'],completed:[0,1]}))for(const v of values)add('neighbor-event/'+key+'/'+JSON.stringify(v),s=>event(s)[key]=v);
add('valid/neighbor-history',s=>{s.neighbors.history=[record()];s.neighbors.people[person].last=record();});
add('valid/neighbor-duplicate-recent',s=>s.neighbors.people[person].recent=['test','test']);
add('valid/neighbor-completed',s=>{const e=event(s);e.status='done';e.method='join';e.completed=0;});
add('valid/neighbor-history-utf16',s=>{s.neighbors.history=[{...record(),key:'🌾'.repeat(50),text:'🌾'.repeat(1100),choice:'🌾'.repeat(100)}];});
for(const v of ['unknown',false,0,[],{}])add('village/interior/'+JSON.stringify(v),s=>s.village.interior=v);
for(const v of [null,undefined])add('valid/village-interior/'+v,s=>{if(v===undefined)delete s.village.interior;else s.village.interior=v;});
for(const key of ['ranch','environment','forage','neighbors'])add('valid/missing-'+key,s=>delete s[key]);
// Error precedence follows the actual nested source load wrappers.
add('precedence/village-ranch',s=>{s.village.interior='bad';s.ranch.version=2;});
add('precedence/ranch-kitchen',s=>{s.ranch.version=2;s.kitchen.version=2;});
add('precedence/environment-forage',s=>{s.environment.version=2;s.forage.version=2;});
add('precedence/forage-fishing',s=>{s.forage.version=2;s.fishing.version=2;});
add('precedence/fishing-neighbors',s=>{s.fishing.version=2;s.neighbors.version=2;});

add('valid/animal-name-whitespace',s=>s.animals[0].name='  春禾  ');
add('valid/animal-name-empty',s=>s.animals[0].name='');
add('valid/ranch-id-continuation',s=>{s.animals[0].id='livestock-199';s.ranch.nextId=1;birth(s).id='birth-301';});
add('valid/ranch-empty-birth-id',s=>birth(s).id='');
add('valid/animal-indoor-blocked',s=>{s.animals[0].position.inside={x:480,y:495};});
add('valid/animal-outdoor-blocked',s=>{s.animals[0].position.x=2000;s.animals[0].position.y=1300;});
add('valid/ranch-upgrade-default',s=>{s.ranch=null;s.day=27;s.upgrades.coop=true;s.freeRange=true;});

for(const key of ['uiArt','visualFx','feedback','collection'])for(const value of [null,false,0,'',[],{},true,2])add('outer/'+key+'/'+JSON.stringify(value),s=>s[key]=value);
for(const [key,values]of Object.entries({outfit:['bad',null,0],hairColor:[-1,4,.5,true,null],bag:[0,null,'false'],weatherDress:[0,null,'false']}))for(const value of values)add('appearance-extra/'+key+'/'+JSON.stringify(value),s=>s.appearance[key]=value);
for(const [key,values]of Object.entries({theme:['bad',null,3],seasonal:[0,null,'true']}))for(const value of values)add('uiArt/'+key+'/'+JSON.stringify(value),s=>s.uiArt[key]=value);
for(const [key,values]of Object.entries({density:['bad',null,3],weather:['bad',null,3],ambient:[0,null,'true']}))for(const value of values)add('visualFx/'+key+'/'+JSON.stringify(value),s=>s.visualFx[key]=value);
for(const [key,values]of Object.entries({version:[0,true,2],next:[0,1000000001,.5],rows:[null,{},Array(81).fill({})],days:[null,{},Array(8).fill({})],seen:[null,{},Array(81).fill('x'),['🌾'.repeat(71)]],prefs:[null,false,{}]}))for(const value of values)add('feedback/'+key+'/'+JSON.stringify(value),s=>s.feedback[key]=value);
for(const [key,values]of Object.entries({pace:['bad',null],motion:['bad',null],floating:['bad',null],seconds:[0,9,true,'5'],quiet:[0,null]}))for(const value of values)add('feedback-prefs/'+key+'/'+JSON.stringify(value),s=>s.feedback.prefs[key]=value);
function feedbackRow(){return {id:1,day:0,minute:390,key:'test',title:'test',text:'test',type:'提醒',priority:1,link:'feedback',read:false,count:1};}
for(const [key,values]of Object.entries({id:[-1,2,.5],day:[-1,1,.5],minute:[-1,1321,.5],key:[null,'🌾'.repeat(71)],title:[null,'🌾'.repeat(61)],text:[null,'🌾'.repeat(901)],type:['bad'],priority:[-1,3,true],link:['bad'],read:[0,null],count:[0,1000000,.5]}))for(const value of values)add('feedback-row/'+key+'/'+JSON.stringify(value),s=>{s.feedback.next=2;s.feedback.rows=[{...feedbackRow(),[key]:value}];});
add('feedback-row/duplicate',s=>{s.feedback.next=2;s.feedback.rows=[feedbackRow(),feedbackRow()];});
add('valid/feedback-limits',s=>{s.feedback.next=2;s.feedback.rows=[{...feedbackRow(),key:'🌾'.repeat(70),title:'🌾'.repeat(60),text:'🌾'.repeat(900),count:999999}];s.feedback.seen=['a','a'];});
function feedbackDay(){return {day:0,actions:1,income:0,spent:0,items:{'wood:0':1}};}
for(const [key,values]of Object.entries({day:[-1,1,.5],actions:[-1,1000000001,true],income:[-1,1000000000001],spent:[-1,1000000000001],items:[null,[],{'bad:0':1},{'wood:4':1},{'wood:0':-1}]}))for(const value of values)add('feedback-day/'+key+'/'+JSON.stringify(value),s=>s.feedback.days=[{...feedbackDay(),[key]:value}]);
add('feedback-day/duplicate',s=>s.feedback.days=[feedbackDay(),feedbackDay()]);
add('valid/feedback-day-primitive',s=>s.feedback.days=[{...feedbackDay(),items:true}]);
for(const [key,values]of Object.entries({version:[0,2,true],entries:[null,[]],observations:[null,[]],donated:[null,[]],featured:[null,[]],level:[-1,4,true,1],claimed:[null,['bad'],['field']],badges:[null,['bad'],['observer','observer']],tracked:['bad',0]}))for(const value of values)add('collection/'+key+'/'+JSON.stringify(value),s=>s.collection[key]=value);
const museumKey=Object.keys(ZRZMuseum.byKey)[0],wildId=ZRZMuseum.wildlife[0].id;
for(const [key,values]of Object.entries({first:[-2,1,.5],acquired:[0,null],researched:[0,null],best:[-1,4,.5]}))for(const value of values)add('collection-entry/'+key+'/'+JSON.stringify(value),s=>s.collection.entries[museumKey]={first:0,acquired:false,researched:false,best:0,[key]:value});
add('collection-entry/unknown',s=>s.collection.entries.bad={first:0,acquired:false,researched:false,best:0});
for(const value of [null,{},[-1],[1],[0,0],[0,0,0]])add('collection-observation/'+JSON.stringify(value),s=>s.collection.observations[wildId]=value);
add('collection-donation/undiscovered',s=>{delete s.collection.entries['item:cabbage'];s.collection.donated['item:cabbage']={day:0,mode:'sample',grade:0};});
for(const [key,values]of Object.entries({day:[-1,1,.5],mode:['bad'],grade:[-1,4,true]}))for(const value of values)add('collection-donation/'+key+'/'+JSON.stringify(value),s=>{s.collection.entries['item:cabbage']={first:0,acquired:true,researched:false,best:0};s.collection.donated['item:cabbage']={day:0,mode:'sample',grade:0,[key]:value};});
add('collection-feature/missing',s=>s.collection.featured['物产']='item:cabbage');
add('valid/collection-donation',s=>{s.collection.entries['item:cabbage']={first:0,acquired:true,researched:false,best:0};s.collection.donated['item:cabbage']={day:0,mode:'sample',grade:3};s.collection.featured['物产']='item:cabbage';});
for(const key of ['uiArt','visualFx','feedback','collection'])add('valid/outer-missing-'+key,s=>delete s[key]);
add('precedence/visual-ui',s=>{s.visualFx=null;s.uiArt=null;s.money=-1;});
add('precedence/ui-appearance',s=>{s.uiArt=null;s.appearance.outfit='bad';s.money=-1;});
add('precedence/appearance-core',s=>{s.appearance.outfit='bad';s.money=-1;});
add('precedence/atlas-environment',s=>{s.atlas.version=2;s.environment.version=2;});
add('precedence/neighbors-feedback',s=>{s.neighbors.version=2;s.feedback.version=2;});
add('precedence/feedback-museum',s=>{s.feedback.version=2;s.collection.version=2;});
function exact(row){const precision=[];function floats(value,path){if(typeof value==='number'&&!Number.isInteger(value)){const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);precision.push({path,bytes:bytes.toString('base64')});}else if(Array.isArray(value))value.forEach((v,i)=>floats(v,[...path,i]));else if(value&&typeof value==='object')for(const[k,v]of Object.entries(value))floats(v,[...path,k]);}floats(row,[]);if(precision.length)row._float64_roundtrip={version:1,entries:precision};return row;}
fs.writeFileSync(process.argv[2],[{caseCount:rows.length},...rows].map(row=>JSON.stringify(exact(row))).join('\n')+'\n');console.log('Source save validation '+rows.length);
