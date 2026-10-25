const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const app=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8');
const start=app.indexOf('  function pollGamepad(now){'),end=app.indexOf('  function move(dt)',start);
if(start<0||end<0)throw Error('Original poll missing');
const source=app.slice(start,end),rows=[];
const patterns=[...Array.from({length:17},(_,i)=>({pressed:[i],axes:[0,0]})),{pressed:[],axes:[.2,-.2]},{pressed:[],axes:[.200000001,-.200000001]},{pressed:[],axes:[.5,-.5]},{pressed:[],axes:[.500000001,-.500000001]},{pressed:[12,13,14,15],axes:[0,0]},{pressed:[4,5],axes:[0,0]},{pressed:[0,1,2,3,4,5,9,10],axes:[0,0]},{pressed:[13,15,0],axes:[.75,-.6]},{pressed:[],axes:[-.200000001,.200000001]}];
for(const mode of ['play','panel','action','disabled','hidden','disconnected'])for(const kind of ['button','select','range','number','none'])for(const seed of [[],Array(17).fill(true)])for(const pattern of patterns){
 let calls=[],priorSelect=1,priorValue=5;
 const focus={tagName:kind==='select'?'SELECT':kind==='button'?'BUTTON':'INPUT',selectedIndex:1,options:[0,1,2],step:'2',min:'0',max:'10',value:'5',
 matches(selector){if(selector.startsWith('button')){calls.push({kind:'activate'});return kind==='button'}return kind==='range'||kind==='number'},
 dispatchEvent(){calls.push({kind:'horizontal',value:kind==='select'?this.selectedIndex-priorSelect:(Number(this.value)-priorValue)/2})},click(){},scrollIntoView(){}};
 const list=[0,1,2].map(i=>({...focus,offsetParent:{},focus(){calls.push({kind:'focus',value:i-1})},scrollIntoView(){}}));list[1]=focus;
 const context={padX:0,padY:0,padPrevious:structuredClone(seed),padMenuAt:0,inputMode:'keyboard',inputLocked:mode==='action',currentPanel:mode==='panel'?'menu':null,
 s:{settings:{gamepad:mode!=='disabled'}},document:{hidden:mode==='hidden',activeElement:focus},navigator:{getGamepads(){return context.sample.connected?[{connected:true,buttons:context.sample.buttons.map(pressed=>({pressed})),axes:context.sample.axes}]:[]}},
 $(){return {querySelectorAll(){return list}}},Event:class{},tools:Array.from({length:8},(_,i)=>({id:String(i)})),tool:'0',
 cancelAction(){calls.push({kind:'cancel'})},closePanel(){calls.push({kind:'close'})},cycleTarget(){calls.push({kind:'target'})},nearest(){calls.push({kind:'interact'});return kind==='none'?null:{}},interact(){},
 openPanel(name){calls.push({kind:name==='menu'?'menu':name})},setTool(id){const delta=Number(id)===1?1:-1;calls.push({kind:'tool',value:delta})},pending:{},queuedDestination:{},farmQueue:[],ranchQueue:[],kitchenTask:{},buildTask:{}};
 Object.defineProperty(context,'path',{get(){return []},set(){calls.push({kind:'interrupt'})}});
 vm.createContext(context);vm.runInContext(source,context);
 const samples=[];
 for(const [index,now]of [0,1,190,191,380,381,571,572,573,764,955].entries()){
  const buttons=Array(17).fill(false);if(index!==7)for(const i of pattern.pressed)buttons[i]=true;
  context.sample={connected:mode!=='disconnected',buttons,axes:pattern.axes};
  calls=[];focus.selectedIndex=1;focus.value='5';priorSelect=1;priorValue=5;context.inputMode='keyboard';
  context.pollGamepad(now);
  samples.push({now,sample:context.sample,expected:{commands:calls,motion:{x:context.padX,y:context.padY},previous:context.padPrevious,menu_at:context.padMenuAt,used:context.inputMode==='pad'}});
 }
 rows.push({mode,kind,seed,samples});
}
const precise=require('./export_world_precision.cjs');
fs.writeFileSync(process.argv[2],rows.map(row=>JSON.stringify(precise(row))).join('\n')+'\n');console.log(JSON.stringify({cases:rows.length,frames:rows.reduce((n,r)=>n+r.samples.length,0)}));
