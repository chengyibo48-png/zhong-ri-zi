(function(root){
'use strict';const N=root.ZRZNpc,C=root.ZRZCore,D=root.ZRZData,V=root.ZRZVillage,X=root.ZRZPanels;
const ui={tab:'people',person:'all',kind:'all',search:''},esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const b=(text,op,id='',extra='')=>'<button class="secondary" data-action="np-'+op+'" data-id="'+esc(id)+'" '+extra+'>'+esc(text)+'</button>';
const status={offered:'想找人搭把手',accepted:'已约好 · 随时可做',postponed:'改天再说 · 可以重新答应',done:'已一起完成'};
const emotion={calm:'平静',happy:'笑着说',focus:'认真说',thought:'想了想'};
function request(s,id){
 const e=N.event(s,id);if(!e)return '';const p=N.profiles[id];
 let h='<section class="np-request"><h3>'+esc(p.request)+'</h3><p>'+status[e.status]+'</p>';
 if(e.status==='done')return h+'<p>记得你'+(e.method==='join'?'留下来一起动手':'送来了材料')+'的那一天。</p></section>';
 h+='<p>'+esc(p.materialUse)+'</p><p>送来 '+D.items[p.item].name+' ×2，或一起动手：20 分钟、3 体力。完成关系 +6；没有期限，改天再说不会扣关系。</p><div class="button-row">';
 const attr='data-day="'+e.day+'"';
 h+=e.status==='accepted'?b('一起动手','event',id,'data-op="join" '+attr)+b('送来两份材料','event',id,'data-op="supply" '+attr)+b('约好改天再说','event',id,'data-op="later" '+attr):b('我愿意搭把手','event',id,'data-op="accept" '+attr)+b('先说好，改天再来','event',id,'data-op="later" '+attr);
 return h+'</div></section>';
}
function dialogue(s,id,A){const n=D.npcs.find(n=>n.id===id),p=N.profiles[id],last=N.ensure(s).people[id].last,where=N.location(s,id);if(!n)return A.head('这位邻居还没来');
 let h=A.head(n.name+' · 坐下慢慢聊',n.role+' · '+C.stage(s.relations[id].points)+' · '+p.trait);
 h+='<div class="np-dialogue"><canvas class="dialogue-portrait" width="128" height="160" data-npc="'+id+'" data-emotion="'+(last?.emotion||'calm')+'" aria-label="'+n.name+'的对话神情"></canvas><div><span class="tag">'+emotion[last?.emotion||'calm']+' · '+esc(last?.category||'相遇')+'</span><p class="dialogue-quote typed-text">'+esc(last?.text||n.greeting)+'</p><small>'+esc(where.place+' · '+where.activity)+'</small></div></div>';
 h+='<div class="button-row">'+b('聊聊此刻','talk',id,'data-topic="auto"')+b('说点家常','talk',id,'data-topic="daily"')+b('请教生活窍门','talk',id,'data-topic="advice"')+b('说起一起经历的事','talk',id,'data-topic="memory"')+'</div>';
 h+=request(s,id)+'<section class="paper-note"><strong>对方惦记着</strong><p>'+esc(p.goal)+'</p><p>'+esc(C.storyReady(s,id).msg)+'</p></section><div class="button-row">'+A.button('聊聊个人故事','e-story-open',id,'secondary')+A.button('送一道菜','gift-list',id,'secondary')+A.button('邀请来吃饭','home','','secondary')+b('查看行踪与约定','person',id)+b('回看我们的对话','history',id)+'</div>';
 if(n.tier==='romance'&&s.stories[id].step>=4)h+=A.button(s.marriage.spouse===id?'我们的共同生活':s.partners[id]==='dating'?'商量婚礼':'认真表达心意',s.marriage.spouse===id?'home':s.partners[id]==='dating'?'e-wedding-open':'e-date',id,'secondary');
 return h;
}
function book(s,A){const f=N.ensure(s),people=D.npcs.filter(n=>(ui.person==='all'||n.id===ui.person)&&(!ui.search||[n.name,n.role,N.profiles[n.id].trait,N.profiles[n.id].goal].join(' ').includes(ui.search)));let h=A.head('禾溪邻里簿','每个人都有正在忙的事。看看行踪、记下约定，也翻翻真正聊过的话。');
 h+='<div class="button-row">'+b((ui.tab==='people'?'✓ ':'')+'行踪与近况','tab','people')+b((ui.tab==='history'?'✓ ':'')+'对话记录','tab','history')+'</div><div class="np-filters"><label>人物<select id="np-person"><option value="all">全部邻居</option>'+D.npcs.map(n=>'<option value="'+n.id+'" '+(ui.person===n.id?'selected':'')+'>'+n.name+'</option>').join('')+'</select></label><label>关键词<input id="np-search" maxlength="40" placeholder="姓名、职业、对话或线索" value="'+esc(ui.search)+'"></label>'+(ui.tab==='history'?'<label>内容<select id="np-kind">'+['all','故事','邻里小事','线索','回忆','节庆','日常'].map(k=>'<option value="'+k+'" '+(ui.kind===k?'selected':'')+'>'+(k==='all'?'全部内容':k)+'</option>').join('')+'</select></label>':'')+b('查找','filter')+b('清除筛选','clear')+'</div>';
 if(ui.tab==='history'){const rows=f.history.filter(r=>(ui.person==='all'||r.id===ui.person)&&(ui.kind==='all'||r.category===ui.kind)&&(!ui.search||(r.text+r.choice+D.npcs.find(n=>n.id===r.id).name).includes(ui.search))).slice().reverse();return h+'<p class="subtitle">最近 '+f.history.length+' 条已发生的交流 · 同日同一内容只收一条，最多保留 '+N.historyLimit+' 条。完整个人故事仍在故事页永久回看。</p><div class="np-history">'+(rows.map(r=>'<article><header><strong>'+D.npcs.find(n=>n.id===r.id).name+'</strong><span>'+r.category+' · 第 '+(r.day+1)+' 天 '+Math.floor(r.minute/60)+':'+String(r.minute%60).padStart(2,'0')+'</span></header><p>'+esc(r.text).replace(/\n/g,'<br>')+'</p>'+(r.choice?'<p class="paper-note">你的选择：'+esc(r.choice)+'</p>':'')+'</article>').join('')||'<p>还没有符合条件的对话。先沿路拜访一位邻居吧。</p>')+'</div>';}
 return h+'<div class="np-residents">'+people.map(n=>{const d=N.profiles[n.id],l=N.location(s,n.id),e=f.people[n.id].event;return '<article><div class="np-person-head"><canvas width="64" height="80" data-npc="'+n.id+'"></canvas><div><h3>'+n.name+'</h3><span>'+n.role+' · '+C.stage(s.relations[n.id].points)+'</span></div></div><p>'+d.trait+' · '+d.goal+'</p><p><strong>'+esc(l.place)+'</strong> · '+esc(l.activity)+'</p><small>'+esc(l.reason)+'</small><details><summary>今天的作息线索</summary><p>早间整理手边东西；白天'+d.work+'；午饭回屋；傍晚走访或散步；夜间回家。风雨天转为室内，节庆和赶集会调整去处。</p></details>'+(e?'<p class="np-promise">'+d.request+' · '+status[e.status]+'</p>':'')+'<div class="button-row">'+A.button('沿路去找对方','find-npc',n.id,'secondary')+b('回看对话','history',n.id)+'</div></article>';}).join('')+'</div>';
}
const old={render:X.render,after:X.after,dispatch:X.dispatch};X.panels.push('neighbors');X.render=(name,arg,s,A)=>name==='npc'?dialogue(s,arg,A):name==='neighbors'?book(s,A):old.render(name,arg,s,A);
X.after=(name,s,A)=>old.after(name,s,A)+(['menu','relations','map','calendar','stories'].includes(name)?'<div class="button-row"><button class="secondary" data-action="neighbors">禾溪邻里簿 · 行踪、约定与对话记录</button></div>':'');
X.dispatch=(a,id,data,ctx)=>{
 if(a==='e-story-choice'){ctx.queueNeighbor(id,'story',{choice:Number(data.choice)});return true;}
 if(!a.startsWith('np-'))return old.dispatch(a,id,data,ctx);
 if(a==='np-talk')ctx.queueNeighbor(id,'talk',{topic:data.topic});
 else if(a==='np-event')ctx.queueNeighbor(id,data.op,{day:Number(data.day)});
 else if(a==='np-tab'){ui.tab=id;ctx.render();}
 else if(a==='np-person'||a==='np-history'){ui.tab=a==='np-person'?'people':'history';ui.person=id;ui.search='';ui.kind='all';ctx.open('neighbors');}
 else if(a==='np-filter'){ui.person=document.getElementById('np-person').value;ui.search=document.getElementById('np-search').value.trim().slice(0,40);ui.kind=document.getElementById('np-kind')?.value||'all';ctx.render();}
 else if(a==='np-clear'){ui.person='all';ui.search='';ui.kind='all';ctx.render();}
 return true;
};
})(typeof window!=='undefined'?window:globalThis);
