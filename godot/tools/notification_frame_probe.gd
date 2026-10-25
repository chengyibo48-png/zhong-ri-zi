extends "res://scripts/game_state.gd"
var calls:Array=[]
var added:=false
func save_game(_path:String=SAVE_PATH,_silent:bool=false)->bool:calls.append("save");return true
func _feedback_poll(_present:bool=true)->bool:
 calls.append("poll")
 _feedback_poll_added=[{"title":"提醒","text":"内容","priority":1},{"title":"照料","text":"需要关注","priority":2}] if added else []
 return added
