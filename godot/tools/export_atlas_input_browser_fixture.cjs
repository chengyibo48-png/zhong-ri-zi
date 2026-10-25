const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),source=path.join(root,'godot/artifacts/atlas-input-browser-source-20261008.json');
const fixture=JSON.parse(fs.readFileSync(source,'utf8')),files=[];
function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name);if(e.isDirectory())walk(p);else if(e.isFile())files.push(p);}}
walk(path.join(root,'src'));const h=crypto.createHash('sha256');
for(const f of files.sort()){h.update(path.relative(root,f).split(path.sep).join('/'));h.update(fs.readFileSync(f));}
if(h.digest('hex')!==fixture.original_source_sha256)throw Error('Original DOM fixture invalidated: source changed; recapture using independent browser session');
if(!fixture.success||fixture.data.result.rows.length!==2109)throw Error('Incomplete real browser fixture');
fs.copyFileSync(source,process.argv[2]);console.log('Real original browser DOM cases: 2109; source fingerprint verified');
