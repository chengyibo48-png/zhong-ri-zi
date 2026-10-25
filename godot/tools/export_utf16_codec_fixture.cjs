const fs=require('node:fs'),exact=require('./export_world_precision.cjs'),fd=fs.openSync(process.argv[2],'w');let cases=0,units=0,pairs=0,keys=0;
function signature(v){
 if(typeof v==='string')return {string:Array.from({length:v.length},(_,i)=>v.charCodeAt(i))};
 if(Array.isArray(v))return {array:v.map(signature)};
 if(v&&typeof v==='object')return {object:Object.keys(v).map(k=>({key:Array.from({length:k.length},(_,i)=>k.charCodeAt(i)),value:signature(v[k])}))};
 if(typeof v==='number'){const b=Buffer.alloc(8);b.writeDoubleLE(v);return {number:b.toString('base64')};}
 return {literal:v};
}
function write(label,data,group){
 const expected=signature(data),encoded=exact(structuredClone(data)),raw=JSON.stringify(encoded);
 fs.writeSync(fd,JSON.stringify({label,group,raw,expected})+'\n');cases++;
}
for(let u=0;u<=0xffff;u++){write('unit-'+u,{text:String.fromCharCode(u)},'unit');units++;}
for(let i=0;i<1024;i++){const high=0xd800+(i*37)%1024,low=0xdc00+(i*71)%1024;write('pair-'+i,{text:String.fromCharCode(high,low)},'pair');pairs++;}
for(const units of [[0xd800,0xd800],[0xdc00,0xd800],[0xdc00,0xdc00],[0xd800,0,0xdc00],[97,0xd800,98,0xdc00,99],[0xd800,0xdc00,0xd800],[0xfffd,0xd800],[0xf0000&0xffff,0xfdd0,0xfdd1],[0x22,0x5c,0x75,0xd800]])write('mixed-'+units.join('-'),{text:String.fromCharCode(...units)},'mixed');
for(let i=0;i<128;i++){
 const k=String.fromCharCode(0xd800+i),v=String.fromCharCode(0xdc00+i);
 write('key-'+i,{[k]:{[v]:1.7234899999999997,note:k+v},text:v,marker:'__zrz_utf16_'+i+'__'},'keys');keys++;
}
const collisions=['__zrz_utf16_0__','__zrz_utf16_1__','__zrz_utf16_2__','\\ud800','literal "\\ud800"','\ud800','\udc00','\0','�'];
write('placeholder collisions',{tokens:collisions,strings:Object.fromEntries(collisions.map((s,i)=>[s,collisions[collisions.length-1-i]]))},'mixed');
write('all JSON escapes',{text:'"\\/\b\f\n\r\t\0\u001f\ud800😀',literal:'\\uD800',numbers:[0.1,1.7234899999999997]},'mixed');
const duplicateRaw='{"\\ud800":"first","\\ud800":"last","literal":"\\ud800","__zrz_utf16_0__":"\\udc00"}';
fs.writeSync(fd,JSON.stringify({label:'duplicate raw keys',group:'mixed',raw:duplicateRaw,expected:signature(JSON.parse(duplicateRaw))})+'\n');cases++;
fs.closeSync(fd);const counts={cases,units,pairs,keys};fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify(counts));console.log(JSON.stringify(counts));
