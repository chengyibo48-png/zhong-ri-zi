(() => {
 const C=window.ZRZCore,S=window.ZRZScenes,X=window.ZRZPanels;
 const s=C.initial(),cases=[];
 const units=Array.from({length:32},(_,i)=>i).concat([34,38,39,60,62,92,127,133,160,5760,8192,8203,8232,8233,8239,8287,12288,65279,65533]);
 for(let i=0xd800;i<=0xdfff;i++)units.push(i);
 for(const unit of units)cases.push({label:'unit-'+unit,name:String.fromCharCode(unit)});
 for(const name of ['a\0b','a\r\nb','a\rb','a\nb','a\tb','a'.repeat(17)+'😀','a'.repeat(16)+'😀','\ud800a\udc00','\ud800\udc00','__zrz_utf16_0__'])cases.push({label:'mixed-'+cases.length,name});
 const rows=[];
 const codeUnits=value=>Array.from({length:value.length},(_,i)=>value.charCodeAt(i));
 const element=document.createElement('div');
 for(const row of cases){
  s.atlas.pins=[{id:'pin-1',x:2831,y:1652,label:row.name}];s.atlas.nextId=2;
  S.pick(s,{id:'pin-1'});
  const html=X.render('map',null,s,{head(){return '<header></header>';}});
  element.innerHTML=html;
  const input=element.querySelector('#sc-pin-label');
  if(!input)throw Error('Original map input missing '+row.label);
  rows.push({label:row.label,name:codeUnits(row.name),expected:codeUnits(input.value)});
 }
 return {browser:navigator.userAgent,cases:rows.length,rows};
})()
