const fs=require('node:fs'),Module=require('node:module');
const original=Module.prototype._compile;
Module.prototype._compile=function(text,file){
 if(file.replaceAll('\\','/').endsWith('/src/ranch-view.js'))text=text.replace('function state(room)', 'R._sourceRuntime=runtime;\nfunction state(room)');
 return original.call(this,text,file);
};
try{require('./source_navigation_runtime.cjs');}finally{Module.prototype._compile=original;}
const C=ZRZCore,R=ZRZRanch,V=ZRZVillage,copy=x=>structuredClone(x);
function exact(row){
 const entries=[];
 function visit(v,path=[]){
  if(typeof v==='number'&&Number.isFinite(v)&&!Number.isInteger(v)){const b=Buffer.alloc(8);b.writeDoubleLE(v);entries.push({path,bytes:b.toString('base64')});}
  else if(Array.isArray(v))v.forEach((q,i)=>visit(q,[...path,i]));
  else if(v&&typeof v==='object')for(const[k,q]of Object.entries(v))visit(q,[...path,k]);
 }
 visit(row);row._float64_roundtrip={version:1,entries};return JSON.stringify(row);
}
const sunny=Array.from({length:448},(_,i)=>i).find(d=>C.weather(d)==='晴');
const fd=fs.openSync(process.argv[2],'w');let cases=0,frames=0;
for(const type of Object.keys(R.species))for(const mode of ['graze','inside','exit','return','lost','focus','held','sequence','pet-held','pet-follow','pet-patrol','pet-tired']){
 const s=C.initial();s.day=sunny;s.minutes=600;s.ranch.policy='day';s.village.interior=null;
 const a=s.animals[0];s.animals=[a];Object.assign(a,{type,age:R.species[type].adult,health:100,illness:0,rest:false,retired:false,lost:false});
 const house=R.houseOf(a);a.position={x:2690,y:2735,direction:'down',room:null,inside:{x:300,y:510,direction:'right'}};
 if(mode==='inside'){a.position.room=house.id;a.rest=true;}
 if(mode==='exit'){a.position.room=house.id;a.position.inside={x:480,y:565,direction:'down'};}
 if(mode==='return'){s.minutes=1050;Object.assign(a.position,{x:house.door.x,y:house.door.y+5});}
 if(mode==='lost'){a.lost=true;Object.assign(a.position,{x:3680,y:3402});}
 const vr=V.stateRuntime(s);vr.animalFocus=mode==='focus'?{x:2600,y:2700,until:24}:null;
 if(mode==='sequence')vr.sequence={animalId:a.id};
 if(mode==='held')R.hold(s,a.id);
 s.ranch.pet.position={x:2775,y:1690,direction:'right',walking:true};
 if(mode==='pet-held')R.hold(s,'pet');
 if(mode==='pet-follow')s.ranch.pet.mode='follow';
 if(mode==='pet-patrol')s.ranch.pet.mode='patrol';
 if(mode==='pet-tired'){s.ranch.pet.mode='follow';s.ranch.pet.energy=14;s.ranch.pet.position.x+=50;}
 const before=copy(s),initial=copy(vr.animalFocus),samples=[];
 for(let frame=0;frame<120;frame++){
  const dt=[.1,.125,.5,1,0][frame%5];vr.clock+=dt;R.update(s,dt);
  const rt=copy(R._sourceRuntime(s));for(const actor of Object.values(rt.actors))delete actor.hold;
  samples.push({dt,villageClock:vr.clock,clock:rt.clock,actors:rt.actors,positions:s.animals.map(a=>copy(a.position)),pet:copy(s.ranch.pet.position)});frames++;
 }
 fs.writeSync(fd,exact({type,mode,before,focus:initial,samples})+'\n');cases++;
}
for(const mode of ['flock','daily-boundaries','focus-expiry','pet-mode-changes','sequence-release','roster-changes']){
 const s=C.initial();s.day=sunny;s.minutes=600;s.ranch.policy='day';s.village.interior=null;
 s.animals=Object.keys(R.species).flatMap((type,i)=>[0,1].map(j=>{
  const a=copy(s.animals[0]);a.id=type+'-'+j;Object.assign(a,{type,age:R.species[type].adult,health:100,illness:0,rest:false,retired:false,lost:false});
  a.position={x:2690+i*20,y:2735+j*30,direction:'down',room:null,inside:{x:300+i*30,y:510+j*20,direction:'right'}};
  if(j===1)a.position.room=R.houseOf(a).id;return a;
 }));
 const vr=V.stateRuntime(s);vr.animalFocus=null;
 s.ranch.pet.mode='patrol';s.ranch.pet.position={x:2775,y:1690,direction:'right'};
 const before=copy(s),samples=[];
 for(let frame=0;frame<100;frame++){
  const patch={};
  if(mode==='daily-boundaries'&&frame%20===0){s.minutes=[479,480,1049,1050,1140][frame/20];patch.minutes=s.minutes;}
  if(mode==='focus-expiry'&&frame===10){vr.animalFocus={x:2600,y:2700,until:vr.clock+24};patch.focus=copy(vr.animalFocus);}
  if(mode==='pet-mode-changes'&&frame%20===0){s.ranch.pet.mode=['home','follow','patrol','follow','home'][frame/20];patch.petMode=s.ranch.pet.mode;}
  if(mode==='sequence-release'&&(frame===10||frame===35)){vr.sequence=frame===10?{animalId:s.animals[3].id}:null;patch.sequence=copy(vr.sequence);}
  if(mode==='roster-changes'&&(frame===10||frame===30)){s.animals.reverse();patch.animals=copy(s.animals);}
  if(mode==='roster-changes'&&frame===50){s.animals.splice(3,2);patch.animals=copy(s.animals);}
  if(mode==='roster-changes'&&frame===70){s.animals=[];patch.animals=[];}
  const dt=[.1,.125,.5,1,0][frame%5];vr.clock+=dt;R.update(s,dt);
  const rt=copy(R._sourceRuntime(s));for(const actor of Object.values(rt.actors))delete actor.hold;
  samples.push({dt,patch,villageClock:vr.clock,clock:rt.clock,actors:rt.actors,positions:s.animals.map(a=>copy(a.position)),pet:copy(s.ranch.pet.position)});frames++;
 }
 fs.writeSync(fd,exact({type:'mixed',mode,before,focus:null,samples})+'\n');cases++;
}
fs.closeSync(fd);fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify({cases,frames}));console.log(JSON.stringify({cases,frames}));
