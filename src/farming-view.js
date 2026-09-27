(function(root){
'use strict';
const F=root.ZRZFarming,D=root.ZRZData,V=root.ZRZVillage,W=root.ZRZWorld;
const rect=(c,x,y,w,h,col)=>{c.fillStyle=col;c.fillRect(Math.round(x),Math.round(y),w,h);};
function leaf(c,x,y,k,color){rect(c,x-k,y,k,2,color);rect(c,x+1,y-3,k,3,color);rect(c,x,y-4,2,10,'#3f6541');}
F.drawPlot=function(c,s,i,t){
 const p=s.plots[i],b=F.ensure(s).beds[i],pos=V.plotPosition(i),x=pos.x-19,y=pos.y-20,col=F.soils[b.type].color;
 rect(c,x,y,38,32,p.tilled?'#604c38':'#819452');rect(c,x+1,y+1,36,29,p.tilled?col:'#8f9e5d');
 if(!p.tilled||b.removed){for(let j=0;j<6;j++){rect(c,x+4+j*5,y+15+j%3*4,1,4,'#5c7e45');rect(c,x+3+j*5,y+16+j%3*4,3,1,'#bec779');}return;}
 if(b.moisture>60){c.fillStyle=b.type==='wetland'?'#77a5a870':'#293c3230';c.fillRect(x+2,y+2,34,26);}
 for(let j=0;j<4;j++){rect(c,x+3,y+5+j*6,32,2,'#65513c');rect(c,x+3,y+4+j*6,32,1,b.moisture>60?'#a3966c':'#c0a273');}
 if(b.moisture<28)for(let j=0;j<3;j++){rect(c,x+7+j*10,y+12+j%2*8,1,6,'#503e32');rect(c,x+7+j*10,y+16+j%2*8,4,1,'#503e32');}
 if(b.fallow){for(let j=0;j<9;j++)rect(c,x+4+j*3,y+5+j%4*5,5,1,'#c8b97e');}
 if(p.crop){
  const visual=root.ZRZVisualFx,quiet=visual?.policy(s).reduced||s.settings.particles===false;c.save();const scale=visual?.growthScale(s,i)||1;c.translate(pos.x,pos.y);c.scale(1,scale);c.translate(-pos.x,-pos.y);
  const crop=D.crops[p.crop],k=Math.min(1,p.growth/crop.days),sway=quiet?0:Math.sin(t*2+i)*.7,green=b.health<25?'#bab76b':b.health<60?'#90a05c':'#8eaf59';
  if(k<.12){for(let j=0;j<3;j++){rect(c,x+9+j*8,y+13,3,2,'#d5b279');rect(c,x+9+j*8,y+14,2,1,'#614730');}}
  else if(k>=1){c.save();c.globalAlpha=b.health<22?.75:1;W.item(c,p.crop,x+3,y-5,1.1);c.restore();if(b.ripeDays>=4){rect(c,x+20,y-6,1,9,'#6d8041');rect(c,x+18,y-8,5,3,'#d9c387');}else if(quiet||Math.hypot(pos.x-s.player.x,pos.y-s.player.y)<150&&Math.sin(t*1.5+i*2.4)>.92){rect(c,x+31,y-4,1,5,'#fff0b4');rect(c,x+29,y-2,5,1,'#fff9de');}}
  else{
   const stalk=crop.group==='谷物',fruit=crop.group==='果实',rootCrop=crop.group==='根菜',height=4+k*(stalk?28:19);
   for(let j=0;j<(b.density==='dense'?4:3);j++){const xx=x+8+j*8+sway,yy=y+19+(j%2)*3;rect(c,xx,yy-height,2,height,'#3f6944');leaf(c,xx,yy-height*.65,Math.round(2+k*5),green);if(k>.48)leaf(c,xx,yy-height*.95,Math.round(3+k*4),'#b4c975');if(k>.72){if(stalk){rect(c,xx-1,yy-height-6,4,8,'#d5c06b');rect(c,xx-2,yy-height-5,1,5,'#f2dfa0');}else if(fruit){rect(c,xx+2,yy-height+3,4,5,crop.color||'#c48748');rect(c,xx+3,yy-height+3,1,2,'#f1d392');}else if(rootCrop)rect(c,xx-1,yy-1,5,4,crop.color||'#deb988');else{rect(c,xx-2,yy-height-2,5,2,'#efe1a0');rect(c,xx,yy-height-3,2,4,'#fff1c4');}}}
  }
  if(b.companion){const a=b.companion,ratio=a.growth/D.crops[a.crop].days;leaf(c,x+32,y+24-ratio*9,3,'#b7c889');if(ratio>=1)rect(c,x+30,y+9,5,5,D.crops[a.crop].color||'#e3c66e');}
  if(b.pests>=15){const xx=x+11+Math.sin(t*3+i)*4;rect(c,xx,y+8,3,2,'#353c31');rect(c,xx-1,y+7,1,1,'#d9b96c');}
  if(b.disease>=15){rect(c,x+12,y+5,2,2,'#76513b');rect(c,x+23,y+9,2,2,'#76513b');}
 }
 if(p.crop)c.restore();
 if(b.weeds>35){leaf(c,x+4,y+24,2,'#52773c');leaf(c,x+34,y+14,2,'#52773c');}
 if(b.moisture>60){rect(c,x+33,y+25,2,4,'#77c5d5');rect(c,x+34,y+24,1,3,'#d0eee4');}
 if(b.health<30&&p.crop){rect(c,x+1,y-5,2,5,'#efbb71');rect(c,x+1,y+2,2,1,'#efbb71');}
};
F.drawCoverage=function(c,s){if(!F.ensure(s).overlay)return;c.save();for(const a of s.farm.facilities){if(!a.enabled||a.durability<=0)continue;const p=V.plotPosition(a.anchor);c.strokeStyle='#edf8bbcc';c.fillStyle='#c8e4a51c';c.setLineDash([4,5]);c.beginPath();c.arc(p.x,p.y,(root.ZRZTools?root.ZRZTools.radius(a):F.facilities[a.type].radius),0,Math.PI*2);c.fill();c.stroke();}c.restore();};
F.drawFacility=function(c,s,a,t){
 const p=V.plotPosition(a.anchor),same=s.farm.facilities.filter(v=>v.anchor===a.anchor),side=same.indexOf(a)%2?1:-1,x=p.x+side*19,y=p.y+13,disabled=!a.enabled||a.durability<=0;
 c.save();c.globalAlpha=disabled?.5:1;rect(c,x-4,y,11,3,'#304c3b55');
 if(a.type==='sprinkler'){rect(c,x,y-19,3,21,'#708975');rect(c,x-5,y-19,13,3,'#c3c6a0');rect(c,x,y-21,3,2,'#e4dab0');if(s.farm.water>0&&s.farm.beds.some((b,i)=>b.irrigated===s.day&&s.minutes<510&&F.covered(s,i,'sprinkler'))&&!disabled)for(let j=0;j<7;j++){const z=(t*2+j/7)%1;rect(c,x+Math.cos(j)*z*28,y-20+z*z*20,1,2,'#b9e5e8');}}
 if(a.type==='scarecrow'){rect(c,x,y-32,3,34,'#8c704b');rect(c,x-11,y-21,24,3,'#967446');rect(c,x-5,y-27,13,14,'#bd8864');rect(c,x-5,y-36,12,10,'#d6b681');rect(c,x-9,y-37,20,3,'#cfb46c');rect(c,x-4,y-42,11,6,'#af934f');rect(c,x-1,y-31,1,2,'#494a39');rect(c,x+4,y-31,1,2,'#494a39');rect(c,x-4,y-25,11,2,'#6e876a');}
 if(['greenhouse','shade','trellis'].includes(a.type)){const width=a.type==='trellis'?26:40;for(const dx of [-width/2,width/2])rect(c,x+dx,y-29,2,32,'#a1915f');for(let j=0;j<4;j++)rect(c,x-width/2,y-28+j*6,width,1,'#bea775');if(a.type!=='trellis'){c.fillStyle=a.type==='greenhouse'?'#d5eeee66':'#617c5777';c.fillRect(x-width/2,y-34,width,10);rect(c,x-width/2-2,y-34,width+4,2,'#d3d3a3');}else {leaf(c,x-7,y-17,4,'#739851');leaf(c,x+5,y-25,3,'#acc277');}}
 if(a.type==='fence'){for(let j=0;j<4;j++)rect(c,x-13+j*9,y-14,3,17,'#b5a279');rect(c,x-14,y-11,34,3,'#d3bd8f');rect(c,x-14,y-3,34,2,'#907e57');}
 if(a.type==='drain'){rect(c,x-18,y-3,39,6,'#526451');rect(c,x-16,y-2,35,3,'#81b0b4');rect(c,x-10+(Math.sin(t)*5),y-2,9,1,'#c2d7c3');}
 if(a.durability<30){rect(c,x+7,y-8,2,5,'#edb777');rect(c,x+7,y-1,2,1,'#edb777');}c.restore();
};
})(window);

