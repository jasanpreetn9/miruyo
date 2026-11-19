(function(){
// Pointer gesture helper shared by the gesture prototypes.
// drag(e,{axis:'x'|'y'|'xy', slop, longMs, onLong, onMove(dx,dy), onEnd(dx,dy,vx,vy), onCancel(lock)})
function drag(e,o){
  if(e.button>0) return;
  const sx=e.clientX, sy=e.clientY, slop=o.slop||8; let lock=null, last={x:sx,y:sy,t:performance.now()}, vx=0, vy=0;
  const lt=o.onLong?setTimeout(()=>{ if(!lock){ lock='long'; o.onLong(); } }, o.longMs||450):null;
  const mv=ev=>{
    const dx=ev.clientX-sx, dy=ev.clientY-sy;
    if(!lock && Math.hypot(dx,dy)>slop){
      clearTimeout(lt);
      const hz=Math.abs(dx)>Math.abs(dy);
      lock = o.axis==='x' ? (hz?'x':'none') : o.axis==='y' ? (!hz?'y':'none') : 'xy';
      if(lock==='none' && o.onCancel) o.onCancel('none');
    }
    const now=performance.now(), dt=Math.max(1,now-last.t);
    vx=(ev.clientX-last.x)/dt; vy=(ev.clientY-last.y)/dt; last={x:ev.clientX,y:ev.clientY,t:now};
    if(lock==='x'||lock==='y'||lock==='xy'){ if(ev.cancelable) ev.preventDefault(); o.onMove(dx,dy); }
  };
  const up=ev=>{
    clearTimeout(lt);
    window.removeEventListener('pointermove',mv); window.removeEventListener('pointerup',up); window.removeEventListener('pointercancel',up);
    if(lock==='x'||lock==='y'||lock==='xy') o.onEnd(ev.clientX-sx, ev.clientY-sy, vx, vy);
    else if(lock!=='none' && o.onCancel) o.onCancel(lock);
  };
  window.addEventListener('pointermove',mv,{passive:false}); window.addEventListener('pointerup',up); window.addEventListener('pointercancel',up);
}
const PAT={Selection:6, Light:10, Medium:18, Heavy:28, Success:[10,40,14], Warning:[18,60,18]};
function buzz(kind){ try{ navigator.vibrate && navigator.vibrate(PAT[kind]||10); }catch(_){} }
const rubber=(v,lim,k)=>{ k=k||.3; const a=Math.abs(v); return a<=lim? v : Math.sign(v)*(lim+(a-lim)*k); };
window.MG={drag,buzz,rubber};
})();
