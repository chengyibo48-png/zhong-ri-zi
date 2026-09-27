(function(root){
'use strict';const N=root.ZRZNpc;
N.draw=function(c,s,n,p,a,t){if(!a)return;c.save();c.translate(p.x,p.y);const r=(x,y,w,h,col)=>{c.fillStyle=col;c.fillRect(Math.round(x),Math.round(y),w,h);},line=(pts,color,w=2)=>{c.strokeStyle=color;c.lineWidth=w;c.beginPath();pts.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));c.stroke();};
 const mood=a.emotionUntil>root.ZRZVillage.stateRuntime(s).clock?a.emotion:null;
 if(!a.walking){const g=a.gesture,u=Math.sin(t*2.6),skin=root.ZRZArt.styles[n.id]?.skin||'#dfb78e';
 if(g==='read'){r(-9,-17,12,8,'#eee0b3');r(4,-17,11,8,'#dfc891');r(3,-18,1,11,'#917046');line([[-7,-18],[0,-19+u],[10,-16]],skin,3);}
 if(g==='hammer'){line([[8,-15],[17,-20+u*5],[22,-13+u*6]],skin,3);line([[22,-12+u*6],[25,-24+u*6]],'#ab8452',2);r(21,-27+u*6,10,5,'#819c99');r(14,-7,23,5,'#af8751');}
 if(['sort','knead','weave','sew'].includes(g)){r(-15,-10,31,4,'#b69262');r(-9,-15,20,5,g==='knead'?'#e7d0a0':g==='sort'?'#8ca372':'#d3b789');line([[-9,-18],[-4+u*3,-11],[6+u*2,-13],[10,-18]],skin,3);if(g==='weave'||g==='sew')for(let i=0;i<5;i++)r(-8+i*4,-15,1,7,'#765c4e');}
 if(g==='water'){line([[9,-16],[17,-12+u*2]],skin,3);r(14,-15,11,8,'#719f9c');r(23,-11,7,2,'#a6c4b4');r(29,-7+(t*8)%8,1,3,'#c6e9df');r(24,0,15,5,'#ae865d');r(30,-5,4,6,'#679265');}
 if(g==='camera'){r(-8,-28,18,11,'#3c4c51');r(-2,-26,8,7,'#adbab1');r(0,-24,4,4,'#42595e');line([[-9,-15],[-12,-25],[-6,-23]],skin,3);if(Math.sin(t*.8)>.995)r(-5,-32,13,2,'#f8efbe');}
 if(g==='tea'){const lift=(u+1)*2;line([[7,-14],[13,-15-lift]],skin,3);r(10,-18-lift,9,7,'#d8e3cc');r(12,-21-lift,1,2,'#f5ead4a0');}
 if(g==='fish'&&!s.village.interior&&Math.hypot(p.x-749,p.y-2790)<120){line([[8,-15],[24,-42]],'#a48a59',2);line([[24,-42],[780-p.x,2850-p.y]],'#e9e0ba99',1);r(779-p.x,2846-p.y,3,6,'#c86f51');}
 if(g==='fan'){line([[8,-15],[16,-21+u*3]],skin,3);c.fillStyle='#d8b982';c.beginPath();c.arc(16,-23+u*3,10,Math.PI,Math.PI*2);c.fill();}
 if(g==='sleep'){c.font='9px serif';c.fillStyle='#ede8d0';c.fillText('z',11,-39-u*2);}
 }
 if(mood){r(-9,-51,20,12,'#fff0cb');r(-2,-39,4,3,'#fff0cb');c.fillStyle='#776848';c.font='10px sans-serif';c.textAlign='center';c.fillText({happy:'♪',thought:'…',focus:'·',calm:'·'}[mood],1,-42);}
 c.restore();};
})(typeof window!=='undefined'?window:globalThis);
