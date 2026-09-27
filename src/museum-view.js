(function(root){
'use strict';
const M=root.ZRZMuseum,V=root.ZRZVillage,W=root.ZRZWorld,I=root.ZRZInteriors,A=root.ZRZActions;
const cases=[{group:'物产',x:245,y:330,color:'#718457'},{group:'文物',x:715,y:330,color:'#aa8053'},{group:'民俗',x:245,y:470,color:'#ac6850'},{group:'生物',x:715,y:470,color:'#568c87'}];
const old={points:I.points,blocked:I.blocked,draw:I.draw,add:I.addObjects,world:V.points,ui:A.ui,point:A.point};
const keepsakes=old.points(M.house,root.ZRZCore.initial()).filter(p=>p.kind==='egg').map((p,i)=>({...p,name:['晒网旧照','河埠手记','船绳结法'][i],x:175+i*300,y:242}));
const solids=[...cases.map(p=>({x:p.x-78,y:p.y-70,w:156,h:88})),{x:404,y:432,w:152,h:58}];
function obstacles(s){return [...solids,...(M.ensure(s).level>=1?[{x:305,y:209,w:110,h:35}]:[]),...(M.ensure(s).level>=3?[{x:540,y:247,w:90,h:40}]:[])];}
I.points=(h,s)=>h.id!==M.house.id?old.points(h,s):[{kind:'exit',x:480,y:590,name:'走回柳岸村道',house:h.id},{kind:'museum',id:'registry',...M.registry,name:'村史馆 · 登记与布展'},...cases.map(p=>({kind:'museum',id:p.group,x:p.x,y:p.y+43,name:p.group+'展区 · 馆藏目录'})),...keepsakes];
I.blocked=(s,x,y)=>s.village.interior!==M.house.id?old.blocked(s,x,y):x<113||x>847||y<205||y>602||obstacles(s).some(r=>x>r.x&&x<r.x+r.w&&y>r.y&&y<r.y+r.h);
const rect=(c,x,y,w,h,col)=>{c.fillStyle=col;c.fillRect(Math.round(x),Math.round(y),w,h);};
function text(c,t,x,y,col='#ede0bb',size=13){c.fillStyle=col;c.font=size+'px "Microsoft YaHei",sans-serif';c.textAlign='center';c.fillText(t,x,y);}
function scroll(c,x,y,label){rect(c,x-18,y-28,36,36,'#ded0a5');rect(c,x-22,y-30,44,4,'#725e42');rect(c,x-22,y+8,44,4,'#725e42');for(let i=0;i<4;i++)rect(c,x-12,y-21+i*6,24-i%2*7,1,'#9c8c67');if(label)text(c,label,x,y+29,'#f3e6c7',11);}
I.draw=(c,s,t)=>{if(s.village.interior!==M.house.id)return old.draw(c,s,t);const level=M.ensure(s).level;
rect(c,64,80,832,555,'#263f38');rect(c,96,100,768,505,'#715c44');rect(c,108,110,744,94,'#e0d0aa');
for(let y=204;y<601;y+=26)for(let x=111;x<848;x+=46){rect(c,x,y,44,24,(Math.floor(y/26)+Math.floor(x/46))%2?'#8a8d7a':'#949682');rect(c,x+2,y+2,39,1,'#adb09a');}
for(const x of [112,840])rect(c,x,109,8,487,'#684d34');rect(c,111,195,738,10,'#927048');rect(c,111,124,738,7,'#af9260');
for(const x of [160,730]){rect(c,x,135,60,52,'#526e62');rect(c,x+5,140,50,42,'#a5c7b5');for(let i=0;i<3;i++)rect(c,x+10+i*18,139,3,45,'#876e49');rect(c,x+4,159,52,3,'#876e49');}
rect(c,338,138,284,45,'#425f51');rect(c,345,143,270,2,'#c7ad70');text(c,'禾 溪 村 史 馆',480,165,'#f1dfaa',21);text(c,M.levels[level].name+' · 一村水土，一册日常',480,193,'#534e39',11);
rect(c,442,205,76,390,'#b8aa83');for(let y=217;y<580;y+=20){rect(c,448,y,64,1,'#d0bf92');rect(c,449,y+2,2,6,'#8d8969');rect(c,509,y+2,2,6,'#8d8969');}
for(const p of keepsakes){rect(c,p.x-40,205,80,25,'#92744e');scroll(c,p.x,218);text(c,p.name,p.x,246,'#405447',10);}
rect(c,442,586,76,9,'#d2ba81');rect(c,451,595,58,12,'#426052');text(c,'村道',480,604,'#f0dfb3',10);
if(level>=2){rect(c,579,209,184,29,'#9cab83');text(c,'稻田 · 河流 · 人家',671,229,'#3d594a',12);}
return true;};
function cabinet(c,s,p,t){const m=M.ensure(s),key=m.featured[p.group],e=M.byKey[key],don=m.donated[key];
rect(c,p.x-82,p.y+12,164,12,'#273f3733');rect(c,p.x-75,p.y-20,150,36,'#75583d');rect(c,p.x-77,p.y-24,154,7,'#bc9b63');rect(c,p.x-69,p.y-16,138,23,p.color);for(const x of [-62,50])rect(c,p.x+x,p.y+12,12,9,'#584c35');
rect(c,p.x-78,p.y-71,156,46,'#cfdbc23b');rect(c,p.x-76,p.y-69,152,3,'#d9dcbbaa');rect(c,p.x-78,p.y-70,3,45,'#d4debe');rect(c,p.x+75,p.y-70,3,45,'#9da88c');rect(c,p.x-72,p.y-65,30,2,'#ffffff70');
if(e&&don){if(e.type==='item')W.item(c,e.id,p.x-19,p.y-66,1.2);else scroll(c,p.x,p.y-42);if(don.mode!=='sample')text(c,don.mode==='copy'?'副本':'记录',p.x+51,p.y-37,'#405d50',10);}else{rect(c,p.x-27,p.y-43,54,11,'#cabb99');text(c,'待登记',p.x,p.y-46,'#526455',12);}
text(c,p.group+' · '+(e?e.name:'留一格给未来'),p.x,p.y-2,'#fff0c7',12);
if(m.level>=3){rect(c,p.x-3,p.y-101,6,17,'#8b6a3e');rect(c,p.x-11,p.y-86,22,4,'#d8be72');c.fillStyle='#f8e7ae16';c.beginPath();c.moveTo(p.x,p.y-84);c.lineTo(p.x-70,p.y-24);c.lineTo(p.x+70,p.y-24);c.fill();}
}
function wild(c,p,t){const x=p.x+Math.sin(t*.8)*3,y=p.y+Math.abs(Math.sin(t*1.5))*2;if(p.id==='butterfly'){const w=3+Math.abs(Math.sin(t*9))*6;rect(c,x-w,y-17,w*2,4,'#f1e4ae');rect(c,x-1,y-18,2,9,'#72683d');return;}
const white=p.id==='egret';rect(c,x-7,y-14,15,9,white?'#eee9cc':'#b09564');rect(c,x+4,y-22,4,13,white?'#f5efd8':'#846e4f');rect(c,x+4,y-23,8,6,white?'#f3ecd5':'#9b8258');rect(c,x+12,y-20,5,2,'#c99a4a');rect(c,x+10,y-22,1,1,'#293f36');rect(c,x-9,y-12,7,3,white?'#c9d1bd':'#695d43');for(const dx of [-3,4])rect(c,x+dx,y-5,1,7,white?'#776948':'#927849');
}
I.addObjects=(c,s,t,objects,furniture)=>{if(!s.village.interior)for(const p of M.wildlife.filter(p=>M.available(s,p)&&Math.hypot(p.x-s.player.x,p.y-s.player.y)<900))objects.push({y:p.y,draw:()=>wild(c,p,t)});if(s.village.interior!==M.house.id)return old.add(c,s,t,objects,furniture);for(const p of cases)objects.push({y:p.y+18,draw:()=>cabinet(c,s,p,t)});
objects.push({y:490,draw(){rect(c,400,470,160,17,'#6c533d');rect(c,399,432,162,41,'#b6925d');rect(c,404,437,152,2,'#dbc58d');rect(c,414,482,10,14,'#644d34');rect(c,536,482,10,14,'#644d34');scroll(c,457,462);rect(c,506,448,9,14,'#665b3e');rect(c,509,440,2,9,'#414b35');text(c,'登记 · 布展 · 纪念陈设',480,476,'#463e2b',11);}});
if(M.ensure(s).level>=1)objects.push({y:244,draw(){rect(c,305,175,110,65,'#806747');for(let k=0;k<2;k++){for(let j=0;j<10;j++)rect(c,311+j*10,180+k*28,7,23,['#8a9166','#c7b17b','#987258'][j%3]);rect(c,306,204+k*28,108,4,'#d3b478');}text(c,'四时资料',360,256,'#f0e1bb',11);}});
if(M.ensure(s).level>=3)objects.push({y:287,draw(){rect(c,540,249,90,21,'#ab8e60');rect(c,545,270,6,16,'#6f5b3d');rect(c,618,270,6,16,'#6f5b3d');scroll(c,585,261);}});
};
V.points=(s,...args)=>old.world(s,...args).concat(s.village.interior?[]:M.wildlife.filter(p=>M.available(s,p)).map(p=>({...p,kind:'wildlife',name:p.name+' · 静静观察'})));W.points=V.points;
A.point=(p,tool)=>p.kind==='wildlife'?{...A.spec('read','蹲下观察，记下它的活动'),duration:2}:old.point(p,tool);
A.ui=(action,...args)=>['ms-research','ms-track','ms-badge'].includes(action)?A.spec('read',action==='ms-badge'?'翻开册页，收好纪念章':'翻页记录，整理收集笔记'):old.ui(action,...args);
const describe=root.ZRZFeedback.describe;root.ZRZFeedback.describe=(s,p,tool)=>{const d=describe(s,p,tool);return p.kind==='museum'?{...d,verb:'查阅馆藏',state:'在登记桌前捐赠、布展与领奖'}:p.kind==='wildlife'?{...d,verb:'静静观察',state:(M.ensure(s).observations[p.id]?.length||0)+' / 2 天生态记录'}:d;};
root.ZRZMuseumView={cases,obstacles,keepsakes};
})(typeof window!=='undefined'?window:globalThis);
