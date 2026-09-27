(function(root){
'use strict';
const X=root.ZRZPanels,H=root.ZRZCharacters,A=root.ZRZArt;
const select=(id,entries)=>'<select id="'+id+'">'+entries.map(([k,v])=>'<option value="'+k+'">'+v+'</option>').join('')+'</select>';
let previewState=null,running=false;
const original={render:X.render,mount:X.mount};
X.render=(name,arg,s,api)=>{
 let html=original.render(name,arg,s,api);if(name!=='appearance')return html;
 const preview='<section class="character-preview" aria-label="换装预览"><div><canvas width="128" height="160" data-character-portrait aria-label="主角半身肖像"></canvas></div><div class="character-turns">'+H.directions.map((d,i)=>'<figure><canvas width="96" height="100" data-character-direction="'+d+'" aria-label="'+['正面','左侧','背面','右侧'][i]+'人物预览"></canvas><figcaption>'+['正面','左侧','背面','右侧'][i]+'</figcaption></figure>').join('')+'</div></section><div class="character-preview-controls"><label>试试看'+select('character-motion',[['idle','站立'],['walk','行走'],['work','试用水壶']])+'</label><label>试衣天气'+select('character-weather-preview',[['fair','晴日'],['rain','雨日'],['cold','冬日']])+'</label></div><p class="subtitle">四向造型与肖像共用外观。试衣不会改变天气或消耗物品；换好衣服的动作结束后保存。</p>';
 html=html.replace('<div class="appearance-form">',preview+'<div class="appearance-form">');
 const more='<label>服装样式'+select('appearance-outfit',Object.entries(H.outfits))+'</label><label>发色'+select('appearance-hairColor',H.hairNames.map((v,i)=>[i,v]))+'</label><label><input id="appearance-bag" type="checkbox"> 背上帆布挎包</label><label><input id="appearance-weatherDress" type="checkbox"> 自动搭配雨披与冬围巾（纯外观）</label>';
 return html.replace('<label><input id="appearance-hat"',more+'<label><input id="appearance-hat"');
};
function draft(s){const a={...s.appearance};for(const k of ['shirt','hair','skin','hairColor']){const el=document.getElementById('appearance-'+k);if(el)a[k]=Number(el.value);}for(const k of ['hat','bag','weatherDress']){const el=document.getElementById('appearance-'+k);if(el)a[k]=el.checked;}a.outfit=document.getElementById('appearance-outfit')?.value||a.outfit;a.weather=document.getElementById('character-weather-preview')?.value||'fair';return a;}
function draw(time){const portrait=document.querySelector('[data-character-portrait]');if(!portrait||!previewState)return false;const a=draft(previewState),motion=document.getElementById('character-motion').value,quiet=previewState.feedback?.prefs.motion==='reduced',t=quiet?0:time/1000;A.portrait(portrait.getContext('2d'),128,160,null,a);
 for(const el of document.querySelectorAll('[data-character-direction]')){const c=el.getContext('2d');c.imageSmoothingEnabled=false;c.clearRect(0,0,96,100);c.fillStyle=a.weather==='cold'?'#d1ddd6':'#dce2c9';c.fillRect(0,0,96,100);c.save();c.translate(48,86);c.scale(2,2);const direction=el.dataset.characterDirection,ux=direction==='left'?-1:direction==='right'?1:0;const virtual={...previewState,appearance:a,player:{x:0,y:0,direction}},sequence={kind:'water',progress:quiet?.5:(t%2)/2,x:ux*32,y:direction==='up'?-28:direction==='down'?28:0};if(motion==='work'&&direction==='up')root.ZRZActions.draw(c,virtual,sequence,t);A.character(c,0,0,null,t,motion==='walk'&&!quiet,a.hat,direction,{...a,working:motion==='work',lean:motion==='work'?root.ZRZActions.pose(virtual,sequence):null});if(motion==='work'&&direction!=='up')root.ZRZActions.draw(c,virtual,sequence,t);c.restore();}
 return !quiet;
}
function tick(t){if(!draw(t)){running=false;return;}requestAnimationFrame(tick);}
X.mount=s=>{original.mount(s);if(!document.getElementById('appearance-outfit'))return;previewState=s;H.ensure(s);for(const k of ['outfit','hairColor'])document.getElementById('appearance-'+k).value=s.appearance[k];for(const k of ['bag','weatherDress'])document.getElementById('appearance-'+k).checked=s.appearance[k];draw(0);if(!running&&s.feedback?.prefs.motion!=='reduced'){running=true;requestAnimationFrame(tick);}};
document.addEventListener('change',e=>{if(previewState&&/^(appearance-|character-)/.test(e.target.id))draw(performance.now());});
})(typeof window!=='undefined'?window:globalThis);

