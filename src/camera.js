(function(root){
  'use strict';
  const clamp=(v,min,max)=>Math.max(min,Math.min(Math.max(min,max),v));
  function geometry(width,height,player,zoom=1){
    width=Math.max(1,width);height=Math.max(1,height);
    const scale=Math.max(width/800,height/480)*zoom,viewWidth=width/scale,viewHeight=height/scale;
    return {width,height,scale,x:clamp(player.x-viewWidth/2,0,1920-viewWidth),y:clamp(player.y-viewHeight*.48,0,1152-viewHeight),viewWidth,viewHeight};
  }
  const toWorld=(v,x,y)=>({x:x/v.scale+v.x,y:y/v.scale+v.y});
  const toScreen=(v,x,y)=>({x:(x-v.x)*v.scale,y:(y-v.y)*v.scale});
  class Camera{
    constructor(canvas){this.canvas=canvas;this.view=geometry(960,576,{x:911,y:500});this.scene=null;this.buffer=document.createElement('canvas');this.buffer.width=1920;this.buffer.height=1152;}
    update(s,dt=0,snap=false){const r=this.canvas.getBoundingClientRect(),target=geometry(r.width,r.height,s.player,s.settings.zoom||1),dpr=Math.min(window.devicePixelRatio||1,2),w=Math.round(r.width*dpr),h=Math.round(r.height*dpr);if(this.canvas.width!==w||this.canvas.height!==h){this.canvas.width=w;this.canvas.height=h;snap=true;}const weight=snap||this.scene!==s.scene||this.view.scale!==target.scale?1:1-Math.exp(-dt*12);target.x=this.view.x+(target.x-this.view.x)*weight;target.y=this.view.y+(target.y-this.view.y)*weight;this.view=target;this.scene=s.scene;}
    paint(){const c=this.canvas.getContext('2d'),v=this.view;c.imageSmoothingEnabled=false;c.drawImage(this.buffer,Math.round(v.x),Math.round(v.y),v.viewWidth,v.viewHeight,0,0,this.canvas.width,this.canvas.height);}
    toWorld(x,y){return toWorld(this.view,x,y);}toScreen(x,y){return toScreen(this.view,x,y);}
  }
  const api={geometry,toWorld,toScreen,Camera};root.ZRZCamera=api;if(typeof module!=='undefined')module.exports=api;
})(typeof globalThis!=='undefined'?globalThis:window);
