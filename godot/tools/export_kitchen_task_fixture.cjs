const fs = require('node:fs');
global.window = globalThis;
for (const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','kitchen-view','building','tools','interiors']) require('../../src/' + name + '.js');
const C=ZRZCore,K=ZRZKitchen;
const availability=[];
for(let mask=0;mask<8;mask++){
 const s=C.initial();s.upgrades.kitchen=!!(mask&1);s.upgrades.mill=!!(mask&2);s.upgrades.yard=!!(mask&4);
 for(const id of Object.keys(K.stations))availability.push({mask,id,available:K.available(s,id)});
}
const s=C.initial();s.upgrades.kitchen=true;s.bag.milk=4;
const task={op:'process',id:'cream',n:1,station:'dairy'};
const before=JSON.stringify(s),preview=K.preview(s,task),unchanged=JSON.stringify(s)===before;
const result=K.perform(s,task);
fs.writeFileSync(process.argv[2],JSON.stringify({availability,points:Object.fromEntries(Object.keys(K.stations).map(id=>[id,K.point(s,id)])),stations:K.stations,house:K.house(),home:ZRZBuild.home(),task,preview,unchanged,result,job:s.kitchen.jobs[0],milk:s.bag.milk},null,2));
console.log('Exported kitchen task and 80 equipment availability cases');
