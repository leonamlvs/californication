(() => {
  const bridge=window.islandTransition;
  bridge.active=!document.hidden && document.hasFocus();
  bridge.lifetime=new AbortController();
  const update=()=>{bridge.active=!document.hidden && document.hasFocus();};
  for(const event of ['focus','blur']) window.addEventListener(event,update,{signal:bridge.lifetime.signal});
  document.addEventListener('visibilitychange',update,{signal:bridge.lifetime.signal});
  if (new URLSearchParams(location.search).has('capture')) return;
  document.getElementById('transition-controls')?.remove();
  const bar=document.createElement('div');bar.id='transition-controls';
  Object.assign(bar.style,{position:'fixed',bottom:'8px',left:'8px',zIndex:30,display:'flex',gap:'6px',flexWrap:'wrap'});
  for(const [label,command] of [['Pause','pause'],['Play','play'],['Replay','restart'],['Attract','attract']]){
    const button=document.createElement('button');button.textContent=label;
    button.onclick=e=>{e.stopPropagation();window.islandTransition.command(command);};bar.append(button);
  }
  const full=document.createElement('button');full.textContent='Fullscreen';
  full.onclick=()=>document.fullscreenElement?document.exitFullscreen():document.documentElement.requestFullscreen();
  bar.append(full);document.body.append(bar);
})();
