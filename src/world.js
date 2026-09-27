(function(root){
  'use strict';
  const D=root.ZRZData,C=root.ZRZCore,A=root.ZRZArt,L=root.ZRZLandscape,W=L.width,H=L.height;
  let ctx;
  const rect=(x,y,w,h,col)=>A.R(ctx,x,y,w,h,col);
  const poly=(pts,col)=>A.poly(ctx,pts,col);
  function legacyItem(context,id,x=0,y=0,scale=1) {
    const prev=ctx;ctx=context;ctx.save();ctx.translate(x,y);ctx.scale(scale,scale);const icon=D.items[id]?.icon||id;
    if(D.crops[id]&&!['cabbage','radish','bean','tomato','rice','mustard'].includes(id)){const c=D.crops[id];rect(12,5,3,9,'#6e8d54');rect(9,6,11,3,'#94ac70');if(c.group==='叶菜'){rect(5,12,22,12,c.color);rect(9,7,14,20,c.color);rect(15,10,2,16,'#d5dcb0');}else if(c.group==='谷物'){for(let i=0;i<4;i++){rect(7+i*5,9,3,19,c.color);rect(5+i*5,12,5,3,'#e1d1a0');}}else{rect(6,13,21,11,c.color);rect(9,10,14,18,c.color);rect(10,13,5,3,'#efddbd55');if(id==='watermelon')for(let i=0;i<3;i++)rect(10+i*5,12,2,13,'#517954');} }
    else if(icon==='axe'||icon==='sickle'||icon==='build'){rect(14,7,3,21,'#9b8059');rect(7,4,17,6,'#8a9d9a');if(icon==='sickle'){rect(23,7,3,8,'#8a9d9a');}else rect(7,9,7,6,'#7b918d');}
    else if(icon==='hoe'){rect(12,4,3,21,'#9b8059');rect(5,4,16,5,'#788d89');rect(5,5,4,8,'#819991');}
    else if(icon==='water'){rect(7,10,14,13,'#8ca8a2');rect(8,10,13,3,'#b3c9bc');rect(20,14,5,5,'#86a5a0');rect(23,10,3,5,'#91b4a9');rect(3,13,5,7,'#72968f');rect(5,11,3,3,'#a7bab0');rect(12,6,4,4,'#9eb8ad');}
    else if(icon==='hand'){rect(10,10,11,14,'#d6b58b');rect(10,5,3,11,'#e1c294');rect(14,4,3,13,'#e1c294');rect(18,7,3,10,'#e1c294');rect(6,13,5,8,'#e1c294');rect(9,23,13,3,'#728b62');}
    else if(icon==='rod'){rect(8,7,3,20,'#9b8657');rect(11,4,8,3,'#9b8657');rect(19,6,1,16,'#bac5a6');rect(18,20,4,5,'#b86f50');}
    else if(icon==='seed'){rect(6,6,18,20,'#bdab75');rect(7,7,16,4,'#dac99a');rect(8,12,14,12,'#ddd4a9');rect(13,18,3,5,'#748d56');rect(10,15,5,4,'#8da568');rect(15,13,5,5,'#829b5e');}
    else if(['cabbage','mustard','tea','bean'].includes(icon)){rect(13,17,4,10,'#d2d3a0');rect(6,11,8,13,'#6c9257');rect(17,10,8,14,'#71965b');rect(11,5,9,18,'#8eaf69');rect(7,9,5,7,'#acc081');rect(14,9,3,13,'#bdd198');}
    else if(icon==='radish'){rect(10,12,13,12,'#e2e0bd');rect(13,23,7,4,'#d6d6b4');rect(15,27,2,2,'#c7c6a6');rect(13,5,4,10,'#86a765');rect(6,5,8,5,'#93ad6a');rect(17,2,6,8,'#6e965c');}
    else if(icon==='tomato'||icon==='berry'){rect(6,11,20,12,'#bb7050');rect(9,8,14,18,'#ca8059');rect(9,10,6,5,'#d69969');rect(13,5,4,7,'#77925a');rect(9,8,13,3,'#82995c');}
    else if(icon==='rice'||icon==='feed'){rect(7,13,18,14,'#c2ad79');rect(7,12,18,4,'#dbc697');for(let j=0;j<5;j++){rect(9+j*3,7-j%2*3,2,8,'#d9bd72');rect(9+j*3,16,2,3,'#eee0b0');}}
    else if(icon==='egg'){rect(10,10,13,14,'#e0d3a3');rect(12,7,8,17,'#f5e7bb');rect(14,5,4,4,'#eee0b2');rect(13,11,3,7,'#fff2cd');}
    else if(icon==='milk'){rect(10,8,13,19,'#e6e3c7');rect(13,4,7,5,'#9aa99a');rect(10,15,13,7,'#94b7af');rect(12,10,3,4,'#faf2d6');}
    else if(icon==='wood'||icon==='bamboo'){rect(6,9,22,8,icon==='wood'?'#a78e60':'#8ba76a');rect(7,19,21,7,icon==='wood'?'#ad9569':'#8da96a');rect(4,8,6,10,icon==='wood'?'#d2ba86':'#c5cf95');rect(5,18,6,9,icon==='wood'?'#d5be91':'#c8cf94');rect(15,9,2,17,'#7d805122');}
    else if(icon==='shoot'){poly([[7,26],[11,13],[16,4],[21,13],[25,26]],'#b1a474');rect(11,16,10,3,'#d2c79d');rect(9,22,15,3,'#daceaa');rect(15,7,4,5,'#789057');}
    else if(icon==='mushroom'){rect(13,16,7,12,'#e2d4ac');rect(6,12,22,8,'#ad8967');rect(10,8,15,8,'#ba9b75');rect(14,5,6,5,'#b0926b');rect(10,13,4,3,'#e3c69b');rect(21,14,3,2,'#e3c69b');}
    else if(icon==='fish'){poly([[4,17],[9,12],[21,12],[26,16],[21,21],[9,21]],'#7f9c99');poly([[5,16],[1,11],[1,22]],'#92ada2');rect(13,13,9,6,'#b2c4b3');rect(22,15,2,2,'#506d5e');}
    else if(['dish','riceBowl','soup'].includes(icon)){rect(4,16,24,6,'#b2b7a0');rect(7,22,18,3,'#dcd8b6');rect(6,12,20,6,icon==='dish'?'#8ca767':icon==='soup'?'#d9bf7e':'#eee0b1');rect(10,10,14,5,icon==='dish'?'#a8bc7b':'#e6d5a1');rect(11,13,3,3,'#c79758');rect(19,15,4,2,'#829e62');}
    else if(icon==='jar'){rect(8,9,18,18,'#a28767');rect(10,6,14,5,'#c4b393');rect(7,5,19,4,'#b3ab85');rect(11,15,12,7,'#ddd0a1');rect(15,17,4,3,'#889765');}
    ctx.restore();ctx=prev;
  }
  function legacyPoints(s) {
    let list=[];
    if(s.scene==='farm')list=[{id:'bed',x:214,y:216,kind:'sleep',name:'老屋 · 睡个好觉'},{id:'stove',x:680,y:216,kind:'cook',name:'灶台 · 做一道家常菜'},{id:'well',x:624,y:305,kind:'rest',name:'井边坐坐 · 休息'},{id:'board',x:129,y:403,kind:'orders',name:'爷爷的旧便条'},{id:'bench',x:637,y:443,kind:'rest',name:'长椅 · 歇一会儿'},...s.animals.map((a,i)=>({id:a.id,x:706+i*50,y:389+(i%2)*23,kind:'animal',name:a.name+' · '+(a.ready?'收取产物':a.fed?'已经吃饱':'喂食与抚摸')}))];
    if(s.scene==='town')list=[{id:'shop',x:237,y:262,kind:'shop',name:'许婶杂货铺 · 买卖'},{id:'notice',x:377,y:280,kind:'orders',name:'邻里告示板'},{id:'table',x:675,y:384,kind:'festival',name:D.festivals[C.calendar(s).season]},{id:'bench',x:100,y:440,kind:'rest',name:'街边长椅'}];
    if(s.scene==='bamboo'||s.scene==='mountain'){
      const season=C.calendar(s).season;
      const ids=s.scene==='bamboo'?['bamboo','wood',season===0?'shoot':'mushroom','bamboo','wood',season===3?'wood':season===0?'wildHerb':'mushroom']:['wood',season===0?'tea':'berry','mushroom','wood',season===3?'mushroom':'tea','berry'];
      const coords=s.scene==='bamboo'?[[296,287],[215,382],[546,286],[691,237],[181,469],[462,436]]:[[270,411],[601,275],[457,374],[145,340],[528,270],[413,488]];
      list=coords.map(([x,y],i)=>({id:s.scene+'-'+i,x,y,kind:'gather',item:ids[i],name:D.items[ids[i]].name+(s.collected[s.scene+'-'+i]===s.day?' · 明天恢复':' · 轻轻采一些')}));
      list.push({id:'bench',x:s.scene==='bamboo'?515:519,y:s.scene==='bamboo'?237:249,kind:'rest',name:'坐下听听风'});
    }
    if(s.scene==='river')list=[{id:'fishing',x:269,y:198,kind:'fish',name:'垂钓小埠 · 抛竿'},{id:'bridge',x:471,y:195,kind:'project',name:s.flags.bridge?'修好的河埠':'和乡亲们修缮河埠'},...(s.flags.bridge?[{id:'bench',x:608,y:194,kind:'rest',name:'新长椅 · 坐坐'}]:[])];
    const npcLocations={farm:[[253,233],[476,211],[183,414],[579,445],[352,236],[79,286],[550,214],[673,459],[828,446],[62,434]],town:[[474,317],[324,355],[551,288],[188,299],[765,383],[723,409],[92,319],[286,414],[352,455],[512,399],[817,301],[871,373],[79,479],[182,522],[712,520],[799,484],[857,433],[383,98],[443,144],[479,222],[550,541],[641,541],[753,541],[273,535]],bamboo:[[406,347],[535,318],[329,317],[365,410],[627,319],[518,420],[237,345],[767,290]],river:[[610,194],[351,190],[811,189],[731,500],[281,507],[166,183],[647,523],[366,534]],mountain:[[593,294],[343,292],[417,338],[151,447],[526,331],[321,447],[504,438],[709,309]]};
    D.npcs.filter(n=>C.npcScene(s,n)===s.scene).forEach((n,i)=>{const [x,y]=npcLocations[s.scene][i%npcLocations[s.scene].length];list.push({id:n.id,x,y,kind:'npc',name:n.name+' · '+n.role,npc:n});});
    if(s.scene==='farm'){list.push({id:'mailbox',x:174,y:279,kind:'mail',name:'院门信箱'},{id:'old-cabinet',x:318,y:212,kind:'archive',name:'爷爷的旧物柜'},{id:'pet',x:366,y:222,kind:'pet',name:s.pet.name+' · 陪它玩一会儿'});if(s.upgrades.storage)list.push({id:'storage',x:185,y:300,kind:'storage',name:'储物柜'});if(s.upgrades.mill)list.push({id:'mill',x:692,y:262,kind:'processing',name:'小石磨 · 加工'});if(s.upgrades.room)list.push({id:'home-table',x:503,y:218,kind:'home',name:'家中共餐桌'});}if(s.scene==='town')list.push({id:'repair-stand',x:314,y:279,kind:'tools',name:'宋伯修理摊'},{id:'village-events',x:780,y:411,kind:'gatherings',name:'邻里小聚'});
    const destinations={farm:[['town',429,532],['bamboo',42,250],['river',916,462]],town:[['farm',429,548]],bamboo:[['farm',429,542],['mountain',424,89]],river:[['farm',51,188]],mountain:[['bamboo',429,545]]};
    for(const [id,x,y] of destinations[s.scene])list.push({id,x,y,kind:'travel',name:'前往'+D.scenes[id].name});
    return list;
  }
  const plotPosition=i=>({x:790+i%6*42,y:579+Math.floor(i/6)*36});
  function item(c,id,x=0,y=0,scale=1){
    legacyItem(c,id,x,y,scale);c.save();c.translate(x,y);c.scale(scale,scale);
    const kind=D.items[id]?.kind;
    if(kind==='料理'){
      A.ellipse(c,16,21,13,5,'#3e6255');A.ellipse(c,16,19,13,5,'#e5e5c9');A.ellipse(c,16,18,10,4,'#eac990');
      const r=A.rand([...id].reduce((n,v)=>n+v.charCodeAt(0),0));for(let i=0;i<12;i++)A.R(c,8+r()*16,13+r()*6,2+r()*3,2,[id.includes('Egg')?'#e2b647':'#6f9455','#a95b3d','#f4e6be'][i%3]);A.R(c,6,24,20,1,'#8ea58f');
    }else if(D.crops[id]){
      const colors={eggplant:'#574b78',carrot:'#dd9246',pumpkin:'#d99541',cucumber:'#487b44',corn:'#e0be5a',lotus:'#e5ccaa',pepper:'#4c8654'};
      if(colors[id]){const col=colors[id];
        if(id==='eggplant'){A.poly(c,[[9,12],[18,9],[24,16],[21,24],[10,27],[6,22]],col);A.R(c,10,14,3,9,'#9883ae');}
        if(id==='carrot'){A.poly(c,[[8,10],[21,11],[13,28]],col);A.R(c,11,12,3,6,'#eec278');}
        if(id==='cucumber'){A.poly(c,[[9,7],[18,7],[23,23],[18,28],[11,21]],col);for(let i=0;i<5;i++)A.R(c,13+i%2*4,11+i*3,1,2,'#b1c076');}
        if(id==='corn'){A.R(c,10,8,13,20,col);for(let yy=9;yy<26;yy+=4)for(let xx=11;xx<23;xx+=4)A.R(c,xx,yy,2,2,'#f0d886');A.poly(c,[[7,15],[12,21],[15,30],[8,24]],'#698d4c');}
        if(id==='pumpkin'){A.ellipse(c,16,19,12,10,col);for(let a of [9,15,21])A.R(c,a,11,2,15,'#a87336');A.R(c,14,5,4,6,'#648250');}
        if(id==='lotus'){A.ellipse(c,14,20,11,7,col);for(let i=0;i<5;i++)A.R(c,7+i%3*5,17+Math.floor(i/3)*5,2,2,'#ac9271');}
      }
    }c.restore();
  }
  function points(s){
    const pts=legacyPoints(s).map(p=>({...p,x:p.x+480,y:p.y+288}));
    const roles={an:[643,285],liang:[597,290],tao:[1177,285],mei:[1588,288],he:[1166,563],chen:[310,873],lin:[287,297],xu:[714,555],jiang:[1477,853]};
    if(s.scene==='town'&&!C.market(s).open)for(const p of pts)if(p.kind==='npc'&&roles[p.id]){p.x=roles[p.id][0];p.y=roles[p.id][1];}
    if(s.scene==='farm'){
      const pet=pts.find(p=>p.id==='pet');if(pet){pet.x=847;pet.y=520;}
      const mail=pts.find(p=>p.id==='mailbox');if(mail){mail.x=646;mail.y=565;}
    }
    return pts.concat(L.maps[s.scene].landmarks.map(p=>({...p,name:p.kind==='gather'&&s.collected[p.id]===s.day?p.name+' · 明天恢复':p.name})));
  }
  function obstacles(s){return L.maps[s.scene].solids;}
  function blocked(s,x,y){return !Number.isFinite(x)||!Number.isFinite(y)||x<24||x>W-24||y<38||y>H-24||obstacles(s).some(([a,b,w,h])=>x>a-6&&x<a+w+6&&y>b-3&&y<b+h+5);}
  function clearLine(s,a,b){const n=Math.ceil(Math.hypot(a.x-b.x,a.y-b.y)/4);for(let i=1;i<=n;i++)if(blocked(s,a.x+(b.x-a.x)*i/n,a.y+(b.y-a.y)*i/n))return false;return true;}
  let gridKey='',grid=null;
  function gridFor(s){const key=s.scene;if(key!==gridKey){grid=new Uint8Array(120*72);for(let y=0;y<72;y++)for(let x=0;x<120;x++)grid[y*120+x]=blocked(s,x*16+8,y*16+8)?1:0;gridKey=key;}return grid;}
  function nearbyCell(s,p){const g=gridFor(s),cx=Math.floor(p.x/16),cy=Math.floor(p.y/16),list=[];for(let y=Math.max(0,cy-2);y<=Math.min(71,cy+2);y++)for(let x=Math.max(0,cx-2);x<=Math.min(119,cx+2);x++)if(!g[y*120+x])list.push({id:y*120+x,x:x*16+8,y:y*16+8});list.sort((a,b)=>Math.hypot(a.x-p.x,a.y-p.y)-Math.hypot(b.x-p.x,b.y-p.y));return list.find(q=>clearLine(s,p,q));}
  function route(s,x,y){
    if(blocked(s,x,y))return [];const from=nearbyCell(s,s.player),to=nearbyCell(s,{x,y});if(!from||!to)return [];
    const g=gridFor(s),queue=new Int32Array(8640),prev=new Int32Array(8640);prev.fill(-2);queue[0]=from.id;prev[from.id]=-1;let end=1,found=false;
    for(let q=0;q<end;q++){const id=queue[q];if(id===to.id){found=true;break;}const col=id%120,row=Math.floor(id/120);for(const [dx,dy]of [[1,0],[-1,0],[0,1],[0,-1]]){const nx=col+dx,ny=row+dy,next=ny*120+nx;if(nx<0||nx>=120||ny<0||ny>=72||g[next]||prev[next]!==-2)continue;prev[next]=id;queue[end++]=next;}}
    if(!found)return [];const out=[{x,y}];for(let id=to.id;id!==-1;id=prev[id])out.push({x:id%120*16+8,y:Math.floor(id/120)*16+8});return out.reverse();
  }
  function restorePosition(s){if(!blocked(s,s.player.x,s.player.y))return false;const origin={...s.player};for(let radius=8;radius<200;radius+=8)for(let i=0;i<24;i++){const x=Math.round(origin.x+Math.cos(i*Math.PI/12)*radius),y=Math.round(origin.y+Math.sin(i*Math.PI/12)*radius);if(!blocked(s,x,y)){s.player={x,y,direction:origin.direction||'down'};return true;}}s.player={...L.spawn(s.scene)};return true;}
  function plotAt(x,y){const col=Math.floor((x-771)/42),row=Math.floor((y-559)/36);return col>=0&&col<6&&row>=0&&row<4&&x<771+col*42+38&&y<559+row*36+31?row*6+col:-1;}
  function hit(s,x,y){if(s.scene==='farm'){const index=plotAt(x,y);if(index>=0)return {id:'plot-'+index,kind:'plot',index,...plotPosition(index),name:'菜地'};}return points(s).filter(p=>Math.abs(x-p.x)<25&&y>p.y-36&&y<p.y+16).sort((a,b)=>Math.hypot(x-a.x,y-a.y)-Math.hypot(x-b.x,y-b.y))[0]||null;}
  function terrain(c,s){
    const season=C.calendar(s).season,P=A.seasons[season],m=L.maps[s.scene],r=A.rand(929+season);if(root.ZRZTiles?.base)root.ZRZTiles.base(c,s);else A.R(c,0,0,W,H,P.grass);
    for(let i=0;i<(root.ZRZTiles?0:7500);i++){const x=r()*W,y=r()*H;A.R(c,x,y,r()>.7?4:1,1,i%3?P.light:P.dark);}
    // Quiet clusters and low edges leave the paths visually readable.
    for(const p of m.paths){if(root.ZRZTiles?.path?.(c,p,season))continue;A.R(c,p.x-3,p.y-3,p.w+6,p.h+6,'#798751');A.R(c,p.x,p.y,p.w,p.h,p.kind==='wood'?'#90724b':p.kind==='earth'?P.earth:'#a8b5a1');
      if(p.kind==='wood'){for(let y=p.y+2;y<p.y+p.h;y+=9){A.R(c,p.x+2,y,p.w-4,7,'#c4a26c');A.R(c,p.x+5,y+1,p.w-10,1,'#e0c18a');}}
      else if(p.kind==='stone'){for(let y=p.y+2;y<p.y+p.h-4;y+=13)for(let x=p.x+2;x<p.x+p.w-5;x+=23){const ww=Math.min(20,p.x+p.w-x-2),hh=Math.min(11,p.y+p.h-y-1);A.R(c,x+(Math.floor(y/13)%2)*2,y,ww,hh,['#bdc3aa','#c5c8b0','#adb9a4'][Math.floor(r()*3)]);A.R(c,x+2,y+1,Math.max(2,ww-4),1,'#d6d5bd');}}
      else for(let i=0;i<p.w*p.h/110;i++)A.R(c,p.x+r()*p.w,p.y+r()*p.h,2,1,'#a8956b');
    }
    for(const f of m.fields){A.R(c,f.x-5,f.y-5,f.w+10,f.h+10,'#7a8851');A.R(c,f.x,f.y,f.w,f.h,f.type==='rice'?'#87a996':f.type==='grain'?'#c8b078':'#9c9561');
      for(let y=f.y+7;y<f.y+f.h-5;y+=f.type==='tea'?14:13)for(let x=f.x+8;x<f.x+f.w-7;x+=f.type==='tea'?16:12){if(f.type==='tea'){A.R(c,x-5,y,14,8,P.deep);A.R(c,x-4,y-3,12,6,P.leaf);A.R(c,x-2,y-5,7,3,P.tip);}else if(f.type==='flower'){A.R(c,x,y,1,6,'#68823f');A.R(c,x-2,y-2,5,3,season===0?'#e6ca63':season===2?'#d19c69':'#d7d3a1');}else{A.R(c,x,y-4,1,8,season===2?'#d7bd64':'#54894e');A.R(c,x-3,y-2,3,2,season===2?'#edcf7e':'#b1c982');A.R(c,x+1,y-4,3,2,season===2?'#deb757':'#7da663');}}
    }
    for(const w of m.water){
      const shore=(inset,col)=>{const x=w.x+inset,y=w.y+inset,ww=w.w-inset*2,hh=w.h-inset*2;if(w.lotus){A.poly(c,[[x+ww*.14,y],[x+ww*.69,y+3],[x+ww*.87,y+hh*.09],[x+ww*.97,y+hh*.24],[x+ww,y+hh*.65],[x+ww*.89,y+hh*.86],[x+ww*.7,y+hh],[x+ww*.25,y+hh-3],[x+ww*.07,y+hh*.87],[x,y+hh*.58],[x+3,y+hh*.2]],col);}else A.R(c,x,y,ww,hh,col);};
      shore(-9,'#75896a');shore(-5,'#b4bd94');shore(-1,'#537f75');shore(3,'#669e91');shore(10,'#78b1a0');
      for(let i=0;i<w.w*w.h/600;i++){let x=w.x+w.w*.16+r()*w.w*.62,y=w.y+w.h*.18+r()*w.h*.65;A.R(c,x,y,8+r()*17,1,i%2?'#bed7b777':'#4f918b55');}
      if(w.lotus)for(let i=0;i<26;i++){const x=w.x+w.w*.18+r()*w.w*.62,y=w.y+w.h*.18+r()*w.h*.63;A.ellipse(c,x,y,8,4,'#447749');A.ellipse(c,x,y-1,6,3,'#89a85d');A.R(c,x,y-2,1,3,'#c1c977');if(i%5===0&&season!==3){A.R(c,x+3,y-6,7,4,'#d48e87');A.R(c,x+4,y-9,5,6,'#e6b3a4');A.R(c,x+6,y-11,2,6,'#f2d0b5');}}
      const gap=w.w>300?43:24;for(let x=w.x+8;x<w.x+w.w-8;x+=gap){const y=w.y+(w.lotus?12:0);for(let k=0;k<3;k++)A.R(c,x+k*3,y-7-k%2*5,1,8+k%2*5,k%2?'#aec080':'#5c834d');}
    }
    // Bridges are above water and keep both banks connected.
    for(const p of m.paths.filter(p=>p.kind==='wood')){A.R(c,p.x,p.y,p.w,p.h,'#7d6846');for(let y=p.y+2;y<p.y+p.h;y+=10){A.R(c,p.x+3,y,p.w-6,8,'#c5a575');A.R(c,p.x+5,y,p.w-10,1,'#e4c58c');}for(let x of [p.x+4,p.x+p.w-7]){A.R(c,x,p.y,3,p.h,'#715b3c');for(let y=p.y;y<p.y+p.h;y+=34)A.R(c,x-1,y-9,5,15,'#bda16e');}}
    if(s.scene==='farm'){A.R(c,766,554,263,151,'#607743');A.R(c,768,556,259,147,'#b7ab77');}
    if(s.scene==='mountain'){A.poly(c,[[0,135],[0,0],[W,0],[W,131],[1700,104],[1500,168],[1250,102],[980,155],[670,89],[414,134],[177,97]],'#91b09b');A.poly(c,[[0,81],[183,15],[352,91],[533,33],[744,84],[965,21],[1120,80],[1380,16],[1610,92],[1810,26],[1920,78],[1920,0],[0,0]],'#b1c4b1');}
  }
  let cacheKey='',terrainCache,propCache=new Map();
  function sprite(p,season){const key=JSON.stringify(p)+'/'+season;if(propCache.has(key))return propCache.get(key);const c=document.createElement('canvas');c.width=Math.max(280,(p.w||0)+90);c.height=Math.max(240,(p.h||0)+90);const q=c.getContext('2d'),anchor={x:100,y:180};if(p.kind==='house'){anchor.x=30;anchor.y=25;}else if(['pavilion','gate'].includes(p.kind)){anchor.x=30;anchor.y=170;}
    q.imageSmoothingEnabled=false;A.prop(q,{...p,x:anchor.x,y:anchor.y},season);const v={canvas:c,dx:-anchor.x,dy:-anchor.y};propCache.set(key,v);return v;}
  function plots(c,s,t,hover){for(let i=0;i<24;i++){const p=s.plots[i],x=771+i%6*42,y=559+Math.floor(i/6)*36;if(p.tilled){A.R(c,x,y,38,31,'#715e3f');A.R(c,x+1,y+1,36,28,p.watered?'#756c4c':'#a08758');for(let k=0;k<4;k++){A.R(c,x+3,y+5+k*6,32,2,p.watered?'#596247':'#816944');A.R(c,x+3,y+4+k*6,32,1,p.watered?'#a2a16a':'#c4a670');}A.R(c,x+2,y+28,34,2,'#655438');}else{A.R(c,x+1,y+1,35,28,'#7a9252');A.R(c,x+7,y+18,3,1,'#c5c887');}
      if(p.crop){let rate=p.growth/D.crops[p.crop].days;if(rate>=1){item(c,p.crop,x+3,y-2,1.08);if(Math.sin(t*2+i)>.8){A.R(c,x+31,y-4,1,5,'#fff1b0');A.R(c,x+29,y-2,5,1,'#fff1b0');}}else{let h=6+rate*15;A.R(c,x+18,y+24-h,2,h,'#376639');A.R(c,x+10,y+22-h,9,3,'#76a456');A.R(c,x+20,y+17-h,8,4,'#92b369');if(rate>.4){A.R(c,x+12,y+10-h,7,5,'#4e8849');A.R(c,x+20,y+8-h,5,4,'#adc877');}}}
      if(p.pest)A.R(c,x+28,y+18,4,2,'#8c5436');if(p.watered){A.R(c,x+32,y+24,3,4,'#91c8c2');A.R(c,x+33,y+23,1,2,'#d0e6d4');}if(p.tilled)for(let k=0;k<3;k++)A.R(c,x+3+k*4,y+27,2,2,k<Math.ceil(p.soil+1)?'#d2ca83':'#635d3f');if(hover?.kind==='plot'&&hover.index===i){c.strokeStyle='#fff2b3';c.lineWidth=2;c.strokeRect(x-1,y-1,40,33);}}
  }
  function animal(c,a,x,y,t){c.save();c.translate(Math.round(x),Math.round(y));A.shadow(c,0,0,35,9);const blink=Math.floor(t*2)%11===0;
    if(a.species==='牛'){A.R(c,-18,-20,33,20,'#5d513c');A.R(c,-17,-20,32,15,'#bb9059');A.R(c,-14,-19,17,5,'#d7b47b');A.R(c,-15,-5,5,10,'#997345');A.R(c,9,-5,5,10,'#997345');A.R(c,-15,3,6,3,'#4e4936');A.R(c,9,3,6,3,'#4e4936');A.R(c,9,-26,18,17,'#c19a67');A.R(c,18,-16,11,8,'#dbc099');A.R(c,12,-30,3,8,'#ddd5ab');A.R(c,24,-30,3,8,'#ddd5ab');A.R(c,24,-23,2,blink?1:2,'#2f3b2c');A.R(c,22,-12,2,2,'#917254');A.R(c,-22,-21,3,18,'#866b40');}
    else{const duck=a.species==='鸭',col=duck?'#d7d3b4':'#ecdfb8';A.ellipse(c,0,-9,11,8,'#88754c');A.ellipse(c,-1,-11,10,7,col);A.R(c,5,-23,11,15,col);A.R(c,9,-20,2,blink?1:2,'#2f432e');A.R(c,15,-15,7,3,'#cb974b');A.R(c,-7,-11,8,5,'#c1b287');A.R(c,-13,-17,7,7,col);A.R(c,-5,-3,2,8,'#b1813c');A.R(c,3,-3,2,8,'#b1813c');if(!duck){A.R(c,7,-26,7,4,'#b64935');A.R(c,12,-11,3,4,'#b6593a');}}
    if(a.ready>0){A.R(c,-6,-44,13,13,'#fff1cb');A.R(c,-2,-41,5,8,'#d9bd76');}c.restore();}
  function pet(c,s,t){const x=847,y=520,col=s.pet.type==='cat'?'#c49961':'#977550';A.shadow(c,x,y,29,8);A.R(c,x-11,y-13,21,13,col);A.R(c,x+5,y-22,13,14,col);A.R(c,x+6,y-26,4,6,col);A.R(c,x+15,y-26,3,s.pet.type==='cat'?6:14,col);A.R(c,x+8,y-13,10,5,'#e1c398');A.R(c,x+14,y-18,2,2,'#32422e');A.R(c,x-17,y-14+Math.sin(t*2)*2,9,3,col);A.R(c,x-8,y-2,4,6,'#e2c18d');A.R(c,x+5,y-2,4,6,'#e2c18d');}
  function furniture(c,id,x,y,season){const kinds={bench:'bench',pot:'pot',path:'stone',fence:'fence',orchard:'orchard',trellis:'rack',waterbed:'basket',photo:'board'};if(kinds[id])return A.prop(c,{kind:kinds[id],x,y,w:45,size:.6,seed:x},season);if(id==='greenhouse'){A.poly(c,[[x-31,y-30],[x,y-48],[x+31,y-30],[x+31,y],[x-31,y]],'#aecbbb88');for(let k=-28;k<=28;k+=14)A.R(c,x+k,y-30,2,30,'#e0dfb7');A.R(c,x-31,y,62,3,'#849986');return;}A.R(c,x-2,y-35,4,40,'#a28450');A.R(c,x-19,y-29,38,4,'#a28450');A.character(c,x,y-4,'#a08152',0,false,true,'down',{hair:0});}
  function mapView(c,s){c.clearRect(0,0,c.canvas.width,c.canvas.height);c.save();c.scale(c.canvas.width/W,c.canvas.height/H);terrain(c,s);const season=C.calendar(s).season;for(const p of L.maps[s.scene].props){const v=sprite(p,season);c.drawImage(v.canvas,p.x+v.dx,p.y+v.dy);}if(s.scene==='farm')plots(c,s,0,null);c.restore();const sx=c.canvas.width/W,sy=c.canvas.height/H;c.fillStyle='#a84f37';c.beginPath();c.arc(s.player.x*sx,s.player.y*sy,5,0,7);c.fill();c.strokeStyle='#fff2cb';c.lineWidth=2;c.stroke();}
  function draw(canvas,s,t,hover,walking,effect,view){
    ctx=canvas.getContext('2d');ctx.imageSmoothingEnabled=false;const season=C.calendar(s).season,m=L.maps[s.scene],key=s.scene+'/'+season+'/'+!!s.flags.bridge;
    if(cacheKey!==key){terrainCache=document.createElement('canvas');terrainCache.width=W;terrainCache.height=H;terrain(terrainCache.getContext('2d'),s);cacheKey=key;propCache.clear();}
    ctx.drawImage(terrainCache,0,0);if(s.scene==='farm')plots(ctx,s,t,hover);
    const visible=p=>!view||p.x>view.x-350&&p.x<view.x+view.viewWidth+100&&p.y>view.y-50&&p.y<view.y+view.viewHeight+210;
    const pts=points(s),objects=m.props.filter(visible).map(p=>({y:p.kind==='house'?p.y+p.h:p.y,draw:()=>{const v=sprite(p,season);const obscures=s.player.x>p.x-45&&s.player.x<p.x+(p.w||60)&&s.player.y<p.y&&s.player.y>p.y-90;const underRoof=p.kind==='house'&&s.player.x>p.x-15&&s.player.x<p.x+p.w+15&&s.player.y>p.y-8&&s.player.y<p.y+55;if(underRoof||obscures&&['tree','orchard','bamboo','willow','blossom'].includes(p.kind))ctx.globalAlpha=.48;ctx.drawImage(v.canvas,p.x+v.dx,p.y+v.dy);ctx.globalAlpha=1;if(p.kind==='house'&&p.name==='爷爷的老屋'){if(!s.upgrades.roof){for(const [dx,dy]of [[41,24],[87,33],[143,17]])A.R(ctx,p.x+dx,p.y+dy,8,5,'#34494a');}else{A.R(ctx,p.x+157,p.y+78,2,17,'#826b42');A.ellipse(ctx,p.x+158,p.y+91,7,9,'#b6533b');A.R(ctx,p.x+156,p.y+98,4,5,'#dcb575');}}}}));
    if(s.scene==='farm'){
      s.animals.forEach((a,i)=>objects.push({y:677+i%2*23,draw:()=>animal(ctx,a,1186+i*50,677+i%2*23,t)}));objects.push({y:520,draw:()=>pet(ctx,s,t)});
      for(const v of s.layouts){const p=C.layoutSlots[v.slot];objects.push({y:p.y,draw:()=>furniture(ctx,v.id,p.x,p.y,season)});}
      const upgrades=[['storage','chest',665,588],['yard','rack',650,613],['mill','mill',1172,536],['room','table',983,493],['irrigation','jar',1151,601]];for(const [id,kind,x,y]of upgrades)if(s.upgrades[id])objects.push({y,draw:()=>A.prop(ctx,{kind,x,y},season)});
      if(s.projects.canal){A.R(ctx,1057,558,9,155,'#648d7c');A.R(ctx,1059,560,5,153,'#99c2a9');}
    }
    if(s.scene==='river'){if(s.flags.bridge){for(const p of [{kind:'bench',x:1062,y:466},{kind:'table',x:1165,y:467}])objects.push({y:p.y,draw:()=>A.prop(ctx,p,season)});}else{for(const y of [575,689]){A.R(ctx,903,y,114,5,'#685d42');A.R(ctx,905,y+1,108,2,'#8c8261');}}}
    if(s.scene==='town'&&s.projects.stage)objects.push({y:681,draw:()=>{A.prop(ctx,{kind:'pavilion',x:1268,y:678,w:116},season);A.R(ctx,1277,602,15,61,'#a25147');A.R(ctx,1357,602,15,61,'#a25147');}});
    if(s.scene==='town'&&s.projects.market)objects.push({y:652,draw:()=>{A.R(ctx,1064,579,5,81,'#84613b');A.R(ctx,1230,579,5,81,'#84613b');for(let i=0;i<10;i++)A.R(ctx,1059+i*18,559,18,29,i%2?'#6b8b75':'#d9c18c');}});
    for(const p of pts){if(!visible(p))continue;if(p.kind==='gather'&&s.collected[p.id]!==s.day)objects.push({y:p.y,draw:()=>{A.shadow(ctx,p.x,p.y,27,8);item(ctx,p.item,p.x-16,p.y-29,1);}});if(p.kind==='npc')objects.push({y:p.y,draw:()=>A.character(ctx,p.x,p.y,p.npc.color,t,Math.floor(t+p.x)%17<2,false,['down','left','down','right'][Math.floor(t/12+p.x)%4],{id:p.id})});}
    objects.push({y:s.player.y,draw:()=>A.character(ctx,s.player.x,s.player.y,['#57826a','#647e9b','#b17d67','#ac9a65'][s.appearance.shirt],t,walking,s.appearance.hat,s.player.direction,s.appearance)});objects.sort((a,b)=>a.y-b.y).forEach(p=>p.draw());
    for(const p of pts){if(!visible(p))continue;const near=Math.hypot(p.x-s.player.x,p.y-s.player.y)<145;if(p.kind==='travel'){A.prop(ctx,{kind:'board',x:p.x,y:p.y+8,size:.5},season);A.label(ctx,p.x,p.y-35,p.name.replace('前往','→ '),true);}else if((p.kind==='npc'&&near&&Math.hypot(p.x-s.player.x,p.y-s.player.y)>53)||p.id.startsWith('landmark-')&&near&&Math.hypot(p.x-s.player.x,p.y-s.player.y)>53||hover?.id===p.id)A.label(ctx,p.x,p.y-(p.kind==='npc'?44:32),p.kind==='npc'?p.npc.name:p.name,true);}
    if(hover){ctx.strokeStyle='#fff0b6';ctx.lineWidth=2;if(hover.kind!=='plot'){ctx.beginPath();ctx.ellipse(hover.x,hover.y+2,18,7,0,0,7);ctx.stroke();}}
    if(effect&&t-effect.t<.7){let k=(t-effect.t)/.7;for(let i=0;i<8;i++)A.R(ctx,effect.x+Math.cos(i)*k*23,effect.y-10+Math.sin(i)*k*18-k*16,2,3,effect.color||'#f2d884');}
    for(const w of m.water)for(let i=0;i<Math.ceil(w.w/34);i++){let x=w.x+12+(i*59+t*5)%(w.w-24),y=w.y+12+(i*41)%(w.h-25);A.R(ctx,x,y,8,1,'#d9e7c966');}
    if(s.scene==='farm')for(let i=0;i<5;i++){const k=(t*.2+i*.2)%1;A.R(ctx,1204+Math.sin(t+i)*5,366-k*45,4+k*6,4+k*3,'#f2e9d174');}
    if(s.minutes>1020){A.R(ctx,0,0,W,H,'rgba(28,52,69,'+Math.min(.32,(s.minutes-1020)/850)+')');for(const p of m.props.filter(p=>p.kind==='house')){const x=p.x+p.w*.54,y=p.y+p.h-30;A.ellipse(ctx,x,y,37,28,'#f2bc581a');A.R(ctx,x+20,y-25,6,12,'#edc36b');}}
    const vx=view?.x||0,vy=view?.y||0,vw=view?.viewWidth||W,vh=view?.viewHeight||H,weather=C.weather(s.day);
    if(['雨','台风'].includes(weather))for(let i=0;i<90;i++)A.R(ctx,vx+(i*79+t*31)%vw,vy+(i*97+t*187)%vh,1,7,'#d4e8d772');
    if(['小雪','寒潮'].includes(weather))for(let i=0;i<50;i++)A.R(ctx,vx+(i*79+t*7)%vw,vy+(i*61+t*17)%vh,2,2,'#f0f1dcbb');
    if(weather==='雾')for(let i=0;i<4;i++)A.R(ctx,vx+(t*9+i*177)%(vw+200)-100,vy+i*vh/4,220,24,'#e8ecda24');
    if(season===0)for(let i=0;i<12;i++)A.R(ctx,vx+(i*89+t*9)%vw,vy+(i*71+t*6)%vh,2,2,'#eac6a977');
  }
  root.ZRZWorld={terrain,drawPlots:plots,drawAnimal:animal,drawFurniture:furniture,drawPet:pet,draw,item,character:A.character,portrait:A.portrait,points,hit,blocked,route,plotAt,plotPosition,restorePosition,mapView,obstacles,clearLine,width:W,height:H};
})(window);
