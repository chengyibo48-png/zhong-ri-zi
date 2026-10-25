const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,B=ZRZBuild,rows=[];
function add(id,slot,count,requested=slot,extra=false){
 const s=C.initial();s.upgrades.yard=true;s.building.revision=7;s.layouts=[{id,slot}];
 if(extra)s.layouts.push({id:'greenhouse',slot:slot===23?0:23});
 s.greenhouse=s.layouts.some(p=>p.id==='greenhouse');s.furniture[id]=count;
 const before=structuredClone(s),loaded=C.load(before),result=B.legacyRecover(loaded,requested);
 rows.push({label:id+'/'+slot+'/'+count+'/'+requested+'/'+extra,before,requested,result,expected:{building:loaded.building,furniture:loaded.furniture,layouts:loaded.layouts,greenhouse:loaded.greenhouse,money:loaded.money,stamina:loaded.stamina,minutes:loaded.minutes}});
}
for(const id of Object.keys(ZRZData.furniture))for(const slot of [0,5,6,11,12,17,18,23])for(const count of [0,9])add(id,slot,count);
for(const requested of [-1,24,3])add('bench',0,0,requested);
add('greenhouse',0,0,0,true);add('bench',0,0,0,true);
const slots=C.layoutSlots.map((p,slot)=>({slot,x:p.x+1920,y:p.y+1152}));
const source=C.initial();source.upgrades.yard=true;source.layouts=[{id:'bench',slot:5},{id:'greenhouse',slot:23}];source.greenhouse=true;
fs.writeFileSync(process.argv[2],JSON.stringify({rows,slots,source}));
console.log('Source legacy recovery: '+rows.length+' transactions');
