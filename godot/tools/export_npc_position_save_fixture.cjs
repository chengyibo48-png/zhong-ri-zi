const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,V=ZRZVillage,D=ZRZData,fd=fs.openSync(process.argv[2],'w');let rows=0;
function emit(row){
 const entries=[];function visit(v,path=[]){if(typeof v==='number'&&Number.isFinite(v)&&!Number.isInteger(v)){const b=Buffer.alloc(8);b.writeDoubleLE(v);entries.push({path,bytes:b.toString('base64')});}else if(Array.isArray(v))v.forEach((q,i)=>visit(q,[...path,i]));else if(v&&typeof v==='object')for(const[k,q]of Object.entries(v))visit(q,[...path,k]);}
 visit(row);if(entries.length)row._float64_roundtrip={version:1,entries};fs.writeSync(fd,JSON.stringify(row)+'\n');
}
emit({type:'base',before:C.initial()});
const kinds=['home','outside','foreign-home','museum','unknown-room','bad-direction','missing','bad-x','boundary','fractional','bad-room-type'];
for(const n of D.npcs)for(const minutes of [390,600,1170,1200])for(const kind of kinds){
 const s=C.initial();s.day=1;s.minutes=minutes;
 const home=V.homeOf(n.id),p=s.village.npc[n.id];Object.assign(p,{x:home.door.x,y:home.door.y,direction:'right',room:home.id});
 if(kind==='outside')p.room=null;
 if(kind==='foreign-home')p.room=V.homeOf(D.npcs.find(v=>v.id!==n.id).id).id;
 if(kind==='museum')p.room=ZRZMuseum.house.id;
 if(kind==='unknown-room')p.room='missing-room';
 if(kind==='bad-direction')p.direction='diagonal';
 if(kind==='missing')delete s.village.npc[n.id];
 if(kind==='bad-x')p.x='2831';
 if(kind==='boundary'){p.x=24;p.y=38;p.room=null;}
 if(kind==='fractional'){p.x=2831.000000000001;p.y=1652.250000000003;p.room=null;}
 if(kind==='bad-room-type')p.room=42;
 const loaded=C.load(s),reset=structuredClone(loaded);C.nextDay(reset);
 emit({type:'case',id:n.id,kind,day:s.day,minutes,input:s.village.npc,expected:loaded.village.npc,morning:reset.village.npc});rows++;
}
fs.closeSync(fd);fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify({rows}));console.log(JSON.stringify({rows}));
