(function(root){
'use strict';const F=root.ZRZFeedback;
F.draw=function(c,s,dt,point,tool,view){const r=F.runtime(s),prefs=F.ensure(s).prefs;if(r.room!==s.village.interior){if(r.room!==undefined)r.floats=[];r.room=s.village.interior;}r.clock+=Math.max(0,Math.min(.1,dt));r.floats=r.floats.filter(f=>r.clock-f.at<4.5);c.save();c.translate(-view.x,-view.y);
 if(point){const d=F.describe(s,point,tool),w=point.kind==='plot'?21:16;c.strokeStyle=d.ready?'#ffecc0':'#e2c0ad';c.lineWidth=2;if(!d.ready)c.setLineDash([3,3]);c.beginPath();c.ellipse(point.x,point.y+4,w,w*.42,0,0,7);c.stroke();c.setLineDash([]);c.fillStyle=d.ready?'#ffecc0':'#e2c0ad';c.fillRect(point.x-2,point.y-45,4,4);}
 if(prefs.floating!=='off'){
  const rows=prefs.floating==='compact'?r.floats.slice(-1):r.floats.slice(-3);c.font='bold 11px Microsoft YaHei';c.textAlign='center';
  rows.forEach((f,i)=>{const age=r.clock-f.at,raw=f.item?'+'+f.qty+' '+F.grades[f.grade]+root.ZRZData.items[f.item].name:f.text;if(!raw)return;const maxWidth=Math.max(90,Math.min(260,view.viewWidth-24));let text=raw;while(c.measureText(text).width>maxWidth&&text.length>8)text=text.slice(0,-2)+'…';const lift=prefs.motion==='reduced'?0:Math.min(10,age*4),side=f.x+120>view.x+view.viewWidth-90?-120:120,x=Math.max(view.x+90,Math.min(view.x+view.viewWidth-90,f.x+side)),y=Math.max(view.y+30,f.y-15-i*19-lift),w=c.measureText(text).width+16;c.globalAlpha=Math.min(1,(4.5-age)*2);c.fillStyle='#f9edcfec';c.fillRect(Math.round(x-w/2),Math.round(y-12),Math.ceil(w),17);c.fillStyle='#385844';c.fillText(text,x,y);});
 }
 c.restore();};
})(typeof window!=='undefined'?window:globalThis);
