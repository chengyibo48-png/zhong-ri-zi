(function(root){
'use strict';
const A=root.ZRZArt,R=root.ZRZRanch,W=root.ZRZWorld,Chr=root.ZRZCharacters,box=A.R,poly=A.poly;
function blob(c,x,y,w,h,col){poly(c,[[x+3,y],[x+w-3,y],[x+w,y+3],[x+w,y+h-3],[x+w-3,y+h],[x+3,y+h],[x,y+h-3],[x,y+3]],col);}
function state(a,t=0){const p=a.position?.room?a.position.inside:a.position||{},pose=R.visualPose?.(a),active=pose&&t<pose.until;
 return {direction:p.direction||'down',walking:!!p.walking,young:!R.mature(a),sick:a.illness>=20,sleepy:!!a.rest,hungry:a.hunger<35,dirty:a.clean<45,eating:active&&pose.action==='feed',happy:active&&['pet','clean'].includes(pose.action),sheared:active&&pose.action==='collect'&&a.type==='sheep',tail:a.trait==='friendly'?1.5:a.trait==='shy'?.5:1};
}
function animal(c,a,x,y,t=0){
 const v=state(a,t),bird=['hen','duck'].includes(a.type),side=['left','right'].includes(v.direction),back=v.direction==='up',size=v.young?.64:a.type==='cow'?1.23:1;
 const coat=a.breed==='hardy'?'#a38c6e':a.breed==='productive'?'#e2ccad':R.species[a.type].color,shade=Chr.shade(coat,-26),highlight=Chr.shade(coat,20),phase=Math.floor(t*9)%8,lift=v.walking?[0,1,2,1,0,0,0,0][phase]:0;
 c.save();c.translate(Math.round(x),Math.round(y));A.shadow(c,0,1,(bird?31:49)*size,8*size);c.scale(size*(v.direction==='left'?-1:1),size);
 // Feet remain anchored; only the swinging foot lifts above the ground.
 for(const [i,lx]of (bird?[[-1,-7],[1,7]]:side?[[-1,-18],[1,-9],[1,12],[-1,21]]:[[-1,-11],[1,7]])){const l=i<0?lift:v.walking?[0,1,2,1,0,0,0,0][(phase+4)%8]:0;box(c,lx,-10-l,bird?3:5,10,bird?'#b48845':'#937957');box(c,lx-1,-l,bird?7:7,3,bird?'#d0a052':'#464c40');}
 const bw=bird?(side?33:25):(side?51:33),bh=bird?23:(side?29:34),by=bird?-32:-39;
 blob(c,-bw/2,by,bw,bh,shade);blob(c,-bw/2+2,by+1,bw-4,bh-4,coat);box(c,-bw/2+5,by+3,bw-12,3,highlight);
 if(a.type==='sheep'&&!v.sheared){for(let i=0;i<10;i++){const xx=-bw/2+2+i%5*(bw-5)/5,yy=by-2+Math.floor(i/5)*9;blob(c,xx,yy,10,9,i%2?'#dfd9c3':'#ede8d5');}}
 else if(a.type==='cow'){box(c,-bw/2+8,by+6,9,8,shade);box(c,2,by+16,8,7,shade);}
 else if(bird){blob(c,-bw/2+3,by+10,side?15:18,10,a.type==='duck'?'#aab7a0':'#c2a16f');box(c,-bw/2+6,by+14,10,1,highlight);}
 if(v.dirty)for(let i=0;i<6;i++)box(c,-bw/2+5+i*4,by+bh-6-(i%2)*3,3,2,'#8d7956');
 const headX=side?(bird?15:25):0,hy=(bird?-37:-32)+(v.eating?Math.round(3+Math.sin(t*9)*2):v.hungry&&!v.walking?3:0),headW=bird?15:a.type==='pig'?22:20;
 if(!back||side){
 blob(c,headX-headW/2,hy,headW,bird?17:21,a.type==='sheep'?'#9b8b72':coat);
 if(!bird){box(c,headX-headW/2-4,hy+1,6,5,coat);box(c,headX+headW/2-2,hy+1,6,5,coat);if(a.type==='cow'){box(c,headX-9,hy-6,3,8,'#dcd9b7');box(c,headX+7,hy-6,3,8,'#dcd9b7');}}
 const closed=v.sleepy||v.sick||Math.floor(t*3+a.age)%19===0;
 const eye=xx=>{box(c,xx,hy+6,2,closed?1:3,'#2e4138');if(!closed)box(c,xx,hy+6,1,1,'#f6efd2');};
 eye(headX+(side?2:-5));if(!side)eye(headX+4);
 if(bird){box(c,side?headX+6:headX-3,hy+11,a.type==='duck'?10:7,4,'#d5a052');if(a.type==='hen'){box(c,headX-3,hy-4,7,v.young?2:4,'#b65e4c');box(c,headX+2,hy+16,3,4,'#b65e4c');}else box(c,headX-5,hy+17,10,2,'#729387');}
 else{blob(c,side?headX+3:headX-8,hy+12,17,9,a.type==='pig'?'#bd8981':'#c7b391');box(c,side?headX+10:headX-4,hy+16,2,2,'#796252');if(a.type==='pig'||!side)box(c,side?headX+15:headX+3,hy+16,2,2,'#796252');}
 }else{box(c,-6,by-3,12,6,coat);if(a.type==='hen')box(c,-3,by-5,6,3,'#b65e4c');}
 if(!bird){const tx=side?-28:0,ty=side?-23:-16,wiggle=Math.round(Math.sin(t*4)*v.tail*2);box(c,tx,ty,2,13,'#9d8968');box(c,tx-1+wiggle,ty+11,4,4,a.type==='pig'?'#b4897b':'#76644a');if(!back){box(c,headX-8,hy+20,16,3,a.trait==='shy'?'#72959c':a.trait==='friendly'?'#b25c4c':'#789257');box(c,headX,hy+23,3,3,'#dcc07a');}}
 c.restore();
 const symbol=v.sick?'!':a.lost?'!':v.sleepy?'z':v.hungry?'…':a.ready||a.feathers?'✦':v.happy?'♡':'';
 if(symbol){c.save();c.font='bold 12px Microsoft YaHei';c.textAlign='center';blob(c,x-9,y-59*size,18,16,v.sick||a.lost?'#ac7350':'#6a8c70');c.fillStyle='#fff2d2';c.fillText(symbol,x,y-47*size);c.restore();}
}
function pet(c,s,t=0){
 const p=s.ranch.pet.position,cat=s.pet.type==='cat',left=p.direction==='left',back=p.direction==='up',side=left||p.direction==='right',rest=s.ranch.pet.energy<15||s.minutes>=1140,coat=cat?'#c49c66':'#b58758',wag=Math.round(Math.sin(t*(rest?1:5))*(rest?1:3));
 c.save();c.translate(Math.round(p.x),Math.round(p.y));c.scale(left?-1:1,1);A.shadow(c,0,1,32,6);
 for(const x of [-10,8]){box(c,x,-9,4,10,'#80644a');box(c,x-1,0,6,2,'#5c5543');}
 blob(c,side?-18:-13,-24,side?34:26,19,coat);const hx=side?13:0;blob(c,hx-9,-34,18,20,'#d9b886');
 if(cat){poly(c,[[hx-9,-31],[hx-9,-41],[hx-2,-35]],coat);poly(c,[[hx+2,-35],[hx+9,-41],[hx+9,-31]],coat);}
 else{box(c,hx-11,-33,5,13,'#796049');box(c,hx+7,-33,5,13,'#796049');}
 if(!back){box(c,hx-4,-28,2,rest?1:3,'#334237');box(c,hx+4,-28,2,rest?1:3,'#334237');box(c,hx,-22,3,2,'#735846');if(cat){box(c,hx-13,-22,8,1,'#e7d6ac');box(c,hx+7,-22,8,1,'#e7d6ac');}}
 box(c,side?-21:0,-24+wag,4,15,coat);box(c,hx-8,-16,17,3,'#ae6250');box(c,hx,-13,3,3,'#e2c77d');c.restore();
}
const fishColors={fish:['#bfc6a1','#648f88'],perch:['#a1bba0','#537b73'],loach:['#a98e60','#766c48'],shrimp:['#d2b591','#976f53'],crab:['#b39465','#785f43']};
function fish(c,id,x,y,scale=1,t=0){
 const [base,dark]=fishColors[id]||fishColors.fish;c.save();c.translate(Math.round(x),Math.round(y));c.scale(scale,scale);const tail=Math.round(Math.sin(t*5)*2);
 if(id==='crab'){for(const sign of [-1,1]){for(let i=0;i<3;i++){box(c,16+sign*(7+i),18+i*3,sign<0?5:6,2,dark);}box(c,sign<0?2:25,8,4,9,base);box(c,sign<0?1:28,5,3,5,dark);}blob(c,8,11,18,14,base);box(c,12,9,2,3,dark);box(c,21,9,2,3,dark);box(c,11,13,12,2,'#d6bc88');}
 else if(id==='shrimp'){for(let i=0;i<6;i++)blob(c,6+i*3,11+Math.round(i*i*.3),7,6,i%2?base:dark);box(c,5,11,2,2,'#35463a');for(let i=0;i<3;i++)box(c,8+i*4,18+i,1,5,dark);box(c,1,7,10,1,dark);box(c,3,5,9,1,base);poly(c,[[25,24],[32,22+tail],[30,28],[25,27]],base);}
 else{const slim=id==='loach',yy=slim?16:12,hh=slim?8:15;poly(c,[[24,yy+hh/2],[31,yy+tail],[30,yy+hh-tail]],dark);blob(c,3,yy,23,hh,dark);blob(c,4,yy+1,20,hh-3,base);box(c,7,yy+2,11,2,'#e0d9b5');box(c,6,yy+4,2,2,'#30483c');box(c,6,yy+4,1,1,'#f5ebca');if(!slim){poly(c,[[12,yy],[17,yy-5],[21,yy+1]],dark);for(let i=0;i<4;i++)box(c,12+i*3,yy+6,1,5,id==='perch'?dark:'#a2af8c');}else{box(c,2,yy+6,4,1,dark);box(c,1,yy+8,4,1,dark);}}
 c.restore();
}
const baseItem=W.item;W.item=(c,id,x,y,scale=1)=>fishColors[id]?fish(c,id,x,y,scale,0):baseItem(c,id,x,y,scale);
R.drawAnimal=animal;R.drawPet=pet;
root.ZRZCreatures={state,animal,pet,fish,fishColors};
})(typeof window!=='undefined'?window:globalThis);

