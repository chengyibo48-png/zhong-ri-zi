'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const C = require('../src/core.js');
const D = require('../src/data.js');
const Camera = require('../src/camera.js');

test('immersive camera fills all aspect ratios without distortion, keeps player visible and round trips input',()=>{
  for(const [width,height] of [[1920,1080],[1440,900],[800,1000],[390,844],[2560,1080]])for(const zoom of [1,1.2,1.4])for(const player of [{x:16,y:54},{x:480,y:288},{x:1896,y:1128}]){
    const v=Camera.geometry(width,height,player,zoom);assert.ok(v.viewWidth<=960+1e-8);assert.ok(v.viewHeight<=576+1e-8);assert.ok(v.x>=0&&v.y>=0);assert.ok(v.x+v.viewWidth<=1920+1e-8);assert.ok(v.y+v.viewHeight<=1152+1e-8);
    assert.ok(Math.abs(v.viewWidth/v.viewHeight-width/height)<1e-8);
    const screen=Camera.toScreen(v,player.x,player.y),world=Camera.toWorld(v,screen.x,screen.y);assert.ok(screen.x>=0&&screen.x<=width);assert.ok(screen.y>=0&&screen.y<=height);assert.ok(Math.abs(world.x-player.x)<1e-8&&Math.abs(world.y-player.y)<1e-8);
  }
});
test('v0.1 saves gain safe camera and input defaults; customized keys survive reload; corrupt bindings fall back',()=>{
  const legacy=C.initial();legacy.settings={speed:'relaxed',sound:false,volume:.5};const s=C.load(legacy);assert.equal(s.settings.zoom,1);assert.equal(s.settings.hints,true);assert.deepEqual(s.settings.bindings,C.defaultBindings);
  s.settings.bindings.up='i';s.settings.zoom=1.4;s.settings.hints=false;const loaded=C.load(s);assert.equal(loaded.settings.bindings.up,'i');assert.equal(loaded.settings.zoom,1.4);assert.equal(loaded.settings.hints,false);
  loaded.settings.bindings.up='s';assert.deepEqual(C.load(loaded).settings.bindings,C.defaultBindings);loaded.settings.zoom=-1;assert.equal(C.load(loaded).settings.zoom,1);
});
test('villagers mention repaired riverside only after the public project actually completes',()=>{
  const s=C.initial();for(const id of ['granny','lin','chen']){s.relations[id].points=50;const npc=D.npcs.find(n=>n.id===id);assert.ok(C.talk(s,id).msg.startsWith(npc.warm));s.flags.bridge=true;assert.ok(C.talk(s,id).msg.startsWith(npc.close));s.flags.bridge=false;}
});

