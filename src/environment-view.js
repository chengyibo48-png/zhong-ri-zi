(function(root){
'use strict';const E=root.ZRZEnvironment,V=root.ZRZVillage,rect=(c,x,y,w,h,col)=>{c.fillStyle=col;c.fillRect(Math.round(x),Math.round(y),w,h);},ellipse=(c,x,y,rx,ry,col)=>{c.fillStyle=col;c.beginPath();c.ellipse(x,y,rx,ry,0,0,7);c.fill();},mod=(v,n)=>(v%n+n)%n;
// World-space cells keep rain impacts and puddles attached to ground while the camera moves.
function cells(view,spacing=116){const list=[];for(let x=Math.floor(view.x/spacing)*spacing;x<view.x+view.viewWidth+spacing;x+=spacing)for(let y=Math.floor(view.y/spacing)*spacing;y<view.y+view.viewHeight+spacing;y+=spacing){const seed=Math.abs(Math.imul(x+51,31)^Math.imul(y+17,71));list.push({x:x+seed%67,y:y+(seed>>>4)%71,seed});}return list;}
function openGround(s,p){return !V.blocked(s,p.x,p.y)&&!V.houses.some(h=>p.x>h.x-12&&p.x<h.x+h.w+12&&p.y>h.y-12&&p.y<h.y+h.h+15);}
E.drawGround=(c,s,t,view)=>{const g=E.ground(s.day);if(!g.wet&&!g.snow)return;c.save();for(const p of cells(view,132)){if(!openGround(s,p))continue;if(g.wet){c.globalAlpha=g.wet*.5;ellipse(c,p.x,p.y,12+p.seed%17,3+p.seed%3,'#96bcb6');c.strokeStyle='#d2ddd0';c.lineWidth=1;c.beginPath();c.ellipse(p.x,p.y,9+p.seed%11,2,0,0,2.5);c.stroke();}if(g.snow){c.globalAlpha=g.snow*.7;ellipse(c,p.x,p.y,15+p.seed%12,4,'#e5e8d3');rect(c,p.x-6,p.y-2,13,2,'#f6f4e2');}}c.restore();};
function drop(origin,age,wind){return {x:origin.x+wind*age,y:origin.y-95+180*age+80*age*age};}
E.drop=drop;E.cells=cells;
E.atmosphere=(c,s,t,view)=>{const p=E.profile(s.day),light=E.daylight(s.minutes,s.day),{x,y,viewWidth:w,viewHeight:h}=view;
c.save();if(light.warm){const g=c.createLinearGradient(x,y,x+w,y+h);g.addColorStop(0,'rgba(255,176,91,'+light.warm+')');g.addColorStop(1,'rgba(187,105,110,'+light.warm*.6+')');c.fillStyle=g;c.fillRect(x,y,w,h);}if(light.night)rect(c,x,y,w,h,'rgba(19,36,61,'+light.night+')');if(p.sunlight<.7)rect(c,x,y,w,h,'rgba(48,70,82,'+((1-p.sunlight)*(p.kind==='台风'?.29:.16))+')');
if(p.rain){const storm=p.kind==='台风',fall=(-180+Math.sqrt(180*180+4*80*95))/(2*80);for(const q of cells(view,storm?62:85)){const cycle=mod(t*1.5+q.seed*.019,1),impact={x:q.x,y:q.y},v=drop({x:impact.x-p.wind*3*fall,y:impact.y},Math.min(fall,cycle*fall/.78),p.wind*3);
if(cycle<.78){c.strokeStyle='#c6e3e59c';c.lineWidth=1;c.beginPath();c.moveTo(v.x-p.wind*.18,v.y-16);c.lineTo(v.x,v.y);c.stroke();}else if(openGround(s,impact)){c.strokeStyle='#d5e8d576';c.beginPath();c.ellipse(impact.x,impact.y,2+(cycle-.78)*25,1+(cycle-.78)*8,0,0,7);c.stroke();}}
for(const house of V.houses){if(house.x>x-250&&house.x<x+w&&house.y>y-220&&house.y<y+h)for(let i=1;i<4;i++){const age=mod(t*2+i*.23,1),xx=house.x+house.w*i/4,roof=house.y+house.h*.45;rect(c,xx,roof+age*age*house.h*.4,1,3,'#bedddb90');}}}
if(p.snow)for(const q of cells(view,65)){const yy=q.y+mod(t*22+q.seed,65)-32,xx=q.x+Math.sin(t+q.seed)*7+t%2*p.wind*.15;rect(c,xx,yy,2,2,'#eef2e0d9');if(q.seed%3===0)rect(c,xx-1,yy+1,4,1,'#eef2e099');}
if(p.kind==='雾'){for(let i=0;i<5;i++){const xx=x+mod(i*270+t*8,w+360)-180,yy=y+i*h/5,g=c.createRadialGradient(xx,yy,15,xx,yy,240);g.addColorStop(0,'#e4e8dc6a');g.addColorStop(1,'#e4e8dc00');c.fillStyle=g;c.fillRect(x,y,w,h);}}
if(p.wind>=13)for(const q of cells(view,175)){const phase=mod(t*.7+q.seed*.01,1),xx=q.x+phase*90,yy=q.y-Math.sin(phase*Math.PI)*15;c.save();c.translate(xx,yy);c.rotate(Math.sin(t*4+q.seed)*.7);ellipse(c,0,0,4,1.5,'#b5a26aa0');c.restore();}
if(p.kind==='高温'){rect(c,x,y,w,h,'#f7d48410');for(const q of cells(view,190)){c.strokeStyle='#f8e4b930';c.beginPath();c.moveTo(q.x,q.y);c.quadraticCurveTo(q.x+Math.sin(t*2+q.seed)*9,q.y-10,q.x+3,q.y-20);c.stroke();}}
if(light.night>.2)for(const house of V.houses){if(house.x>x-250&&house.x<x+w+100&&house.y>y-220&&house.y<y+h+70){const xx=house.x+house.w*.54,yy=house.y+house.h-20,g=c.createRadialGradient(xx,yy,0,xx,yy,80);g.addColorStop(0,'#ffd38c55');g.addColorStop(1,'#ffd38c00');c.fillStyle=g;c.fillRect(xx-80,yy-80,160,160);rect(c,xx-7,yy-25,14,20,'#dfb56f');}}
c.restore();};
})(typeof window!=='undefined'?window:globalThis);

