extends RefCounted
class_name ActionSequence
var active: Dictionary = {}

func start(spec: Dictionary,commit: Callable,cancel: Callable=Callable()) -> bool:
 if not active.is_empty(): return false
 active={"spec":spec,"elapsed":0.0,"commit":commit,"cancel":cancel}
 return true

func tick(delta: float,paused: bool=false) -> bool:
 if active.is_empty() or paused: return false
 var amount:=0.0 if is_nan(delta) else clampf(delta,0.0,0.1)
 active.elapsed=minf(float(active.spec.duration),float(active.elapsed)+amount)
 if float(active.elapsed)+0.00000001<float(active.spec.duration):return false
 var commit:Callable=active.commit
 active={}
 if commit.is_valid():commit.call()
 return true

func cancel(invoke_callback: bool=true) -> bool:
 if active.is_empty():return false
 var callback:Callable=active.cancel
 active={}
 if invoke_callback and callback.is_valid():callback.call()
 return true

func snapshot() -> Dictionary:
 if active.is_empty():return {}
 var result:Dictionary=active.spec.duplicate(true)
 result.progress=minf(1.0,float(active.elapsed)/float(result.duration))
 result.phase="准备" if float(result.progress)<0.22 else "动手" if float(result.progress)<0.82 else "收好"
 return result
