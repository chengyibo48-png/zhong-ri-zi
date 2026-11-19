extends SceneTree
class ReviewAnimal extends Node2D:
	var animal:Dictionary={}
	var appearance:Dictionary={}
	var clock:float=0
	func _draw()->void:load("res://scripts/animal_layers.gd").draw(self,animal,appearance,Vector2.ZERO,clock)
func _initialize()->void:call_deferred("run")
func run()->void:
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.animal_behavior.clear()
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	var layer:=CanvasLayer.new();root.add_child(layer);var paper:=ColorRect.new();paper.color=Color("ded5b9");paper.size=Vector2(1280,800);layer.add_child(paper)
	var species:Array=["horse","alpaca","cow","sheep","goat","pig","hen","duck","goose","rabbit","cat","dog"];var nodes:Array=[]
	for i:int in species.size():
		var node:=ReviewAnimal.new();node.position=Vector2(160+(i%4)*320,215+(i/4)*245);node.scale=Vector2.ONE*2.6;node.animal={"id":"gait-"+str(i),"type":species[i],"age":40};layer.add_child(node);nodes.append(node)
		var label:=Label.new();label.text=str(species[i])+" / native gait";label.position=Vector2(75+(i%4)*320,235+(i/4)*245);label.add_theme_color_override("font_color",Color("453d2c"));layer.add_child(label)
	var title:=Label.new();title.text="CONTINUOUS SURFACE / ACTUAL DISPLACEMENT SAMPLING / 4 DIRECTIONS";title.position=Vector2(90,18);title.add_theme_color_override("font_color",Color("453d2c"));layer.add_child(title)
	var out:String=OS.get_environment("ZRZ_ART_OUTPUT")+"/gait-motion";DirAccess.make_dir_recursive_absolute(out)
	var positions:Array=[];for i:int in species.size():positions.append(Vector2.ZERO)
	var directions:Array=["right","down","left","up"];var vectors:Array=[Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP];var trace:Array=[]
	for frame:int in 384:
		var t:float=float(frame)/24;var turn:int=mini(3,int(t/4));var moving:bool=fmod(t,4)<2.8
		for i:int in nodes.size():
			var node:ReviewAnimal=nodes[i];var id:String=str(node.animal.id)
			if moving:positions[i]+=Vector2(vectors[turn])*24.0/24
			var sample:Dictionary=s.animal_behavior.sample(id,str(species[i]),positions[i],"review",str(directions[turn]),moving,"",false,t,1.0/24,false,{"age":40,"adult":1})
			node.clock=t;node.appearance={"direction":directions[turn]};node.queue_redraw()
			if i<2:trace.append({"frame":frame,"id":id,"position":str(positions[i]),"phase":sample.phase,"weight":sample.weight,"feet":str(sample.foot_offsets)})
		await process_frame;RenderingServer.force_draw()
		var image:Image=root.get_texture().get_image();image.save_jpg(out+"/frame-%04d.jpg"%frame,.94)
		if frame in [0,48,160,250,383]:image.save_png(OS.get_environment("ZRZ_ART_OUTPUT")+"/gait-review-%03d.png"%frame)
	var f:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/gait-trace.json",FileAccess.WRITE);f.store_string(JSON.stringify(trace));f.close()
	print("WHOLE_GAIT_REPLAY: 12 species x 384 continuous frames; model-review camera follows each animal; not a navigation test")
	await root.get_node("AudioService").prepare_exit();quit()
