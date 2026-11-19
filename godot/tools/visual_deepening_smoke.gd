extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL: ",label)
func run() -> void:
	var state: Node=root.get_node("GameState");state.set_process(false)
	var before: Dictionary=state._make_save_data().duplicate(true)
	var shore: Script=load("res://scripts/shoreline.gd")
	var columns: Dictionary={}
	for y: int in range(5):
		for x: int in range(5):columns[Vector2i(x,y)]=8 if x in [1,2,3] and y in [1,2,3] else 4
	var chains: Array=shore.outlines(columns)
	check(chains.size()==1 and chains[0].closed,"A contiguous pond has one closed bank")
	var edge_count:=0
	for chain: Dictionary in chains:edge_count+=chain.points.size()-1
	check(edge_count==12,"Every pond perimeter edge appears once")
	var rounded: PackedVector2Array=shore.rounded(chains[0].points,true)
	check(rounded[0]==rounded[-1],"Rounded closed banks retain their join")
	var all_in_bounds:=true
	for p: Vector2 in rounded:
		all_in_bounds=all_in_bounds and Rect2(32,32,96.01,96.01).has_point(p)
	check(all_in_bounds,"Rounding stays inside the narrow authored pond boundary")
	for bridge: int in [7,9]:
		columns[Vector2i(2,0)]=bridge
		var open: Array=shore.outlines(columns)
		var count:=0
		for chain: Dictionary in open:count+=chain.points.size()-1
		check(count==11 and not open[0].closed,"No sand across a stone/wood bridge, tile "+str(bridge))
		var smooth: PackedVector2Array=shore.rounded(open[0].points,false)
		check(smooth[0]==open[0].points[0] and smooth[-1]==open[0].points[-1],"Bridge entry endpoints remain fixed")
	columns[Vector2i(2,0)]=4
	var geometry: Dictionary=shore.ribbon(rounded,true)
	var uv_continuous:=true
	var finite:=true
	var triangles:=0
	for row: Dictionary in geometry.values():
		for index: int in row.indices:finite=finite and index>=0 and index<row.vertices.size()
		for vertex: Vector2 in row.vertices:finite=finite and vertex.is_finite()
		for i: int in range(0,row.uvs.size(),4):uv_continuous=uv_continuous and row.uvs[i+2].x>row.uvs[i].x
		triangles+=int(row.indices.size()/3)
	check(finite and triangles>0,"Bank chunks contain valid finite indexed triangles")
	check(uv_continuous,"Trim UVs follow arc length without reversing")
	var diagonal: Dictionary={Vector2i(0,0):8,Vector2i(1,0):4,Vector2i(0,1):4,Vector2i(1,1):8,Vector2i(-1,0):4,Vector2i(0,-1):4,Vector2i(2,1):4,Vector2i(1,2):4}
	check(shore.outlines(diagonal).size()==2,"Diagonal ponds keep their separate shoreline loops")
	var atmosphere: Script=load("res://scripts/interior_atmosphere.gd")
	check(float(atmosphere.profile(720,{}).sun)>.99,"Noon window light is visible")
	check(float(atmosphere.profile(0,{}).sun)<.001,"Window sunlight disappears at midnight")
	check(float(atmosphere.profile(720,{"rain":2}).sun)<float(atmosphere.profile(720,{}).sun),"Rain attenuates direct window light")
	check(float(atmosphere.profile(1260,{}).night)>.99,"Night lantern activation follows actual night time")
	var rig: Script=load("res://scripts/canonical_character.gd")
	var art: Script=load("res://scripts/character_art.gd")
	var spec: Dictionary=art.data().actors.an.clips.idle

	for direction: String in ["down","left","right","up"]:
		for clip: String in ["idle","walk","greet","gather","read","brush","care","trade","pack","water","chop","hoe","rest"]:
			for phase: float in [0.0,.2,.5,.8,1.0]:
				var time:=phase*1.2
				var a: Vector2=rig.deform(Vector2(54,24),clip,direction,time,phase)
				var b: Vector2=rig.deform(Vector2(74,24),clip,direction,time,phase)
				var c: Vector2=rig.deform(Vector2(54,40),clip,direction,time,phase)
				var label:=direction+"/"+clip+"/"+str(phase)
				check(absf(a.distance_to(b)-20.0)<.001 and absf(a.distance_to(c)-16.0)<.001,"Face stays rigid "+label)
				var left: Vector2=rig.deform(Vector2(56,116),clip,direction,time,phase)
				var right: Vector2=rig.deform(Vector2(72,116),clip,direction,time,phase)
				check(absf(maxf(left.y,right.y)-116.0)<.2,"One shoe stays on its authored ground anchor "+label)
				var low: Vector2=rig.deform(Vector2(63.999,85),clip,direction,time,phase)
				var high: Vector2=rig.deform(Vector2(64.001,85),clip,direction,time,phase)
				check(low.distance_to(high)<.02,"No split at the shared leg/torso seam "+label)
				var mesh: Dictionary=rig.geometry(spec,clip,direction,time,phase)
				var valid:=true;var no_fold:=true
				for p: Vector2 in mesh.vertices:valid=valid and p.is_finite()
				for i: int in range(0,mesh.indices.size(),3):
					var p: Vector2=mesh.vertices[mesh.indices[i]];var q: Vector2=mesh.vertices[mesh.indices[i+1]];var r: Vector2=mesh.vertices[mesh.indices[i+2]]
					no_fold=no_fold and (q-p).cross(r-p)<-.00001
				check(valid,"Finite rendered character geometry "+label)
				check(no_fold,"Character mesh does not fold over itself "+label)
				var reduced_a: Vector2=rig.deform(Vector2(82,80),clip,direction,0,.1,false)
				var reduced_b: Vector2=rig.deform(Vector2(82,80),clip,direction,99,.9,false)
				check(reduced_a==reduced_b,"Reduced motion stays still "+label)
	for path: String in ["terrain/oak-planks-v2.png","terrain/blue-brick-v2.png","terrain/bamboo-mat-v2.png","terrain/terrazzo-v2.png","terrain/riverbank-v2.png","interior_details/v2/lantern.png","interior_details/v2/shelf.png","interior_details/v2/herbs.png","interior_details/v2/tea.png"]:
		var texture: Texture2D=art.texture("res://art/world/"+path)
		check(texture!=null and texture.get_width()>=512,"New production asset is actually loadable "+path)
		if texture!=null and (path.contains("riverbank") or path.contains("interior_details")):
			var pixels:=texture.get_image()
			check(pixels.detect_alpha()!=Image.ALPHA_NONE and pixels.get_pixel(0,0).a<.01,"Overlay has real transparent safety pixels "+path)
	check(state.inventory==before.inventory and state.money==before.money and state.plots==before.plots,"Visual sampling preserves economy and cultivated state")
	print("VISUAL_DEEPENING: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
