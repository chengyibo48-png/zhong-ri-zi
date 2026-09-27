(function(root){
'use strict';
const D=root.ZRZData,W=root.ZRZWorld,A=root.ZRZArt,E=root.ZRZEconomy,K=root.ZRZKitchen,F=root.ZRZFarming,base=W.item;
const R=A.R,P=A.poly,ink='#425647',cream='#eee1b7',leaf='#709755';
const seedMap={};for(const crop of Object.keys(D.crops))for(const kind of Object.keys(F.kinds))seedMap[F.seedId(crop,kind)]={crop,kind};
const originalDetails=E.details;E.details=id=>{const m=originalDetails(id),seed=seedMap[id];if(seed){const crop=D.crops[seed.crop];m.uses=['播种'+crop.name+'（'+crop.seasons.map(i=>D.seasons[i]).join(' / ')+'适种）',seed.kind==='seasonal'?'节令种不支持暖棚反季种植':'小暖棚内可反季种植'];if(seed.kind==='heirloom')m.sources='杂货货架（春十五或与沈禾熟悉后可购）、健康高品质作物留种';}return m;};
const materials={feed:['sack','#bba572'],flour:['sack','#e6d4a5'],compost:['sack','#806945'],slowFertilizer:['sack','#a69062'],grainFeed:['sack','#c9b05c'],healthFeed:['sack','#83966c'],hay:['straw','#85995b'],bedding:['straw','#c5b37b'],manure:['heap','#8c7050'],bioCare:['bottle','#729a73'],plantCare:['bottle','#8fa5bb'],animalMedicine:['bottle','#b18065'],wool:['wool','#e5ddc5'],yarn:['yarn','#b1bdaa'],cloth:['cloth','#909f9a'],feather:['feather','#e4debf'],cream:['cream','#eadab0'],yogurt:['cup','#ebe1c4'],cheese:['cheese','#e5be63'],oil:['bottle','#cfad57'],riceWine:['bottle','#cab995'],berryJam:['jar','#ab6864'],dryTea:['tea','#657954'],driedMushroom:['dry','#967953'],driedFish:['fishdry','#ac9d7e'],milk:['bottle','#e3dec0'],egg:['egg','#ecdbac'],duckEgg:['egg','#bbcabc'],fertileHenEgg:['fertile','#ecd9a5'],fertileDuckEgg:['fertile','#b5c6b5'],truffle:['truffle','#816548']};
const vegetables={cabbage:['leaf','#759853',3],bean:['pod',leaf,3],pea:['pod','#83a363',4],broadbean:['pod','#78935d',2],okra:['pod','#679064',5],spinach:['leaf','#608f58',3],lettuce:['leaf','#99b86b',5],bokchoy:['leaf','#a1b27c',4],mustard:['leaf','#7c9b50',2],wildHerb:['leaf','#8ca06d',6],leek:['leek','#64864f',5],potato:['root','#c2a372',2],sweetpotato:['root','#a8796b',3],taro:['root','#998475',4],peanut:['peanut','#bc9b66',2],sesame:['grain','#b8aa82',5],wheat:['grain','#c3ac67',3],pepper:['pepper','#64854d',3],berry:['berry','#ac6264',5],tea:['tea','#759157',3],wintermelon:['melon','#9bab86',3]};
function shape(c,id){const [kind,col,n]=vegetables[id];
 if(kind==='pod'){P(c,[[4,11],[9,7],[27,17],[28,21],[22,25],[6,17]],ink);P(c,[[6,11],[10,9],[26,18],[25,22],[22,23],[7,16]],col);for(let i=0;i<n;i++)R(c,9+i*3,12+i*2,3,3,'#c1ce8c');}
 if(kind==='leaf'){for(let i=0;i<n;i++){const x=4+i*4,y=6+(i%2)*5;P(c,[[x,24],[x-1,y+5],[x+2,y],[x+6,y+2],[x+5,23],[17,28]],col);R(c,x+2,y+4,1,14,cream);}R(c,13,25,7,3,'#d8d5a6');}
 if(kind==='leek'){for(let i=0;i<5;i++)P(c,[[12+i,28],[4+i*5,4+i%2*3],[7+i*5,5],[16+i,28]],i%2?leaf:col);R(c,10,22,12,2,'#bfa46f');}
 if(kind==='root'){for(let i=0;i<2;i++){const x=4+i*11,y=10+i*5;P(c,[[x,y+4],[x+4,y],[x+12,y+1],[x+15,y+8],[x+10,y+13],[x+2,y+12]],ink);P(c,[[x+1,y+4],[x+4,y+1],[x+11,y+2],[x+13,y+8],[x+9,y+11],[x+2,y+10]],col);for(let j=0;j<n;j++)R(c,x+3+j*3,y+3+j%2*3,2,1,'#dac39b');}}
 if(kind==='peanut'){for(let i=0;i<2;i++){const x=5+i*12;P(c,[[x+3,5],[x+8,7],[x+7,14],[x+10,19],[x+8,26],[x+2,27],[x,21],[x+2,14],[x,9]],col);for(let y=9;y<25;y+=4)R(c,x+3,y,4,1,'#e3c48a');}}
 if(kind==='grain'){for(let i=0;i<n;i++){const x=5+i*4;R(c,x,5+i%2*3,1,22,col);for(let y=8;y<20;y+=4){R(c,x-2,y,2,3,cream);R(c,x+1,y+2,2,3,col);}}R(c,9,23,14,2,'#967449');}
 if(kind==='pepper'){P(c,[[7,11],[11,8],[15,10],[20,8],[26,12],[25,23],[20,28],[15,26],[10,28],[6,23]],ink);P(c,[[8,12],[11,10],[16,12],[21,10],[24,13],[23,23],[19,26],[15,24],[10,25]],col);R(c,10,13,2,9,'#a1b778');R(c,16,5,3,6,leaf);}
 if(kind==='berry'){for(const [x,y]of [[6,15],[15,10],[20,20],[9,23],[24,12]]){R(c,x-2,y,7,6,col);R(c,x,y-2,3,2,col);R(c,x-1,y,2,2,'#dca280');}P(c,[[14,10],[9,3],[18,7],[24,3],[23,8]],leaf);}
 if(kind==='tea'){for(let i=0;i<3;i++)P(c,[[7,25],[5+i*7,10-i%2*4],[9+i*7,5],[13+i*7,11],[16,24]],col);R(c,10,22,15,2,'#bda774');}
 if(kind==='melon'){P(c,[[4,12],[9,7],[23,7],[28,12],[28,22],[23,27],[9,27],[4,22]],ink);R(c,6,12,20,10,col);R(c,9,9,14,16,col);R(c,10,10,2,14,'#d1d8b1');R(c,22,12,2,10,'#748663');R(c,15,4,3,4,leaf);}
}
function vessel(c,kind,col){
 if(kind==='sack'){P(c,[[8,5],[24,5],[21,10],[26,15],[26,27],[6,27],[6,15],[11,10]],ink);P(c,[[10,6],[22,6],[19,11],[24,16],[24,25],[8,25],[8,16],[13,11]],col);R(c,10,9,12,2,'#8d7249');R(c,11,15,10,7,cream);}
 else if(kind==='bottle'){R(c,12,3,8,4,ink);R(c,11,4,10,2,'#a68757');R(c,12,7,8,4,col);P(c,[[12,10],[20,10],[24,14],[24,28],[8,28],[8,14]],ink);R(c,10,14,12,12,col);R(c,11,15,2,8,'#f6edc9');R(c,10,19,12,5,cream);}
 else{P(c,[[7,10],[25,10],[27,15],[25,27],[7,27],[5,15]],ink);R(c,8,12,16,13,col);R(c,9,5,14,6,'#a6885d');R(c,7,7,18,3,'#c2ab79');R(c,11,16,10,7,cream);}
}
function material(c,id){const[k,col]=materials[id];
 if(['sack','bottle','jar'].includes(k)){vessel(c,k,col);if(['bioCare','healthFeed'].includes(id)){P(c,[[13,21],[12,17],[17,19],[20,16],[19,21]],leaf);}else if(['plantCare','animalMedicine'].includes(id)){R(c,15,18,2,7,id==='plantCare'?'#588870':'#a86e51');R(c,13,20,6,2,id==='plantCare'?'#588870':'#a86e51');}else if(id==='flour'){R(c,13,18,7,3,'#fff3cf');}else if(id==='grainFeed'){for(let i=0;i<3;i++)R(c,12+i*3,17+i%2,2,3,'#b19145');}else R(c,14,18,4,3,col);return;}
 if(k==='straw'){for(let i=0;i<8;i++)P(c,[[4+i*3,8+i%3],[7+i*3,9],[9+i*2,27],[4+i*3,27]],col);R(c,6,17,22,3,'#8d744f');R(c,8,18,18,1,'#d8c89a');}
 if(k==='heap'||k==='truffle'){P(c,[[4,25],[7,16],[12,14],[14,9],[22,11],[26,17],[28,25]],ink);P(c,[[6,23],[9,17],[14,16],[15,11],[21,13],[25,18],[26,24]],col);for(let i=0;i<6;i++)R(c,9+i%3*6,17+Math.floor(i/3)*4,3,2,'#b2986c');}
 if(k==='wool'){for(const [x,y]of [[8,17],[13,10],[20,12],[24,19],[16,23]]){R(c,x-4,y-4,9,9,'#a9aa92');R(c,x-4,y-5,8,8,col);R(c,x-3,y-5,5,2,'#faf0d2');}}
 if(k==='yarn'){P(c,[[6,13],[11,7],[23,8],[28,15],[26,24],[20,28],[9,25],[5,19]],col);for(let i=0;i<5;i++)P(c,[[8+i*3,10],[10+i*3,9],[23,22-i*2],[22,24-i*2]],'#607a70');R(c,4,27,13,2,col);R(c,3,24,2,4,col);}
 if(k==='cloth'){R(c,6,9,21,19,ink);R(c,8,7,17,19,col);R(c,9,9,3,14,'#c6cfbd');R(c,8,23,17,2,'#60786e');for(let i=0;i<4;i++)R(c,10+i*4,26,1,3,col);}
 if(k==='feather'){P(c,[[5,25],[9,9],[18,4],[25,6],[25,13],[14,24]],col);P(c,[[8,28],[21,8],[23,8],[10,28]],'#8b987e');for(let i=0;i<3;i++)R(c,10+i*3,12+i*3,5,1,'#b5bba0');}
 if(k==='egg'||k==='fertile'){P(c,[[10,26],[6,21],[8,12],[13,5],[19,5],[24,13],[26,21],[22,26]],ink);P(c,[[11,24],[8,20],[10,12],[14,7],[18,7],[22,13],[24,20],[21,24]],col);R(c,12,10,3,7,'#f8efd2');if(k==='fertile'){R(c,22,22,7,7,'#72935c');R(c,24,24,3,3,cream);}}
 if(['cream','cup'].includes(k)){P(c,[[6,13],[26,13],[23,28],[9,28]],'#779a90');R(c,8,11,16,4,cream);R(c,11,15,10,9,col);if(k==='cream')P(c,[[9,11],[13,7],[19,7],[23,11]],col);else R(c,25,16,4,6,'#779a90');}
 if(k==='cheese'){P(c,[[5,14],[21,7],[28,16],[28,26],[5,26]],'#ac8a46');P(c,[[6,14],[21,9],[26,16],[6,17]],cream);R(c,7,18,19,6,col);R(c,11,19,3,3,'#b18d44');R(c,21,20,2,2,'#b18d44');}
 if(k==='tea'||k==='dry'){R(c,4,11,24,17,'#a18455');for(let y=12;y<27;y+=3)R(c,5,y,22,1,'#cfb678');for(let i=0;i<5;i++){if(k==='tea')P(c,[[6+i*4,19],[8+i*4,13],[11+i*4,18]],col);else{R(c,6+i*4,14+i%2*6,5,3,col);R(c,8+i*4,17+i%2*6,2,3,cream);}}}
 if(k==='fishdry'){root.ZRZCreatures.fish(c,'fish',0,0,1,0);R(c,3,8,26,1,'#ab8c59');for(let i=0;i<4;i++)R(c,11+i*3,16,1,8,'#9c7e57');}
}
function dish(c,id){const d=D.items[id],recipe=D.recipes.find(r=>r.id===id),ingredients=Object.keys(recipe?.ingredients||{}),soup=d.icon==='soup'||/Soup|Bowl|laba/.test(id),cake=/Cake|Toast|Pudding|Dumpling/.test(id),jar=d.icon==='jar';
 if(jar){vessel(c,'jar','#9a825b');P(c,[[13,21],[12,17],[20,17],[18,22]],leaf);return;}
 if(/Drink|Milk/.test(id)){vessel(c,'bottle',id==='summerDrink'?'#bb7888':cream);return;}
 if(id==='riceDumpling'){P(c,[[4,25],[14,5],[29,25]],ink);P(c,[[7,23],[14,8],[25,23]],leaf);R(c,9,18,15,2,cream);P(c,[[15,8],[17,9],[18,25],[16,25]],cream);return;}
 P(c,[[3,19],[29,19],[25,27],[7,27]],soup?'#6a8b83':'#a8b8a5');R(c,4,16,24,6,cream);R(c,7,14,18,5,soup?'#c4aa68':'#e1ce98');R(c,9,27,14,1,ink);
 if(soup){for(const x of [10,20]){R(c,x,4,1,3,'#a1aaa0');R(c,x+1,7,1,3,'#a1aaa0');}}
 if(id==='milkPudding'){P(c,[[8,14],[24,14],[22,26],[10,26]],'#7d9b90');P(c,[[10,13],[12,8],[21,8],[23,13]],cream);R(c,12,11,9,2,'#f9efcc');R(c,16,7,3,2,'#bd9560');return;}
 if(id==='autumnToast'){R(c,6,10,21,14,'#8a683e');R(c,8,9,17,13,'#c89c5a');R(c,11,12,5,5,cream);R(c,17,17,6,3,'#e1b767');return;}
 if(cake){for(const x of [7,17]){P(c,[[x,13],[x+3,10],[x+9,12],[x+10,21],[x,21]],id==='greensDumpling'?'#8aa06a':'#b48a4e');R(c,x+1,13,8,5,id==='greensDumpling'?'#a5bb80':'#e2bf79');if(id==='sweetpotatoCake'){R(c,x+2,12,2,8,'#b27658');R(c,x+6,12,2,8,'#f3d59d');}if(id==='sesameCake')for(let i=0;i<3;i++)R(c,x+2+i*2,14+i%2,1,1,ink);}return;}
 if(id==='spinachNoodle'){for(let i=0;i<4;i++){R(c,8+i*4,12,2,9,'#e4dca7');R(c,8+i*4,12,4,1,'#f2e6bf');}R(c,7,16,3,3,leaf);return;}
 const food=ingredients.filter(i=>!['oil','rice'].includes(i)).slice(0,3);if(!food.length)food.push('cabbage','mushroom');food.forEach((part,i)=>{c.save();c.translate(5+i*7,9+(i%2)*3);c.scale(.35,.35);drawBase(c,part);c.restore();});
}
function drawBase(c,id){if(id==='coin'){P(c,[[8,5],[24,5],[28,10],[28,24],[23,28],[8,28],[4,23],[4,10]],'#8f743d');R(c,7,9,18,14,'#d9ba68');R(c,10,6,12,20,'#e5c77e');R(c,13,12,7,8,ink);R(c,14,13,5,6,cream);return;}if(seedMap[id]){const seed=seedMap[id];vessel(c,'sack','#c4ad78');R(c,8,12,16,13,'#efe1b8');c.save();c.translate(9,12);c.scale(.44,.44);drawBase(c,seed.crop);c.restore();if(seed.kind!=='normal'){const x=seed.kind==='heirloom'?8:21;R(c,x,4,4,5,seed.kind==='heirloom'?'#b77854':'#72957c');R(c,x+1,5,2,seed.kind==='heirloom'?1:3,cream);}return;}
 if(root.ZRZTools.defs[id])return root.ZRZTools.drawTool(c,id,0,16,23,.5);if(vegetables[id])return shape(c,id);if(materials[id])return material(c,id);if(D.items[id]?.kind==='料理')return dish(c,id);if(D.items[id]||['hoe','water','hand','rod','axe','sickle','build','seed','care'].includes(id))return base(c,id,0,0,1);
 R(c,7,7,18,19,'#ad9771');R(c,9,9,14,15,cream);R(c,14,12,4,6,ink);R(c,15,21,2,2,ink);
}
const cache=new Map();
function draw(c,id,x=0,y=0,scale=1){c.save();c.imageSmoothingEnabled=false;c.translate(Math.round(x),Math.round(y));c.scale(scale,scale);if(root.document?.createElement){let tile=cache.get(id);if(!tile){tile=document.createElement('canvas');tile.width=tile.height=32;const ink=tile.getContext('2d');ink.imageSmoothingEnabled=false;drawBase(ink,id);if(cache.size>=224)cache.delete(cache.keys().next().value);cache.set(id,tile);}c.drawImage(tile,0,0);}else drawBase(c,id);c.restore();}
function status(s,id,side='bag'){const counts=E.counts(s,id,side),grades=counts.map((n,i)=>n?i:-1).filter(i=>i>=0),qty=s[side][id]||0,fresh=qty&&K.food(id)?K.fresh(s,id,side,qty):null;return {qty,grades,quality:grades.length>1?'混合品质':grades.length?K.grades[grades[0]]:'暂无库存',locked:E.locked(s,id),fresh:fresh?.label||'',urgent:!!fresh&&fresh.ratio<=.2};}
function describe(id){const d=D.items[id];if(!d)return {id,name:'未识别物品',category:'其他',family:'fallback'};return {id,name:d.name,category:E.category(id),family:seedMap[id]?'seed':vegetables[id]?.[0]||materials[id]?.[0]||(d.kind==='料理'?'dish':d.icon||id)};}
W.item=draw;root.ZRZItemIcons={draw,drawBase,status,describe,seedMap,materials,vegetables,size:32};
})(typeof window!=='undefined'?window:globalThis);
