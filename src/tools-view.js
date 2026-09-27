(function(root){
'use strict';const T=root.ZRZTools,F=root.ZRZFarming,V=root.ZRZVillage,W=root.ZRZWorld;
const r=(c,x,y,w,h,color)=>{c.fillStyle=color;c.fillRect(Math.round(x),Math.round(y),w,h);};
T.drawTool=(c,id,level,x,y,scale=1)=>{c.save();c.translate(x,y);c.scale(scale,scale);const wood=level===2?'#896139':'#b39460',metal=['#84958b','#bac5b6','#dfcba0'][level];c.fillStyle='#43554422';c.beginPath();c.ellipse(0,7,24,6,0,0,7);c.fill();
if(id==='hoe'||id==='axe'||id==='sickle'){r(c,-3,-31,6,40,wood);r(c,-2,-7,4,10,'#5d7763');if(id==='hoe'){r(c,-18,-34,37,7,metal);r(c,12,-29,10,14,metal);r(c,13,-19,9,3,'#546c61');}if(id==='axe'){r(c,-5,-34,26,16,metal);r(c,12,-35,10,19,metal);r(c,20,-31,3,10,'#e4e5c9');}if(id==='sickle'){r(c,-19,-35,30,5,metal);r(c,-25,-31,9,11,metal);r(c,-22,-20,17,4,metal);r(c,-11,-23,7,4,'#ece2b4');}}
if(id==='water'){r(c,-18,-21,32,27,'#739d96');r(c,-16,-17,27,4,'#acc9b4');r(c,13,-18,13,7,metal);r(c,22,-24,6,12,metal);r(c,-21,-28,6,17,metal);r(c,-19,-31,22,5,metal);r(c,-2,-29,5,9,metal);r(c,-12,-5,21,3,'#507a78');}
if(id==='rod'){c.save();c.rotate(.45);r(c,-2,-47,4,58,wood);r(c,-3,-2,6,10,'#587b6b');r(c,2,-44,1,38,'#dacfa8');r(c,1,-7,5,3,metal);c.restore();}
if(id==='care'){r(c,-19,-24,38,16,wood);for(let i=0;i<8;i++)r(c,-18+i*5,-9,3,13,'#d7c3a0');r(c,-13,-20,27,5,metal);r(c,12,-2,18,15,'#b3c6b4');r(c,16,-1,2,13,'#6f9389');}
for(let i=0;i<level;i++)r(c,17+i*7,10,4,4,'#b68b49');c.restore();};
T.drawPreview=(c,s,hover)=>{if(s.village.interior||hover?.kind!=='plot'||!['hoe','water','sickle'].includes(T.equipped))return;const id=T.equipped,targets=T.targets(s,hover.index,id),active=T.plan(s,hover.index,id).map(t=>t.index);c.save();for(const i of targets){const p=V.plotPosition(i);c.fillStyle=active.includes(i)?'#8ed5a735':'#ead7a928';c.strokeStyle=i===hover.index?'#ffdf87':active.includes(i)?'#b5efbb':'#d8cfac';c.lineWidth=i===hover.index?2:1;c.fillRect(p.x-20,p.y-21,40,35);c.strokeRect(p.x-20,p.y-21,40,35);}c.restore();};
const old=F.drawFacility;F.drawFacility=(c,s,a,t)=>{old(c,s,a,t);const p=V.plotPosition(a.anchor),side=s.farm.facilities.filter(v=>v.anchor===a.anchor).indexOf(a)%2?1:-1,x=p.x+side*19,y=p.y-30;const status=T.status(s,a)[0];if(a.level)r(c,x-3,y-2,7,3,'#e6c77c');if(!['运行','暂停'].includes(status)){r(c,x-3,y-13,9,9,status==='缺水'?'#6bb8d1':'#d79b61');r(c,x+1,y-12,1,4,'#fff0cb');r(c,x+1,y-6,1,1,'#fff0cb');}};
const item=W.item;W.item=(c,id,x,y,scale=1)=>{if(T.defs[id]&&id!=='care'){T.drawTool(c,id,0,x+16*scale,y+22*scale,.55*scale);return;}item(c,id,x,y,scale);};
})(typeof window!=='undefined'?window:globalThis);
