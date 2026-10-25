const fs=require('node:fs');
global.window=globalThis;
require('./source_navigation_runtime.cjs');
require('../../src/characters.js');require('../../src/creatures-view.js');
const C=ZRZCore,R=ZRZRanch,V=ZRZVillage;
const weatherDays={};for(let day=0;day<448;day++)weatherDays[C.weather(day)]??=day;
const sunny=weatherDays['晴'];
const source=C.initial(),rules=[];
for(const type of Object.keys(R.species))for(const variant of ['normal','young','lost','rest','retired','weak','ill','ill-boundary','health-boundary','inside','rain-safe','rain-day','typhoon','cold','snow','heat','before','opening','last','closing']){
 const s=C.initial();s.day=sunny;s.minutes=600;s.ranch.policy='safe';const a=s.animals[0];
 a.type=type;a.age=R.species[type].adult;a.health=100;a.illness=0;a.lost=false;a.rest=false;a.retired=false;
 if(variant==='young')a.age--;
 if(variant==='lost')a.lost=true;
 if(variant==='rest')a.rest=true;
 if(variant==='retired')a.retired=true;
 if(variant==='weak')a.health=44;
 if(variant==='ill')a.illness=45;
 if(variant==='ill-boundary')a.illness=44;
 if(variant==='health-boundary')a.health=45;
 if(variant==='inside')s.ranch.policy='inside';
 if(variant==='rain-safe'||variant==='rain-day'){s.day=weatherDays['雨'];if(variant==='rain-day')s.ranch.policy='day';}
 const badWeather={typhoon:'台风',cold:'寒潮',snow:'小雪',heat:'高温'}[variant];if(badWeather)s.day=weatherDays[badWeather];
 const time={before:479,opening:480,last:1049,closing:1050}[variant];if(time!==undefined)s.minutes=time;
 rules.push({variant,day:s.day,minutes:s.minutes,policy:s.ranch.policy,animal:{type:a.type,age:a.age,health:a.health,illness:a.illness,lost:a.lost,rest:a.rest,retired:a.retired},out:R.safeOut(s,a)});
}
const trajectories=[];
for(const mode of ['graze-hen','graze-duck','graze-cow','rest-inside','exit','return','lost','gather','held','pet-follow','pet-patrol','pet-tired']){
 const s=C.initial();s.day=sunny;s.minutes=600;s.ranch.policy='day';s.village.interior=null;
 const a=s.animals.find(v=>v.type===(mode==='graze-cow'?'cow':mode==='graze-duck'?'duck':'hen'));
 s.animals=[a];a.position={x:2690,y:2735,direction:'down',room:null,inside:{x:300,y:510,direction:'right'}};
 if(mode==='rest-inside'){a.rest=true;a.position.room=R.houseOf(a).id;}
 if(mode==='exit'){a.position.room=R.houseOf(a).id;a.position.inside={x:480,y:565,direction:'down'};}
 if(mode==='return'){s.minutes=1050;Object.assign(a.position,{x:R.houseOf(a).door.x,y:R.houseOf(a).door.y+5});}
 if(mode==='lost'){a.lost=true;a.position.x=3680;a.position.y=3402;}
 if(mode==='gather')V.stateRuntime(s).animalFocus={x:2600,y:2700,until:24};
 if(mode==='held')R.hold(s,a.id);
 s.ranch.pet.position={x:2775,y:1690,direction:'right'};
 if(mode==='pet-follow')s.ranch.pet.mode='follow';
 if(mode==='pet-patrol')s.ranch.pet.mode='patrol';
 if(mode==='pet-tired'){s.ranch.pet.mode='follow';s.ranch.pet.energy=14;s.ranch.pet.position.x+=50;}
 const before=JSON.parse(JSON.stringify(s)),steps=[],routes=[];
 let animalRoute={direct:true},petRoute={direct:true};
 const oldRoute=V.route;V.route=(nav,x,y,from)=>{const path=oldRoute(nav,x,y,from);const role=from===a.position||from===a.position.inside?'animal':'pet';const record={role,room:nav.village.interior||null,x,y,direct:path.length===1};routes.push(record);if(role==='animal')animalRoute=record;else petRoute=record;return path;};
 let clock=0;
 try{for(const dt of [.1,.1,1]){clock+=dt;V.stateRuntime(s).clock=clock;R.update(s,dt);steps.push({dt,animalRoute:{...animalRoute},petRoute:{...petRoute},animal:JSON.parse(JSON.stringify(a.position)),pet:JSON.parse(JSON.stringify(s.ranch.pet.position))});}}
 finally{V.route=oldRoute;}
 trajectories.push({mode,before,steps,routes});
}
const visuals=[];
const oldPose=R.visualPose;
for(const type of Object.keys(R.species))for(const variant of ['idle','walk','young','sick','sleepy','hungry','dirty','feed','happy','sheared'])for(const direction of ['up','down','left','right']){
 const a={...source.animals[0],type,age:R.species[type].adult,illness:0,rest:false,hunger:80,clean:90,position:{room:null,direction,walking:variant==='walk'}};
 if(variant==='young')a.age--;
 if(variant==='sick')a.illness=20;
 if(variant==='sleepy')a.rest=true;
 if(variant==='hungry')a.hunger=34;
 if(variant==='dirty')a.clean=44;
 const action={feed:'feed',happy:'clean',sheared:'collect'}[variant],pose=action?{action,until:2.2}:{};
 R.visualPose=()=>pose;
 visuals.push({a,pose,clock:.5,expected:ZRZCreatures.state(a,.5)});
}
R.visualPose=oldPose;
const effects=[];
for(const [type,action] of [['hen','feed'],['cow','collect'],['sheep','collect'],['duck','collect'],['hen','clean']]){
 const s=C.initial(),a=s.animals[0];s.animals=[a];a.type=type;a.age=100;a.hunger=30;a.clean=10;a.ready=3;a.qualityStock=[3,0,0,0];
 a.position={x:100.25,y:200.75,room:null,inside:{x:480,y:500}};
 for(const id of Object.keys(ZRZData.items))s.bag[id]=999;
 s.stamina=100;for(const barn of Object.values(s.ranch.barns))barn.built=true;
 const result=R.perform(s,{animalId:a.id,action,arg:'feed'});
 if(!result.ok)throw new Error('Effect setup '+type+'/'+action+': '+JSON.stringify(result));
 for(const age of [0,.1,.7,1.5,2.2]){
  const rows=[];let lineStart=null;
  const c={beginPath(){},fill(){},ellipse(x,y,rx,ry){rows.push(['oval',x,y,rx,ry,this.fillStyle]);},fillRect(x,y,w,h){rows.push(['rect',x,y,w,h,this.fillStyle]);},moveTo(x,y){lineStart=[x,y];},lineTo(x,y){rows.push(['line',...lineStart,x,y,this.strokeStyle,this.lineWidth]);},stroke(){}};
  R.drawAction(c,s,age);effects.push({animal:{id:a.id,type},at:a.position,action,age,expected:rows});
 }
}

fs.writeFileSync(process.argv[2],JSON.stringify({source,rules,trajectories,weatherDays,visuals,effects},null,2));
console.log('Exported '+rules.length+' turnout rules and '+trajectories.length+' original movement trajectories');
