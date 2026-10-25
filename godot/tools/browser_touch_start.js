(() => {
  const canvas = document.getElementById('canvas');
  const rect = canvas.getBoundingClientRect();
  const point = new Touch({identifier:17, target:canvas,
    clientX:rect.left+105, clientY:rect.top+260,
    pageX:rect.left+105, pageY:rect.top+260,
    screenX:105,screenY:260,radiusX:8,radiusY:8,force:1});
  window.zrzQualityTouch = point;
  canvas.dispatchEvent(new TouchEvent('touchstart',{touches:[point],targetTouches:[point],changedTouches:[point],bubbles:true,cancelable:true}));
  return {injected:true,canvas:[canvas.width,canvas.height],ua:navigator.userAgent};
})()
