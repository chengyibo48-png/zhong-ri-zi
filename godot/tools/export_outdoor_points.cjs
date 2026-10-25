const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback']) require('../../src/'+name+'.js');

require('../../src/ranch-view.js');
require('../../src/tiles.js');
require('../../src/museum.js');
const C=global.ZRZCore,V=global.ZRZVillage;
const allowed=new Set(['rest','orders','festival','project','mail','archive','storage','processing','home','tools','gatherings','forage','farmcare','weather','economy','animals']);
const cases={}, kinds={};
for(let season=0;season<4;season++)for(let bridge=0;bridge<2;bridge++)for(let mask=0;mask<8;mask++){
 const s=C.initial();s.day=season*28;s.flags.bridge=!!bridge;
 s.upgrades.storage=!!(mask&1);s.upgrades.mill=!!(mask&2);s.upgrades.room=!!(mask&4);
 const points=V.points(s,true).filter(p=>allowed.has(p.kind)).map(p=>({...p}));
 cases[season+'/'+bridge+'/'+mask]=points;
 for(const p of points)kinds[p.kind]=(kinds[p.kind]||0)+1;
}
if(!process.argv[2])throw Error('Pass output filename');
const rests=[[50,600],[95,1300],[100,1320]].map(([stamina,minutes])=>{const s=C.initial();s.stamina=stamina;s.minutes=minutes;const result=C.rest(s);return {before:{stamina,minutes},stamina:s.stamina,minutes:s.minutes,message:result.msg};});
fs.writeFileSync(process.argv[2],JSON.stringify({cases,rests},null,2));
console.log(JSON.stringify({variants:Object.keys(cases).length,kinds}));
