(function(root){
'use strict';
const A=root.ZRZArt,C=root.ZRZCore,D=root.ZRZData,R=A.R,P=A.poly;
const outfits={field:'盘扣便衣',apron:'田间围裙',traveler:'行路马甲',festival:'节庆绣衣'};
const hairColors=['#394337','#674c3b','#80634a','#a6a79a'],hairNames=['墨黑','栗棕','茶褐','银灰'];
const defaults={outfit:'field',hairColor:0,bag:false,weatherDress:true};
const shapes={granny:[.97,.95],chen:[1.12,1],yu:[1.04,1.04],an:[.96,1.05],lin:[.96,1.03],zhouSenior:[1.02,.96],luSenior:[1.04,.94],song:[1.08,.96],lan:[.88,.79],bao:[.92,.81],qi:[.84,.86],xiaohe:[.91,.87]};
const directions=['down','left','up','right'];
function extras(a={}){const out={};for(const[k,v]of Object.entries(defaults)){const x=a[k]===undefined?v:a[k];if(k==='outfit'?!Object.hasOwn(outfits,x):k==='hairColor'?!Number.isInteger(x)||x<0||x>=hairColors.length:typeof x!=='boolean')throw Error('角色外观数据无效，请使用存档备份。');out[k]=x;}return out;}
function ensure(s){Object.assign(s.appearance,extras(s.appearance));return s.appearance;}
const old={initial:C.initial,load:C.load};C.initial=(...args)=>{const s=old.initial(...args);ensure(s);return s;};C.load=raw=>{const v=typeof raw==='string'?JSON.parse(raw):structuredClone(raw),extra=extras(v.appearance),s=old.load(v);Object.assign(s.appearance,extra);return s;};
function context(s,id=null,emotion){
 const weather=root.ZRZEnvironment.profile(s.day,s.minutes),npc=id&&s.village.npc[id],outdoors=id?!npc?.room:!s.village.interior,actor=id&&root.ZRZVillage.stateRuntime(s).actors[id];
 const live=actor?.emotionUntil>root.ZRZVillage.stateRuntime(s).clock?actor.emotion:null;
 return {...(id?{id}:s.appearance),weather:outdoors&&weather.rain?'rain':weather.season===3?'cold':'fair',emotion:emotion||live||(!id&&s.stamina<20?'tired':'calm'),festival:C.calendar(s).date===14,gesture:actor&&!actor.walking?actor.gesture:null};
}
function resolve(color,hat,a={}){
 const npc=a.id&&A.styles[a.id],look=npc?{...npc}:{shirt:['#427660','#506c93','#a76755','#a38b48'][a.shirt||0]||color,accent:['#dfc18d','#d8c8a1','#ecc6a7','#e2dabb'][a.shirt||0],skin:['#e3b991','#c69b74','#a87e5d'][a.skin||0],hair:['short','bob','bun','wave'][a.hair||0],hairColor:hairColors[a.hairColor||0],hat};
 look.outfit=npc?(look.apron?'apron':look.vest?'traveler':'field'):(a.outfit||'field');
 look.apron=look.outfit==='apron';look.vest=look.outfit==='traveler';look.bag=npc?['tao','yu','qiao','yan'].includes(a.id):!!a.bag;
 look.shape=npc?(shapes[a.id]||[1,1]):[1,1];look.emotion=a.emotion||'calm';look.rain=a.weather==='rain'&&(npc||a.weatherDress!==false);look.cold=a.weather==='cold'&&(npc||a.weatherDress!==false);look.festival=a.festival||look.outfit==='festival';
 return look;
}
function shade(hex,amount){const n=parseInt(hex.slice(1),16),mix=v=>Math.max(0,Math.min(255,v+amount)).toString(16).padStart(2,'0');return '#'+mix(n>>16)+mix((n>>8)&255)+mix(n&255);}
function face(c,a,x,y,w,h,direction,emotion,blink=false){
 const side=direction==='left'||direction==='right',left=direction==='left',back=direction==='up',ink='#324039';
 R(c,x,y,w,h,shade(a.skin,-45));R(c,x+1,y+1,w-2,h-2,a.skin);R(c,x+2,y+2,2,h-5,shade(a.skin,18));R(c,x+w-3,y+4,2,h-5,shade(a.skin,-20));
 if(back){A.hair(c,a,x-1,y-3,w+2,h,true);return;}
 if(side){const nose=left?x-2:x+w-1;R(c,nose,y+h*.48,3,3,a.skin);R(c,left?x+2:x+w-4,y+h*.43,2,blink||emotion==='tired'?1:2,ink);}
 else{for(const xx of [x+3,x+w-5]){R(c,xx,y+h*.43,2,blink||emotion==='tired'?1:2,ink);if(!blink&&h>20)R(c,xx,y+h*.43,1,1,'#f6ecd3');}R(c,x+w/2,y+h*.54,1,3,shade(a.skin,-33));}
 const mx=side?(left?x+1:x+w-4):x+w/2-2,my=y+h-3;
 if(emotion==='happy'){R(c,mx,my,4,1,'#925e4a');R(c,mx+1,my+1,2,1,'#925e4a');}
 else if(emotion==='surprised')R(c,mx+1,my-1,2,3,'#925e4a');
 else{R(c,mx,my,3,1,'#a46d53');if(['focus','thought','worried'].includes(emotion)){R(c,x+2,y+h*.3,4,1,'#625443');if(!side)R(c,x+w-6,y+h*.3+(emotion==='thought'?-1:0),4,1,'#625443');}}
 A.hair(c,a,x-1,y-3,w+2,h*.75,false);
 if(side){R(c,left?x+w-1:x-1,y+3,2,h*.7,a.hairColor);}
 if(a.glasses){c.strokeStyle='#53554a';c.lineWidth=1;const yy=Math.round(y+h*.39);if(side)c.strokeRect(left?x+1:x+w-6,yy,5,4);else{c.strokeRect(x+1,yy,5,4);c.strokeRect(x+w-6,yy,5,4);R(c,x+w/2-1,yy+1,2,1,'#53554a');}}
}
function clothing(c,a,side,back,off){
 const shirt=a.rain?'#677f70':a.shirt,dark=shade(shirt,-30),light=shade(shirt,24);
 P(c,[[-7,-21],[6,-21],[9,-8],[-9,-8]],dark);R(c,-6,-20,12,12,shirt);R(c,-5,-19,3,9,light);R(c,5,-17,2,9,dark);R(c,-7,-9,15,2,dark);
 if(a.skirt)P(c,[[-6,-11],[6,-11],[9,-4],[-9,-4]],shirt);
 if(a.apron&&!back){R(c,side?off-3:-4,-17,side?6:9,11,a.accent);R(c,side?off-2:-3,-12,side?4:7,3,shade(a.accent,-22));R(c,-5,-17,11,1,shade(a.accent,18));}
 else if(a.vest){R(c,-6,-20,side?3:4,12,a.accent);if(!side)R(c,3,-20,4,12,a.accent);R(c,-5,-13,3,3,shade(a.accent,-30));}
 else if(!back){P(c,[[-4,-20],[0,-17],[4,-20],[4,-18],[0,-15],[-4,-18]],a.accent);for(let i=0;i<3;i++)R(c,off,-16+i*3,2,1,a.accent);}
 if(a.festival){R(c,-6,-10,13,2,'#c5a65c');if(!back){R(c,3,-17,2,5,'#e8d08b');R(c,1,-15,6,1,'#e8d08b');}}
 if(a.bag){if(back){R(c,-6,-19,13,13,'#7b6347');R(c,-5,-19,11,9,'#b89962');R(c,-4,-16,9,1,'#d2ba81');R(c,-1,-13,3,3,'#786e4d');}else{for(let i=0;i<11;i++)R(c,-5+i,-20+i,2,2,'#c2ae79');R(c,side?off+5:6,-11,5,7,'#b39760');}}
 if(a.cold){R(c,-7,-21,14,4,a.accent);R(c,side?off+1:3,-18,3,8,a.accent);R(c,side?off+1:3,-11,3,1,'#e9dfbd');}
}
function character(c,x,y,color,t=0,walking=false,hat=false,direction='down',appearance={}){
 const a=resolve(color,hat,appearance),side=['left','right'].includes(direction),back=direction==='up',off=direction==='left'?-2:direction==='right'?2:0,phase=Math.floor(t*(a.child?10:8))%8;
 const lifts=[0,1,2,1,0,0,0,0],left=walking?lifts[phase]:0,right=walking?lifts[(phase+4)%8]:0,bob=walking&&phase%4===2?-1:0;
 c.save();c.translate(Math.round(x),Math.round(y));A.shadow(c,0,1,22*a.shape[0],6);c.scale(a.shape[0],a.shape[1]);
 const foot=(xx,lift)=>{R(c,xx,-8-lift,5,8,'#4f6058');R(c,xx+1,-7-lift,2,5,'#738073');R(c,xx-1,-lift,7,3,'#303e39');R(c,xx,-lift,5,1,'#adb29d');};
 foot(side?-4:-6,left);foot(side?0:2,right);
 c.save();c.translate(appearance.lean?Math.round(appearance.lean.ux*appearance.lean.reach*3):0,bob+(appearance.lean?.low?Math.round(appearance.lean.reach*3):0));
 clothing(c,a,side,back,off);
 const work=appearance.working||(['read','hammer','sort','knead','weave','sew','water','camera','tea','fan','fish'].includes(appearance.gesture)&&!walking);
 if(!work){const swing=walking?left-right:0;for(const [xx,dy]of [[side?-7:-10,-swing],[side?5:8,swing]]){R(c,xx,-18+dy,3,9,a.rain?'#677f70':a.shirt);R(c,xx,-10+dy,3,3,a.skin);R(c,xx,-10+dy,1,2,shade(a.skin,15));}}
 face(c,a,side?-5:-6,-31,side?11:13,13,direction,a.emotion,Math.floor(t*3)%17===0);
 if(a.rain){P(c,[[-12,-32],[-6,-39],[6,-39],[12,-32]],'#b5aa72');R(c,-13,-32,27,3,'#d4c28b');R(c,-10,-30,22,1,'#7e7950');}
 else if(a.hat){R(c,-12,-33,25,3,'#947641');R(c,-10,-34,21,2,'#d9bd79');R(c,-7,-39,15,5,'#caae6b');R(c,-6,-39,12,1,'#f0d799');R(c,-7,-35,15,1,'#866b3d');}
 else if(a.cap){R(c,-7,-34,15,4,a.accent);R(c,off<0?-11:off>0?3:-5,-31,side?10:14,2,shade(a.accent,-15));}
 if(a.festival&&!a.rain){R(c,6,-29,3,4,'#bb5d48');R(c,7,-26,2,4,'#e7bc6e');}
 if(a.prop&&!work)A.accessory(c,a,back?0:side?(off<0?-8:9):8,back?-10:-8,.65);
 c.restore();c.restore();
}
function portrait(c,w,h,n,appearance){
 const options=appearance||{id:n?.id},a=resolve(n?.color||'#427660',options.hat,options);c.save();c.imageSmoothingEnabled=false;c.clearRect(0,0,w,h);c.scale(w/64,h/80);
 R(c,0,0,64,80,'#e7ddbd');R(c,2,2,60,76,a.rain?'#bbcbd0':a.cold?'#c4d2cf':'#d3ddbf');P(c,[[2,64],[14,48],[31,57],[50,37],[62,48],[62,78],[2,78]],'#a6bba0');
 for(let i=0;i<4;i++){R(c,7+i*2,8+i*5,1,13,'#94ab8c');R(c,4+i*2,10+i*5,7,1,'#94ab8c');}
 c.save();c.translate(32,99);c.scale(2.35,2.2);clothing(c,a,false,false,0);c.restore();
 R(c,28,43,11,11,shade(a.skin,-15));
 P(c,[[20,25],[23,21],[42,21],[46,26],[46,39],[42,46],[37,49],[29,49],[23,45],[20,38]],shade(a.skin,-32));
 P(c,[[22,25],[25,23],[41,23],[44,27],[44,38],[40,44],[36,47],[29,46],[24,42],[22,37]],a.skin);
 R(c,19,31,3,7,a.skin);R(c,45,31,3,7,a.skin);R(c,24,28,2,10,shade(a.skin,17));R(c,40,38,3,4,shade(a.skin,-13));
 const ey=33,closed=a.emotion==='tired';for(const x of [26,37]){R(c,x,ey-3,5,1,a.hairColor);R(c,x,ey,4,closed?1:3,'#394237');if(!closed)R(c,x+1,ey,1,1,'#faf1d9');}
 R(c,32,36,2,4,shade(a.skin,-28));R(c,33,39,3,1,shade(a.skin,16));R(c,25,39,4,1,'#d79d80');R(c,39,39,3,1,'#d79d80');
 R(c,31,43,5,1,'#98654e');if(a.emotion==='happy')R(c,32,44,3,1,'#98654e');if(a.emotion==='surprised')R(c,32,42,3,3,'#98654e');
 if(['thought','worried','focus'].includes(a.emotion))R(c,27,29,a.emotion==='focus'?4:2,1,a.hairColor);
 A.hair(c,a,20,20,26,19,false);R(c,23,23,5,3,a.hairColor);R(c,28,23,4,2,a.hairColor);
 if(a.glasses){c.strokeStyle='#53554a';c.lineWidth=1;c.strokeRect(24,32,8,5);c.strokeRect(35,32,8,5);R(c,32,33,3,1,'#53554a');}
 if(a.hat||a.rain){const col=a.rain?'#aa9d65':'#c5a361';P(c,[[13,21],[22,10],[43,10],[53,21]],col);R(c,10,21,46,4,'#d9c087');R(c,18,19,29,2,'#876f3e');R(c,23,11,17,2,'#e8d297');}
 if(a.cap&&!a.rain){R(c,20,15,29,7,a.accent);R(c,29,21,24,3,shade(a.accent,-15));}
 if(a.festival){R(c,45,27,4,5,'#b85848');R(c,46,32,2,6,'#e8c77c');}
 if(a.prop)A.accessory(c,a,48,69,.85);
 if(a.cold){R(c,24,51,18,5,a.accent);R(c,38,55,5,16,a.accent);R(c,38,68,5,2,'#ebe2c6');}
 if(a.rain){R(c,7,30,1,8,'#e7f0db');R(c,54,9,1,7,'#e7f0db');}
 R(c,0,0,64,2,'#9dab8c');R(c,0,78,64,2,'#9dab8c');c.restore();
}
A.character=character;A.portrait=portrait;root.ZRZWorld.character=character;root.ZRZWorld.portrait=portrait;
root.ZRZCharacters={outfits,hairColors,hairNames,defaults,directions,ensure,extras,context,resolve,shade,character,portrait,frameCount:8,anchor:'feet-center'};
})(typeof window!=='undefined'?window:globalThis);

