const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
global.ZRZData=require('../src/content.js');global.ZRZCore=require('../src/core.js');global.ZRZLandscape=require('../src/landscape.js');global.ZRZArt=require('../src/art.js');global.window=global;
for(const name of ['world','village','farming'])vm.runInThisContext(fs.readFileSync(require.resolve('../src/'+name+'.js'),'utf8'));
const C=ZRZCore,D=ZRZData,V=ZRZVillage,F=ZRZFarming;
const ok=r=>assert.equal(r.ok,true,r.msg),clone=s=>JSON.parse(JSON.stringify(s));
function rich(){const s=C.initial();s.money=100000;for(const id of Object.keys(D.items))s.bag[id]=100;s.stamina=100;return s;}
function plant(s,i,id='cabbage',kind='normal'){s.plots[i].tilled=true;s.plots[i].crop=null;s.stamina=100;ok(F.perform(s,i,'sow',{crop:id,kind,density:'balanced'}));}
test('old 24/72 plot saves migrate once, preserving crops, money, inventory and local irrigation investment',()=>{
 const before=C.initial('旧院');delete before.farm;before.upgrades.irrigation=true;before.waterReserve=2;const s=C.load(before);assert.equal(s.plots.length,72);assert.equal(s.farm.beds.length,72);assert.deepEqual(s.bag,before.bag);assert.equal(s.money,before.money);assert.equal(s.plots[0].crop,before.plots[0].crop);assert.equal(s.farm.facilities.length,1);assert.equal(C.load(s).farm.facilities.length,1);
 const legacy=JSON.parse(fs.readFileSync(require.resolve('./fixtures/v02.json'),'utf8'));const migrated=C.load(legacy);assert.equal(migrated.farm.beds.length,72);assert.equal(migrated.money,legacy.money);assert.equal(migrated.day,legacy.day);
});
test('seed variants, density cost and seasons are enforced atomically',()=>{
 const s=rich();plant(s,2);const count=s.bag.cabbageSeed;s.stamina=100;ok(F.perform(s,3,'sow',{crop:'cabbage',kind:'normal',density:'dense'}));assert.equal(s.bag.cabbageSeed,count-2);
 let before=JSON.stringify(s);assert.equal(F.perform(s,4,'sow',{crop:'tomato',kind:'normal'}).ok,false);assert.equal(JSON.stringify(s),before);
 s.stamina=0;before=JSON.stringify(s);assert.equal(F.perform(s,4,'sow',{crop:'cabbage',kind:'normal'}).ok,false);assert.equal(JSON.stringify(s),before);
 assert.equal(C.buy(s,'cabbage_heirloom').ok,false);s.day=14;ok(C.buy(s,'cabbage_heirloom'));
});
test('moisture follows soil evaporation, rain, drainage and recoverable overwatering',()=>{
 const s=rich();for(const i of [2,3]){plant(s,i);s.farm.beds[i].moisture=70;}s.farm.beds[2].type='sand';s.farm.beds[3].type='clay';C.nextDay(s);assert(s.farm.beds[2].moisture<s.farm.beds[3].moisture);
 const b=s.farm.beds[2];b.moisture=50;ok(F.perform(s,2,'water'));ok(F.perform(s,2,'water'));assert.equal(b.moisture,100);ok(F.perform(s,2,'drain'));assert.equal(b.moisture,70);
 s.day=3;b.moisture=10;C.nextDay(s);assert(b.moisture>10);assert.equal(s.plots[2].crop,'cabbage');
});
test('sprinklers are local, consume finite water, can be moved, wear and repaired; greenhouse is local too',()=>{
 const s=rich();s.day=56;ok(F.facility(s,2,'sprinkler'));plant(s,2);plant(s,71);s.farm.beds[2].moisture=0;s.farm.beds[71].moisture=0;s.farm.water=1;C.nextDay(s);assert.equal(s.farm.water,0);assert(s.farm.beds[71].moisture<35);assert(F.covered(s,2,'sprinkler'));assert(!F.covered(s,71,'sprinkler'));
 s.stamina=100;ok(F.facility(s,2,'sprinkler','move',71));assert(F.covered(s,71,'sprinkler'));assert(!F.covered(s,2,'sprinkler'));
 const a=s.farm.facilities[0];a.durability=0;assert(!F.covered(s,71,'sprinkler'));ok(F.facility(s,71,'sprinkler','repair'));assert.equal(a.durability,100);
 s.day=84;ok(F.facility(s,3,'greenhouse'));plant(s,3,'tomato');s.plots[70].tilled=true;assert.equal(F.perform(s,70,'sow',{crop:'tomato',kind:'normal'}).ok,false);assert.equal(F.perform(s,4,'sow',{crop:'tomato',kind:'seasonal'}).ok,false);
});
test('quality has four grades, seed caps, sustained-condition scoring and high-grade seed return',()=>{
 const s=rich();plant(s,2,'cabbage','heirloom');const p=s.plots[2],b=s.farm.beds[2];p.growth=3;b.condition=100;b.fertility=100;b.health=100;assert.equal(F.grade(s,2),3);b.kind='normal';assert.equal(F.grade(s,2),2);b.kind='heirloom';
 const q=s.bag.cabbage||0;ok(F.perform(s,2,'harvest'));assert.equal(s.bag.cabbage-q,2);assert.equal(s.quality.cabbage[2],2);assert.equal(s.farm.collection.cabbage,4);assert.equal(F.perform(s,2,'harvest').ok,false);
 plant(s,3);s.plots[3].growth=3;s.farm.beds[3].condition=100;const seed=s.bag.cabbage_heirloom;ok(F.perform(s,3,'seedSave'));assert.equal(s.bag.cabbage_heirloom-seed,2);assert.equal(s.plots[3].crop,null);
});
test('rare quality survives splits, reload, selling, eating, gifts and cooking without phantom stock',()=>{
 let s=rich();s.upgrades.storage=true;s.bag.cabbage=6;s.quality.cabbage=[1,2,2];ok(C.storageMove(s,'cabbage',5,true));assert.deepEqual(s.storageQuality.cabbage,[1,2,1]);assert.deepEqual(s.quality.cabbage,[0,0,1]);s=C.load(s);const price=C.price(s,'cabbage',1);assert.equal(price,Math.floor(D.items.cabbage.price*1.7));ok(C.sell(s,'cabbage',1));assert.equal(s.quality.cabbage.reduce((a,b)=>a+b,0),0);
 ok(C.storageMove(s,'cabbage',5,false));ok(C.gift(s,'qiao','cabbage'));assert.equal(s.bag.cabbage,4);assert.equal(s.quality.cabbage.reduce((a,b)=>a+b,0),4);
 s.stamina=50;s.bag.berry=1;s.quality.berry=[0,0,1];ok(C.eat(s,'berry'));assert.deepEqual(s.quality.berry,[0,0,0]);
 s.bag.cabbage=2;s.quality.cabbage=[0,0,2];s.upgrades.kitchen=true;ok(C.cook(s,'greens'));assert(s.quality.greens[1]>=1);assert.equal(s.quality.cabbage.reduce((a,b)=>a+b,0),0);C.load(s);
});
test('premium processing and queued cooking carry quality through saves and rain delays only once',()=>{
 let s=rich();s.upgrades.mill=true;s.bag.wheat=1;s.quality.wheat=[0,1,0];ok(C.process(s,'flour'));assert.equal(s.quality.flour[0],2);
 s.knownRecipes=D.recipes.map(r=>r.id);s.upgrades[D.stations['腌菜坛'].upgrade]=true;s.bag.mustard=2;s.quality.mustard=[0,2,0];ok(C.cook(s,'pickles'));assert.equal(s.processing.at(-1).farmGrade,2);s=C.load(s);C.nextDay(s);assert.equal(s.quality.pickles[1],1);C.nextDay(s);assert.equal(s.quality.pickles[1],1);s.day=3;s.bag.mushroom=2;s.quality.mushroom=[2,0,0];s.upgrades[D.stations['晾晒架'].upgrade]=true;ok(C.process(s,'driedMushroom'));C.nextDay(s);assert.equal(s.processing.length,1);assert.equal(s.quality.driedMushroom,undefined);s=C.load(s);C.nextDay(s);assert.equal(s.quality.driedMushroom[0],2);C.nextDay(s);assert.equal(s.quality.driedMushroom[0],2);
});
test('rotation, fallow, slow fertilizer and soil restoration are stateful with no duplicate click benefit',()=>{
 const s=rich();plant(s,2,'bean');const p=s.plots[2],b=s.farm.beds[2];p.growth=4;b.fertility=30;ok(F.perform(s,2,'harvest'));assert.equal(b.fertility,44);ok(F.perform(s,2,'fallow'));const before=b.fertility;C.nextDay(s);assert(b.fertility>=before+9);
 s.stamina=100;ok(F.perform(s,2,'slow'));let snap=JSON.stringify(s);assert.equal(F.perform(s,2,'slow').ok,false);assert.equal(JSON.stringify(s),snap);C.nextDay(s);assert.equal(b.slow,4);
 s.stamina=100;ok(F.perform(s,2,'soil','sand'));assert.equal(b.type,'sand');snap=JSON.stringify(s);assert.equal(F.perform(s,2,'soil','constructor').ok,false);assert.equal(JSON.stringify(s),snap);
});
test('companion crops have compatible roots, independent growth and survive main harvest',()=>{
 const s=rich();s.plots[0].crop=null;s.plots[1].crop=null;plant(s,2);assert.equal(F.perform(s,2,'companion',{crop:'spinach',kind:'normal'}).ok,false);ok(F.perform(s,2,'companion',{crop:'bean',kind:'normal'}));assert(F.relation(s,2)>0);C.nextDay(s);const grown=s.farm.beds[2].companion.growth;assert(grown>0);s.plots[2].growth=3;ok(F.perform(s,2,'harvest'));assert.equal(s.plots[2].crop,'bean');assert.equal(s.plots[2].growth,grown);assert.equal(s.farm.beds[2].companion,null);C.load(s);
});
test('pest simulation is deterministic after reload, neighbor transmission and treatments have real tradeoffs',()=>{
 let s=rich();s.day=30;plant(s,2);plant(s,3);s.farm.beds[2].pests=80;s.farm.beds[3].moisture=100;s.farm.beds[3].density='dense';const t=C.load(s);C.nextDay(s);C.nextDay(t);assert.deepEqual(s.farm,t.farm);assert(s.farm.beds[3].pests>=2);
 s.stamina=100;const b=s.farm.beds[2];b.disease=60;ok(F.perform(s,2,'agent'));assert(b.pests<10&&b.disease===0);assert.equal(b.penalty,8);assert.equal(F.perform(s,2,'bio').ok,false);
});
test('wilt and late harvest are recoverable, crop removal cannot silently destroy produce',()=>{
 const s=rich();plant(s,2);const b=s.farm.beds[2];b.health=15;b.moisture=10;assert(F.stage(s,2).startsWith('萎蔫'));ok(F.perform(s,2,'water'));b.pests=20;ok(F.perform(s,2,'manual'));b.moisture=65;C.nextDay(s);assert(b.health>22);
 let snap=JSON.stringify(s);assert.equal(F.perform(s,2,'remove').ok,false);assert.equal(JSON.stringify(s),snap);s.plots[2].growth=3;b.ripeDays=20;ok(F.perform(s,2,'harvest'));ok(F.perform(s,2,'remove'));assert.equal(b.removed,true);ok(F.perform(s,2,'restore'));assert.equal(b.removed,false);
});
test('batch planning targets the selected region/crop, prevents duplicate jobs and stops without overspending',()=>{
 const s=rich();s.farm.beds.forEach(b=>b.moisture=10);const ids=F.list(s,'dry','home','cabbage');assert.deepEqual(ids,[0,1]);const tasks=F.plan(s,[0,0,1],'water');assert.equal(tasks.length,2);s.stamina=2;let completed=0;for(const t of tasks){const r=F.perform(s,t.index,t.action,t.arg);if(!r.ok)break;completed++;}assert.equal(completed,1);assert.equal(s.stamina,0);assert.equal(s.farm.beds[1].moisture,10);
});
test('malformed farming saves are rejected before replacing the game',()=>{
 for(const change of [s=>s.farm.beds.pop(),s=>s.farm.beds[2].moisture=-1,s=>s.farm.beds[2].type='constructor',s=>s.farm.seedKind='__proto__',s=>s.farm.water=999,s=>s.farm.facilities=[{type:'sprinkler',anchor:99,durability:100,enabled:true}],s=>s.farm.beds[2].companion={crop:'cabbage',kind:'normal',growth:100},s=>s.farm.collection.cabbage=5]){const s=rich();change(s);assert.throws(()=>C.load(s));}
});
test('225-day full village simulation keeps all 72 fields finite, recoverable and saveable',()=>{
 let s=rich();for(let i=2;i<72;i++)plant(s,i,i%3===0?'rice':i%3===1?'radish':'cabbage',i%2?'heirloom':'normal');for(let day=0;day<225;day++){if(day%5===0){s.stamina=100;F.perform(s,2,'water');}C.nextDay(s);s=C.load(s);assert.equal(s.farm.beds.length,72);for(const b of s.farm.beds)for(const k of ['fertility','moisture','health','pests','disease'])assert(Number.isFinite(b[k])&&b[k]>=0&&b[k]<=100);}assert.equal(s.plots.filter(p=>p.crop).length,72);assert.equal(s.animals.length,3);
});


test('tool upgrades reduce real farm labor and furniture stock replaces construction costs',()=>{
 const s=rich();s.toolUpgrades.water=true;s.farm.beds[0].moisture=10;s.stamina=10;ok(F.perform(s,0,'water'));assert.equal(s.stamina,9);
 s.toolUpgrades.hoe=true;s.stamina=10;ok(F.perform(s,25,'hoe'));assert.equal(s.stamina,8);
 s.furniture.scarecrow=1;const money=s.money,wood=s.bag.wood;ok(F.facility(s,25,'scarecrow'));assert.equal(s.money,money);assert.equal(s.bag.wood,wood);assert.equal(s.furniture.scarecrow,0);assert.equal(s.farm.facilities.length,1);assert.equal(F.facility(s,25,'scarecrow').ok,false);
});
