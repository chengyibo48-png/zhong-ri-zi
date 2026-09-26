(function (root) {
  'use strict';
  const D = root.ZRZData, C = root.ZRZCore, W = 960, H = 576;
  const palettes = [
    { grass: '#a8b97e', light: '#bac991', dark: '#94a972', leaf: '#729158', leafLight: '#9fb16d', leafDark: '#52774d' },
    { grass: '#98b477', light: '#adc786', dark: '#88a56d', leaf: '#648851', leafLight: '#90ab62', leafDark: '#466e48' },
    { grass: '#beb580', light: '#cebd8b', dark: '#aea776', leaf: '#b09352', leafLight: '#c9ab61', leafDark: '#82794b' },
    { grass: '#b4bfaf', light: '#cbd1ba', dark: '#a2b3a1', leaf: '#819784', leafLight: '#a0af98', leafDark: '#627c6b' }
  ];
  let ctx, P;
  const rect = (x, y, w, h, c) => { ctx.fillStyle = c; ctx.fillRect(Math.round(x), Math.round(y), w, h); };
  function poly(points, c) { ctx.fillStyle = c; ctx.beginPath(); points.forEach(([x, y], i) => i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)); ctx.closePath(); ctx.fill(); }
  function random(seed) { let n = seed; return () => { n = (n * 1664525 + 1013904223) >>> 0; return n / 4294967296; }; }
  function shadow(x, y, w, h) { rect(x + 4, y, w - 8, h, '#3c573425'); rect(x, y + 3, w, h - 6, '#3c573418'); }
  function tree(x, y, size = 1, blossom = false) {
    const old = ctx; ctx.save(); ctx.translate(x, y); ctx.scale(size, size);
    shadow(-27, -1, 66, 17); rect(-5, -35, 11, 41, '#7d7450'); rect(1, -30, 5, 33, '#938057'); rect(-13, -26, 11, 5, '#7d7450');
    const dark = blossom ? '#ae7e76' : P.leafDark, mid = blossom ? '#d8b298' : P.leaf, light = blossom ? '#efcbb4' : P.leafLight;
    poly([[-33,-32],[-38,-49],[-31,-62],[-20,-65],[-18,-76],[2,-81],[22,-75],[30,-61],[37,-52],[35,-31],[18,-21],[-9,-20]],dark);
    poly([[-32,-43],[-29,-61],[-13,-63],[-14,-73],[5,-75],[23,-68],[24,-52],[31,-49],[28,-34],[7,-28],[-13,-30]],mid);
    rect(-23,-62,17,10,light); rect(-13,-69,27,8,light); rect(-28,-53,17,8,light); rect(9,-59,13,7,light); rect(-7,-43,17,8,light); rect(17,-38,9,4,light);
    if (blossom) { [[-18,-55],[9,-68],[20,-44],[-3,-35]].forEach(([a,b])=>{rect(a,b,4,4,'#f5dfc4');rect(a+2,b+1,2,2,'#bf8c73');}); }
    ctx.restore(); ctx = old;
  }
  function bamboo(x, y, height = 105) {
    shadow(x - 17, y - 3, 44, 10);
    [-13,0,14].forEach((dx,i)=> { const h = height - i * 9; rect(x+dx,y-h,5,h,'#64895b'); rect(x+dx+1,y-h,2,h,'#9eb577'); for(let j=14;j<h;j+=19) {rect(x+dx-1,y-j,7,2,'#b1c383');poly([[x+dx,y-j-3],[x+dx-20,y-j-15],[x+dx-6,y-j-13]],'#72925c');poly([[x+dx+3,y-j-12],[x+dx+25,y-j-26],[x+dx+21,y-j-14]],'#829e61');} });
  }
  function bush(x,y) { shadow(x-17,y,38,9); rect(x-19,y-13,37,14,P.leaf); rect(x-13,y-20,24,12,P.leafLight); rect(x-8,y-23,14,5,P.leaf); rect(x+9,y-14,10,6,P.leafDark); }
  function fence(x,y,length,vertical=false) {
    if(vertical) { rect(x,y,4,length,'#a39466'); for(let i=0;i<length;i+=22){rect(x-3,y+i,9,8,'#ac9c70');rect(x-3,y+i,9,2,'#d8c395');} return; }
    rect(x,y+6,length,5,'#ab9466'); rect(x,y+16,length,4,'#9a855a');
    for(let i=0;i<length;i+=24){rect(x+i,y,6,26,'#b29b6e');rect(x+i,y,6,4,'#d0b987');rect(x+i+4,y+4,2,22,'#998356');}
  }
  function path(x,y,w,h) { rect(x,y,w,h,'#d4c59b'); rect(x+3,y+3,w-6,h-6,'#dccda7'); const r=random(x*32+y+4); for(let i=0;i<w*h/500;i++) rect(x+r()*w,y+r()*h,3+r()*4,2,'#c3b68d'); }
  function house(x,y,w,h,kind='home',repaired=false) {
    shadow(x+3,y+h-7,w+20,20); rect(x+9,y+41,w-18,h-39,'#e6dbb9'); rect(x+9,y+h-18,w-18,18,'#aaa68d');
    rect(x+9,y+44,w-18,7,'#bbb295'); rect(x+w-21,y+46,12,h-62,'#d5cbaa'); rect(x+9,y+h-21,w-18,3,'#c4b99a');
    for(let row=0;row<3;row++)for(let k=0;k<8;k++) if((row+k)%3===0)rect(x+20+k*22,y+h-14+row*4,11,1,'#999780');
    const roof = repaired ? '#636e69' : '#737d77';
    poly([[x-9,y+45],[x+18,y+9],[x+w-23,y+9],[x+w+10,y+45]],'#505f5b');
    poly([[x-6,y+39],[x+18,y+6],[x+w-24,y+6],[x+w+8,y+39]],roof);
    for(let row=0;row<5;row++) { const ry=y+11+row*6, off=(4-row)*5; rect(x+off,ry,w-off*2,2,'#8c9486'); for(let j=off+7;j<w-off;j+=15) rect(x+j,ry,2,6,'#5c6b64'); }
    rect(x+18,y+3,w-42,4,'#a0a08a'); rect(x-9,y+43,w+18,5,'#4c5d55');
    const dx=x+w*.53; rect(dx-16,y+h-61,32,61,'#7f7960'); rect(dx-12,y+h-57,25,57,'#5d6859'); rect(dx-11,y+h-55,10,52,'#817f63'); rect(dx+7,y+h-25,2,3,'#c5b482'); rect(dx-20,y+h,41,6,'#b7b497'); rect(dx-25,y+h+6,51,5,'#c7c4a5');
    (w<180?[x+23]:[x+29,x+w-66]).forEach(wx=> {rect(wx,y+62,31,35,'#aaa88d');rect(wx+3,y+65,25,27,'#92aea0');rect(wx+4,y+66,11,12,'#c3cdc0');rect(wx+14,y+64,3,29,'#6d7967');rect(wx+2,y+77,28,3,'#6d7967');rect(wx-3,y+95,37,4,'#b7af8d');});
    // Contemporary details: an air conditioner and solar hot-water tubes.
    rect(x+w-55,y+107,30,17,'#d6d5bb');for(let j=0;j<5;j++)rect(x+w-51,y+111+j*2,21,1,'#acb19e');
    if(kind==='home') {rect(x+34,y-1,41,7,'#bfc8bd');for(let j=0;j<6;j++)rect(x+38+j*5,y+6,3,15,'#83a1a4');rect(x+30,y+22,49,3,'#b4b5a3');}
    if(kind==='shop') {rect(x+20,y+46,w-40,24,'#b58160');for(let j=0;j<(w-40)/15;j++)rect(x+20+j*15,y+46,7,24,'#d1ae7f');}
    if(repaired) {rect(dx+28,y+h-58,8,12,'#c8a25e');rect(dx+27,y+h-60,10,3,'#997e4f');rect(dx+31,y+h-45,2,7,'#be9260');}
  }
  function bench(x,y) { rect(x,y,52,8,'#a18c60');rect(x+3,y+8,5,12,'#7e7854');rect(x+42,y+8,5,12,'#7e7854');rect(x+2,y-12,48,6,'#b6a075');rect(x+4,y-7,3,9,'#897e59');rect(x+44,y-7,3,9,'#897e59'); }
  function label(x,y,text,color='#5b6c4d') { ctx.font='11px "Microsoft YaHei",sans-serif'; const w=ctx.measureText(text).width+16;rect(x-w/2,y-12,w,19,'#f8f3dce8');rect(x-w/2,y+7,w,1,'#75835d33');ctx.fillStyle=color;ctx.textAlign='center';ctx.fillText(text,x,y+1); }
  function flowers(x,y,seed=8) { const r=random(seed); for(let i=0;i<11;i++){const a=x+r()*55,b=y+r()*35;rect(a,b+3,1,4,'#7b9360');rect(a-1,b,4,3,i%2?'#e4cd95':'#eddfbd');} }
  function pot(x,y) {rect(x-6,y-9,12,13,'#b58662');rect(x-8,y-11,16,4,'#d0a47a');rect(x-4,y-20,8,10,P.leaf);rect(x-9,y-17,6,5,P.leafLight);rect(x+2,y-24,6,12,P.leafLight);}
  function water(x,y,w,h,seed=8) {rect(x-9,y,w+18,h,'#929c71');rect(x-4,y,w+8,h,'#a9b58c');rect(x,y,w,h,'#91b8ad');const r=random(seed);for(let i=0;i<w*h/600;i++){const a=x+r()*(w-15),b=y+r()*h;rect(a,b,12+r()*12,2,'#c2d0b24a');rect(a+5,b+4,8,1,'#6da39855');}}
  function base(s) {
    const season=C.calendar(s).season;P=palettes[season];rect(0,0,W,H,P.grass);const r=random(791+season);
    for(let i=0;i<2400;i++){let x=Math.floor(r()*W),y=Math.floor(r()*H);rect(x,y,r()>.7?5:2,2,i%3?P.light:P.dark);}
    // Layered hedgerow gives the map a soft, enclosed horizon.
    rect(0,0,960,35,P.dark);for(let x=0;x<1000;x+=35)bush(x,30+(x%3)*5);
    if(s.scene==='farm') {
      path(28,216,815,47);path(401,199,49,369);path(202,181,43,65);path(615,182,56,292);path(405,444,555,39);
      water(868,0,92,576);for(let y=0;y<576;y+=36){rect(850,y,7,13,P.leaf);rect(855,y-4,3,14,P.leafLight);}
      rect(854,441,106,38,'#9b865d');for(let x=855;x<960;x+=12){rect(x,442,9,35,'#c1a777');rect(x,443,9,2,'#d8be8e');}fence(851,429,110);fence(851,477,110);
      house(96,65,225,136,'home',s.upgrades.roof);house(606,94,148,108,'kitchen',s.upgrades.kitchen);
      rect(711,279,108,71,'#baad80');rect(708,272,114,12,'#8c8061');poly([[702,274],[727,251],[806,251],[830,274]],'#a28e64');rect(724,299,30,51,'#716d4e');rect(773,296,30,23,'#d6c599');
      if(s.upgrades.coop){rect(698,345,131,5,'#c2a874');fence(682,376,152);}
      fence(267,252,110);fence(455,252,112);fence(266,420,305);fence(264,264,156,true);fence(570,264,156,true);
      // Farm well, stool, woodpile, and neat vegetable baskets.
      shadow(602,288,52,17);rect(607,268,38,29,'#8f9a87');rect(603,266,46,8,'#c1c1a4');rect(610,263,32,7,'#596e61');rect(601,234,5,37,'#9c8e65');rect(644,234,5,37,'#9c8e65');rect(598,229,53,8,'#a29670');rect(623,235,2,25,'#cdb582');
      bench(612,420);pot(320,190);pot(582,182);pot(674,201);
      rect(99,340,58,39,'#a99770');rect(103,344,50,26,'#e2d4a7');rect(105,349,31,2,'#afa783');rect(105,355,40,2,'#afa783');rect(105,361,22,2,'#afa783');rect(110,379,5,17,'#857853');rect(142,379,5,17,'#857853');
      for(let i=0;i<5;i++){rect(74+i*10,185,9,22,'#a48759');rect(75+i*10,185,7,4,'#c4aa75');}
      rect(171,270,33,20,'#b89b69');rect(174,270,27,6,'#dcc18a');rect(174,277,26,2,'#917b54');
      tree(47,137,1.15);tree(360,145,.85,true);tree(795,160,1.1);tree(80,510,1.15);tree(223,512,.9);tree(761,534,1.1);tree(21,391,.8);
      bamboo(14,237,90);bamboo(53,220,115);flowers(132,445);flowers(674,500);bush(581,516);bush(589,497);bush(336,471);
      label(211,65,'爷爷的老屋');label(677,97,'小厨房');label(765,258,'散养小棚');
    } else if(s.scene==='town') {
      path(0,299,960,80);path(405,70,66,506);path(145,224,610,67);rect(94,295,714,7,'#c1b895');
      house(118,98,219,145,'shop',true);house(566,85,241,160,'home',true);house(464,400,169,124,'home');
      rect(590,302,164,59,'#baa47c');for(let i=0;i<5;i++)rect(594+i*33,303,29,54,'#cdb486');rect(602,290,140,7,'#f1dfb2');
      for(let i=0;i<6;i++){rect(607+i*22,314,17,13,'#ded4a5');rect(610+i*22,311,11,6,i%2?'#b67848':'#83a262');}
      bench(78,417);bench(741,430);rect(356,220,43,48,'#ae9b70');rect(360,223,35,35,'#e9ddb8');
      for(let i=0;i<5;i++){rect(148+i*31,230,26,22,'#b09a68');rect(151+i*31,228,20,10,i%2?'#8e9b60':'#c4a462');}
      // Bicycle and utility pole ground the setting in the present.
      ctx.strokeStyle='#647866';ctx.lineWidth=3;[[531,259],[562,259]].forEach(([x,y])=>{ctx.beginPath();ctx.arc(x,y,10,0,7);ctx.stroke();});poly([[531,259],[544,243],[553,259]],'#90a27c');rect(545,239,14,3,'#5f7160');
      rect(866,73,6,188,'#8b9580');rect(849,88,41,4,'#7b8b78');ctx.strokeStyle='#687c6355';ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(0,72);ctx.quadraticCurveTo(430,128,868,89);ctx.stroke();
      tree(40,153,1.2);tree(879,182,1.2);tree(70,542,1.1,true);tree(795,539,1.1);bush(388,117);bush(443,535);pot(340,244);pot(547,243);flowers(188,480);flowers(794,407);
      label(227,99,'许婶杂货铺');label(686,87,'禾溪合作社');label(679,291,D.festivals[C.calendar(s).season]);label(374,213,'邻里告示板');
    } else if(s.scene==='bamboo') {
      path(387,0,72,576);path(130,250,650,54);path(194,302,48,193);path(663,180,45,115);
      const r=random(99);for(let i=0;i<48;i++){const x=r()*920+20,y=90+r()*460;if((x>345&&x<480)||(y>230&&y<345)||(x>170&&x<270&&y>300))continue;bamboo(x,y,65+r()*90);}
      for(let i=0;i<10;i++)bush(30+i*97,60);
      bench(490,212);rect(493,190,9,13,'#b58b61');pot(543,215);tree(58,196,.9);tree(889,556,.95);label(421,137,'竹影里的小路');label(530,186,'听风长椅');
    } else if(s.scene==='river') {
      water(0,220,960,245,22);path(0,163,960,53);path(0,489,960,46);path(121,62,51,126);
      poly([[0,451],[219,443],[343,468],[641,450],[960,465],[960,491],[0,491]],'#b9c49a');
      rect(413,210,118,291,s.flags.bridge?'#b6a176':'#91836a');for(let y=211;y<502;y+=15)rect(413,y,118,11,s.flags.bridge?'#d5b88a':'#ad9a76');
      if(s.flags.bridge){for(let x of [409,527]){rect(x,204,5,303,'#8d8059');for(let y=214;y<501;y+=35)rect(x-2,y,9,15,'#c1aa7b');}bench(582,178);rect(665,151,40,30,'#b19a6b');rect(659,146,51,9,'#c9b585');pot(704,170);}
      else {rect(416,287,111,17,'#7b7f68');rect(417,400,113,14,'#797e66');}
      for(let x=22;x<940;x+=76){rect(x,214,3,19,'#7c9964');rect(x+5,210,2,26,'#a1b27b');rect(x+9,222,3,11,'#759366');}
      tree(42,147,1.15);tree(278,121,.85,true);tree(753,140,1.2);tree(930,167,1.1);tree(96,565,1);bush(557,521);flowers(635,500);
      rect(226,191,85,11,'#c1ae80');rect(230,201,6,35,'#8b805f');rect(299,201,6,35,'#8b805f');label(270,171,'垂钓小埠');label(472,164,s.flags.bridge?'乡亲们修好的河埠':'待修缮的河埠');
    } else {
      // Hills: stacked pixel silhouettes rather than a distant, inaccessible dungeon.
      poly([[0,156],[0,53],[132,8],[274,93],[413,34],[574,99],[722,12],[960,101],[960,170]],'#91a88c');
      poly([[0,186],[73,107],[204,139],[344,82],[478,147],[679,77],[846,126],[960,102],[960,209]],'#809b76');
      path(395,243,62,333);path(262,236,359,48);path(574,188,46,87);path(105,390,320,45);path(121,290,47,138);
      for(let i=0;i<5;i++){rect(640,301+i*37,196,9,'#6f8b57');rect(641,297+i*37,194,8,'#8ba46a');for(let j=0;j<8;j++)rect(646+j*24,295+i*37,15,6,'#a0b375');}
      tree(67,297,1.1);tree(297,464,1.05);tree(877,321,1.2);tree(865,554,1.1);tree(511,427,.85);tree(138,543,.95);tree(215,278,.8);
      bench(495,226);rect(555,189,39,11,'#a89b74');rect(570,200,5,28,'#827858');label(543,181,'望村亭');
      rect(72,357,43,19,'#a4ad96');rect(81,347,27,13,'#b6bca5');flowers(451,509);bush(581,297);bush(38,524);
    }
  }
  function character(context,x,y,color='#72947a',time=0,walking=false,hat=false,direction='down',appearance={}) {
    const prev=ctx;ctx=context;ctx.save();ctx.translate(Math.round(x),Math.round(y));ctx.scale(1,.75);const skin=['#e6c69c','#c49b75','#a27958'][appearance.skin||0];
    shadow(-9,-1,19,6);const step=walking?Math.sin(time*12)*2:0;
    rect(-6,-5+step,5,7,'#526458');rect(2,-5-step,5,7,'#526458');rect(-7,1+step,6,3,'#6a6854');rect(2,1-step,6,3,'#6a6854');
    rect(-7,-19,15,15,color);rect(-9,-17,3,10,'#d4b38a');rect(8,-17,3,10,'#d4b38a');rect(-3,-20,6,4,'#e1c39a');rect(-7,-32,15,15,'#4d584c');rect(-6,-28,13,12,skin);rect(-7,-31,15,5,'#536153');rect(-7,-29,3,7,'#536153');
    if(direction==='up'){rect(-6,-28,13,8,'#52604f');}else {const off=direction==='left'?-2:direction==='right'?2:0;rect(-3+off,-23,2,2,'#4a5646');if(direction==='down')rect(3,-23,2,2,'#4a5646');rect(1+off,-18,3,1,'#b68a72');}
    if(hat){rect(-10,-33,21,5,'#bca473');rect(-6,-38,14,7,'#d6be86');rect(-13,-31,27,3,'#d4b982');rect(-6,-34,15,2,'#9b8a5c');}
    if(appearance.hair===1){rect(-9,-29,3,15,'#536153');rect(7,-29,3,15,'#536153');}if(appearance.hair===2){rect(5,-36,7,7,'#4e5b50');}if(appearance.hair===3){rect(-9,-32,19,5,'#58604f');rect(-10,-28,4,7,'#58604f');rect(7,-29,4,8,'#58604f');}rect(-3,-15,7,7,'#ffffff16');ctx.restore();ctx=prev;
  }
  function animal(a,x,y,t) {
    const drift=Math.sin(t*.8+x)*3;ctx.save();ctx.translate(Math.round(x+drift),y);shadow(-11,0,27,7);
    if(a.species==='牛'){rect(-15,-19,30,20,'#c4ac80');rect(-15,-4,5,9,'#8a805f');rect(9,-4,5,9,'#8a805f');rect(10,-25,15,15,'#bba478');rect(18,-18,9,9,'#d0bb94');rect(21,-24,2,2,'#555d45');rect(10,-29,3,7,'#e3d7b6');rect(22,-28,3,6,'#e3d7b6');rect(-6,-18,10,13,'#998564');}
    else {const col=a.species==='鸭'?'#d9d6b2':'#eee3bd';rect(-9,-13,17,13,col);rect(5,-21,10,12,col);rect(14,-15,7,3,'#bf9451');rect(11,-19,2,2,'#516048');rect(-5,-1,2,5,'#a3894f');rect(3,-1,2,5,'#a3894f');rect(-12,-13,7,5,col);if(a.species==='鸡')rect(8,-24,6,4,'#b86f50');rect(-7,-10,8,6,'#d1c797');}
    if(a.ready>0){rect(0,-39,13,13,'#fff4d0');rect(4,-37,5,8,'#c4ad73');}ctx.restore();
  }
  function item(context,id,x=0,y=0,scale=1) {
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
  function plots(s,t,selected) {
    s.plots.forEach((p,i)=> {const x=291+(i%6)*42,y=271+Math.floor(i/6)*36;
      if(p.tilled){rect(x,y,38,31,p.watered?'#8d8862':'#ad9569');rect(x+2,y+2,34,2,p.watered?'#9e9b70':'#c0a579');for(let j=0;j<3;j++)rect(x+4,y+8+j*7,30,2,p.watered?'#797b56':'#97845c');}
      else {rect(x+2,y+2,34,28,'#9baa71');rect(x+7,y+8,4,2,'#b6bd82');rect(x+22,y+18,5,2,'#839b67');}
      if(p.crop){const crop=D.crops[p.crop],stage=p.growth/crop.days;if(stage>=1){item(ctx,p.crop,x+5,y-1,1);if(Math.sin(t*2+i)>.5)rect(x+32,y-3,2,5,'#fff1ab');}else {const h=stage<.33?6:stage<.67?13:19;rect(x+18,y+22-h,2,h,'#779250');rect(x+11,y+20-h,7,5,'#96ac64');rect(x+20,y+15-h,7,6,'#819f54');if(stage>.33)rect(x+12,y+11-h,7,5,'#adc078');}}
      if(p.tilled){rect(x+3,y+26,3,3,p.soil>=1.75?'#708b4f':p.soil>=.75?'#d2bd81':'#bc8662');}if(p.pest){rect(x+26,y+15,4,2,'#91724f');}if(p.watered){rect(x+32,y+25,3,3,'#a8c7ba');}if(selected===i){ctx.strokeStyle='#fff5c7';ctx.lineWidth=2;ctx.strokeRect(x-1,y-1,40,33);}
    });
  }
  function points(s) {
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
  function obstacles(s) {
    if(s.scene==='farm')return [[99,105,218,98],[608,127,143,74],[707,277,113,75],[603,237,47,58],[99,340,58,47], [868,0,92,437],[868,484,92,92]];
    if(s.scene==='town')return [[120,140,218,106],[568,127,239,119],[463,437,169,90],[590,299,165,63],[356,220,43,48]];
    if(s.scene==='river')return [[0,236,411,238],[534,236,426,238]];
    return [];
  }
  function blocked(s,x,y) {return x<16||x>944||y<54||y>556||obstacles(s).some(([a,b,w,h])=>x>a-5&&x<a+w+5&&y>b-2&&y<b+h+3);}
  function route(s,x,y) {
    const step=16,cols=60,rows=36,sx=Math.floor(s.player.x/step),sy=Math.floor(s.player.y/step),tx=Math.floor(x/step),ty=Math.floor(y/step);
    if(blocked(s,x,y))return [];
    const start=sy*cols+sx,goal=ty*cols+tx,queue=[start],prev=new Map([[start,null]]);let found=false;
    for(let q=0;q<queue.length;q++){const cur=queue[q];if(cur===goal){found=true;break;}const cx=cur%cols,cy=Math.floor(cur/cols);for(const [dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const nx=cx+dx,ny=cy+dy,n=ny*cols+nx;if(nx<1||ny<3||nx>=cols-1||ny>=rows-1||prev.has(n)||blocked(s,nx*step+8,ny*step+8))continue;prev.set(n,cur);queue.push(n);}}
    if(!found)return [];const result=[{x,y}];let cur=goal;while(cur!==start){result.push({x:(cur%cols)*step+8,y:Math.floor(cur/cols)*step+8});cur=prev.get(cur);}return result.reverse();
  }
  let cache=null,cacheKey='';
  function draw(canvas,s,t,hover,walking,effect) {
    ctx=canvas.getContext('2d');ctx.imageSmoothingEnabled=false;P=palettes[C.calendar(s).season];
    const key=s.scene+'-'+C.calendar(s).season+'-'+JSON.stringify(s.upgrades)+'-'+s.flags.bridge;
    if(cacheKey!==key){cache=document.createElement('canvas');cache.width=W;cache.height=H;const previous=ctx;ctx=cache.getContext('2d');base(s);ctx=previous;cacheKey=key;}
    ctx.drawImage(cache,0,0);additions(s,t);
    if(s.scene==='farm'){
      plots(s,t,hover?.kind==='plot'?hover.index:-1);
      s.animals.forEach((a,i)=>animal(a,706+i*50,389+(i%2)*23,t));
      // A curl of cooking smoke rising above the old kitchen.
      for(let i=0;i<4;i++){const f=(t*.35+i*.25)%1;rect(663+Math.sin(t+i)*5,104-f*48,6+f*6,5+f*5,'#efecd147');}
    }
    const pts=points(s);
    pts.filter(p=>p.kind==='gather'&&s.collected[p.id]!==s.day).forEach(p=>{shadow(p.x-14,p.y-2,32,9);item(ctx,p.item,p.x-16,p.y-29,1);});
    pts.filter(p=>p.kind==='travel').forEach(p=>{rect(p.x-8,p.y-15,17,17,'#eff0d398');ctx.fillStyle='#70875b';ctx.font='15px sans-serif';ctx.textAlign='center';ctx.fillText('›',p.x,p.y-2);});
    const people=pts.filter(p=>p.kind==='npc').map(p=>({...p,player:false}));people.push({...s.player,player:true});people.sort((a,b)=>a.y-b.y).forEach(p=>{const look=p.player?s.appearance:p.npc.appearance;const npcWalk=!p.player&&Math.floor(t+p.x)%13<2;character(ctx,p.x+(npcWalk?Math.sin(t*3)*5:0),p.y,p.player?['#829773','#768fa7','#ad8070','#b4a579'][s.appearance.shirt]:p.npc.color,t,p.player?walking:npcWalk,p.player?s.appearance.hat:look.hat,p.player?s.player.direction:['down','left','up','right'][Math.floor(t/9+p.x)%4],look);if(!p.player){label(p.x,p.y-36,p.npc.name);if(s.relations[p.id].talked!==s.day){rect(p.x+12,p.y-31,5,5,'#fff2bf');}}});
    if(hover&&hover.kind!=='plot'){ctx.strokeStyle='#ffefb3';ctx.lineWidth=2;ctx.strokeRect(hover.x-18,hover.y-34,36,39);}
    if(effect&&t-effect.t<.7){const k=(t-effect.t)/.7;for(let i=0;i<6;i++)rect(effect.x+Math.cos(i)*k*24,effect.y-10+Math.sin(i)*k*20-k*14,3,3,effect.color||'#f5e6a1');}
    if(s.minutes>1020){const alpha=Math.min(.27,(s.minutes-1020)/1000);rect(0,0,W,H,`rgba(42,62,83,${alpha})`);}
    if(['雨','台风'].includes(C.weather(s.day))){for(let i=0;i<90;i++){const x=(i*127+t*27)%960,y=(i*89+t*190)%576;rect(x,y,1,8,'#dae5c759');}rect(0,0,W,H,'#78939516');}
    if(C.weather(s.day)==='雾'){for(let i=0;i<5;i++)rect((t*8+i*227)%1200-240,i*110+60,350,36,'#eff1d126');}
    if(['小雪','寒潮'].includes(C.weather(s.day)))for(let i=0;i<48;i++)rect((i*137+t*9)%960,(i*73+t*18)%576,2,2,'#eef2deaa');
    // Small drifting petals and river glints keep quiet scenes alive.
    if(C.calendar(s).season===0)for(let i=0;i<9;i++){const x=(i*117+t*10)%960,y=(i*87+t*7)%576;rect(x,y,3,2,'#eddbbfa8');}
    if(s.scene==='river'||s.scene==='farm')for(let i=0;i<9;i++){const x=s.scene==='river'?90+i*97:877+i%3*26,y=s.scene==='river'?280+i%3*58:70+i*46;rect(x+Math.sin(t+i)*5,y,7,1,'#e8ebce70');}
  }
  function furniture(id,x,y){
    if(id==='bench'){bench(x-20,y-8);return;}
    if(id==='pot'){pot(x,y);return;}
    if(id==='path'){rect(x-19,y-4,37,11,'#9ba698');rect(x-17,y-3,15,5,'#c3c7b0');return;}
    if(id==='fence'){fence(x-20,y-12,42);return;}
    if(id==='orchard'){tree(x,y,.43);return;}
    if(id==='trellis'){rect(x-15,y-32,3,34,'#9f956c');rect(x+13,y-32,3,34,'#9f956c');for(let i=0;i<3;i++)rect(x-15,y-30+i*9,31,2,'#beb589');rect(x-11,y-24,11,8,'#7a9b60');return;}
    if(id==='waterbed'){rect(x-22,y-8,44,14,'#8ca798');rect(x-19,y-5,39,9,'#a4c4b4');rect(x-8,y-13,4,12,'#7e9b61');return;}
    if(id==='scarecrow'){rect(x-2,y-29,4,33,'#a1936d');rect(x-17,y-21,34,3,'#a1936d');rect(x-8,y-25,18,17,'#98a684');rect(x-6,y-37,14,12,'#c8b68a');rect(x-12,y-38,25,4,'#b8a677');return;}
    if(id==='greenhouse'){rect(x-23,y-31,46,36,'#b7cbb19c');poly([[x-26,y-31],[x,y-49],[x+26,y-31]],'#d3e1c599');for(let k=-20;k<25;k+=20)rect(x+k,y-30,2,34,'#d6dcb7');rect(x-23,y+3,46,3,'#9baa86');return;}
    rect(x-14,y-26,28,28,'#aa956c');rect(x-11,y-23,22,21,'#dccea7');rect(x-7,y-17,6,13,'#83a080');rect(x+2,y-18,6,14,'#b28874');
  }
  function additions(s,t){
    if(s.scene==='farm'){
      if(s.upgrades.storage){rect(158,283,44,20,'#b89e70');rect(159,284,42,5,'#d9bb89');rect(177,290,5,7,'#7c7c53');}
      if(s.upgrades.yard){for(let x=155;x<236;x+=38){rect(x,298,3,40,'#a4966d');rect(x-8,296,57,3,'#bba97b');for(let j=0;j<4;j++)rect(x+j*10,303,5,15,j%2?'#bfa565':'#8eaa63');}}
      if(s.upgrades.mill){rect(671,242,37,15,'#aaa892');rect(666,239,47,8,'#c4c4ac');rect(687,229,4,17,'#8d8f7b');rect(688,228,27,3,'#b9a379');}
      if(s.upgrades.room){rect(474,197,54,7,'#bea677');rect(481,204,4,12,'#a38c64');rect(519,204,4,12,'#a38c64');rect(490,191,15,6,'#e4d9b2');label(502,184,'家中饭桌');}
      if(s.upgrades.irrigation){rect(657,281,28,39,'#8eaa9c');rect(654,280,34,6,'#b4c6aa');for(let i=0;i<s.waterReserve;i++)rect(661,308-i*8,20,5,'#b4d4c3');}
      if(s.projects.canal){water(578,269,7,158);rect(573,424,20,5,'#b9bda0');}
      s.layouts.forEach(v=>{const p=C.layoutSlots[v.slot];furniture(v.id,p.x,p.y);});
      const x=359+Math.sin(t*.45)*9,y=223;shadow(x-10,y,24,6);rect(x-8,y-12,20,12,s.pet.type==='cat'?'#b7a685':'#b09672');rect(x+5,y-22,13,13,'#cab694');rect(x+7,y-27,4,s.pet.type==='cat'?8:14,'#a99577');rect(x+15,y-26,3,9,'#a99577');rect(x+15,y-17,2,2,'#626950');rect(x-13,y-15+Math.sin(t)*2,9,3,'#ac9978');
      rect(162,254,4,25,'#a38e69');rect(153,250,22,13,'#a57d63');rect(152,247,24,4,'#c49f7b');if(s.letters.some(m=>!s.mailRead.includes(m.id)))rect(170,243,5,7,'#fff0ac');
    }
    if(s.scene==='town'){
      if(s.projects.market){rect(584,288,4,87,'#8f8464');rect(750,288,4,87,'#8f8464');poly([[574,290],[606,257],[738,257],[767,290]],'#adad82');for(let i=0;i<9;i++)rect(588+i*18,280,14,12,i%2?'#e2cc9f':'#bba780');label(671,250,'晴雨都能赶集');}
      if(s.projects.stage){rect(788,358,116,33,'#b7a57c');rect(785,352,122,8,'#d0b68a');rect(792,287,4,68,'#9a8e6c');rect(897,287,4,68,'#9a8e6c');rect(788,279,116,10,'#b58b72');rect(796,289,18,54,'#ba8f7b');rect(882,289,14,54,'#ba8f7b');label(846,266,'禾溪小戏台');}
      if(C.market(s).open){label(225,74,'今日赶集 · 来往皆是邻里');}
      rect(288,256,45,7,'#ac9870');rect(293,263,4,13,'#8e845f');rect(324,263,4,13,'#8e845f');item(ctx,'hoe',301,229,.65);
    }
    if(s.scene==='river'&&s.projects.bridge){for(let i=0;i<3;i++)rect(669+i*11,141,5,5,'#ded9b8');}
    if(s.scene==='bamboo'||s.scene==='mountain'){for(let i=0;i<3;i++){const x=90+i*309+Math.sin(t*.6+i)*20,y=120+i*130;rect(x,y,5,2,'#65795b');rect(x-3,y-2+Math.sin(t*5),4,2,'#849667');rect(x+5,y-2-Math.sin(t*5),4,2,'#849667');}}
  }
  function plotAt(x,y) {const col=Math.floor((x-291)/42),row=Math.floor((y-271)/36);return col>=0&&col<6&&row>=0&&row<4&&x<291+col*42+38&&y<271+row*36+31?row*6+col:-1;}
  function hit(s,x,y) {if(s.scene==='farm'){const index=plotAt(x,y);if(index>=0)return {id:'plot-'+index,kind:'plot',index,x:310+index%6*42,y:291+Math.floor(index/6)*36,name:'菜地'};}return points(s).filter(p=>Math.abs(x-p.x)<30&&y>p.y-40&&y<p.y+18).sort((a,b)=>Math.hypot(x-a.x,y-a.y)-Math.hypot(x-b.x,y-b.y))[0]||null;}
  root.ZRZWorld={draw,item,character,points,hit,blocked,route,plotAt};
})(window);
