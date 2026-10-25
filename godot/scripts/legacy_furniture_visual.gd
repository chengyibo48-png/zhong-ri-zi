extends Sprite2D
var type_id:String=""
var slot:int=0
var season:int=-1
func _ready()->void:
 centered=false;offset=Vector2(-96,-192)
 refresh_season()
func refresh_season()->void:
 var next:int=GameState.season_index()
 if season==next and texture!=null:return
 season=next
 var path:String="res://art/legacy_furniture/%s-%d-%d.svg"%[type_id,season,slot%6]
 texture=load(path) as Texture2D
 if texture==null:push_error("旧院家具资源缺失："+path)
