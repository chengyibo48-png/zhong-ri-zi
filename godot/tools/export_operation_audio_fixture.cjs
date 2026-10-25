const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','actions'])require('../../src/'+name+'.js');
const app=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8'),apply=app.split('\n').find(s=>s.includes('  function apply(result, refresh'));
const confirmations=[],fills=[];
for(let mask=0;mask<128;mask++){
 const settings={sound:!!(mask&1),vibration:!!(mask&2),volume:mask&4?.2:0,effects:mask&8?.6:0};
 const ok=!!(mask&16),refresh=!!(mask&32),panel=!!(mask&64),sounds=[],rumble=[];
 const ctx={s:{settings},currentPanel:panel?'menu':null,panelArg:'',sound:(kind)=>sounds.push(kind),save(){},update(){},renderPanel(){},toast(){},navigator:{getGamepads:()=>[null,{vibrationActuator:{playEffect:(type,args)=>{rumble.push({type,...args});return{catch(){}};}}}]}};
 vm.createContext(ctx);vm.runInContext(apply,ctx);const result=ctx.apply({ok,msg:'结果'},refresh);
 confirmations.push({settings,ok,refresh,panel,result,sounds,rumble,played:sounds.filter(()=>settings.sound&&settings.volume>0&&settings.effects>0)});
}
for(const water of [0,119,120])for(const money of [0,5,6,30])for(const stamina of [0,1,2,3,99])for(const irrigation of [false,true]){
 const s=ZRZCore.initial();s.day=10;s.minutes=600;s.farm.water=water;s.money=money;s.stamina=stamina;s.upgrades.irrigation=irrigation;s.waterReserve=1;
 const before=structuredClone(s),result=ZRZFarming.fillWater(s);
 fills.push({before,result,after:{water:s.farm.water,money:s.money,stamina:s.stamina,minutes:s.minutes,reserve:s.waterReserve}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({confirmations,fills}));console.log('Actual apply confirmations '+confirmations.length+'; F.fillWater '+fills.length);
