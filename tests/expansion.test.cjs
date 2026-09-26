const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const C=require('../src/core.js'),D=require('../src/data.js');
const give=(s,needs)=>Object.entries(needs).forEach(([id,n])=>C.add(s,id,n));
const expectOK=r=>assert.equal(r.ok,true,r.msg);
test('content budget and references: 24 neighbors, 8 adult candidates balanced by gender, 28 crops, 30 recipes and complete arcs',()=>{
  assert.equal(D.npcs.length,24);const candidates=D.npcs.filter(n=>n.tier==='romance');assert.equal(candidates.length,8);assert.equal(candidates.filter(n=>n.gender==='女').length,4);assert.equal(candidates.filter(n=>n.gender==='男').length,4);assert(candidates.every(n=>n.age>=18));assert.equal(D.npcs.filter(n=>n.tier==='support').length,12);assert.equal(D.npcs.filter(n=>n.tier==='child').length,4);
  assert.equal(Object.keys(D.crops).length,28);assert.equal(D.recipes.length,30);assert.equal(Object.keys(D.projects).length,4);assert.equal(Object.keys(D.upgrades).length,8);assert.equal(Object.keys(D.stations).length,6);
  for(const n of D.npcs){assert(D.scenes[n.home]);n.likes.forEach(id=>assert(D.items[id]));assert(D.arcs[n.id].length===(n.tier==='romance'?5:n.tier==='support'?3:2));assert(n.family&&n.birthday>0&&n.birthday<=112);}
  for(const r of D.recipes){assert(D.items[r.id]);assert(D.stations[r.station]);Object.keys(r.ingredients).forEach(id=>assert(D.items[id]));}
});
test('all eight romance arcs progress through actual social actions, friendship can be respected, marriage and work persist',()=>{
  for(const [j,n]of D.npcs.filter(n=>n.tier==='romance').entries()){
    let s=C.initial('归乡者',j%2?'男':'女');s.money=2000;give(s,{wood:20,bamboo:20,greens:30});expectOK(C.upgrade(s,'room'));
    for(let step=0;step<4;step++){
      expectOK(C.talk(s,n.id));expectOK(C.gift(s,n.id,'greens'));expectOK(C.storyChoice(s,n.id,step===3&&j===0?1:0));assert.equal(C.storyChoice(s,n.id,0).ok,false);s=C.load(JSON.stringify(s));C.nextDay(s);
    }
    if(j===0){assert.equal(C.marry(s,n.id).ok,false);expectOK(C.date(s,n.id));}
    expectOK(C.marry(s,n.id));assert.equal(C.marry(s,n.id).ok,false);C.nextDay(s);expectOK(C.storyChoice(s,n.id,0));assert.equal(s.stories[n.id].step,5);
    expectOK(C.sharedLife(s,'meal','greens'));assert.equal(C.sharedLife(s,'meal','greens').ok,false);expectOK(C.sharedLife(s,'visit'));s=C.load(s);assert.equal(s.marriage.spouse,n.id);assert.equal(s.marriage.memories.length,2);
    s.minutes=1260;assert.equal(C.npcScene(s,n),'farm');s.minutes=600;assert(D.scenes[C.npcScene(s,n)]);assert.equal(C.marry(s,'lan').ok,false);
  }
});
test('all support and child arcs are playable and remain recoverable after their original season',()=>{
  for(const n of D.npcs.filter(n=>n.tier!=='romance')){let s=C.initial();s.day=112+90;give(s,{greens:20});for(let i=0;i<D.arcs[n.id].length;i++){C.talk(s,n.id);C.gift(s,n.id,'greens');expectOK(C.storyChoice(s,n.id,i%2));s=C.load(s);C.nextDay(s);}assert.equal(s.stories[n.id].step,D.arcs[n.id].length);assert.equal(C.date(s,n.id).ok,false);assert.equal(C.marry(s,n.id).ok,false);}
});
test('every recipe can be learned, prepared with its station, cooked in batches, processed through rain and saved',()=>{
  for(const r of D.recipes){let s=C.initial();for(const id of Object.keys(D.upgrades))s.upgrades[id]=true;C.unlockRecipe(s,r.id);give(s,Object.fromEntries(Object.entries(r.ingredients).map(([k,n])=>[k,n*3])));expectOK(C.cook(s,r.id,3));s=C.load(s);for(let i=0;i<3;i++)C.nextDay(s);assert((s.bag[r.id]||0)>=3,r.id);}
  let s=C.initial();give(s,{tomato:1,egg:1});const before=JSON.stringify(s.bag);expectOK(C.trial(s,'tomato','egg'));assert.equal(JSON.stringify(s.bag),before);assert(s.knownRecipes.includes('tomatoEgg'));assert.equal(C.trial(s,'wood','milk').ok,false);
  give(s,{spinach:3});delete s.bag.cabbage;expectOK(C.cook(s,'greens',1,true));assert.equal(s.bag.spinach,1);
  s.upgrades.yard=true;s.day=3;C.add(s,'mushroom',2);expectOK(C.process(s,'driedMushroom'));C.nextDay(s);assert.equal(s.processing.length,1);s=C.load(s);C.nextDay(s);assert.equal(s.processing.length,0);assert.equal(s.bag.driedMushroom,2);
});
test('quality survives splitting stacks, storing, loading, selling and consuming without duplication',()=>{
  let s=C.initial();s.upgrades.storage=true;C.add(s,'cabbage',10);s.quality.cabbage=[3,2];const before=s.money;expectOK(C.storageMove(s,'cabbage',8,true));assert.equal(s.bag.cabbage,2);assert.deepEqual(s.quality.cabbage,[0,2]);assert.deepEqual(s.storageQuality.cabbage,[3,0]);s=C.load(s);expectOK(C.sell(s,'cabbage',2));assert.equal(s.money-before,Math.floor(22*2*1.4));expectOK(C.storageMove(s,'cabbage',8,false));expectOK(C.cook(s,'greens',3));s=C.load(s);assert.equal(s.bag.cabbage,2);assert.deepEqual(s.quality.cabbage,[2,0]);const unchanged=JSON.stringify(s);assert.equal(C.storageMove(s,'cabbage',99,true).ok,false);assert.equal(JSON.stringify(s),unchanged);
});
test('four public projects honor unlock season, change saved world, unlock useful recipes and reject duplicate spending',()=>{
  let s=C.initial();s.flags.firstDish=true;give(s,{wood:100,bamboo:100});for(const [id,p]of Object.entries(D.projects)){s.day=Math.max(0,p.season*28-1);if(p.season)assert.equal(C.project(s,id).ok,false);s.day=p.season*28;expectOK(C.project(s,id));const bag=JSON.stringify(s.bag);assert.equal(C.project(s,id).ok,false);assert.equal(JSON.stringify(s.bag),bag);s=C.load(s);assert(s.projects[id]);assert(s.knownRecipes.includes(p.recipe));}
});
test('furniture can be crafted, placed, moved and returned; water, compost, pests and animal comfort have mild effects',()=>{
  let s=C.initial();s.money=5000;give(s,{wood:100,bamboo:100,feed:30,compost:2});expectOK(C.upgrade(s,'yard'));expectOK(C.craft(s,'trellis'));expectOK(C.place(s,'trellis',3));assert.equal(C.place(s,'bench',3).ok,false);expectOK(C.removeFurniture(s,3));expectOK(C.place(s,'trellis',4));s=C.load(s);assert.deepEqual(s.layouts,[{id:'trellis',slot:4}]);
  s.plots[0].soil=0;expectOK(C.fertilize(s,0));assert.equal(s.plots[0].soil,1);s.plots[0].pest=true;expectOK(C.clearPest(s,0));s.projects.canal=true;expectOK(C.upgrade(s,'irrigation'));s.day=51;s.plots[2]={tilled:true,crop:'corn',growth:0,watered:false,soil:2,lastGroup:null,repeats:0,care:0,pest:false};C.nextDay(s);assert(s.plots[2].growth>0);assert.equal(s.waterReserve,2);
  s.day=99;const crops=s.plots.filter(p=>p.crop).length;C.nextDay(s);assert.equal(s.plots.filter(p=>p.crop).length,crops);expectOK(C.animalAction(s,'cow','clean'));assert.equal(C.animalAction(s,'cow','clean').ok,false);expectOK(C.pet(s));assert.equal(C.pet(s).ok,false);
});
test('four festivals have choices, late make-up entry and once-per-season rewards; all chapters and year choices persist',()=>{
  let s=C.initial();s.day=111;C.add(s,'greens',10);for(let season=0;season<4;season++){expectOK(C.festival(s,'greens',season%2,season));assert.equal(C.festival(s,'greens',0,season).ok,false);expectOK(C.chapter(s,season,season%2));}s=C.load(s);assert.equal(s.festivals.length,4);C.nextDay(s);expectOK(C.yearPlan(s,2));s=C.load(s);assert.equal(s.yearPlans[1],2);assert(C.yearSummary(s).length>=5);assert.equal(s.day,112);
});
test('letters, achievements, invitations, skill rewards and gathering recovery cannot be repeatedly claimed',()=>{
  let s=C.initial();expectOK(C.mail(s,'welcome'));const seeds=s.bag.cabbageSeed;assert.equal(C.mail(s,'welcome').ok,false);assert.equal(s.bag.cabbageSeed,seeds);s.stats.harvested=30;expectOK(C.claimAchievement(s,'harvest'));assert.equal(C.claimAchievement(s,'harvest').ok,false);s.skills.farming.xp=25;expectOK(C.skill(s,'farming','gentle'));assert.equal(C.skill(s,'farming','care').ok,false);s.upgrades.room=true;C.add(s,'greens',3);expectOK(C.hostMeal(s,'granny','greens'));assert.equal(C.hostMeal(s,'granny','greens').ok,false);expectOK(C.smallEvent(s,'tea'));assert.equal(C.smallEvent(s,'tea').ok,false);s=C.load(s);assert.equal(C.smallEvent(s,'tea').ok,false);
});
test('v1/v2 migrate to v3, malformed additions are rejected, and original progress is preserved',()=>{
  const s=C.initial();s.money=321;s.flags.bridge=true;s.day=41;const old=JSON.parse(JSON.stringify(s));old.version=2;delete old.stories;delete old.knownRecipes;const next=C.load(old);assert.equal(next.version,3);assert.equal(next.money,321);assert.equal(next.day,41);assert(next.projects.bridge);assert.equal(Object.keys(next.relations).length,24);
  for(const mutate of [v=>v.version=99,v=>v.storage.wood=-2,v=>v.quality.rice=[999,1],v=>v.stories.granny.step=50,v=>v.partners.lan='dating',v=>v.marriage.spouse='lan',v=>v.layouts=[{id:'bench',slot:99}],v=>v.appearance.skin=99,v=>v.processing=[{id:'rice',qty:-1,readyDay:0,station:'石磨'}]]){const v=C.initial();mutate(v);assert.throws(()=>C.load(v));}
});
test('all NPCs are reachable in all weather/day templates, including a crowded market day',()=>{
  const sandbox={window:{ZRZData:D,ZRZCore:C,ZRZArt:require('../src/art.js'),ZRZLandscape:require('../src/landscape.js')}};vm.runInNewContext(fs.readFileSync(require.resolve('../src/world.js'),'utf8'),sandbox);const W=sandbox.window.ZRZWorld;
  for(const day of [0,3,5,46,99,111])for(const minutes of [390,700,1000,1260]){const s=C.initial();s.day=day;s.minutes=minutes;for(const scene of Object.keys(D.scenes)){s.scene=scene;s.player=require('../src/landscape.js').spawn(scene);const points=W.points(s).filter(p=>p.kind==='npc');const used=new Set();for(const p of points){assert(!used.has(p.x+','+p.y),p.id+' overlaps another NPC');used.add(p.x+','+p.y);assert.equal(W.blocked(s,p.x,p.y+5),false,p.id+' blocked on '+scene);assert(W.route(s,p.x,p.y+5).length,p.id+' unreachable on '+scene);}}}
});
test('save/load every day across 225 days with farming, cooking, processing, schedules and a second year',()=>{
  let s=C.initial();s.money=20000;give(s,{wood:200,bamboo:200,greens:200,mushroom:500,wheat:500});Object.keys(D.upgrades).forEach(id=>s.upgrades[id]=true);
  for(let day=0;day<225;day++){const n=D.npcs[day%D.npcs.length];C.talk(s,n.id);C.gift(s,n.id,'greens');C.storyChoice(s,n.id,0);if(day%3===0)C.process(s,'driedMushroom');C.process(s,'flour');C.nextDay(s);s=C.load(JSON.stringify(s));assert.equal(s.day,day+1);assert.equal(Object.keys(s.relations).length,24);assert(s.stamina>=0&&s.stamina<=100);}
  assert.equal(C.calendar(s).year,3);assert(s.bag.flour>0);assert(s.eventLog.length<=200);
});

