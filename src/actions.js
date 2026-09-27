(function(root){
'use strict';
// Live callbacks never enter saves. The only mutation happens after all visible phases.
class Sequence{
 constructor(){this.active=null;}
 start(spec,commit,cancel=()=>{}){if(this.active)return false;this.active={spec,elapsed:0,commit,cancel};return true;}
 tick(dt,paused=false){const a=this.active;if(!a||paused)return false;a.elapsed=Math.min(a.spec.duration,a.elapsed+Math.max(0,Math.min(.1,Number(dt)||0)));if(a.elapsed+1e-8<a.spec.duration)return false;this.active=null;a.commit();return true;}
 cancel(){const a=this.active;if(!a)return false;this.active=null;a.cancel();return true;}
 snapshot(){const a=this.active;if(!a)return null;const progress=Math.min(1,a.elapsed/a.spec.duration);return {...a.spec,progress,phase:progress<.22?'准备':progress<.82?'动手':'收好'};}
}
const catalog={hoe:['翻松土壤',1.25],water:['倾壶补水',1.25],seed:['俯身落种',1.15],harvest:['摘下收进竹篮',1.3],gather:['整理采下物产',1.3],feed:['舀料添进食槽',1.25],brush:['梳洗与清扫',1.3],pet:['伸手轻轻抚摸',1.1],steam:['生火料理',1.6],trade:['点货、交接与记账',1.6],pack:['分拣物品入篮',1.2],build:['丈量、敲打与安置',1.7],door:['伸手推门',.75],read:['翻开手边物件',.7],greet:['招手、侧身交谈',1.1],eat:['拿起食物慢慢吃',1.4],rest:['落座歇一歇',1.5],sleep:['铺好被褥，安静入梦',2.2],fish:['抛竿、等漂、收线',2.2],bell:['握住铜铃轻轻摇',1.1],dress:['整理衣袖与装束',1.1],bike:['扶稳车把上落车',.9]};
function spec(kind,label,item){const c=catalog[kind]||catalog.read;return {kind:catalog[kind]?kind:'read',label:label||c[0],duration:c[1],item};}
function point(p,tool='hand'){let k='read';if(p.kind==='walk')return null;if(p.kind==='animal'||p.kind==='plot'&&['hoe','water','sickle'].includes(tool)||p.kind==='chore'&&p.action==='churn')return null;
if(p.kind==='build-task')k=p.op?.startsWith('economy-')?'trade':'build';else if(p.kind==='kitchen-task')k=p.op==='collect'?'pack':p.op==='clean'?'brush':p.op==='upgrade'?'build':'steam';else if(p.kind==='farm-task')k=['harvest','companionHarvest','seedSave'].includes(p.action)?'harvest':['water','fill'].includes(p.action)?'water':['sow','companion'].includes(p.action)?'seed':p.action==='facility'?'build':p.action==='inspect'?'read':'hoe';else if(p.kind==='ranch-task')k=p.action==='collect'?'harvest':p.action==='feed'?'feed':p.action==='clean'?'brush':p.action==='water'?'water':['build','upgrade','repair'].includes(p.action)?'build':p.action==='purchase'?'trade':'pet';else if(['enter','exit'].includes(p.kind))k='door';else if(p.kind==='npc')k='greet';else if(p.kind==='gather')k='gather';else if(p.kind==='plot')k=tool==='hand'?'harvest':tool;else if(p.kind==='tea'||p.kind==='rest'||p.kind==='bed-visit')k='rest';else if(p.kind==='fish')k='fish';else if(p.kind==='pet')k='pet';else if(p.kind==='chore')k=['feed','brush','water','bell'].includes(p.action)?p.action:'hoe';else if(p.kind==='ambient')k='bell';else if(p.kind==='build-piece')k=p.service==='water'?'water':p.service==='rest'?'rest':'read';return {...spec(k,undefined,p.item||p.id),door:p.kind==='enter'||p.kind==='exit'};}
const groups={
 trade:['buy','sell-item','sell-all','gift-item','deliver','join-festival','f-buy','r-buy','k-buy','e-recipe-buy','e-favor','e-festival','e-host','e-shared','e-marry','e-date'],
 pack:['ec-transfer','ec-tidy','ec-lock','ec-pin','e-store','e-take','e-store-all','e-take-all','r-store','r-withdraw','k-store','b-store','b-withdraw','e-mail','e-achievement','b-claim','r-adopt','r-confirm'],
 build:['repair','upgrade','b-apply','b-recover','b-mode','b-style','b-room','b-showcase','e-project','e-craft','e-place','e-tool-upgrade','k-cold'],
 eat:['eat','ec-eat','k-eat'],steam:['cook-item','e-sub-cook','e-trial','e-process','k-finish','k-assist'],
 read:['e-story-choice','e-chapter','e-small-event','e-year-plan','e-skill','e-pet-name','e-animal-name','r-rename','r-policy','r-pet-mode','e-free-range','t-branch','t-shape','f-selection','f-threshold','f-auto-seed','sc-pin','sc-remove'],
 dress:['e-appearance'],pet:['e-pet','e-animal'],greet:['v-npc-talk','e-separate'],water:['e-fill-water'],hoe:['e-fertilize','e-pest'],sleep:['next-day'],bike:['v-bike']};
const uiMap=new Map(Object.entries(groups).flatMap(([kind,ids])=>ids.map(id=>[id,kind])));
function ui(id,label){return uiMap.has(id)?spec(uiMap.get(id),label):null;}
function draw(c,s,a,time){if(!a)return;const p=s.player,x=p.x,y=p.y,k=a.kind,t=a.progress,wave=Math.sin(t*Math.PI*6),reach=Math.sin(t*Math.PI),R=(x,y,w,h,color)=>{c.fillStyle=color;c.fillRect(Math.round(x),Math.round(y),w,h);};
c.save();c.lineCap='round';const hx=x+14+reach*8,hy=y-19-wave*2;c.strokeStyle='#e1b18a';c.lineWidth=5;c.beginPath();c.moveTo(x+6,y-23);c.lineTo(hx,hy);c.stroke();
if(['trade','pack','harvest','gather','feed'].includes(k)){R(x+16,y-5,24,13,'#856239');for(let i=0;i<4;i++)R(x+18+i*5,y-4,2,10,'#c7a36b');R(x+14,y-8,28,4,'#d0ad70');const iy=y-26-Math.sin(t*Math.PI)*18;if(root.ZRZData.items[a.item])root.ZRZWorld.item(c,a.item,x+17,iy,.6);else{R(x+23,iy,11,8,k==='feed'?'#c0a057':'#7fa063');R(x+27,iy-4,3,5,'#b9c586');}if(k==='trade'){R(x-34,y-8,17,12,'#eee0ae');R(x-30,y-5,9,1,'#826145');R(x-30,y-2,7,1,'#826145');c.fillStyle='#e2bb58';c.beginPath();c.arc(x-16+wave*2,y-17,5,0,7);c.fill();}}
if(['build','hoe','brush'].includes(k)){c.save();c.translate(hx,hy);c.rotate(wave*.55);R(-1,-21,3,27,'#ab7d49');R(-9,-22,20,k==='brush'?10:7,k==='brush'?'#c6ac70':'#92a7a1');c.restore();if(t>.2&&t<.82)for(let i=0;i<5;i++)R(x+16+i*6,y+3-Math.abs(Math.sin(time*9+i))*9,3,2,'#d4bf8b');}
if(k==='water'){root.ZRZWorld.item(c,'water',hx-4,hy-16,.8);for(let i=0;i<9;i++)R(x+29+i%3*4,y-9+(time*24+i*3)%19,2,3,'#99dce6');}
if(['eat','rest','steam'].includes(k)){R(x+8,y-27+wave,15,7,'#eee0bf');R(x+10,y-20+wave,11,3,'#598b8a');for(let i=0;i<4;i++){c.strokeStyle='#fff0d4a0';c.lineWidth=2;c.beginPath();c.moveTo(x+10+i*4,y-30-(t*24+i*6)%22);c.lineTo(x+12+i*4,y-36-(t*24+i*6)%22);c.stroke();}if(k==='steam'){R(x+28,y-4,20,9,'#876344');R(x+31,y-9,14,5,'#d9b67f');}}
 if(k==='read'){R(x+10,y-20,12,17,'#e6d4a1');R(x+23,y-20,12,17,'#f5e7bf');R(x+22,y-22,2,20,'#a38551');for(let i=0;i<3;i++)R(x+12,y-16+i*4,8,1,'#9d8b63');R(x+24,y-20,Math.max(1,Math.round(10*Math.abs(wave))),16,'#f8edcb');}
if(k==='door'){R(x+23,y-40,Math.max(3,Math.round(22*(1-t))),43,'#956740');R(x+24,y-39,2,40,'#d4ad6c');R(x+26,y-19,3,3,'#dec27f');}
if(k==='dress'){R(x+8,y-22+wave,15,16,'#8baba0');R(x+11,y-21+wave,2,13,'#d6e1c0');R(x+17,y-21+wave,2,13,'#d6e1c0');}
if(k==='bike'){c.strokeStyle='#637e70';c.lineWidth=2;for(const dx of [16,43]){c.beginPath();c.arc(x+dx,y+3,9,0,7);c.stroke();}c.beginPath();c.moveTo(x+16,y+3);c.lineTo(x+27,y-13);c.lineTo(x+43,y+3);c.lineTo(x+16,y+3);c.moveTo(x+38,y-17);c.lineTo(x+43,y+3);c.stroke();R(x+21,y-16,12,3,'#b99360');}
if(k==='seed')for(let i=0;i<7;i++)R(x+18+Math.sin(i)*12,y-13+(t*24+i*3)%22,2,3,'#e0c791');
if(k==='greet'||k==='pet'){c.strokeStyle=k==='pet'?'#d79c87':'#f0d49c';c.lineWidth=2;c.beginPath();c.arc(x+24,y-33,8,Math.PI,Math.PI*1.8);c.stroke();}
if(k==='bell'){R(hx,hy-13,8,12,'#b48d46');R(hx-2,hy-2,12,3,'#e1c171');}
if(k==='sleep'){R(x-14,y-5,36,12,'#738c87');R(x-14,y-7,9,7,'#eadabc');c.fillStyle='#f0e5c6';c.font='12px serif';c.fillText('z',x+19,y-36-t*16);}
if(k==='fish'){c.strokeStyle='#cba46d';c.lineWidth=2;c.beginPath();c.moveTo(hx,hy);c.lineTo(x+36,y-62+reach*10);c.lineTo(x+55,y-3);c.stroke();R(x+52,y-7+wave,4,8,'#ce6150');}
c.restore();}
root.ZRZActions={Sequence,catalog,spec,point,ui,draw,uiActions:[...uiMap.keys()]};
})(typeof window!=='undefined'?window:globalThis);
