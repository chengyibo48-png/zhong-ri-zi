const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,R=ZRZRanch,A=ZRZActions,V=ZRZVillage;
const rows=[];
for(const id of Object.keys(R.barns))for(const y of [510,550,560]){
 let s=C.initial();s.day=27;s.minutes=600.25;s.money=100000;
 for(const b of Object.values(s.ranch.barns)){b.built=true;b.clean=40.25;b.waste=7;b.durability=60.25;}
 s.bag.wood=40;s.bag.bamboo=20;s.bag.bedding=3;ZRZKitchen.ensure(s);s=C.load(JSON.parse(JSON.stringify(s)));
 s.village.interior=R.barns[id].house;s.player={x:480,y,direction:'up'};
 const p={x:480,y:490,kind:'ranch-task',room:s.village.interior,name:'牧场工位'},stand=A.approach(s,p),route=V.route(s,stand.x,stand.y);
 rows.push({barn:id,start:s.player,stand,path:route,blockedStart:V.blocked(s,s.player.x,s.player.y),blockedWork:V.blocked(s,480,495)});
}
console.log(JSON.stringify(rows));
