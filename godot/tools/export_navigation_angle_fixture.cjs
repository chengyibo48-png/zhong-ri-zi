const fs=require('node:fs'),exact=require('./export_world_precision.cjs'),rows=[];
for(let y=-40;y<=40;y++)for(let x=-40;x<=40;x++)rows.push({x,y,result:Math.atan2(y,x)});
for(const y of [0,-0,Infinity,-Infinity,1e-300,-1e-300,1e300,-1e300])for(const x of [0,-0,Infinity,-Infinity,1e-300,-1e-300,1e300,-1e300]){
 const encode=n=>{const b=Buffer.alloc(8);b.writeDoubleLE(n);return b.toString('base64');};rows.push({bytes:true,x:encode(x),y:encode(y),result:encode(Math.atan2(y,x))});
}
fs.writeFileSync(process.argv[2],JSON.stringify(exact({rows})));console.log(rows.length);
