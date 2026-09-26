/* Loaded only by `node server.cjs --dev`; not included in the offline release. */
(function(){
  if(!window.ZRZ_DEV)return;
  const C=window.ZRZCore,D=window.ZRZData;
  const option=(k,n)=>'<option value="'+k+'">'+n+'</option>';
  window.ZRZDebug={render(s){return '<h2 id="modal-title">开发检查台</h2><p class="subtitle">仅开发服务启用。修改当前开发存档；正式离线构建没有此入口。</p><div class="form-inline"><label>推进天数 <input id="debug-days" type="number" min="1" max="112" value="1"></label><button class="mini-btn" data-debug="days">推进日期</button><select id="debug-scene">'+Object.entries(D.scenes).map(([id,v])=>option(id,v.name)).join('')+'</select><button class="mini-btn" data-debug="travel">传送</button></div><div class="form-inline"><select id="debug-item">'+Object.entries(D.items).map(([id,v])=>option(id,v.name)).join('')+'</select><input id="debug-qty" type="number" min="1" max="100" value="10"><button class="mini-btn" data-debug="item">生成物品</button><button class="mini-btn" data-debug="money">增加测试资金</button></div><div class="form-inline"><select id="debug-npc">'+D.npcs.map(n=>option(n.id,n.name)).join('')+'</select><button class="mini-btn" data-debug="relation">关系设为信任</button><button class="mini-btn" data-debug="reset">重置此人事件</button></div><div class="form-inline"><button class="primary" data-debug="fixture">载入功能验收场景</button><button class="secondary" data-action="save">导入导出开发存档</button></div><pre class="debug-state">'+JSON.stringify({day:s.day,scene:s.scene,plot:s.plots[0],projects:s.projects,stories:s.stories,processing:s.processing,diagnostics:window.ZRZDiagnostics()},null,2)+'</pre>';}};
  const button=document.createElement('button');button.className='hud-icon';button.dataset.action='debug';button.textContent='开发';button.setAttribute('aria-label','开发检查台');document.querySelector('.hud-actions').appendChild(button);
  document.addEventListener('click',e=>{const b=e.target.closest('[data-debug]');if(!b)return;let s=window.ZRZDeveloper.state();const v=id=>document.getElementById(id).value;
    if(b.dataset.debug==='days'){const count=Math.min(112,Math.max(1,Number(v('debug-days'))||1));for(let i=0;i<count;i++)C.nextDay(s);}
    if(b.dataset.debug==='travel'){s.scene=v('debug-scene');s.player={...window.ZRZLandscape.spawn(s.scene)};}
    if(b.dataset.debug==='item')C.add(s,v('debug-item'),Math.min(100,Math.max(1,Math.floor(Number(v('debug-qty'))||1))));
    if(b.dataset.debug==='money')s.money+=1000;
    if(b.dataset.debug==='relation')s.relations[v('debug-npc')].points=100;
    if(b.dataset.debug==='reset'){const id=v('debug-npc');s.stories[id]={step:0,choices:[],lastDay:-1};delete s.partners[id];if(s.marriage.spouse===id)s.marriage={spouse:null,day:-1,weekly:{},memories:[]};}
    if(b.dataset.debug==='fixture'){
      s=C.initial('验收小院','不设定');s.flags.introDone=true;s.flags.firstHarvest=true;s.flags.firstCook=true;s.flags.firstDish=true;s.day=90;s.money=5000;
      for(const id of Object.keys(D.items))C.add(s,id,30);C.add(s,'wood',200);C.add(s,'bamboo',200);
      for(const id of Object.keys(D.upgrades)){if(id==='irrigation')continue;C.upgrade(s,id);}
      s.knownRecipes=D.recipes.map(r=>r.id);for(const id of Object.keys(s.skills))s.skills[id].xp=30;
      for(const n of D.npcs)s.relations[n.id].points=90;
      s.stories.qiao={step:3,choices:[0,0,0],lastDay:89};
    }
    window.ZRZDeveloper.replace(s);
  });
})();
