const fs=require('node:fs');
global.window=globalThis;
for(const m of ['data','content','actions'])require('../../src/'+m+'.js');
const A=ZRZActions;
class Recorder {
 constructor(){this.rows=[];this.origin={x:0,y:0};this.angle=0;this.stack=[];this.fillStyle='';this.strokeStyle='';this.lineWidth=1;this.font='';}
 emit(data){this.rows.push({...data,origin:{...this.origin},angle:this.angle});}
 save(){this.stack.push({origin:{...this.origin},angle:this.angle,fillStyle:this.fillStyle,strokeStyle:this.strokeStyle,lineWidth:this.lineWidth,font:this.font});}
 restore(){Object.assign(this,this.stack.pop());}
 translate(x,y){const a=this.angle;this.origin={x:this.origin.x+Math.cos(a)*x-Math.sin(a)*y,y:this.origin.y+Math.sin(a)*x+Math.cos(a)*y};}
 rotate(a){this.angle+=a;}
 fillRect(x,y,w,h){this.emit({op:'rect',x,y,w,h,color:this.fillStyle});}
 beginPath(){this.path=[];this.shape=null;}
 moveTo(x,y){this.path=[{x,y}];}
 lineTo(x,y){this.path.push({x,y});}
 ellipse(x,y,rx,ry){this.shape={op:'oval',x,y,rx,ry};}
 arc(x,y,radius,start,end){this.shape={op:'arc',x,y,radius,start,end};}
 quadraticCurveTo(cx,cy,x,y){this.path.push({x:cx,y:cy},{x,y});this.shape={op:'quad',points:this.path};}
 fill(){this.emit({...this.shape,color:this.fillStyle});}
 stroke(){this.emit({...this.shape||{op:'line',points:this.path},color:this.strokeStyle,width:this.lineWidth});}
 fillText(text,x,y){this.emit({op:'text',text,x,y,color:this.fillStyle,font:this.font});}
}
let fishing={};
global.ZRZFishing={current:()=>fishing};
global.ZRZWorld={item:(c,id,x,y,scale)=>c.emit({op:'item',id,x,y,scale})};
const rows=[];
const directions={left:[-1,0],right:[1,0],up:[0,-1],down:[0,1]};
function add(kind,direction,progress,offset,animalType='',game={},known=false){
 const player={x:0,y:0,direction};
 const action={kind,progress,x:offset[0],y:offset[1],animalType,item:known?'cabbage':'unknown'};
 if(kind==='fish'){action.waterX=52.25;action.waterY=18.5;}
 const s={player,appearance:{skin:1}},c=new Recorder();
 fishing=game;
 A.draw(c,s,action,1.375);
 rows.push({player,action,skin:'#c69b74',clock:1.375,known,game,pose:A.pose(s,action),frame:c.rows});
}
for(const kind of Object.keys(A.catalog))for(const direction of Object.keys(directions))
 for(const t of [0,.12,.22,.3,.45,.51,.66,.78,.82,.9,1])
  for(const offset of [[40,25],[90,-45],[0,0]])add(kind,direction,t,offset,'',{},t>=.66);
for(const type of ['cow','sheep'])for(const direction of Object.keys(directions))
 for(const t of [.2,.31,.46,.65,.77,.81,.91])add('harvest',direction,t,[31,17],type);
for(const release of [false,true])for(const direction of Object.keys(directions))
 for(const t of [.84,.87,.9,.96,1])add('fish',direction,t,[40,25],'',{caught:true,plan:{release}},true);
const ballistic=[];
for(const t of [-1,0,.1,.25,.5,.75,1,2])for(const lift of [0,3,10,30])
 ballistic.push({from:{x:-12.25,y:7.75},to:{x:35.5,y:-18.25},t,lift,result:A.ballistic({x:-12.25,y:7.75},{x:35.5,y:-18.25},t,lift)});
fs.writeFileSync(process.argv[2],JSON.stringify({rows,ballistic}));
console.log('Exported '+rows.length+' original action frames and '+ballistic.length+' ballistic samples');