test('first-day loop: harvest, cook, deliver, gather, repair changes persisted village', () => {
  const s = C.initial('春生');
  assert.ok(C.plotAction(s,0,'hand').ok);
  assert.equal(s.bag.cabbage,2);
  assert.ok(C.cook(s,'greens').ok);
  assert.ok(C.deliver(s,'firstDish').ok);
  assert.equal(s.relations.granny.points,20);
  for(let day=0;day<2;day++){
    for(const [id,item] of [['bamboo-0','bamboo'],['bamboo-1','wood'],['bamboo-3','bamboo'],['bamboo-4','wood']]) assert.ok(C.gather(s,id,item).ok);
    if(!day)C.nextDay(s);
  }
  assert.ok(C.repair(s).ok);
  assert.ok(s.flags.bridge);
  assert.equal(C.load(JSON.stringify(s)).flags.bridge,true);
  assert.equal(C.repair(s).ok,false);
});
test('planting spends one seed; rain and water advance crops; harvest cannot duplicate',()=>{
  const s=C.initial();s.seed='radish';const count=s.bag.radishSeed;
  assert.ok(C.plotAction(s,3,'seed').ok);
  assert.equal(s.bag.radishSeed,count-1);
  assert.equal(C.plotAction(s,3,'seed').ok,false);
  for(let i=0;i<4;i++){C.plotAction(s,3,'water');C.nextDay(s);}
  assert.equal(s.plots[3].growth,4);
  assert.ok(C.plotAction(s,3,'hand').ok);
  assert.equal(s.bag.radish,2);
  assert.equal(C.plotAction(s,3,'hand').ok,false);
});
test('missed care slows crops but never removes crops or animals, including season change',()=>{
  const s=C.initial();s.day=27;s.plots[2]={tilled:true,crop:'radish',growth:0,watered:false,soil:2,lastGroup:null,repeats:0};
  C.nextDay(s);assert.equal(C.calendar(s).season,1);assert.equal(s.plots[2].crop,'radish');assert.ok(s.plots[2].growth>0);assert.equal(s.animals.length,3);
  s.seed='radish';assert.equal(C.plotAction(s,3,'seed').ok,false);
});
test('rotation degrades repeated categories and beans restore fertility',()=>{
  const s=C.initial();let p=s.plots[0];p.lastGroup='叶菜';p.repeats=1;C.plotAction(s,0,'hand');assert.equal(p.soil,1);
  s.seed='bean';C.add(s,'beanSeed',2);C.plotAction(s,0,'seed');assert.equal(p.soil,2);p.growth=4;C.plotAction(s,0,'hand');assert.equal(p.soil,2);
});
test('transactions are atomic on missing money, ingredients, materials, or quantities',()=>{
  const s=C.initial(),before=JSON.stringify(s);assert.equal(C.buy(s,'rice',999).ok,false);assert.equal(JSON.stringify(s),before);
  assert.equal(C.buy(s,'wood',1).ok,false);assert.equal(C.sell(s,'rice',-2).ok,false);assert.equal(C.cook(s,'greens').ok,false);assert.equal(C.repair(s).ok,false);assert.equal(C.upgrade(s,'roof').ok,false);
  assert.equal(JSON.stringify(s),before);
});
test('animal produce requires care, collects once, never disappears without food',()=>{
  const s=C.initial();assert.ok(C.tend(s,'hen').ok);const eggs=s.bag.egg;assert.ok(C.tend(s,'hen').ok);C.nextDay(s);assert.ok(C.tend(s,'hen').ok);assert.equal(s.bag.egg,eggs+1);delete s.bag.feed;const ready=s.animals[0].ready;C.nextDay(s);assert.equal(s.animals[0].ready,ready);
});
test('dialogue and gifts have daily caps, relationships never decay, return gift only once',()=>{
  const s=C.initial();C.talk(s,'granny');C.talk(s,'granny');assert.equal(s.relations.granny.points,5);C.add(s,'greens',2);assert.ok(C.gift(s,'granny','greens').ok);assert.equal(C.gift(s,'granny','greens').ok,false);C.nextDay(s);assert.equal(s.relations.granny.points,20);C.talk(s,'granny');assert.equal(s.bag.rice,6);C.talk(s,'granny');assert.equal(s.bag.rice,6);
});
test('zero stamina prevents labor without losing materials and rest recovers',()=>{
  const s=C.initial();s.stamina=0;const before=JSON.stringify(s);assert.equal(C.plotAction(s,0,'hand').ok,false);assert.equal(C.fish(s).ok,false);assert.equal(C.gather(s,'bamboo-0','bamboo').ok,false);assert.equal(JSON.stringify(s),before);C.rest(s);assert.equal(s.stamina,25);
});
test('processing waits for next morning and survives saves',()=>{
  const s=C.initial();s.upgrades.kitchen=true;C.add(s,'mustard',6);assert.ok(C.cook(s,'pickles',3).ok);assert.equal(s.bag.pickles,undefined);const loaded=C.load(JSON.stringify(s));C.nextDay(loaded);assert.equal(loaded.bag.pickles,3);assert.equal(loaded.processing.length,0);C.nextDay(loaded);assert.equal(loaded.bag.pickles,3);
});
test('112-day year advances, late festivals work once each season, play continues',()=>{
  const s=C.initial();s.day=13;C.add(s,'greens',3);assert.ok(C.festival(s,'greens').ok);assert.equal(C.festival(s,'greens').ok,false);s.day=111;assert.ok(C.festival(s,'greens').ok);C.nextDay(s);assert.deepEqual(C.calendar(s),{year:2,season:0,date:1,term:'立春'});assert.ok(s.flags.yearReview);C.nextDay(s);assert.equal(s.day,113);
});
test('save validates and migrates v1, rejects malformed, future, or corrupt payloads',()=>{
  const s=C.initial('小禾');s.flags.firstDish=true;s.settings.speed='normal';assert.deepEqual(C.load(JSON.stringify(s)),s);
  s.version=1;delete s.processing;delete s.festivals;assert.equal(C.load(s).version,3);
  assert.throws(()=>C.load('{oops'));assert.throws(()=>C.load({...s,version:99}));assert.throws(()=>C.load({...s,day:-1}));assert.throws(()=>C.load({...s,plots:[]}));assert.throws(()=>C.load({...s,bag:{fish:-8}}));assert.throws(()=>C.load({...s,bag:{fakeItem:1}}));assert.throws(()=>C.load({...s,stamina:Infinity}));
});
test('full year simulation: seasonal crops, saves and reloads, stable economy and state',()=>{
  let s=C.initial();
  for(let i=0;i<115;i++){
    const seed=Object.keys(D.crops).find(id=>D.crops[id].seasons.includes(C.calendar(s).season));s.seed=seed;
    if(!s.bag[D.crops[seed].seed])C.buy(s,D.crops[seed].seed,1);
    s.plots.forEach((p,j)=>{if(p.crop&&p.growth>=D.crops[p.crop].days)C.plotAction(s,j,'hand');else if(!p.crop){if(!p.tilled)C.plotAction(s,j,'hoe');C.plotAction(s,j,'seed');}C.plotAction(s,j,'water');});
    for(const id of Object.keys(D.crops))if(s.bag[id])C.sell(s,id,s.bag[id]);
    C.talk(s,'granny');C.nextDay(s);s=C.load(JSON.stringify(s));assert.ok(s.money>=0);assert.ok(s.stamina>=0);
  }
  assert.equal(C.calendar(s).year,2);assert.ok(s.stats.harvested>0);assert.ok(s.flags.yearReview);
});

