(function(root) {
  'use strict';
  const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
  // One uniform scale fills the viewport. Follow the player without stretching.
  function geometry(width,height,player,zoom=1) {
    width=Math.max(1,width);height=Math.max(1,height);
    const scale=Math.max(width/960,height/576)*zoom;
    const viewWidth=width/scale,viewHeight=height/scale;
    return {width,height,scale,x:clamp(player.x-viewWidth/2,0,960-viewWidth),y:clamp(player.y-viewHeight*.46,0,576-viewHeight),viewWidth,viewHeight};
  }
  function toWorld(view,x,y){return {x:x/view.scale+view.x,y:y/view.scale+view.y};}
  function toScreen(view,x,y){return {x:(x-view.x)*view.scale,y:(y-view.y)*view.scale};}
  class Camera {
    constructor(canvas){this.canvas=canvas;this.view=geometry(960,576,{x:480,y:288});this.scene=null;this.buffer=document.createElement('canvas');this.buffer.width=960;this.buffer.height=576;}
    update(state,dt=0,snap=false){
      const rect=this.canvas.getBoundingClientRect(),target=geometry(rect.width,rect.height,state.player,state.settings.zoom||1),dpr=Math.min(window.devicePixelRatio||1,2);
      const width=Math.round(rect.width*dpr),height=Math.round(rect.height*dpr);
      if(this.canvas.width!==width||this.canvas.height!==height){this.canvas.width=width;this.canvas.height=height;snap=true;}
      const jump=snap||this.scene!==state.scene||this.view.scale!==target.scale;
      const weight=jump?1:1-Math.exp(-dt*10);
      target.x=this.view.x+(target.x-this.view.x)*weight;target.y=this.view.y+(target.y-this.view.y)*weight;
      this.view=target;this.scene=state.scene;
    }
    paint(){const c=this.canvas.getContext('2d'),v=this.view;c.imageSmoothingEnabled=false;c.clearRect(0,0,this.canvas.width,this.canvas.height);c.drawImage(this.buffer,v.x,v.y,v.viewWidth,v.viewHeight,0,0,this.canvas.width,this.canvas.height);}
    toWorld(x,y){return toWorld(this.view,x,y);}
    toScreen(x,y){return toScreen(this.view,x,y);}
  }
  const api={geometry,toWorld,toScreen,Camera};root.ZRZCamera=api;if(typeof module!=='undefined')module.exports=api;
})(typeof globalThis!=='undefined'?globalThis:window);
