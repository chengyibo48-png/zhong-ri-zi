const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const path=process.argv[2];fs.writeFileSync(path,'');let count=0;
function write(row){
 const entries=[];function visit(value,parts){if(typeof value==='number'&&!Number.isInteger(value)){const b=Buffer.alloc(8);b.writeDoubleLE(value);entries.push({path:parts,bytes:b.toString('base64')});}else if(Array.isArray(value))value.forEach((v,i)=>visit(v,[...parts,i]));else if(value&&typeof value==='object')for(const [k,v]of Object.entries(value))visit(v,[...parts,k]);}
 visit(row,[]);if(entries.length)row._float64_roundtrip={version:1,entries};fs.appendFileSync(path,JSON.stringify(row)+'\n');count++;
}
const values=[0,.1,.95,1,1.25,2.75,25.75,99.95,99.99999999999999,100];
for(const stamina of values)for(const cost of [1,2,3,4.5])for(let mask=0;mask<8;mask++){
 const s=ZRZCore.initial();s.day=10;s.minutes=mask%2?1319.9:600.125;s.stamina=stamina;
 if(mask&1)s.skills.farming.choice='gentle';if(mask&2)s.buffs.laborDay=s.day;if(mask&4)s.kitchen.buff={kind:'暖胃',until:ZRZKitchen.now(s)+10};
 const before=structuredClone(s),time=mask%2?0.35:8.25;
 const ok=ZRZCore.labor(s,cost,time);
 write({kind:'labor',stamina,cost,time,mask,before,result:{ok},expected:{stamina:s.stamina,minutes:s.minutes}});
}
for(const stamina of values){
 const s=ZRZCore.initial();s.minutes=1310.125;s.stamina=stamina;const before=structuredClone(s),result=ZRZCore.rest(s);
 write({kind:'rest',before,result,expected:{stamina:s.stamina,minutes:s.minutes}});
}
for(const id of Object.keys(ZRZData.items).filter(id=>ZRZData.items[id].energy>0))for(const stamina of [20.75,99.95,99.99999999999999])for(const grade of [0,3]){
 const s=ZRZCore.initial();s.day=10;s.minutes=600.125;s.stamina=stamina;ZRZCore.add(s,id,3);
 if(grade)s.quality[id]=[0,0,s.bag[id]];
 const before=structuredClone(s),result=ZRZCore.eat(s,id);
 write({kind:'eat',id,grade,before,result,expected:{stamina:s.stamina,minutes:s.minutes,bag:s.bag,quality:s.quality,kitchen:s.kitchen}});
}
console.log('Actual source fractional stamina operations '+count);
