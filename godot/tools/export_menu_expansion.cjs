const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
module.exports=function(){
 const panels=fs.readFileSync(path.join(__dirname,'../../src/panels.js'),'utf8');
 const line=panels.split(/\r?\n/).find(s=>s.includes("if(name==='menu')"));
 const start=line.indexOf("[['stories'"),end=line.indexOf('].map(',start)+1;
 if(start<0||end<=start)throw Error('Source expansion menu missing');
 const entries=vm.runInNewContext(line.slice(start,end));
 for(const file of ['economy-ui','item-icons-ui']){
  const source=fs.readFileSync(path.join(__dirname,'../../src/'+file+'.js'),'utf8');
  const match=source.match(/<button class="secondary" data-action="([^"]+)">([^<]+)<\/button>/);
  if(!match)throw Error('Source appended menu missing '+file);
  entries.push([match[1],match[2],'']);
 }
 return entries;
};
if(require.main===module){const entries=module.exports();fs.writeFileSync(process.argv[2],JSON.stringify(entries,null,2)+'\n');console.log('Exported '+entries.length+' source expansion menu entries');}
