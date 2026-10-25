const fs=require('node:fs'),vm=require('node:vm');
const app=fs.readFileSync(require('node:path').join(__dirname,'../../src/app.js'),'utf8');
const functions=app.slice(app.indexOf("  function sound(type = 'action')"),app.indexOf('  function save('));
function context(settings,active=false,{hidden=false,panel=false,next=0,season=0,wet=false,night=false,town=false,indoors=false}={}){
 const nodes=[];
 class Param{constructor(){this.events=[];this.value=0;}setValueAtTime(v,t){this.events.push([v,t]);}linearRampToValueAtTime(v,t){this.events.push([v,t]);}exponentialRampToValueAtTime(v,t){this.events.push([v,t]);}}
 class Node{constructor(kind){this.kind=kind;this.type='sine';this.frequency=new Param();this.gain=new Param();this.Q=new Param();this.Q.value=1;this.links=[];nodes.push(this);}connect(n){this.links.push(n);}start(t){this.startAt=t;}stop(t){this.stopAt=t;}}
 class AC{constructor(){this.currentTime=0;this.sampleRate=16;this.state='running';this.destination={};}resume(){this.state='running';}createOscillator(){return new Node('osc');}createGain(){return new Node('gain');}createBufferSource(){return new Node('noise');}createBiquadFilter(){return new Node('filter');}createBuffer(ch,n,rate){const data=new Float32Array(n);return {getChannelData:()=>data};}}
 const ctx={window:{AudioContext:AC},soundContext:active?new AC():null,s:{settings,day:0,minutes:night?1140.1:1140,scene:town?'town':wet?'river':'farm',village:{interior:indoors?'home':null}},document:{hidden},currentPanel:panel?'menu':null,melodyAt:next,C:{calendar:()=>({season}),weather:()=>wet?'雨':'晴'},Math:Object.create(Math)};
 ctx.Math.random=()=>.75;vm.createContext(ctx);vm.runInContext(functions,ctx);
 return{ctx,nodes};
}
function voice(osc,mode){
 const gains=osc.links[0].kind==='filter'?osc.links[0].links[0].gain.events:osc.links[0].gain.events;
 if(osc.kind==='noise')return{wave:'noise',start:osc.startAt,end:osc.stopAt,filter:osc.links[0].frequency.value,noise:.2,q:osc.links[0].Q.value,gain:[gains[0][0],gains[1][0],gains[1][1],gains[2][0],gains[2][1]]};
 const f=osc.frequency.events;
 const start=f.length?f[0][0]:osc.frequency.value,end=f.length?f[1][0]:start;
 const d=f.length?f[1][1]-f[0][1]:0;
 const origin=mode==='ambient'&&osc.type==='sine'?0:osc.startAt;
 const row={wave:osc.type,start:osc.startAt,end:osc.stopAt,frequency:[start,end,d],gain:[gains[0][0],gains[1][0],gains[1][1]-origin,gains[2][0],gains[2][1]-origin]};
 if(mode==='ambient'&&osc.type==='sine')row.gain_origin=0;
 return row;
}
const settings={sound:true,volume:.2,effects:.6,music:.35,ambient:.3},sounds=[],ambient=[];
for(const sound of [false,true])for(const volume of [0,.2,1])for(const effects of [0,.6,1])for(const kind of ['water','hoe','build','chop','harvest','gather','seed','feed','door','read','trade','greet','good','soft','music','action','fish','steam','brush','bell']){
 const s={...settings,sound,volume,effects},r=context(s);r.ctx.sound(kind);
 sounds.push({kind,settings:s,expected:{activate:r.ctx.soundContext!==null,voices:r.nodes.filter(n=>n.kind==='osc').map(n=>voice(n,'sound'))}});
}
for(let i=0;i<384;i++){
 const options={season:i%4,wet:!!(i&4),night:!!(i&8),town:!!(i&16),indoors:!!(i&32),hidden:i>=256&&!!(i&1),panel:i>=256&&!!(i&2),next:i>=256?8:0};
 const s={...settings,music:i%3===0?0:i%3===1?.35:1,ambient:i%3===2?0:.3,volume:i>=256&&!!(i&64)?0:.2,sound:i>=256&&!!(i&16)?false:true};
 const active=i<256||!(i&32),seconds=i>=256&&!!(i&8)?7.999:16+i%5*.1,r=context(s,active,options);r.ctx.ambient(seconds);
 const oscs=r.nodes.filter(n=>['osc','noise'].includes(n.kind));
 ambient.push({seconds,active,settings:s,options,expected:{next:r.ctx.melodyAt,music:oscs.filter(n=>n.kind==='osc'&&n.type==='triangle').map(n=>voice(n,'ambient')),ambient:oscs.filter(n=>n.kind==='noise'||n.type==='sine').map(n=>voice(n,'ambient'))}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({sounds,ambient}));console.log('Actual app.js audio: '+sounds.length+' sounds, '+ambient.length+' ambient frames');
