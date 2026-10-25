const fs=require('node:fs');
require('./source_navigation_runtime.cjs');
const C=ZRZCore,V=ZRZVillage,copy=x=>structuredClone(x),exact=require('./export_world_precision.cjs');
const houses=V.houses,fd=fs.openSync(process.argv[2],'w');let cases=0,steps=0;
function snapshot(s){return {day:s.day,minutes:s.minutes,stamina:s.stamina,player:copy(s.player),room:s.village.interior,back:copy(s.village.returnPoint),riding:s.village.riding,npc:copy(s.village.npc)};}
function write(row){fs.writeSync(fd,JSON.stringify(exact(row))+'\n');cases++;steps+=row.samples.length;}
for(const h of houses)for(const offset of [[0,0],[69.999999999,0],[70,0],[70.000000001,0],[-70,0],[0,70],[0,70.000000001],[42,56]]){
 const s=C.initial();s.village.riding=true;s.player={x:h.door.x+offset[0],y:h.door.y+offset[1],direction:'left'};
 const before=copy(s),samples=[],result=V.enter(s,h.id);
 samples.push({operation:'enter',house:h.id,result,expected:snapshot(s)});
 if(result){const left=V.leave(s);samples.push({operation:'leave',result:left,expected:snapshot(s)});}
 write({label:'enter/'+h.id+'/'+offset.join(','),before,samples});
}
for(const h of houses)for(const variant of ['decimal','absent','fence','boundary']){
 const s=C.initial();s.village.interior=h.id;s.village.riding=false;s.player={x:480.123456789,y:567.987654321,direction:'up'};
 s.village.returnPoint=variant==='absent'?null:variant==='decimal'?{x:h.door.x+.1234567890123,y:h.door.y+12.987654321098,direction:'left'}:variant==='boundary'?{x:24.000000000001,y:38.000000000001,direction:'right'}:{x:ZRZForage.pens[0].x,y:ZRZForage.pens[0].y+30.123456789,direction:'down'};
 const before=copy(s),result=V.leave(s);write({label:'leave/'+h.id+'/'+variant,before,samples:[{operation:'leave',result,expected:snapshot(s)}]});
}
for(const room of [null,...houses.map(h=>h.id)])for(const day of [0,27,55,83,111,223,447]){
 const s=C.initial();s.day=day;s.minutes=1319.875;s.stamina=17;s.village.interior=room;
 s.player=V.safePosition(s,room?{x:480.123456789,y:550.987654321,direction:'left'}:{x:2831.123456789,y:1652.987654321,direction:'right'});
 if(room){const h=houses.find(h=>h.id===room);s.village.returnPoint={x:h.door.x+.123456789,y:h.door.y+12.987654321,direction:'down'};}else s.village.riding=true;
 const before=copy(s),samples=[];
 for(let i=0;i<2;i++){const result=C.nextDay(s);samples.push({operation:'day',result,expected:snapshot(s)});}
 write({label:'day/'+room+'/'+day,before,samples});
}
for(const mode of ['no-room-leave','unknown-house','already-inside']){
 const s=C.initial();if(mode==='already-inside'){s.village.interior=houses[0].id;s.player={x:480,y:567,direction:'up'};}
 const before=copy(s),result=mode==='no-room-leave'?V.leave(s):V.enter(s,mode==='unknown-house'?'missing-house':houses[1].id);
 write({label:mode,before,samples:[{operation:mode==='no-room-leave'?'leave':'enter',house:mode==='unknown-house'?'missing-house':houses[1].id,result,expected:snapshot(s)}]});
}
fs.closeSync(fd);fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify({cases,steps,houses:houses.length}));console.log(JSON.stringify({cases,steps,houses:houses.length}));
