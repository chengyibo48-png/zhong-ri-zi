const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const C=require('../src/core.js'),D=require('../src/data.js'),L=require('../src/landscape.js'),A=require('../src/art.js'),Camera=require('../src/camera.js');
const sandbox={window:{ZRZData:D,ZRZCore:C,ZRZLandscape:L,ZRZArt:A}};vm.runInNewContext(fs.readFileSync(require.resolve('../src/world.js'),'utf8'),sandbox);const W=sandbox.window.ZRZWorld;
test('old-map save positions migrate once; expanded outskirts persist and sleeping returns home',()=>{
  for(const scene of Object.keys(D.scenes)){const legacy=C.initial();delete legacy.worldRevision;legacy.scene=scene;legacy.player={x:431,y:212,direction:'left'};const next=C.load(legacy);assert.equal(next.player.x,911);assert.equal(next.player.y,500);assert.equal(next.worldRevision,2);assert.deepEqual(C.load(next).player,next.player);next.player={x:1777,y:1025,direction:'right'};assert.deepEqual(C.load(next).player,next.player);C.nextDay(next);assert.deepEqual(next.player,L.home);}
});
test('every interaction, upgrade and new landmark is accessible without walking through a wall or water',()=>{
  assert.equal(L.width*L.height,4*960*576);let landmarks=0;
  for(const scene of Object.keys(D.scenes))for(const repaired of [false,true]){const s=C.initial();s.scene=scene;s.player=L.spawn(scene);s.flags.bridge=repaired;for(const id of Object.keys(D.upgrades))s.upgrades[id]=repaired;const points=W.points(s);assert.equal(new Set(points.map(p=>p.id)).size,points.length);for(const p of points){const dest={x:p.x,y:p.y+5};assert(!W.blocked(s,dest.x,dest.y),scene+'/'+p.id+' blocked');const route=W.route(s,dest.x,dest.y);assert(route.length,scene+'/'+p.id+' unreachable');let last=s.player;for(const step of route){assert(W.clearLine(s,last,step),scene+'/'+p.id+' clips through collision');last=step;}}if(repaired)landmarks+=L.maps[scene].landmarks.length;}
  assert.equal(landmarks,26);
});
test('new gathering locations cannot be farmed repeatedly by saving or reloading',()=>{
  for(const [scene,m] of Object.entries(L.maps))for(const p of m.landmarks.filter(v=>v.kind==='gather')){let s=C.initial();s.scene=scene;assert(C.gather(s,p.id,p.item).ok);const qty=s.bag[p.item];s=C.load(s);assert.equal(s.collected[p.id],s.day);assert.equal(C.gather(s,p.id,p.item).ok,false);assert.equal(s.bag[p.item],qty);C.nextDay(s);s.scene=scene;assert(C.gather(s,p.id,p.item).ok);}
  let s=C.initial();s.scene='bamboo';for(let i=0;i<4;i++)assert(C.gather(s,'bamboo-'+i,'bamboo').ok);s.scene='mountain';assert(C.gather(s,'landmark-tea','tea').ok);assert.equal(s.resourcePressure.mountain.count,1);assert.equal(s.resourcePressure.bamboo.count,4);s=C.load(s);assert.equal(s.resourcePressure.mountain.count,1);assert.equal(s.resourcePressure.bamboo.count,4);
});
test('all 24 character designs have a distinct combination of silhouette, clothes and profession',()=>{
  assert.equal(Object.keys(A.styles).length,24);assert.equal(new Set(D.npcs.map(n=>JSON.stringify(A.styles[n.id]))).size,24);for(const n of D.npcs){assert(A.styles[n.id].prop);assert(A.styles[n.id].hair);assert(A.styles[n.id].shirt);}
});
test('expanded world camera preserves coordinates on wide and narrow screens and cannot expose off-map pixels',()=>{
  for(const [w,h]of [[1920,1080],[1280,720],[390,844],[2560,1080]])for(const zoom of [1,1.2,1.4])for(const p of [{x:24,y:38},{x:911,y:500},{x:1896,y:1128}]){const v=Camera.geometry(w,h,p,zoom);assert(v.x>=0&&v.y>=0);assert(v.x+v.viewWidth<=1920);assert(v.y+v.viewHeight<=1152);const pos=Camera.toScreen(v,p.x,p.y),back=Camera.toWorld(v,pos.x,pos.y);assert(Math.abs(back.x-p.x)<1e-8&&Math.abs(back.y-p.y)<1e-8);}
});
test('new scenery cannot trap an imported player and expanded furniture slots leave the central path clear',()=>{
  const s=C.initial();s.player={x:650,y:450,direction:'up'};assert(W.blocked(s,s.player.x,s.player.y));assert(W.restorePosition(s));assert(!W.blocked(s,s.player.x,s.player.y));for(const p of C.layoutSlots){assert(!W.blocked(s,p.x,p.y));assert(p.x<840||p.x>980);}
});