test('real v0.2 fixture migrates without losing existing dates, money, relations or upgrades',()=>{
  const previous=JSON.parse(fs.readFileSync(require.resolve('./fixtures/v02.json'),'utf8'));
  assert.equal(previous.version,2);const s=C.load(previous);assert.equal(s.version,3);
  for(const key of ['day','money','name'])assert.equal(s[key],previous[key]);
  assert.equal(s.relations.qiao.points,previous.relations.qiao.points);assert.equal(s.flags.bridge,previous.flags.bridge);assert.equal(s.upgrades.kitchen,previous.upgrades.kitchen);assert.equal(Object.keys(s.relations).length,24);
});

test('invitations and favors remain once-only after reload; unknown inherited identifiers cannot create content',()=>{
  let s=C.initial();s.upgrades.room=true;C.add(s,'greens',5);expectOK(C.hostMeal(s,'zhouSenior','greens'));
  for(const f of D.favors){give(s,f.needs);s.scene=f.id===2?'town':'farm';expectOK(C.favor(s,f.id));s=C.load(s);assert.equal(C.favor(s,f.id).ok,false);}
  s.scene='farm';assert.equal(C.hostMeal(s,'zhouSenior','greens').ok,false);const before=JSON.stringify(s.bag);assert.equal(C.craft(s,'constructor').ok,false);assert.equal(C.project(s,'__proto__').ok,false);assert.equal(JSON.stringify(s.bag),before);
  for(const key of ['constructor','__proto__']){const bad=C.initial();bad.storage=JSON.parse('{"'+key+'":1}');assert.throws(()=>C.load(bad));}
});
