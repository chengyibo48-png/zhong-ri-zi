const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
global.ZRZData=require('../src/content.js');global.ZRZCore=require('../src/core.js');global.ZRZLandscape=require('../src/landscape.js');global.ZRZArt=require('../src/art.js');global.window=global;
for(const name of ['world','village','farming','ranch','ranch-view'])vm.runInThisContext(fs.readFileSync(require.resolve('../src/'+name+'.js'),'utf8'));
const C=ZRZCore,D=ZRZData,V=ZRZVillage,R=ZRZRanch,F=ZRZFarming,ok=r=>assert.equal(r.ok,true,r.msg),clone=s=>JSON.parse(JSON.stringify(s));
function rich(){const s=C.initial();s.money=100000;for(const id of Object.keys(D.items))s.bag[id]=100;s.stamina=100;return s;}
function healthy(s){s.stamina=100;for(const a of s.animals){a.hunger=100;a.health=100;a.clean=100;a.mood=100;a.bond=100;a.illness=0;a.warning=0;a.stress=0;}for(const b of Object.values(s.ranch.barns)){b.clean=100;b.comfort=1;}}
test('legacy saves migrate three companions without changing inventory, fields or earned products',()=>{
 const s=C.initial();assert.equal(s.animals.length,3);const raw=clone(s);delete raw.ranch;raw.animals=raw.animals.map(({id,name,species,product,bond,fed,ready})=>({id,name,species,product,bond,fed,ready}));raw.animals[0].ready=6;
 const v=C.load(raw);assert.equal(v.animals[0].ready,6);assert.deepEqual(v.bag,raw.bag);assert.deepEqual(v.farm,raw.farm);assert.deepEqual(C.load(v).animals,v.animals);
 const legacy=JSON.parse(fs.readFileSync(require.resolve('./fixtures/v02.json'),'utf8'));const old=C.load(legacy);assert.equal(old.money,legacy.money);assert.equal(old.animals.length,3);assert.equal(old.ranch.barns.poultry.built,true);
});
test('new barns are on the continuous map with reachable doors and usable interiors',()=>{
 const s=C.initial();assert.equal(V.houses.length,47);
 for(const b of Object.values(R.barns)){const h=V.houses.find(h=>h.id===b.house);assert(h);assert(!V.blocked(s,h.door.x,h.door.y));assert(V.route(s,h.door.x,h.door.y).length>0,h.name);assert(V.roomObjects(h).some(p=>p.kind==='animals'),h.name);}
 for(let i=0;i<72;i++){const p=V.plotPosition(i);assert(V.route(s,p.x,p.y).length>0,'plot '+i);}
});
test('feeding charges per species, rejects unsuitable hay and repeats atomically',()=>{
 const s=rich(),cow=s.animals.find(a=>a.type==='cow');let n=s.bag.feed;ok(R.action(s,cow.id,'feed'));assert.equal(s.bag.feed,n-3);assert.equal(cow.hunger,100);
 let before=JSON.stringify(s);assert.equal(R.action(s,cow.id,'feed').ok,false);assert.equal(JSON.stringify(s),before);
 assert.equal(R.action(s,'hen','feed','hay').ok,false);s.bag.feed=0;before=JSON.stringify(s);assert.equal(R.action(s,'hen','feed').ok,false);assert.equal(JSON.stringify(s),before);
});
test('five species have housing, sex, age and production cycle constraints',()=>{
 const s=rich();assert.equal(R.buyAnimal(s,'sheep').ok,false);ok(R.barnAction(s,'sheepfold','build'));ok(R.barnAction(s,'pigpen','build'));
 ok(R.buyAnimal(s,'sheep','male','hardy',false));ok(R.buyAnimal(s,'pig','female','local',false));ok(R.buyAnimal(s,'hen','male','local',false));ok(R.buyAnimal(s,'cow','female','local',true));healthy(s);
 const young=s.animals.at(-1),male=s.animals.find(a=>a.type==='hen'&&a.sex==='male'),sheep=s.animals.find(a=>a.type==='sheep');
 for(let i=0;i<3;i++){healthy(s);C.nextDay(s);}assert.equal(young.ready,0);assert.equal(male.ready,0);assert.equal(sheep.ready,0);healthy(s);C.nextDay(s);assert.equal(sheep.ready,1);assert(s.animals.find(a=>a.type==='pig').ready>=1);
});
test('four quality grades survive collection, save, sell and prevent duplicate collection',()=>{
 const s=rich(),a=s.animals[0];a.qualityStock=[1,2,3,4];a.ready=10;const before=s.bag.egg;ok(R.action(s,a.id,'collect'));assert.equal(s.bag.egg,before+10);assert.deepEqual(s.quality.egg,[2,3,4]);assert.equal(R.action(s,a.id,'collect').ok,false);
 const v=C.load(s);assert.deepEqual(v.quality.egg,[2,3,4]);assert.equal(v.animals[0].ready,0);ok(C.sell(v,'egg',1));assert.deepEqual(v.quality.egg,[2,3,4]);
});
test('automatic feeding consumes actual stocks and never uses legacy free feeding',()=>{
 const s=rich();s.ranch.policy='inside';s.upgrades.coop=true;s.ranch.barns.cattle.autoFeed=true;s.ranch.stores.feed=3;const a=s.animals.find(a=>a.type==='cow');a.hunger=35;const bag=s.bag.feed;C.nextDay(s);assert.equal(s.ranch.stores.feed,0);assert.equal(s.bag.feed,bag);assert(a.hunger>50);
 a.hunger=35;C.nextDay(s);assert(a.hunger<25);assert(s.ranch.notices.some(n=>n.text.includes('料仓不足')));
});
test('illness follows warning days; rest and medicine help without death or permanent loss',()=>{
 const s=rich(),a=s.animals[0];s.ranch.policy='inside';a.hunger=0;a.clean=0;s.ranch.barns.poultry.clean=0;C.nextDay(s);assert.equal(a.illness,0);C.nextDay(s);assert(a.illness>0);
 for(let i=0;i<120;i++)C.nextDay(s);assert.equal(s.animals.length,3);assert(a.health>=15);const illness=a.illness;s.stamina=100;ok(R.action(s,a.id,'treat'));assert(a.illness<illness);assert(a.rest);healthy(s);a.illness=20;C.nextDay(s);assert(a.illness<20);
});
test('breeding reserves capacity and offspring inherits a parent breed after comfortable days',()=>{
 const s=rich();ok(R.barnAction(s,'sheepfold','build'));ok(R.buyAnimal(s,'sheep','female','hardy',false));ok(R.buyAnimal(s,'sheep','male','hardy',false));healthy(s);const [m,f]=s.animals.filter(a=>a.type==='sheep');ok(R.breed(s,m.id,f.id));assert.equal(R.reserved(s,'sheepfold'),1);assert.equal(R.buyAnimal(s,'sheep').ok,false);assert.equal(R.breed(s,m.id,f.id).ok,false);
 let saved=C.load(s);assert.equal(saved.ranch.births.length,1);for(let i=0;i<6;i++){healthy(saved);C.nextDay(saved);}const baby=saved.animals.find(a=>a.parents.includes(m.id));assert(baby);assert.equal(baby.breed,'hardy');assert.equal(baby.age,0);assert.equal(baby.generation,1);assert.equal(baby.position.room,R.barns.sheepfold.house);assert.equal(saved.ranch.births.length,0);
});
test('incubation consumes only fertile eggs and stalls in dirty barns',()=>{
 const s=rich();assert.equal(R.incubate(s,'hen').ok,false);ok(R.barnAction(s,'poultry','comfort'));const eggs=s.bag.egg,n=s.bag.fertileHenEgg;ok(R.incubate(s,'hen'));assert.equal(s.bag.fertileHenEgg,n-1);assert.equal(s.bag.egg,eggs);s.ranch.barns.poultry.clean=0;C.nextDay(s);assert.equal(s.ranch.births[0].remaining,4);for(let i=0;i<4;i++){healthy(s);C.nextDay(s);}assert.equal(s.ranch.births.length,0);assert(s.animals.some(a=>a.age===0));
});
test('barn cleaning and compost connect husbandry to planting without free materials',()=>{
 const s=rich(),b=s.ranch.barns.poultry;b.clean=50;b.waste=4;const m=s.bag.manure;ok(R.barnAction(s,'poultry','clean'));assert.equal(s.bag.manure,m+4);assert.equal(R.barnAction(s,'poultry','clean').ok,false);const compost=s.bag.compost;ok(R.craft(s,'compost'));assert.equal(s.bag.manure,m+2);assert.equal(s.processing.at(-1).qty,3);C.nextDay(s);assert.equal(s.bag.compost,compost+3);
 const saved=C.load(s);assert.equal(saved.bag.compost,compost+3);
});
test('processing milk and wool spends ingredients, supports delayed dairy and preserves quality',()=>{
 const s=rich();s.bag.milk=2;s.quality.milk=[0,0,2];ok(R.craft(s,'yogurt'));assert.equal(s.bag.milk||0,0);const v=C.load(s),before=v.bag.yogurt;C.nextDay(v);assert.equal(v.bag.yogurt,before+2);assert.equal(v.quality.yogurt[0],2);
 ok(R.craft(s,'yarn'));ok(R.craft(s,'cloth'));assert.equal(v.bag.wool,100);
});
test('rehoming is explicit, reversible, and blocks parents with an active pregnancy',()=>{
 const s=rich(),a=s.animals[0];ok(R.collect(s,a));assert.equal(R.rehome(s,a.id).ok,false);const n=s.money;ok(R.rehome(s,a.id,true));assert.equal(s.animals.length,2);const v=C.load(s);assert.equal(v.animals.length,2);ok(R.adopt(v,a.id));assert.equal(v.money,n);assert.equal(v.animals.length,3);assert.equal(v.animals.find(x=>x.id===a.id).name,a.name);
});
test('pet care and training spend time/resources and have once-a-day limits',()=>{
 const s=rich(),before=s.bag.feed;ok(R.petAction(s,'feed'));assert.equal(s.bag.feed,before-1);assert.equal(R.petAction(s,'feed').ok,false);ok(R.petAction(s,'train'));assert.equal(s.ranch.pet.training,10);assert.equal(R.petAction(s,'train').ok,false);ok(R.petAction(s,'follow'));assert.equal(s.ranch.pet.mode,'follow');assert.equal(C.load(s).ranch.pet.mode,'follow');
});
test('animals travel physically, enter only through doors, and are clickable only in their room',()=>{
 const s=rich();s.minutes=700;s.ranch.policy='safe';s.day=0;const a=s.animals[0],h=R.houseOf(a);a.position.room=h.id;a.position.inside={x:480,y:555};let prev={...a.position.inside};for(let i=0;i<60;i++){R.update(s,.05);if(a.position.room){assert(Math.hypot(a.position.inside.x-prev.x,a.position.inside.y-prev.y)<4);prev={...a.position.inside};}}
 assert.equal(a.position.room,null);assert(Math.hypot(a.position.x-h.door.x,a.position.y-h.door.y)<150);assert(R.points(s).some(p=>p.id===a.id));s.minutes=1200;
 for(let i=0;i<1200;i++)R.update(s,.05);assert.equal(a.position.room,h.id);assert(!R.points(s).some(p=>p.id===a.id));s.village.interior=h.id;assert(R.points(s).some(p=>p.id===a.id));
});
test('dynamic flock positions and selection survive save/load with no fixed-index spawn overflow',()=>{
 const s=rich();for(const id of Object.keys(R.barns)){s.ranch.barns[id].built=true;s.ranch.barns[id].space=3;}for(let i=0;i<8;i++){s.stamina=100;ok(R.buyAnimal(s,['hen','duck','sheep','pig'][i%4],'female','local',false));}const v=C.load(s);assert.equal(v.animals.length,11);for(const a of v.animals){assert(a.position.x<5760&&a.position.y<2304);assert(R.destination(v,a.id));}assert.equal(new Set(v.animals.map(a=>a.id)).size,11);
});
test('corrupt husbandry records fail safely rather than silently creating products or animals',()=>{
 for(const mutate of [s=>s.animals[0].qualityStock=[999,0,0,0],s=>s.animals[1].id=s.animals[0].id,s=>s.ranch.stores.feed=-1,s=>s.animals[0].position.room='unknown',s=>s.ranch.barns.poultry.space=99]){const s=C.initial();mutate(s);assert.throws(()=>C.load(s));}
});
test('automatic cleaning and collection consume reserves and preserve product grades exactly once',()=>{
 const s=rich(),b=s.ranch.barns.poultry;b.autoClean=b.autoCollect=true;b.clean=40;s.ranch.stores.bedding=1;const a=s.animals[0];a.qualityStock=[0,0,0,2];a.ready=2;a.retired=true;const eggs=s.bag.egg;C.nextDay(s);assert.equal(s.ranch.stores.bedding,0);assert(b.clean>90);assert.equal(s.bag.egg,eggs+2);assert.equal(s.quality.egg[2],2);assert.equal(a.ready,0);const v=C.load(s);C.nextDay(v);assert.equal(v.bag.egg,eggs+2);
});
test('feed storage is conserved and barn auto upgrades can be toggled without charging twice',()=>{
 const s=rich(),before=s.bag.feed;ok(R.storeFeed(s,'feed',5));assert.equal(s.bag.feed,before-5);ok(R.storeFeed(s,'feed',5,true));assert.equal(s.bag.feed,before);assert.equal(R.storeFeed(s,'feed',5,true).ok,false);
 ok(R.barnAction(s,'poultry','autoFeed'));const money=s.money;ok(R.barnAction(s,'poultry','autoFeed'));ok(R.barnAction(s,'poultry','autoFeed'));assert.equal(s.money,money);
 const v=C.load(s);ok(R.barnAction(v,'poultry','autoFeed'));ok(R.barnAction(v,'poultry','autoFeed'));assert.equal(v.money,money);
});
test('identifier counter recovery cannot duplicate purchased or rehomed animals',()=>{
 const s=rich();ok(R.buyAnimal(s,'hen'));s.ranch.nextId=1;const v=C.load(s);ok(R.buyAnimal(v,'hen'));assert.equal(new Set(v.animals.map(a=>a.id)).size,v.animals.length);assert.doesNotThrow(()=>C.load(v));
});
test('225-day integrated ranch stays saveable through aging, production, automation and farming',()=>{
 let s=rich();s.ranch.barns.sheepfold.built=true;s.ranch.barns.pigpen.built=true;ok(R.buyAnimal(s,'sheep','female','productive',false));ok(R.buyAnimal(s,'pig','female','hardy',false));
 for(const b of Object.values(s.ranch.barns)){b.autoFeed=true;b.autoClean=true;b.autoCollect=true;b.protection=2;b.comfort=2;}
 s.ranch.policy='day';s.ranch.stores.feed=9999;s.ranch.stores.bedding=9999;
 for(let i=0;i<225;i++){if(i%3===0)healthy(s);C.nextDay(s);s=C.load(s);assert.equal(s.animals.length,5);assert.equal(s.farm.beds.length,72);for(const a of s.animals){assert(Number.isFinite(a.progress));assert(a.ready<=28);}}
 assert(s.bag.wool>100);assert(s.bag.egg>100);assert(s.ranch.stores.feed<9999);
});
test('new ranch neighbor orders use ordinary produce and cannot be claimed twice after reload',()=>{
 const s=rich(),before=s.money,qty=s.bag.wool;ok(C.deliver(s,'ranchWool'));assert.equal(s.bag.wool,qty-3);assert.equal(s.money,before+220);const v=C.load(s);assert(v.flags.ranchWool);assert.equal(C.deliver(v,'ranchWool').ok,false);assert.equal(v.money,s.money);
});
test('barn interior chores consume bedding and all visible action points remain reachable',()=>{
 const s=rich();for(const barn of Object.values(R.barns)){const h=V.houses.find(h=>h.id===barn.house);s.village.interior=h.id;s.player={x:480,y:567};for(const point of V.roomObjects(h))assert(V.route(s,point.x,point.y).length,h.name+' '+point.name);}
 s.ranch.barns.poultry.clean=50;const h=V.houses.find(h=>h.id===R.barns.poultry.house),p=V.roomObjects(h).find(p=>p.action==='bedding'),before=s.bag.bedding;ok(V.chore(s,p));assert.equal(s.bag.bedding,before-1);assert.equal(s.ranch.barns.poultry.clean,85);
});
