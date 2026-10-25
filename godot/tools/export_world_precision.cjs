// Preserve source binary64 coordinates across Godot's decimal JSON parser.
function exactNumbers(data){
 const entries=[];
 function visit(value,path=[]){
  if(typeof value==='number'&&Number.isFinite(value)&&!Number.isInteger(value)){
   const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);entries.push({path,bytes:bytes.toString('base64')});
  }else if(Array.isArray(value))value.forEach((child,index)=>visit(child,[...path,index]));
  else if(value&&typeof value==='object')for(const[key,child]of Object.entries(value))visit(child,[...path,key]);
 }
 delete data._float64_roundtrip;visit(data);
 if(entries.length>20000)throw Error('World binary64 metadata exceeds decoder limit');
 if(entries.length)data._float64_roundtrip={version:1,entries};
 return data;
}
module.exports=exactNumbers;
if(require.main===module){
 const fs=require('node:fs'),target=process.argv[2],data=JSON.parse(fs.readFileSync(target,'utf8'));
 fs.writeFileSync(target,JSON.stringify(exactNumbers(data),null,2)+'\n');
 console.log('Preserved '+(data._float64_roundtrip?.entries.length||0)+' fractional world coordinates');
}
