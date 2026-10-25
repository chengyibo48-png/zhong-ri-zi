(() => {
  const canvas = document.getElementById('canvas');
  canvas.dispatchEvent(new TouchEvent('touchend',{touches:[],targetTouches:[],changedTouches:[window.zrzQualityTouch],bubbles:true,cancelable:true}));
  return {released:true};
})()
