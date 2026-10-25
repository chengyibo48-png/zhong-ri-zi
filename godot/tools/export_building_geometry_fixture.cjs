const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','building','tools','economy','scenes','environment','forage','interiors'])require('../../src/'+name+'.js');
const C=ZRZCore,B=ZRZBuild,s=C.initial(),placements=[],layouts=[],commits=[];
s.upgrades.yard=true;s.building.house=3;s.building.land.orchard=true;
function placement(piece,others=[],label=''){
 const expected=B.placement(s,piece,others);
 placements.push({piece,others,label,house:s.building.house,yard:s.upgrades.yard,orchard:s.building.land.orchard,legacy:s.layouts.slice(),expected});
}
for(const type of Object.keys(B.defs))for(const [zone,z] of Object.entries(B.zones))for(const rotation of [0,1,2,3])for(let cell=0;cell<z.cols*z.rows;cell++)placement({key:1,type,zone,cell,rotation});
for(const house of [0,1,2]){
 s.building.house=house;
 for(const type of ['bench','pot','photo'])for(let cell=0;cell<112;cell++)placement({key:1,type,zone:'home',cell,rotation:0},[],'phase');
}
s.building.house=3;
for(const zone of ['court','orchard']){
 s.upgrades.yard=false;s.building.land.orchard=false;
 for(let cell=0;cell<B.zones[zone].cols*B.zones[zone].rows;cell++)placement({key:1,type:'pot',zone,cell,rotation:0},[],'locked');
}
s.upgrades.yard=true;s.building.land.orchard=true;
for(const slot of [0,5,6,12,23]){
 s.layouts=[{id:'bench',slot}];
 for(let cell=0;cell<40;cell++)placement({key:1,type:'pot',zone:'court',cell,rotation:0},[],'legacy');
}
s.layouts=[];
for(const zone of Object.keys(B.zones))for(let cell=0;cell<B.zones[zone].cols*B.zones[zone].rows;cell++){
 const piece={key:1,type:'pot',zone,cell,rotation:0};
 placement(piece,[{...piece,key:2}], 'overlap');
}
function layout(label,layout){s.building.layout=layout;layouts.push({label,layout,house:s.building.house,expected:B.checkLayout(s,layout)});}
layout('empty',[]);
for(const zone of Object.keys(B.zones))for(const type of ['bench','pot','lantern','workbench','teaTable'])for(const rotation of [0,1]){
 const cells=Array.from({length:B.zones[zone].cols*B.zones[zone].rows},(_,cell)=>cell).filter(cell=>B.placement(s,{key:1,type,zone,cell,rotation},[]).ok);
 if(cells.length)for(const cell of [...new Set([cells[0],cells[Math.floor(cells.length/2)],cells.at(-1)])])layout(zone+'/'+type+'/'+rotation+'/'+cell,[{key:1,type,zone,cell,rotation}]);
}
for(const zone of Object.keys(B.zones)){
 const z=B.zones[zone];
 for(const [pattern,filter] of [
 ['all',()=>true],['ring',(col,row)=>col===0||row===0||col===z.cols-1||row===z.rows-2],
 ['cluster',(col,row)=>col>=4&&col<=6&&row>=1&&row<=3]]){
  const placed=[];for(let cell=0;cell<z.cols*z.rows;cell++){
   if(!filter(cell%z.cols,Math.floor(cell/z.cols)))continue;
   const p={key:placed.length+1,type:'pot',zone,cell,rotation:0};
   if(B.placement(s,p,placed).ok)placed.push(p);
  }
  layout(zone+'/'+pattern,placed);
 }
}
layout('duplicate-key',[{key:1,type:'pot',zone:'home',cell:3,rotation:0},{key:1,type:'pot',zone:'home',cell:4,rotation:0}]);
function transaction(label,pieces,setup=()=>{}){
 const state=C.initial();state.upgrades.yard=true;state.building.house=3;state.building.land.orchard=true;
 for(const id of Object.keys(B.defs))state.furniture[id]=3;
 state.player={x:2831,y:1652,direction:'down'};
 const draft=B.draft(state);draft.layout=structuredClone(pieces);
 setup(state,draft);
 const before=structuredClone(state);
 const expected=B.commit(state,draft);
 commits.push({label,before,base:draft.base,layout:pieces,expected,building:state.building,furniture:state.furniture});
}
for(const zone of Object.keys(B.zones))for(const type of Object.keys(B.defs)){
 const row=placements.find(r=>r.piece.zone===zone&&r.piece.type===type&&r.expected.ok&&r.house===3&&r.yard&&r.orchard&&!r.legacy.length);
 if(!row)continue;
 transaction(zone+'/'+type,[row.piece]);
 transaction(zone+'/'+type+'/missing',[row.piece],state=>state.furniture[type]=0);
 const r=B.rect(row.piece),home=B.home().id;
 for(const [suffix,x,y]of [['left',r.x,r.y],['inside',r.x+1,r.y+1],['right',r.x+r.w,r.y+1],['below',r.x+1,r.y+r.h],['left-epsilon',r.x-1e-8,r.y+1],['right-epsilon',r.x+r.w-1e-8,r.y+1],['above-epsilon',r.x+1,r.y-1e-8],['below-epsilon',r.x+1,r.y+r.h-1e-8]]){
  transaction(zone+'/'+type+'/'+suffix,[row.piece],state=>{state.player.x=x;state.player.y=y;state.village.interior=zone==='home'?home:null;});
 }
 transaction(zone+'/'+type+'/stale',[row.piece],state=>state.building.revision++);
 transaction(zone+'/'+type+'/return',[],state=>{state.building.layout=[row.piece];state.building.nextId=2;state.furniture[type]=0;});
}
for(const row of layouts.filter(r=>!r.expected.ok))transaction('invalid/'+row.label,row.layout);
const initial=C.initial();
fs.writeFileSync(process.argv[2],JSON.stringify({placements,layouts,commits,source:initial}));
console.log('Source building geometry: '+placements.length+' placements, '+layouts.length+' full layouts, '+commits.length+' commits');
