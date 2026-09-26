(function(root){
  'use strict';
  // Every mark is drawn on an integer pixel grid; shared silhouettes keep the village coherent.
  const seasons=[
    {grass:'#88a960',light:'#a8bd76',dark:'#77994e',leaf:'#568348',tip:'#9eba69',deep:'#345e3b',earth:'#c8b488',sky:'#b4d5cc'},
    {grass:'#7fa159',light:'#9eb870',dark:'#6c904c',leaf:'#3f784b',tip:'#82ab5a',deep:'#28503d',earth:'#cbb68a',sky:'#aed3d0'},
    {grass:'#a5a161',light:'#bdb378',dark:'#8f914f',leaf:'#9a8847',tip:'#d0af63',deep:'#646b39',earth:'#c4aa7f',sky:'#c5d4c4'},
    {grass:'#a4b6a0',light:'#c3cdb5',dark:'#8b9e8b',leaf:'#698673',tip:'#a1b69b',deep:'#476653',earth:'#c4c1a7',sky:'#bfced0'}
  ];
  const styles={
    granny:{hair:'bun',hairColor:'#d2cbb5',shirt:'#685b89',accent:'#af9977',prop:'basket',skin:'#d8ad84',skirt:true},
    qiao:{hair:'pony',hairColor:'#333d32',shirt:'#447f68',accent:'#dfb85d',prop:'seedbag',skin:'#dfb28e'},
    lin:{hair:'bob',hairColor:'#333642',shirt:'#729bae',accent:'#eae3c5',prop:'book',skin:'#e5ba98',glasses:true,skirt:true},
    chen:{hair:'short',hairColor:'#3f3b32',shirt:'#ad8452',accent:'#374d60',prop:'hammer',skin:'#be926b',apron:true},
    xu:{hair:'bun',hairColor:'#423c35',shirt:'#a75850',accent:'#d1ad79',prop:'basket',skin:'#d8aa82',apron:true},
    zhou:{hair:'short',hairColor:'#363b2e',shirt:'#4b6978',accent:'#adb871',prop:'tea',skin:'#bf946e',hat:true},
    mei:{hair:'braid',hairColor:'#463528',shirt:'#bd875d',accent:'#f0dcb1',prop:'tray',skin:'#e8ba94',apron:true},
    ning:{hair:'bun',hairColor:'#333c35',shirt:'#9a6679',accent:'#e9d4a8',prop:'bowl',skin:'#dbb18c',apron:true},
    an:{hair:'short',hairColor:'#343e40',shirt:'#e2e8d8',accent:'#548f90',prop:'medical',skin:'#d9b397'},
    yu:{hair:'crop',hairColor:'#35413c',shirt:'#537e88',accent:'#b4a465',prop:'net',skin:'#b78b64',vest:true},
    yan:{hair:'wave',hairColor:'#3d3634',shirt:'#d0b986',accent:'#66755e',prop:'camera',skin:'#dbab85',vest:true},
    luo:{hair:'bun',hairColor:'#73756a',shirt:'#776988',accent:'#c8b58a',prop:'seedbag',skin:'#c99d7b'},
    liang:{hair:'short',hairColor:'#a0a396',shirt:'#e5e6d1',accent:'#587785',prop:'medical',skin:'#d4ae8c',glasses:true},
    wu:{hair:'crop',hairColor:'#4c473c',shirt:'#66848b',accent:'#baa271',prop:'wrench',skin:'#b98d68',cap:true},
    jiang:{hair:'bun',hairColor:'#59524b',shirt:'#a65165',accent:'#d8b879',prop:'fan',skin:'#d5a87f',skirt:true},
    zhouSenior:{hair:'short',hairColor:'#c0c0ad',shirt:'#6c8173',accent:'#d0b477',prop:'tea',skin:'#bd9572',hat:true},
    luSenior:{hair:'crop',hairColor:'#a9aa95',shirt:'#8b7956',accent:'#c7bb83',prop:'basket',skin:'#b58c66',vest:true},
    tao:{hair:'pony',hairColor:'#3d3731',shirt:'#4d8b78',accent:'#d7bd87',prop:'mail',skin:'#ddb18b',cap:true},
    he:{hair:'bob',hairColor:'#393d36',shirt:'#aa8052',accent:'#e8d9af',prop:'book',skin:'#d3a98b',glasses:true},
    song:{hair:'crop',hairColor:'#c0bda8',shirt:'#596d82',accent:'#bda27c',prop:'wrench',skin:'#c49b77',vest:true},
    lan:{hair:'pigtail',hairColor:'#3a332e',shirt:'#d59588',accent:'#efdc9c',prop:'book',skin:'#e3b896',child:true,skirt:true},
    bao:{hair:'crop',hairColor:'#3b4031',shirt:'#c9a758',accent:'#4e8590',prop:'pinwheel',skin:'#dcb48c',child:true},
    qi:{hair:'pony',hairColor:'#3c3331',shirt:'#6f8daa',accent:'#eddaa6',prop:'book',skin:'#d1a481',child:true},
    xiaohe:{hair:'wave',hairColor:'#343e38',shirt:'#b18464',accent:'#608578',prop:'wrench',skin:'#bf966f',child:true}
  };
  const R=(c,x,y,w,h,col)=>{c.fillStyle=col;c.fillRect(Math.round(x),Math.round(y),Math.max(1,Math.round(w)),Math.max(1,Math.round(h)));};
  const poly=(c,pts,col)=>{c.fillStyle=col;c.beginPath();pts.forEach(([x,y],i)=>i?c.lineTo(Math.round(x),Math.round(y)):c.moveTo(Math.round(x),Math.round(y)));c.closePath();c.fill();};
  const rand=seed=>{let n=seed>>>0;return()=>{n=(Math.imul(n,1664525)+1013904223)>>>0;return n/4294967296;};};
  function ellipse(c,x,y,rx,ry,col){c.fillStyle=col;c.beginPath();c.ellipse(Math.round(x),Math.round(y),rx,ry,0,0,Math.PI*2);c.fill();}
  function text(c,x,y,t,size=12,col='#f5e9ca'){c.font='600 '+size+'px "Microsoft YaHei",sans-serif';c.textAlign='center';c.fillStyle=col;c.fillText(t,Math.round(x),Math.round(y));}
  function shadow(c,x,y,w=48,h=12){ellipse(c,x+5,y+2,w/2,h/2,'#263e352b');}
  function label(c,x,y,t,small=false){const n=small?10:12;c.font='500 '+n+'px "Microsoft YaHei",sans-serif';const w=c.measureText(t).width+18;R(c,x-w/2,y-14,w,20,'#fff5daee');R(c,x-w/2,y+6,w,1,'#50674070');text(c,x,y,t,n,'#344a39');}
  function roof(c,x,y,w,h=58){
    poly(c,[[x-13,y+h+8],[x+19,y+3],[x+w-20,y+3],[x+w+13,y+h+8]],'#2e4141');
    for(let row=0;row<Math.floor(h/7);row++){
      const yy=y+7+row*7,inset=Math.round(17-row*3.4),left=x+inset,right=x+w-inset;
      R(c,left,yy,right-left,7,row%2?'#657c7b':'#708786');
      for(let tx=left+(row%2)*6;tx<right-4;tx+=12){R(c,tx,yy+1,3,5,'#8da09a');R(c,tx+7,yy+2,2,5,'#425e61');R(c,tx,yy+6,10,1,'#344e53');}
    }
    R(c,x-13,y+h+3,w+26,4,'#273e40');R(c,x-14,y+h+1,w+28,2,'#94a79b');
    R(c,x+15,y-1,w-30,5,'#3c5457');R(c,x+14,y-3,w-28,2,'#abb8a7');
    R(c,x-17,y+h-1,9,4,'#526e70');R(c,x+w+8,y+h-1,9,4,'#526e70');
  }
  function windowFrame(c,x,y,w=31,h=33,light=false){
    R(c,x-2,y-2,w+4,h+4,'#c4b698');R(c,x,y,w,h,'#344d50');R(c,x+3,y+3,w-6,h-6,light?'#e8bd6d':'#95b8b0');
    R(c,x+4,y+4,w/2-5,h/2-4,light?'#ffdc92':'#c9d8c9');R(c,x+w/2-1,y+2,3,h-3,'#57695e');R(c,x+2,y+h/2,w-4,3,'#57695e');R(c,x-4,y+h+1,w+8,4,'#7e8b7b');
  }
  function house(c,p,season=0){
    const {x,y,w=220,h=140,kind='home',name=''}=p,base=y+h,rh=Math.min(58,h*.43),wallY=y+rh+4;
    shadow(c,x+w/2,base+7,w+32,28);R(c,x+8,wallY,w-16,h-rh,'#ebe3cb');R(c,x+w-28,wallY,20,h-rh,'#c6c9b4');R(c,x+8,base-16,w-16,17,'#7f9187');
    for(let row=0;row<3;row++)for(let j=0;j<w/21-1;j++){R(c,x+10+j*21+(row%2)*7,base-14+row*5,17,1,'#acb6a0');}
    if(kind==='brick'){R(c,x+8,wallY,w-16,h-rh-16,'#b67e62');for(let yy=wallY+7;yy<base-16;yy+=9)for(let xx=x+9;xx<x+w-12;xx+=24){R(c,xx,yy,22,1,'#d1aa85');R(c,xx+12,yy-8,1,7,'#8f6654');}}
    roof(c,x,y,w,rh);
    const dx=x+w*.54,doorH=Math.min(58,h-rh-8);R(c,dx-20,base-doorH-3,40,doorH+3,'#c0a380');R(c,dx-16,base-doorH,32,doorH,'#473e31');R(c,dx-13,base-doorH+3,12,doorH-3,'#816348');R(c,dx+2,base-doorH+3,11,doorH-3,'#694e3b');R(c,dx-1,base-doorH,2,doorH,'#372f26');
    for(let yy=base-doorH+10;yy<base-5;yy+=10){R(c,dx-10,yy,7,1,'#af8b60');R(c,dx+4,yy,6,1,'#8f7153');}R(c,dx-5,base-22,2,3,'#ccb367');R(c,dx+4,base-22,2,3,'#ccb367');
    R(c,dx-25,base-doorH,5,doorH-1,'#b4583e');R(c,dx+21,base-doorH,5,doorH-1,'#b4583e');for(let yy=base-doorH+5;yy<base-5;yy+=9){R(c,dx-24,yy,3,3,'#e1bf73');R(c,dx+22,yy,3,3,'#e1bf73');}
    R(c,dx-24,base-doorH-7,50,5,'#b75c41');R(c,dx-25,base+1,52,5,'#a6af9e');R(c,dx-30,base+6,62,5,'#c3c8ad');
    const windowY=wallY+12;if(w>190){windowFrame(c,x+28,windowY,33,32);windowFrame(c,x+w-65,windowY,29,32);}else windowFrame(c,x+22,windowY,29,30);
    R(c,x+15,base-5,17,3,season===3?'#d3dcce':'#6a8d60');R(c,x+w-44,base-4,21,3,'#7f9971');
    if(kind==='home'){R(c,x+w-48,wallY+15,29,18,'#d8dcd0');for(let i=0;i<5;i++)R(c,x+w-44,wallY+19+i*2,20,1,'#9aa9a0');R(c,x+30,y+2,40,7,'#ccd5cd');for(let i=0;i<6;i++)R(c,x+31+i*6,y+10,3,16,'#577f89');}
    if(name){R(c,dx-39,wallY-2,78,19,'#614d36');R(c,dx-37,wallY,74,15,'#876846');text(c,dx,wallY+12,name,w<190?10:11,'#f5e2b4');}
    if(kind==='clinic'){R(c,x+25,wallY+10,29,28,'#f0e6cb');R(c,x+37,wallY+14,5,19,'#b95d49');R(c,x+30,wallY+21,19,5,'#b95d49');}
    if(kind==='shop'){R(c,x+20,base-34,5,39,'#755d43');R(c,x+w-26,base-34,5,39,'#755d43');for(let i=0;i<Math.floor((w-24)/17);i++){R(c,x+11+i*17,base-45,17,19,i%2?'#719079':'#e1ce9b');R(c,x+11+i*17,base-28,17,4,i%2?'#496c59':'#c2ad79');}for(let i=0;i<3;i++)basket(c,x+30+i*30,base+10,i%2?'greens':'tomato');}
    if(kind==='kitchen'){R(c,x+w-29,y-11,16,26,'#8e9990');R(c,x+w-32,y-14,22,5,'#c1c4ab');jar(c,x+w+12,base-2);jar(c,x+w+30,base,0.7);}
    if(season===3){R(c,x+15,y,Math.max(4,w-28),2,'#e4e6d2');R(c,x-5,y+rh,w+10,2,'#d5ddcc');}
  }
  function tree(c,p,season=0){
    const P=seasons[season],{x,y,size=1,kind='tree',seed=1}=p,r=rand(seed);c.save();c.translate(x,y);c.scale(size,size);shadow(c,0,0,77,19);
    R(c,-7,-43,13,47,'#66513a');R(c,-3,-42,5,45,'#9d8255');R(c,3,-33,2,30,'#b19969');poly(c,[[-2,-28],[-20,-49],[-14,-52],[5,-32]],'#70563a');
    const bloom=kind==='blossom'&&season===0,col=bloom?['#ae7466','#d9a491','#f4cab2']:[P.deep,P.leaf,P.tip];
    const lobes=[[-21,-56,22,20],[4,-74,27,22],[28,-55,23,22],[4,-48,35,23],[-2,-91,18,12]];
    for(const [a,b,w,h]of lobes){poly(c,[[a-w,b-h+6],[a-w+8,b-h],[a+w-8,b-h],[a+w,b-h+8],[a+w,b+h-6],[a+w-7,b+h],[a-w+7,b+h],[a-w,b+h-8]],col[0]);R(c,a-w+5,b-h+5,w*2-12,h*2-12,col[1]);}
    for(let i=0;i<100;i++){const a=-40+r()*82,b=-98+r()*59;if(((a/43)**2+((b+67)/33)**2)<1)R(c,a,b,3+r()*8,2+r()*4,i%3?col[2]:col[0]);}
    if(kind==='orchard'&&season!==3)for(let i=0;i<9;i++){let a=-29+r()*58,b=-84+r()*42;R(c,a,b,5,5,season===2?'#de993e':'#a7b85e');R(c,a+1,b,2,2,'#f1d28b');}
    if(kind==='willow')for(let i=0;i<8;i++){let a=-32+i*9;for(let k=0;k<6;k++)R(c,a+Math.sin(k+i)*4,-56+k*7,2,7,k%2?P.leaf:P.tip);}
    if(season===3){R(c,-18,-94,29,3,'#e3e7d8');R(c,-37,-62,20,2,'#dce1cf');}c.restore();
  }
  function bamboo(c,p,season=0){const {x,y,size=1}=p;const P=seasons[season];c.save();c.translate(x,y);c.scale(size,size);shadow(c,0,0,50,11);for(let i=0;i<5;i++){const dx=-23+i*11,h=88+(i%3)*17;R(c,dx,-h,4,h,'#386b4b');R(c,dx+1,-h,1,h,'#9fbf70');for(let j=13;j<h;j+=17){R(c,dx-1,-j,6,2,'#c6d295');poly(c,[[dx,-j-4],[dx-22,-j-15],[dx-8,-j-7]],P.leaf);poly(c,[[dx+3,-j-9],[dx+24,-j-29],[dx+11,-j-11]],P.tip);}}c.restore();}
  function basket(c,x,y,fill='grain'){shadow(c,x,y,26,7);poly(c,[[x-15,y-13],[x+15,y-13],[x+12,y+1],[x-11,y+1]],'#a47840');R(c,x-13,y-12,27,3,'#ddbf7b');for(let i=0;i<4;i++){R(c,x-11,y-7+i*2,23,1,'#c69c59');R(c,x-8+i*6,y-10,1,11,'#775b36');}const col=fill==='greens'?'#699754':fill==='tomato'?'#c56843':'#dfbe66';for(let i=0;i<5;i++)R(c,x-11+i*5,y-15-i%2*2,5,5,col);}
  function jar(c,x,y,scale=1){c.save();c.translate(x,y);c.scale(scale,scale);shadow(c,0,0,26,8);poly(c,[[-9,-27],[9,-27],[13,-18],[12,-3],[7,1],[-7,1],[-12,-3],[-13,-18]],'#79523e');R(c,-9,-24,16,20,'#a2734d');R(c,-6,-22,3,16,'#c99d6b');R(c,-10,-30,20,5,'#554c39');R(c,-8,-31,16,2,'#b49a64');R(c,-4,-14,9,7,'#e0c694');R(c,-1,-12,3,3,'#9d4938');c.restore();}
  function prop(c,p,season=0){const {x,y,kind,w=90,h=20}=p,P=seasons[season];
    if(kind==='haystack'){shadow(c,x,y,79,16);poly(c,[[x-41,y],[x-36,y-34],[x-19,y-56],[x+13,y-62],[x+32,y-39],[x+40,y]],'#947438');poly(c,[[x-35,y-5],[x-28,y-34],[x-12,y-52],[x+11,y-53],[x+29,y-30],[x+33,y-5]],'#cead60');for(let j=0;j<16;j++)R(c,x-28+j*4,y-10-(j%4)*9,2,14,'#ead086');R(c,x-33,y-22,65,3,'#998344');R(c,x-29,y-20,60,1,'#e0c178');return;}
    if(kind==='cart'){shadow(c,x,y,78,18);for(let a of [-25,25]){ellipse(c,x+a,y+2,12,12,'#49564d');ellipse(c,x+a,y+2,7,7,'#a9b29c');R(c,x+a-1,y-6,2,16,'#647565');R(c,x+a-8,y+1,16,2,'#647565');}poly(c,[[x-40,y-33],[x+32,y-33],[x+26,y-6],[x-31,y-6]],'#748a74');R(c,x-37,y-32,67,4,'#bac4a1');R(c,x-32,y-26,57,13,'#91a087');for(let j=0;j<5;j++){R(c,x-27+j*10,y-42,8,15,j%2?'#bda45d':'#d6bd7c');R(c,x-24+j*10,y-43,2,13,'#e1ce97');}R(c,x+26,y-27,28,4,'#796240');R(c,x+48,y-26,5,11,'#ac8b50');return;}
    if(kind==='scarecrow'){shadow(c,x,y,44,10);R(c,x-2,y-53,5,57,'#8f7042');R(c,x-28,y-47,58,4,'#b79b60');poly(c,[[x-15,y-49],[x+14,y-49],[x+21,y-15],[x-19,y-15]],'#638475');R(c,x-10,y-45,20,4,'#9fb398');R(c,x-2,y-43,3,25,'#c9bb88');R(c,x-8,y-28,6,6,'#b98963');R(c,x-9,y-67,19,18,'#d8bc7f');R(c,x-6,y-61,3,2,'#584e38');R(c,x+4,y-61,3,2,'#584e38');R(c,x-3,y-54,7,1,'#8f6546');R(c,x-19,y-69,39,5,'#b5934d');R(c,x-11,y-79,24,10,'#d2b169');R(c,x-13,y-70,27,2,'#82673b');for(let j=0;j<4;j++){R(c,x-19+j*3,y-15,2,10,'#d7b66d');R(c,x+8+j*3,y-15,2,10,'#d7b66d');}return;}
    if(kind==='flowers'){const r=rand(x*19+y);for(let i=0;i<14;i++){const xx=x-23+r()*50,yy=y-17+r()*22;R(c,xx,yy,1,6,'#4f7845');R(c,xx-2,yy-2,5,3,season===0?'#e8c873':season===2?'#d79f69':'#e5dcc0');R(c,xx,yy-2,1,2,'#b58a48');}return;}
    if(kind==='shrub'){shadow(c,x,y,44,10);poly(c,[[x-23,y-5],[x-22,y-15],[x-14,y-23],[x+12,y-24],[x+24,y-12],[x+21,y]],P.deep);R(c,x-16,y-19,31,14,P.leaf);for(let i=0;i<10;i++)R(c,x-19+(i*11)%36,y-20+(i*7)%17,7,3,i%3?P.tip:P.leaf);return;}
    if(['tree','blossom','orchard','willow'].includes(kind)){tree(c,p,season);return;}if(kind==='bamboo'){bamboo(c,p,season);return;}
    if(kind==='house'){house(c,{...p,kind:p.style},season);return;}
    if(kind==='fence'){R(c,x,y-17,w,4,'#ab8b57');R(c,x,y-7,w,3,'#88663e');for(let a=0;a<w;a+=22){R(c,x+a,y-24,5,30,'#75563a');R(c,x+a,y-24,3,28,'#c2a06b');}return;}
    if(kind==='wall'){R(c,x,y-h,w,h,'#d8d7c0');R(c,x,y-h-4,w,6,'#566f70');for(let a=0;a<w;a+=13)R(c,x+a,y-h-4,2,5,'#9baca0');R(c,x,y-5,w,5,'#869882');return;}
    if(kind==='bench'){shadow(c,x+25,y+4,60,13);R(c,x,y-6,54,8,'#b18a51');R(c,x+1,y-5,52,2,'#dec191');R(c,x+5,y+2,5,12,'#715639');R(c,x+44,y+2,5,12,'#715639');R(c,x+3,y-25,48,5,'#9b7446');R(c,x+6,y-22,3,19,'#796042');R(c,x+45,y-22,3,19,'#796042');return;}
    if(kind==='jar'){jar(c,x,y,p.size);return;}if(kind==='basket'){basket(c,x,y,p.fill);return;}
    if(kind==='pot'){R(c,x-7,y-12,14,14,'#ae6f48');R(c,x-9,y-14,18,4,'#d19a65');R(c,x-4,y-26,3,15,'#587d41');for(let i=0;i<6;i++)R(c,x-12+i*4,y-25+(i%2)*5,8,5,i%2?P.tip:P.leaf);R(c,x-3,y-28,4,4,'#dcbd62');return;}
    if(kind==='well'){shadow(c,x,y,56,18);ellipse(c,x,y-9,23,13,'#788d83');R(c,x-23,y-19,46,13,'#8e9e92');ellipse(c,x,y-20,25,12,'#b6bdab');ellipse(c,x,y-21,17,7,'#334f50');R(c,x-29,y-64,5,52,'#795b3a');R(c,x+24,y-64,5,52,'#795b3a');R(c,x-33,y-66,66,6,'#bb995d');R(c,x,y-63,2,37,'#d4bd78');R(c,x-5,y-44,13,4,'#7e6946');return;}
    if(kind==='board'){R(c,x-25,y-51,50,37,'#987747');R(c,x-22,y-48,44,29,'#eee2b8');for(let i=0;i<4;i++)R(c,x-17,y-44+i*6,22+i%2*12,2,'#9b9c7d');R(c,x-20,y-14,4,18,'#795c3c');R(c,x+17,y-14,4,18,'#795c3c');return;}
    if(kind==='mailbox'){R(c,x-3,y-26,6,30,'#775d40');R(c,x-15,y-46,29,23,'#6a8973');R(c,x-13,y-47,26,3,'#adbaa0');R(c,x-10,y-38,18,2,'#354e43');R(c,x-7,y-33,12,6,'#ecdbb0');return;}
    if(kind==='drying'){for(let i=0;i<3;i++){ellipse(c,x+i*34,y-2,16,11,'#8f7547');ellipse(c,x+i*34,y-3,13,8,'#d7bd78');for(let j=0;j<12;j++)R(c,x+i*34-9+j%4*5,y-7+Math.floor(j/4)*4,3,2,i===0?'#b54833':i===1?'#dba144':'#edcf78');}return;}
    if(kind==='laundry'){R(c,x,y-59,4,64,'#977b4e');R(c,x+100,y-59,4,64,'#977b4e');R(c,x,y-54,100,1,'#5f6b58');for(let i=0;i<4;i++){const col=['#dbe0c3','#7f9e9f','#b69b7f','#79957a'][i];poly(c,[[x+9+i*23,y-51],[x+26+i*23,y-51],[x+29+i*23,y-39],[x+24+i*23,y-37],[x+23+i*23,y-18],[x+12+i*23,y-18],[x+11+i*23,y-37],[x+7+i*23,y-39]],col);R(c,x+17+i*23,y-54,2,5,'#b99559');}return;}
    if(kind==='bike'){c.strokeStyle='#425d56';c.lineWidth=2;for(let dx of [0,29]){c.beginPath();c.arc(x+dx,y-5,10,0,7);c.stroke();}c.beginPath();c.moveTo(x,y-5);c.lineTo(x+12,y-21);c.lineTo(x+20,y-5);c.closePath();c.moveTo(x+29,y-5);c.lineTo(x+24,y-28);c.stroke();R(c,x+6,y-25,12,3,'#775238');R(c,x+22,y-30,11,2,'#414c43');basket(c,x+29,y-22,'grain');return;}
    if(kind==='table'){R(c,x-28,y-15,57,7,'#9e7347');R(c,x-23,y-8,5,20,'#735537');R(c,x+19,y-8,5,20,'#735537');R(c,x-27,y-15,55,2,'#c99e61');ellipse(c,x,y-17,10,5,'#e3d9b5');R(c,x-4,y-22,8,5,'#76907c');R(c,x+17,y-24,8,8,'#d7dbbe');return;}
    if(kind==='mill'){ellipse(c,x,y-5,29,14,'#778779');R(c,x-26,y-19,52,15,'#9aab9d');ellipse(c,x,y-19,29,13,'#bec5ae');ellipse(c,x,y-25,22,10,'#899b90');for(let i=0;i<8;i++)R(c,x-17+i*5,y-28,2,7,'#bfc7ae');R(c,x-1,y-39,5,18,'#715f43');R(c,x+2,y-40,32,4,'#ac8854');return;}
    if(kind==='boat'){poly(c,[[x-55,y-12],[x-34,y+10],[x+30,y+10],[x+61,y-13]],'#695a3b');poly(c,[[x-43,y-11],[x-29,y+5],[x+26,y+5],[x+47,y-10]],'#af8e57');for(let i=0;i<5;i++)R(c,x-25+i*13,y-9,4,15,'#d0ae70');R(c,x-11,y-27,35,16,'#8b7952');R(c,x-14,y-28,42,4,'#bfaa75');return;}
    if(kind==='pavilion'){const ww=p.w||135;shadow(c,x+ww/2,y,ww+15,25);R(c,x,y-4,ww,9,'#7f9181');R(c,x+6,y-12,ww-12,9,'#c6c5a7');R(c,x+14,y-87,6,75,'#735737');R(c,x+ww-22,y-87,6,75,'#735737');R(c,x+20,y-39,ww-40,4,'#a08350');roof(c,x-5,y-132,ww+10,46);return;}
    if(kind==='rack'){R(c,x,y-51,4,58,'#a58953');R(c,x+70,y-51,4,58,'#a58953');R(c,x-5,y-51,84,5,'#cfb782');for(let i=0;i<5;i++){R(c,x+7+i*13,y-46,2,20,'#e2c89a');R(c,x+4+i*13,y-38,7,18,i%2?'#c0994e':'#816b4c');}return;}
    if(kind==='gate'){R(c,x,y-83,11,83,'#a39e7f');R(c,x+w-11,y-83,11,83,'#a39e7f');roof(c,x-8,y-115,w+16,32);R(c,x+22,y-76,w-44,24,'#695538');text(c,x+w/2,y-59,p.name||'禾溪人家',13);return;}
    if(kind==='stone'){poly(c,[[x-19,y],[x-24,y-15],[x-9,y-28],[x+17,y-24],[x+24,y-3]],'#83948b');poly(c,[[x-18,y-16],[x-7,y-25],[x+15,y-22],[x+8,y-8]],'#b5bfad');return;}
    // Storage chests, planters and garden furniture have their own visible construction.
    R(c,x-22,y-26,44,27,'#9b794b');R(c,x-24,y-31,48,7,'#c5a165');for(let i=0;i<4;i++)R(c,x-19+i*10,y-23,1,24,'#c19a61');R(c,x-24,y-27,48,2,'#755838');R(c,x-3,y-17,7,7,'#dac282');
  }
  function look(color,hat,appearance={}){return appearance.id&&styles[appearance.id]?styles[appearance.id]:{shirt:color,accent:['#dfc18d','#d8c8a1','#ecc6a7','#e2dabb'][appearance.shirt||0],skin:['#e3b991','#c69b74','#a87e5d'][appearance.skin||0],hair:['short','bob','bun','wave'][appearance.hair||0],hairColor:'#394337',hat};}
  function hair(c,a,x,y,w,h,back=false){const col=a.hairColor;R(c,x-1,y,w+2,4,col);R(c,x,y-2,w,4,col);R(c,x-2,y+3,3,h*.65,col);R(c,x+w-1,y+3,3,h*.62,col);if(back)R(c,x,y,w,h-2,col);if(['bob','braid','pony'].includes(a.hair)){R(c,x-3,y+4,4,h+3,col);R(c,x+w-1,y+3,4,h+3,col);}if(a.hair==='bun')R(c,x+w-4,y-6,7,6,col);if(a.hair==='pony')R(c,x+w,y,5,h+7,col);if(a.hair==='pigtail'){R(c,x-6,y+4,5,10,col);R(c,x+w+1,y+4,5,10,col);R(c,x-6,y+4,5,2,'#c97165');R(c,x+w+1,y+4,5,2,'#c97165');}if(a.hair==='wave'){R(c,x-2,y-2,5,6,col);R(c,x+4,y-3,5,6,col);R(c,x+w-6,y-1,7,6,col);}R(c,x+2,y+1,Math.max(3,w-6),1,'#ffffff20');}
  function accessory(c,a,x,y,scale=1){c.save();c.translate(x,y);c.scale(scale,scale);const k=a.prop;
    if(['book','mail','seedbag','medical'].includes(k)){R(c,-5,-8,10,14,k==='book'?'#e0c486':k==='mail'?'#dde1bd':k==='medical'?'#f1ecda':'#b89859');R(c,-4,-6,2,10,k==='book'?'#847249':'#79917b');R(c,-1,-4,4,2,'#fff1c4');if(k==='medical'){R(c,-1,-3,2,7,'#7caaa0');R(c,-3,-1,6,2,'#7caaa0');}}
    if(k==='camera'){R(c,-7,-6,14,9,'#374950');R(c,-3,-8,6,3,'#596971');R(c,-3,-5,7,7,'#b1bdb1');R(c,-1,-3,3,3,'#34484c');}
    if(k==='hammer'||k==='wrench'){R(c,-1,-9,2,21,'#ab8150');R(c,-5,-10,10,5,k==='hammer'?'#586e70':'#849b9b');if(k==='wrench')R(c,-2,-10,4,3,'#cfba8b');}
    if(k==='basket'||k==='tea'){R(c,-7,-6,14,12,'#b69559');for(let i=0;i<3;i++)R(c,-6,-4+i*3,12,1,'#ddc584');R(c,-5,-10,10,2,'#a98c52');if(k==='tea')R(c,-4,-9,7,4,'#64975e');}
    if(k==='net'){R(c,0,-12,2,27,'#a08958');c.strokeStyle='#b9ccb2';c.lineWidth=1;c.strokeRect(-6,-13,14,12);for(let i=0;i<3;i++)R(c,-4+i*4,-12,1,10,'#d1d9b6');}
    if(k==='tray'||k==='bowl'){R(c,-8,-2,17,4,'#ddd8b8');for(let i=0;i<3;i++)R(c,-6+i*5,-6,4,4,k==='bowl'?'#96a16a':'#f1dfaf');}
    if(k==='fan'){poly(c,[[-9,-6],[0,-12],[10,-5],[1,4]],'#d9c695');R(c,0,1,2,9,'#a28756');}
    if(k==='pinwheel'){R(c,0,-6,1,20,'#a38452');poly(c,[[0,-5],[-7,-12],[-7,-3],[0,-5],[7,-12],[6,-3],[0,-5],[7,3],[-1,2],[0,-5],[-7,3],[-7,-3]],'#d09559');R(c,0,-5,2,2,'#f3d499');}c.restore();
  }
  function character(c,x,y,color='#648974',t=0,walking=false,hat=false,direction='down',appearance={}){
    const a=look(color,hat,appearance),child=a.child?.86:1; c.save();c.translate(Math.round(x),Math.round(y));c.scale(child,child);shadow(c,0,0,22,7);const step=walking?Math.round(Math.sin(t*13)*2):0,side=direction==='left'||direction==='right',off=direction==='left'?-2:direction==='right'?2:0;
    R(c,-6,-7+step,5,8,'#3e5050');R(c,2,-7-step,5,8,'#3e5050');R(c,-7,0+step,7,3,'#303e39');R(c,2,0-step,7,3,'#303e39');R(c,-7,0+step,5,1,'#a2a58b');
    poly(c,[[-7,-19],[7,-19],[9,-7],[-9,-7]],'#344b43');R(c,-6,-19,13,13,a.shirt);R(c,-5,-18,4,11,'#ffffff12');R(c,-9,-17-step,3,9,a.shirt);R(c,8,-17+step,3,9,a.shirt);R(c,-9,-9-step,3,4,a.skin);R(c,8,-9+step,3,4,a.skin);R(c,-3,-20,6,3,a.skin);
    if(a.skirt)poly(c,[[-6,-10],[6,-10],[9,-4],[-9,-4]],a.shirt);if(a.apron){R(c,-4,-15,9,10,a.accent);R(c,-5,-9,10,2,'#fff4d338');}else if(a.vest){R(c,-6,-18,4,11,a.accent);R(c,3,-18,4,11,a.accent);}else{R(c,0,-15,1,8,a.accent);R(c,-4,-17,8,2,a.accent);}
    if(direction==='up'&&a.prop){accessory(c,a,0,-11,.75);}
    R(c,-6,-29,13,12,'#5b4b38');R(c,-5,-28,11,11,a.skin);R(c,-5,-28,3,7,'#f5d9aa33');hair(c,a,-6,-31,13,12,direction==='up');
    if(direction!=='up'){R(c,-3+off,-24,2,2,'#29372e');if(!side)R(c,3,-24,2,2,'#29372e');R(c,1+off,-20,2,1,'#b07356');if(a.glasses){c.strokeStyle='#514c3e';c.lineWidth=1;c.strokeRect(-5,-26,5,4);c.strokeRect(2,-26,5,4);R(c,0,-25,2,1,'#514c3e');}}
    if(a.hat){R(c,-11,-31,23,3,'#b98f4b');R(c,-7,-36,15,5,'#dabe77');R(c,-6,-36,12,1,'#ebd597');R(c,-7,-32,15,2,'#8d6e3e');}if(a.cap){R(c,-7,-32,15,4,a.accent);R(c,-3+off,-29,12,2,a.accent);}
    if(direction!=='up')accessory(c,a,side?(off<0?-9:10):8,-8,.65);c.restore();
  }
  function portrait(c,w,h,n,appearance){
    const a=look(n?.color||'#648974',appearance?.hat,appearance||{id:n?.id});c.save();c.imageSmoothingEnabled=false;c.clearRect(0,0,w,h);c.scale(w/64,h/80);
    R(c,0,0,64,80,'#e5dfc4');R(c,3,3,58,74,'#ccd7bc');poly(c,[[3,55],[25,29],[41,43],[61,26],[61,77],[3,77]],'#b1c5a4');R(c,7,9,2,38,'#93aa84');R(c,9,16,9,2,'#93aa84');R(c,9,31,7,2,'#93aa84');
    shadow(c,32,77,44,9);poly(c,[[13,79],[14,59],[25,51],[40,51],[51,60],[53,79]],'#344a42');poly(c,[[16,79],[17,60],[27,53],[38,53],[48,61],[50,79]],a.shirt);R(c,27,48,11,11,a.skin);poly(c,[[22,56],[27,52],[32,60],[37,52],[44,57],[37,65],[31,60],[25,65]],a.accent);
    R(c,22,20,24,29,'#514333');R(c,23,22,22,27,a.skin);R(c,20,31,3,9,a.skin);R(c,45,31,3,9,a.skin);R(c,24,25,3,16,'#ffe6b72b');R(c,42,30,2,17,'#a36f512a');R(c,27,33,4,3,'#394032');R(c,38,33,4,3,'#394032');R(c,28,33,1,1,'#f2e4c8');R(c,39,33,1,1,'#f2e4c8');R(c,33,37,2,4,'#bc8564');R(c,31,44,7,1,'#ab6c54');R(c,25,39,4,2,'#d18b7035');R(c,40,39,4,2,'#d18b7035');hair(c,a,22,18,23,22);
    if(a.glasses){c.strokeStyle='#4f4e41';c.lineWidth=1;c.strokeRect(25,31,8,6);c.strokeRect(36,31,8,6);R(c,33,33,3,1,'#4f4e41');}
    if(a.hat){R(c,12,20,43,4,'#b5904c');R(c,18,10,31,10,'#d5b46e');R(c,20,9,25,3,'#e7cd8b');R(c,18,18,31,3,'#876f3e');}if(a.cap){R(c,20,16,28,7,a.accent);R(c,28,22,24,3,a.accent);}
    if(a.apron)R(c,24,64,19,16,a.accent);if(a.vest){R(c,18,61,9,19,a.accent);R(c,39,61,9,19,a.accent);}accessory(c,a,43,71,1.1);R(c,0,0,64,2,'#a6b493');R(c,0,78,64,2,'#a6b493');c.restore();
  }
  const api={seasons,styles,R,poly,rand,ellipse,text,shadow,label,roof,house,tree,bamboo,basket,jar,prop,character,portrait};root.ZRZArt=api;if(typeof module!=='undefined')module.exports=api;
})(typeof globalThis!=='undefined'?globalThis:window);
