const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
global.ZRZPanels={render(){},mount(){},dispatch(){}};require('../../src/scenes-ui.js');
const exact=require('./export_world_precision.cjs'),fd=fs.openSync(process.argv[2],'w');let count=0;
for(const day of [0,13,28,56,84])for(const rotation of [0,1,2,3]){
 const s=ZRZCore.initial();s.day=day;ZRZBuild.ensure(s).land.orchard=true;s.upgrades.yard=true;
 s.building.layout=[{key:1,type:'bench',zone:'court',cell:0,rotation},{key:2,type:'flowerbed',zone:'orchard',cell:1,rotation},{key:3,type:'pot',zone:'home',cell:35,rotation}];s.building.nextId=4;
 s.plots.forEach((p,i)=>{if(i%3===0)p.crop='cabbage';else p.crop=null;});
 const fills=[];let inWorld=false;const stack=[];
 const c={canvas:{width:340,height:340},globalAlpha:1,fillStyle:'',save(){stack.push({inWorld,alpha:this.globalAlpha,color:this.fillStyle});},restore(){const q=stack.pop();inWorld=q.inWorld;this.globalAlpha=q.alpha;this.fillStyle=q.color;},scale(){inWorld=true;},fillRect(x,y,w,h){if(inWorld)fills.push({x,y,w,h,color:this.fillStyle,alpha:this.globalAlpha});},clearRect(){},beginPath(){},arc(){},fill(){},stroke(){},strokeRect(){},moveTo(){},lineTo(){},setLineDash(){},fillText(){}};
 ZRZScenes.drawMap(c,s,{mini:true});fs.writeSync(fd,JSON.stringify(exact({day,rotation,before:s,fills}))+'\n');count++;
}
fs.closeSync(fd);fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify({cases:count}));console.log(JSON.stringify({cases:count}));
