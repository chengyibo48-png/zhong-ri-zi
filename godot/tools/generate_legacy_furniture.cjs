const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
global.window=globalThis;
for(const name of ['data','content','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','building'])require('../../src/'+name+'.js');
function color(c){if(/^#[a-f0-9]{8}$/i.test(c))return {fill:c.slice(0,7),opacity:parseInt(c.slice(7),16)/255};return {fill:c,opacity:1};}
class SVG{
 constructor(x,y){this.m=[1,0,0,1,96-x,192-y];this.stack=[];this.elements=[];this.commands=[];this.fillStyle='#000000';}
 save(){this.stack.push({m:[...this.m],fillStyle:this.fillStyle});}
 restore(){Object.assign(this,this.stack.pop());}
 translate(x,y){const [a,b,c,d,e,f]=this.m;this.m=[a,b,c,d,a*x+c*y+e,b*x+d*y+f];}
 scale(x,y){const [a,b,c,d,e,f]=this.m;this.m=[a*x,b*x,c*y,d*y,e,f];}
 point(x,y){const[a,b,c,d,e,f]=this.m;return {x:a*x+c*y+e,y:b*x+d*y+f};}
 emit(shape){
  const paint=color(this.fillStyle),style=' fill="'+paint.fill+'" fill-opacity="'+paint.opacity+'"';
  if(shape.op==='rect'){
   const q=this.point(shape.x,shape.y),w=shape.w*this.m[0],h=shape.h*this.m[3];
   this.elements.push('<rect x="'+q.x+'" y="'+q.y+'" width="'+w+'" height="'+h+'"'+style+'/>');
   this.commands.push({op:'rect',x:q.x,y:q.y,w,h,...paint});
  }else if(shape.op==='ellipse'){
   const q=this.point(shape.x,shape.y),rx=shape.rx*this.m[0],ry=shape.ry*this.m[3];
   this.elements.push('<ellipse cx="'+q.x+'" cy="'+q.y+'" rx="'+rx+'" ry="'+ry+'"'+style+'/>');
   this.commands.push({op:'ellipse',x:q.x,y:q.y,rx,ry,...paint});
  }else if(shape.op==='poly'){
   const points=shape.points.map(([x,y])=>this.point(x,y));
   this.elements.push('<polygon points="'+points.map(p=>p.x+','+p.y).join(' ')+'"'+style+'/>');
   this.commands.push({op:'poly',points,...paint});
  }else throw Error('Unsupported furniture drawing '+shape.op);
 }
 fillRect(x,y,w,h){this.emit({op:'rect',x,y,w,h});}
 beginPath(){this.shape=null;this.points=[];}
 moveTo(x,y){this.points.push([x,y]);}
 lineTo(x,y){this.points.push([x,y]);}
 closePath(){}
 ellipse(x,y,rx,ry,rotation=0){if(rotation)throw Error('Unexpected ellipse rotation');this.shape={op:'ellipse',x,y,rx,ry};}
 fill(){this.emit(this.shape||{op:'poly',points:this.points});}
 svg(){return '<svg xmlns="http://www.w3.org/2000/svg" width="224" height="224" viewBox="0 0 224 224">'+this.elements.join('')+'</svg>';}
}
const destination=path.resolve(__dirname,'../art/legacy_furniture');fs.mkdirSync(destination,{recursive:true});
const assets={},slots=ZRZCore.layoutSlots.map(p=>({x:p.x+1920,y:p.y+1152}));
let comparisons=0;
for(const id of Object.keys(ZRZData.furniture))for(let season=0;season<4;season++)for(let col=0;col<6;col++){
 const p=slots[col],c=new SVG(p.x,p.y);ZRZWorld.drawFurniture(c,id,p.x,p.y,season);
 const name=id+'-'+season+'-'+col+'.svg',text=c.svg();
 fs.writeFileSync(path.join(destination,name),text);
 assets[id+'/'+season+'/'+col]={path:'res://art/legacy_furniture/'+name,sha256:crypto.createHash('sha256').update(text).digest('hex'),commands:c.commands.length};
 // Verify every source row has the same local artwork for this seed/column.
 for(let slot=col;slot<24;slot+=6){
  const p=slots[slot],other=new SVG(p.x,p.y);ZRZWorld.drawFurniture(other,id,p.x,p.y,season);
  if(JSON.stringify(other.commands)!==JSON.stringify(c.commands))throw Error('Row-dependent source art '+id+'/'+slot);
  comparisons++;
 }
}
fs.writeFileSync(path.resolve(__dirname,'../data/legacy_furniture.json'),JSON.stringify({slots,offset:{x:-96,y:-192},size:{x:224,y:224},assets},null,2));
console.log('Source legacy furniture: '+Object.keys(assets).length+' SVG assets; '+comparisons+' original slot/season comparisons passed.');
