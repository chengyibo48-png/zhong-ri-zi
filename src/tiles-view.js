(function(root){
'use strict';
const T=root.ZRZTiles,A=root.ZRZArt,C=root.ZRZCore,R=A.R,E=A.ellipse,P=A.poly;
const cache=new Map(),LIMIT=256;
const colors={earth:['#b8a178','#c8b18a','#9e8963'],stone:['#a9b1a0','#c5c8b2','#859181'],sand:['#bac3a0','#d6d4af','#9ba98e'],leaves:['#85935e','#a8ad70','#677a52'],gravel:['#9da68a','#c1c7ae','#7f8d78']};
function groundTile(region,season,kind,variant,edges){
 const key=[region,season,kind,variant,edges].join('/');if(cache.has(key)){const v=cache.get(key);cache.delete(key);cache.set(key,v);return v;}
 const c=document.createElement('canvas');c.width=c.height=32;const q=c.getContext('2d'),pal=A.seasons[season],r=A.rand(variant*137+season*39+region.length*83);
 const col=kind==='grass'?[pal.grass,pal.light,pal.dark]:colors[kind];R(q,0,0,32,32,col[0]);
 for(let i=0;i<(kind==='grass'?6:12);i++){const x=Math.floor(r()*30),y=Math.floor(r()*30);R(q,x,y,kind==='stone'?5:2+i%3,1,col[1+i%2]);if(kind==='leaves')R(q,x+2,y+1,2,2,col[2]);if(kind==='gravel')R(q,x,y-1,3,1,col[1]);}
 if(kind==='stone'){R(q,0,15,32,1,col[2]);R(q,14,0,1,15,col[2]);R(q,25,16,1,16,col[2]);}
 if(kind!=='grass')for(let i=0;i<4;i++)if(edges&(1<<i))for(let j=0;j<32;j+=2){const d=2+(T.hash(j,i,variant)%4);if(i===0)R(q,j,0,2,d,pal.grass);if(i===1)R(q,32-d,j,d,2,pal.grass);if(i===2)R(q,j,32-d,2,d,pal.grass);if(i===3)R(q,0,j,d,2,pal.grass);}
 if(season===3){q.globalAlpha=.38;for(let i=0;i<8;i++)R(q,r()*30,r()*30,4,2,'#e4e9da');q.globalAlpha=1;}
 cache.set(key,c);while(cache.size>LIMIT)cache.delete(cache.keys().next().value);return c;
}
function base(c,s){const season=C.calendar(s).season;for(let y=0;y<1152;y+=32)for(let x=0;x<1920;x+=32){const t=T.tile(s.scene,x/32,y/32);c.drawImage(groundTile(s.scene,season,t.kind,t.variant,t.edges),x,y);}}
function path(c,p,season){const pal=A.seasons[season],kind=p.kind==='earth'?'earth':'stone';
 if(p.kind==='wood')return false;
 c.save();c.beginPath();c.rect(p.x-4,p.y-4,p.w+8,p.h+8);c.clip();
 for(let y=Math.floor((p.y-4)/32)*32;y<p.y+p.h+4;y+=32)for(let x=Math.floor((p.x-4)/32)*32;x<p.x+p.w+4;x+=32)c.drawImage(groundTile('farm',season,kind,T.hash(x,y)%4,0),x,y);
 c.restore();
 // Uneven sod, inset stones and tread marks soften the hard rectangle without altering navigation.
 for(let x=p.x-4;x<p.x+p.w+4;x+=7){const d=2+T.hash(x,p.y)%4;R(c,x,p.y-4,4,d,pal.grass);R(c,x,p.y+p.h+4-d,3,d,pal.grass);}
 for(let y=p.y;y<p.y+p.h;y+=9){R(c,p.x-4,y,3,4,pal.grass);R(c,p.x+p.w+1,y,3,3,pal.grass);}
 return true;
}
function plants(c,o,s,t){const season=C.calendar(s).season,pal=A.seasons[season],type=T.biomes[o.region].plants,wind=root.ZRZEnvironment.profile(s.day).wind||0;
 const sway=Math.round(Math.sin(t*1.7+o.x)*Math.min(2,1+wind*.01));
 for(let i=0;i<5;i++){const x=o.x-15+i*7,y=o.y-(i%2)*3,h=type==='reeds'?23+i%3*7:type==='fern'?13+i%2*6:12+i%3*4;
 R(c,x,y-h,1,h,pal.deep);if(type==='reeds'){R(c,x+sway,y-h-4,3,7,season===3?'#d9d9bf':'#ab9360');R(c,x-3,y-8,4,2,pal.tip);}
 else{R(c,x-5+sway,y-h+5,5,2,pal.leaf);R(c,x+1+sway,y-h+1,6,3,pal.tip);if(type==='flowers'&&season!==3)R(c,x+sway-2,y-h-2,5,3,['#ead794','#d49a85','#dcca9e'][i%3]);if(type==='fern')for(let j=0;j<3;j++)R(c,x-6+j,y-h+3+j*4,12-j*2,1,pal.leaf);}}
 if(type==='planter'||o.region==='farm'&&o.site==='scenery-1'){R(c,o.x-20,o.y-5,40,10,'#9b6950');R(c,o.x-22,o.y-8,44,4,'#c0976b');}
 if(type==='clover')for(let i=0;i<3;i++)E(c,o.x-9+i*9,o.y-9,4,2,'#c4c69a');
}
function prop(c,o,s,t){
 const x=o.x,y=o.y,k=o.kind,season=C.calendar(s).season,pal=A.seasons[season],r=A.rand(T.hash(x,y)),night=s.minutes<420||s.minutes>1080;
 if(k==='plants'){plants(c,o,s,t);return;}
 if(k==='stones'){for(let i=0;i<3;i++){P(c,[[x-14+i*11,y],[x-17+i*11,y-6-i%2*4],[x-9+i*11,y-10],[x-4+i*11,y-4]],'#8b9782');R(c,x-12+i*11,y-7,6,2,pal.tip);}return;}
 A.shadow(c,x,y,Math.min(72,T.assets[k].w),8);
 if(k==='bench'){R(c,x-29,y-12,5,16,'#6c543a');R(c,x+23,y-12,5,16,'#6c543a');R(c,x-33,y-18,66,8,'#9a7950');R(c,x-31,y-20,62,4,'#cfb27c');for(let i=0;i<4;i++)R(c,x-25+i*16,y-19,1,8,'#816b42');R(c,x+15,y-26,7,7,'#e4dfc3');R(c,x+17,y-27,4,2,'#548d87');}
 else if(k==='teaRack'||k==='grainMat'){const ground=k==='grainMat',yy=y-(ground?5:24);if(!ground)for(const dx of [-31,28]){R(c,x+dx,yy,4,27,'#80603d');R(c,x+dx-2,yy+10,8,3,'#bca775');}
 E(c,x,yy,ground?41:37,ground?12:14,'#79673e');E(c,x,yy-2,ground?39:35,ground?11:12,'#d0b171');
 for(let i=0;i<8;i++)R(c,x-30+i*8,yy-9,1,15,'#a18750');
 for(let i=0;i<65;i++){const xx=(r()-.5)*63,dy=(r()-.5)*15;if(xx*xx/1050+dy*dy/56<1)R(c,x+xx,yy-3+dy,2,1,ground?(i%2?'#e8c56e':'#c59c48'):(i%2?'#739054':'#3f7146'));}
 if(ground){R(c,x+27,y-13,3,23,'#957344');R(c,x+20,y+7,17,3,'#b39759');}}
 else if(k==='loom'){for(const dx of [-32,29])R(c,x+dx,y-62,4,66,'#8d7145');R(c,x-34,y-64,70,4,'#c9b27c');R(c,x-28,y-54,56,41,o.region==='river'?'#8c9e88':'#cab684');for(let i=0;i<9;i++)R(c,x-27+i*6,y-54,1,41,'#6a785866');for(let i=0;i<7;i++)R(c,x-28,y-51+i*6,56,1,'#e4ce9866');R(c,x-32,y-14,64,4,'#a58854');R(c,x+22,y-11,2,17,'#d6bd7a');}
 else if(k==='washstone'){R(c,x-34,y-14,68,19,'#6b7f78');P(c,[[x-34,y-14],[x-22,y-25],[x+29,y-25],[x+34,y-14]],'#abb9a4');for(let i=0;i<7;i++)R(c,x-17,y-22+i*2,33,1,'#7f9587');R(c,x-30,y-11,59,2,'#c7c9ac');R(c,x+20,y-26,12,7,'#557f8b');R(c,x+22,y-24,2,11,'#9bb9b4');}
 else if(k==='board'){for(const dx of [-20,17])R(c,x+dx,y-54,4,59,'#74573d');R(c,x-26,y-60,52,43,'#936d45');R(c,x-23,y-57,46,36,'#e1d3a9');for(let i=0;i<4;i++){R(c,x-17,y-50+i*7,23-i%2*7,2,'#6b7560');R(c,x+12,y-50+i*7,5,2,'#aa7052');}P(c,[[x-30,y-61],[x,y-68],[x+30,y-61]],'#607b75');R(c,x-28,y-61,56,4,'#799389');}
 else if(k==='jars'){for(let i=0;i<3;i++){const xx=x-23+i*23,yy=y-i%2*8;A.jar(c,xx,yy,.65+i%2*.15);E(c,xx,yy-24-i%2*4,10,3,['#b56d52','#718b87','#c9b585'][i]);R(c,xx-6,yy-25-i%2*4,12,2,'#decaa0');}}
 else if(k==='hayrack'){for(const dx of [-34,30])R(c,x+dx,y-31,4,37,'#886944');for(let i=0;i<24;i++)R(c,x-29+i*2.5,y-39+i%5*2,2,31,'#c4b36a');for(let i=0;i<3;i++)R(c,x-35,y-21+i*9,70,4,'#aa8753');R(c,x-35,y-21,70,1,'#d2b577');}
 else if(k==='weather'){R(c,x-3,y-79,6,83,'#7e7149');for(let i=0;i<6;i++)R(c,x-3,y-70+i*12,6,2,'#b2b87b');const sway=Math.sin(t*(1+root.ZRZEnvironment.profile(s.day).wind/12)+x)*(2+root.ZRZEnvironment.profile(s.day).wind/6);R(c,x-17,y-70,35,3,'#d0bd85');P(c,[[x+1,y-73],[x+29,y-69+sway],[x+21,y-61+sway],[x+1,y-64]],'#af624c');R(c,x+2,y-71,10,2,'#dfad78');E(c,x,y-81,4,3,'#d1bd82');}
 else if(k==='lamp'){R(c,x-6,y-7,12,11,'#7f8e7e');R(c,x-2,y-61,4,55,'#776245');R(c,x-9,y-57,18,20,'#75613d');R(c,x-7,y-55,14,16,night?'#e6bf70':'#c5b786');R(c,x-1,y-55,2,17,'#876e42');R(c,x-9,y-39,18,3,'#665d41');P(c,[[x-13,y-58],[x,y-66],[x+13,y-58]],'#5b7a71');R(c,x-11,y-58,22,2,'#94a38a');}
 else if(k==='seedTray'){R(c,x-22,y-16,44,18,'#947344');R(c,x-20,y-15,40,12,'#635f3d');for(let i=0;i<6;i++){const xx=x-16+i%3*13,yy=y-11+Math.floor(i/3)*7;R(c,xx-4,yy,10,1,'#c1a56d');R(c,xx,yy-7,1,7,'#588345');R(c,xx-3,yy-6,3,2,pal.tip);R(c,xx+1,yy-8,4,2,pal.leaf);}}
 else if(k==='scale'){R(c,x-23,y-6,46,9,'#a48752');R(c,x-1,y-28,3,24,'#80653e');R(c,x-22,y-27,44,2,'#bcaa71');for(const dx of [-18,18]){R(c,x+dx,y-24,1,12,'#777a60');E(c,x+dx,y-10,9,3,'#b7b58c');}R(c,x-13,y-8,5,4,'#63796e');}
 else if(k==='netCoil'){for(let i=0;i<6;i++){E(c,x+i%2*3,y-3-i*2,20-i,4,'#a6aa7f');E(c,x+i%2*3,y-4-i*2,15-i,2,'#778a73');}R(c,x-8,y-14,3,15,'#c6bd81');}
 else if(k==='bambooBundle'){for(let i=0;i<5;i++){R(c,x-22,y-5-i*4,43,3,i%2?'#8fa165':'#b7ba79');for(let j=0;j<4;j++)R(c,x-18+j*11,y-5-i*4,1,3,'#597953');}R(c,x-11,y-23,3,22,'#b99559');R(c,x+12,y-23,3,22,'#b99559');}
 else if(k==='teaCrate'){R(c,x-21,y-20,42,23,'#997b47');R(c,x-18,y-19,36,10,'#527c48');for(let i=0;i<15;i++)R(c,x-17+r()*32,y-21+r()*10,3,2,pal.tip);for(let i=0;i<5;i++)R(c,x-20+i*9,y-11,3,13,'#c8ab70');R(c,x-22,y-5,44,3,'#b39357');}
 else if(k==='haybale'){R(c,x-21,y-22,42,25,'#b8a75f');for(let i=0;i<14;i++)R(c,x-20+i*3,y-20+i%3,1,20,'#d6c67d');R(c,x-10,y-23,3,26,'#78815a');R(c,x+10,y-23,3,26,'#78815a');R(c,x-21,y-2,42,3,'#927d47');}
 else if(k==='woodpile'){for(let row=0;row<3;row++)for(let i=0;i<3-row;i++){const xx=x-16+i*14+row*7,yy=y-row*7;R(c,xx-4,yy-7,16,6,'#806445');E(c,xx+10,yy-4,4,3,'#c8a66f');R(c,xx+9,yy-5,2,2,'#90764c');}R(c,x-10,y-24,2,24,'#667c58');}
 else if(k==='basket'){E(c,x,y-5,12,8,'#9f814e');E(c,x,y-12,12,5,'#cfb379');E(c,x,y-13,9,3,'#806a43');for(let i=0;i<5;i++)R(c,x-9+i*4,y-9,1,8,'#dec18a');}
 if(season===3&&!['grainMat','basket'].includes(k)){const h=T.assets[k].h;R(c,x-Math.min(25,T.assets[k].w/3),y-h+4,Math.min(50,T.assets[k].w*.66),3,'#e1e7d9');}
}
function drawGround(c,s,t,view){
 if(s.village.interior)return;
 for(const site of T.sites){if(site.x<view.x-160||site.x>view.x+view.viewWidth+160||site.y<view.y-120||site.y>view.y+view.viewHeight+120)continue;
 const season=C.calendar(s).season,kind=T.biomes[site.region].material;
 c.save();c.beginPath();for(let i=0;i<16;i++){const a=i*Math.PI/8,rx=80+T.hash(i,site.x)%17,ry=45+T.hash(i,site.y)%12,x=site.x+Math.round(Math.cos(a)*rx/3)*3,y=site.y+9+Math.round(Math.sin(a)*ry/3)*3;if(i)c.lineTo(x,y);else c.moveTo(x,y);}c.closePath();c.clip();
 const region=root.ZRZVillage.offsets[site.region],roads=root.ZRZVillage.maps[site.region].paths.map(p=>({...p,x:p.x+region.x,y:p.y+region.y})).concat(root.ZRZVillage.corridors);
 for(const road of roads)if(T.intersects({x:site.x-96,y:site.y-48,w:192,h:120},road)){c.beginPath();c.rect(site.x-100,site.y-70,200,150);c.rect(road.x,road.y,road.w,road.h);c.clip('evenodd');}
 for(let y=site.y-48;y<site.y+72;y+=32)for(let x=site.x-96;x<site.x+96;x+=32)c.drawImage(groundTile(site.region,season,kind,T.hash(x,y)%4,0),x,y);
 c.restore();
 if(root.ZRZEnvironment.profile(s.day).rain){E(c,site.x+22,site.y+38,18,4,'#6e968066');R(c,site.x+13,site.y+37,19,1,'#d1ddbd99');}
 // Worn footprints lead to the interaction space; they never define collision.
 for(let i=0;i<5;i++){R(c,site.x-3+i%2*7,site.y+31+i*6,3,2,'#817b5755');}
 }
 for(const o of T.objects)if(T.assets[o.kind].layer==='ground'&&o.x>view.x-100&&o.x<view.x+view.viewWidth+100&&o.y>view.y-80&&o.y<view.y+view.viewHeight+80)prop(c,o,s,t);
}
function addObjects(c,s,t,objects,visible){if(s.village.interior)return;for(const o of T.objects)if(T.assets[o.kind].layer!=='ground'&&visible(o))objects.push({y:o.y,draw:()=>{const a=T.assets[o.kind],behind=Math.abs(s.player.x-o.x)<a.w/2+8&&s.player.y<o.y&&s.player.y>o.y-a.h;c.save();c.globalAlpha=behind?.45:1;prop(c,o,s,t);c.restore();}});}
function drawLights(c,s,t,view){if(s.village.interior)return;const n=root.ZRZEnvironment.daylight(s.minutes,s.day).night;if(n<.12)return;for(const o of T.objects)if(o.kind==='lamp'&&o.x>view.x-80&&o.x<view.x+view.viewWidth+80&&o.y>view.y-80&&o.y<view.y+view.viewHeight+150){const g=c.createRadialGradient(o.x,o.y-45,2,o.x,o.y-35,60);g.addColorStop(0,'#ffdc9666');g.addColorStop(1,'#ffdc9600');c.fillStyle=g;c.fillRect(o.x-60,o.y-95,120,120);R(c,o.x-6,o.y-54,12,14,'#f2d797');}}
Object.assign(T,{base,path,drawGround,addObjects,drawLights,prop,groundTile,stats:()=>({tiles:cache.size,limit:LIMIT,sites:T.sites.length,objects:T.objects.length})});
})(typeof window!=='undefined'?window:globalThis);

