(function(root){
 'use strict';const K=root.ZRZKitchen,V=root.ZRZVillage,W=root.ZRZWorld;
 const rect=(c,x,y,w,h,color)=>{c.fillStyle=color;c.fillRect(Math.round(x),Math.round(y),w,h);};
 K.roomObjects=h=>h.id===K.house().id?[{id:'room-exit',kind:'exit',name:'推门回到村庄',x:480,y:590},...Object.keys(K.stations).map(id=>K.point(null,id)),{id:'kitchen-book',kind:'cook',name:'灶边菜谱 · 做饭与试配',x:455,y:395}]:null;
 K.drawRoom=(c,s,t)=>{if(s.village.interior!==K.house().id)return false;K.ensure(s);
   rect(c,0,0,960,672,'#253c37');rect(c,96,111,771,510,'#594e40');rect(c,107,199,746,408,'#baa37b');
   c.save();c.beginPath();c.rect(107,199,746,408);c.clip();for(let y=204;y<607;y+=28)for(let x=110;x<850;x+=48){rect(c,x,y,45,25,(x+y)%4?'#c5b18c':'#b8a27b');rect(c,x+3,y+3,39,1,'#d7c4a0');}c.restore();
   rect(c,98,108,765,96,'#e0d4b4');rect(c,98,187,765,18,'#65553e');rect(c,100,109,11,500,'#886c49');rect(c,851,109,11,500,'#886c49');
   for(const x of [190,455,725]){rect(c,x-44,124,88,58,'#5d6b58');rect(c,x-37,129,74,45,'#b8ccac');rect(c,x-33,132,65,17,'#e5e9bc');for(let i=-1;i<=1;i++)rect(c,x+i*21,129,3,46,'#77866a');rect(c,x-37,149,74,3,'#77866a');}
   c.fillStyle='#5e5140';c.font='bold 18px serif';c.textAlign='center';c.fillText('一 粥 一 饭 · 四 季 有 味',455,233);
   // Furniture follows the shared indoor collision rectangles, leaving broad walking aisles.
   rect(c,161,249,183,43,'#75634d');rect(c,165,251,175,7,'#ded4b7');for(let x=171;x<335;x+=26){rect(c,x,263,22,7,'#b1a28a');rect(c,x+7,275,18,6,'#c8b694');}
   for(const x of [223,311]){c.fillStyle='#303d37';c.beginPath();c.ellipse(x,254,30,10,0,0,7);c.fill();c.strokeStyle='#76847a';c.lineWidth=3;c.stroke();rect(c,x-15,278,29,9,'#553d2e');if(s.kitchen.jobs.some(j=>['stove','steam'].includes(j.station)&&j.ready>K.now(s)))rect(c,x-9,280,17,5,'#e68b43');}
   if(s.kitchen.jobs.some(j=>['stove','steam'].includes(j.station)&&j.ready>K.now(s))&&s.feedback?.prefs.motion!=='reduced'&&root.ZRZVisualFx?.policy(s).ambient!==false)for(let i=0;i<3;i++){const y=235-(t*18+i*17)%52;rect(c,213+i*7+Math.sin(t*2+i)*4,y,4,10,'#fff6d68a');}
   rect(c,297,231,28,14,'#b9945e');for(let i=0;i<4;i++)rect(c,300+i*6,232,2,12,'#dec08c');rect(c,294,228,34,4,'#ddbd80');
   rect(c,627,248,140,40,'#735b40');rect(c,630,250,134,7,'#bc9768');c.fillStyle='#a0a498';c.beginPath();c.ellipse(700,251,46,18,0,0,7);c.fill();c.strokeStyle='#666d65';c.lineWidth=3;c.stroke();c.beginPath();c.ellipse(700,248,26,9,0,0,7);c.stroke();rect(c,696,226,7,25,'#725335');rect(c,698,226,34,5,'#987441');
   rect(c,658,443,144,38,'#825f43');for(let i=0;i<3;i++){const x=684+i*43;rect(c,x-17,435,33,41,'#996a47');rect(c,x-21,431,40,6,'#624b3c');rect(c,x-10,443,20,21,'#d6bd89');c.fillStyle='#714a39';c.font='12px serif';c.fillText(['腌','酿','乳'][i],x,458);}
   rect(c,158,447,152,53,'#8d7652');for(let j=0;j<3;j++){rect(c,163,451+j*16,142,3,'#d6bd86');for(let i=0;i<9;i++)rect(c,170+i*15,455+j*16,8,5,j%2?'#c49758':'#aa6950');}
   rect(c,380,328,140,41,'#9e774d');rect(c,377,326,146,8,'#ddbb82');for(const x of [390,500])rect(c,x,367,7,17,'#775336');rect(c,401,313,33,16,'#eee3c0');rect(c,438,314,30,14,'#e5d7b3');rect(c,435,312,3,19,'#98734b');
   // Copper pot, banded fermenting barrel, lever press, milk bottles and woven compost basket.
   rect(c,579,249,42,41,'#a57b4d');for(let i=0;i<5;i++)rect(c,582+i*8,252,2,36,'#725739');rect(c,576,254,48,5,'#56635a');rect(c,576,280,48,5,'#56635a');rect(c,577,245,46,7,'#c2a573');
   rect(c,766,315,7,58,'#8a673f');rect(c,816,315,7,58,'#8a673f');rect(c,760,313,69,8,'#bb9664');rect(c,790,322,6,22,'#6d5a42');rect(c,774,347,39,23,'#b28e5b');rect(c,769,369,50,6,'#715c41');rect(c,780,339,25,8,'#d8ba7c');
   rect(c,564,432,53,14,'#9c7a4f');for(let i=0;i<3;i++){rect(c,570+i*15,408,10,24,'#dfe5d0');rect(c,573+i*15,404,5,5,'#b29268');rect(c,572+i*15,420,6,5,'#a3b4a0');}
   c.fillStyle='#ba8549';c.beginPath();c.ellipse(391,347,25,11,0,0,7);c.fill();rect(c,370,342,41,10,'#c2985f');c.fillStyle='#b16a58';c.beginPath();c.ellipse(391,342,21,6,0,0,7);c.fill();rect(c,384,325,4,21,'#755c3c');
   rect(c,319,488,39,26,'#bda16d');for(let i=0;i<5;i++){rect(c,321+i*8,488,2,26,'#80663f');rect(c,319,491+i*5,39,2,'#dfc18a');}rect(c,317,485,44,5,'#c5ab75');
   for(const [id,st]of Object.entries(K.stations)){const jobs=s.kitchen.jobs.filter(j=>j.station===id),ready=jobs.some(j=>j.ready<=K.now(s));if(jobs.length){rect(c,st.x-17,st.y-19,34,6,'#455847');rect(c,st.x-15,st.y-17,30,2,ready?'#f2cb6a':'#8ab8aa');c.fillStyle=ready?'#ffe59a':'#e0ebcc';c.font='11px sans-serif';c.fillText(ready?'可收取':'加工中',st.x,st.y-23);}}
   // Labels stay legible at normal zoom; tooltips provide detailed device state.
   c.font='11px sans-serif';c.fillStyle='#5b5342';for(const st of Object.values(K.stations))c.fillText(st.name,st.x,st.y+13);
   rect(c,443,584,76,24,'#554e3d');rect(c,438,582,86,5,'#d9be8c');c.textAlign='left';return true;
 };
 const item=W.item;W.item=(c,id,x,y,scale=1)=>{if(!['riceWine','berryJam','cheese','gardenSoup','springBowl','summerDrink','autumnToast','winterMilk'].includes(id))return item(c,id,x,y,scale);c.save();c.translate(x,y);c.scale(scale,scale);const color={riceWine:'#d4ac6d',berryJam:'#b95867',cheese:'#edcc7a',gardenSoup:'#769c68',springBowl:'#95b675',summerDrink:'#bc8795',autumnToast:'#d6a35d',winterMilk:'#eee0b1'}[id];rect(c,4,11,24,18,'#795d45');rect(c,2,9,28,5,'#ddd7b5');rect(c,5,10,22,4,color);rect(c,8,16,15,9,'#efe1bc');rect(c,14,17,4,5,color);rect(c,8,30,17,2,'#43594855');c.restore();};
})(typeof window!=='undefined'?window:globalThis);
