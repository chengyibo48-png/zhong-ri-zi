const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,S=ZRZScenes,V=ZRZVillage,B=ZRZBuild,G=ZRZForage,copy=x=>structuredClone(x),exact=require('./export_world_precision.cjs'),fd=fs.openSync(process.argv[2],'w');
const seed=C.initial(),states=[];
for(let i=0;i<8;i++){
 const s=copy(seed);s.village.interior=i%3===1?'home-granny':i%3===2?ZRZRanch.barns.poultry.house:null;
 s.upgrades.yard=i>=2;s.building.land.orchard=i>=4;
 s.furniture.bench=1;s.furniture.flowerbed=1;s.furniture.pot=1;s.building.layout=[];
 let key=1;
 for(const [type,zone] of [['bench','court'],['flowerbed','orchard'],['pot','home']]){
  if(!B.zoneOpen(s,zone))continue;
  const z=B.zones[zone];let found=false;
  for(let cell=0;cell<z.cols*z.rows;cell++){
   const p={key,type,zone,cell,rotation:i%4};
   if(B.checkLayout(s,[...s.building.layout,p]).ok){s.building.layout.push(p);key++;found=true;break;}
  }
  if(!found)throw Error('No valid '+type+' placement for state '+i);
 }
 s.building.nextId=key;
 const validated=C.load(copy(s));
 states.push(validated);
}
function write(r){fs.writeSync(fd,JSON.stringify(exact(r))+'\n');}
write({kind:'states',states});
const labels=['',null,false,true,0,1,-1,0.1,1e-7,1e-6,1e20,1e21,1.2345678901234567,{},[],[1,null,'菜'],[[1,2],[]],'我的标记','  稻香小路  ','中'.repeat(19),'😀'.repeat(10),'a'.repeat(17)+'😀','a'.repeat(16)+'😀','a'.repeat(17)+'\ud800','\ud800','\udc00','\ud800\ud800','\udc00\ud800','\0','a\0b','\ufeff'.repeat(2)+'茶园'+'\ufeff','\u0085菜\u0085','\u200b菜\u200b','\u0001菜\u0001','__zrz_utf16_0__'];
let pins=0,removes=0,numbers=0;
function transact(stateIndex,x,y,label,fill=0,tracking=null){const s=copy(states[stateIndex]);s.atlas.pins=Array.from({length:fill},(_,i)=>({id:'pin-'+i,x:2831+i,y:1652,label:'保留'+i}));s.atlas.nextId=fill+1;s.atlas.tracking=tracking;
 const before=copy(s.atlas),result=S.pin(s,x,y,label);
 const coord=v=>typeof v==='number'&&!Number.isFinite(v)?{special:String(v)}:{value:v};
 write({kind:'pin',state:stateIndex,x:coord(x),y:coord(y),label,before,result,after:copy(s.atlas)});pins++;
}
const points=[[2831,1652],[2831.499999999,1652.499999999],[2831.5,1652.5],[24,38],[3816,3816],[23.999999999,38],[24,37.999999999],[3816.000000001,3816],[3816,3816.000000001],[0,0],[NaN,1652],[Infinity,1652],[-Infinity,1652],['2831',1652],[true,1652],[null,1652],[2831,'1652']];
for(const r of V.solids){for(const [x,y] of [[r[0]-6,r[1]-3],[r[0]+r[2]+6,r[1]+r[3]+5]])for(const delta of [-.00000001,0,.00000001])points.push([x+delta,y+delta]);}
for(const h of V.houses){points.push([h.door.x,h.door.y],[h.x+2,h.y+51],[h.x+h.w-2,h.y+h.h+3],[h.x+h.w/2,h.y+h.h/2]);}
for(const p of G.pens)for(const [x,y] of [[p.x-10,p.y-8],[p.gate,p.y],[p.x+p.w,p.y+p.h]])for(const d of [-.00000001,0,.00000001])points.push([x+d,y+d]);
for(const z of Object.values(B.zones)){points.push([z.x,z.y],[z.x+z.size,z.y+z.size],[z.x+z.cols*z.size,z.y+z.rows*z.size]);}
for(let x=24;x<=3816;x+=173)for(let y=38;y<=3816;y+=191)points.push([x+.49999999,y+.50000001]);
for(let state=0;state<states.length;state++)points.forEach(([x,y],i)=>transact(state,x,y,labels[(i+state)%labels.length],i%31===0?12:i%17===0?11:0));
for(const label of labels)for(const fill of [0,11,12])transact(0,2831.49999999,1652.5,label,fill);
for(let unit=0xd800;unit<=0xdfff;unit++)transact(unit%8,2831.5,1652.499999999,'a'.repeat(17)+String.fromCharCode(unit));
for(const unit of [9,10,11,12,13,32,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288,65279,0,1,8,14,31,133,8203])transact(0,2831,1652,String.fromCharCode(unit)+'菜'+String.fromCharCode(unit));
for(const id of ['pin-0','pin-1','gone',null,false,0,'0','\ud800']){
 for(const trackedId of [null,'pin-0','pin-1','gone','\ud800']){
  const s=copy(seed);s.atlas.pins=[{id:'pin-0',x:2831,y:1652,label:'\ud800'},{id:'pin-1',x:2832,y:1652,label:'😀'}];s.atlas.nextId=2;s.atlas.tracking={id:trackedId,name:'a'.repeat(17)+'\ud800',x:2831,y:1652};
  const before=copy(s.atlas);S.removePin(s,id);write({kind:'remove',state:0,id,before,after:s.atlas});removes++;
 }
}
let random=0x67ac31bd;
function rnd(){random^=random<<13;random^=random>>>17;random^=random<<5;return random>>>0;}
const values=[0,-0,0.1,1.2345678901234567,1e-7,1e-6,1e20,1e21,Number.MIN_VALUE,Number.MAX_VALUE,Math.PI,Math.E,1.0000000000000002,1000000000000000100,1.005,0.0000010000000000000002];
for(let i=0;i<12000;i++){const bytes=Buffer.alloc(8);bytes.writeUInt32LE(rnd(),0);bytes.writeUInt32LE(rnd(),4);const n=bytes.readDoubleLE();if(Number.isFinite(n))values.push(n);}
for(const value of values){const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);write({kind:'number',bytes:bytes.toString('base64'),expected:String(value)});numbers++;}
fs.closeSync(fd);const counts={states:states.length,pins,removes,numbers,total:pins+removes+numbers,points:points.length};fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify(counts));console.log(JSON.stringify(counts));
