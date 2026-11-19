extends Node2D
## Rounded painted trim follows water cells without changing navigation.
const CELL := 32.0
const CHUNK := 256.0
const WIDTH := 32.0
var chunks: Array[MeshInstance2D] = []
var environment_stamp := ""
var ground: TileMapLayer
var bank_material: ShaderMaterial

static func outlines(columns: Dictionary) -> Array[Dictionary]:
	var graph: Dictionary = {}
	var incoming: Dictionary = {}
	var cells: Array = columns.keys()
	cells.sort_custom(func(a: Vector2i,b: Vector2i):return a.y<b.y if a.y!=b.y else a.x<b.x)
	for cell: Vector2i in cells:
		if int(columns[cell])!=8:continue
		var corners: Array[Vector2i]=[cell,cell+Vector2i.RIGHT,cell+Vector2i.ONE,cell+Vector2i.DOWN]
		var sides: Array[Vector2i]=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
		for side: int in range(4):
			var neighbor:=cell+sides[side]
			# Bridge supports terminate trim. Sand never crosses the bridge.
			if not columns.has(neighbor) or int(columns[neighbor]) in [7,8,9]:continue
			var a:=corners[side];var b:=corners[(side+1)%4]
			if not graph.has(a):graph[a]=[]
			graph[a].append(b);incoming[b]=int(incoming.get(b,0))+1
	var starts: Array=graph.keys()
	starts.sort_custom(func(a: Vector2i,b: Vector2i):
		var ai:=int(incoming.get(a,0));var bi:=int(incoming.get(b,0))
		if ai!=bi:return ai<bi
		return a.y<b.y if a.y!=b.y else a.x<b.x)
	var result: Array[Dictionary]=[]
	for start: Vector2i in starts:
		while not graph[start].is_empty():
			var points:=PackedVector2Array([Vector2(start)*CELL])
			var at:=start;var previous:=Vector2i.ZERO
			while graph.has(at) and not graph[at].is_empty():
				var choices: Array=graph[at];var best:=0;var score:=-100.0
				for i: int in range(choices.size()):
					var step: Vector2i=choices[i]-at
					var turn:=float(previous.x*step.y-previous.y*step.x)
					if previous==-step:turn=-2.0
					if turn>score:score=turn;best=i
				var next: Vector2i=choices.pop_at(best)
				previous=next-at;at=next;points.append(Vector2(at)*CELL)
				if at==start:break
			if points.size()>1:result.append({"points":points,"closed":at==start})
	return result

func configure(layer: TileMapLayer) -> void:
	z_index=-9;ground=layer
	bank_material=ShaderMaterial.new();bank_material.shader=preload("res://art/shaders/shoreline.gdshader")
	bank_material.set_shader_parameter("bank_texture",preload("res://scripts/character_art.gd").texture("res://art/world/terrain/riverbank-v2.png"))
	var columns: Dictionary=layer.get_meta("visual_columns",{})
	if columns.is_empty():
		for cell: Vector2i in layer.get_used_cells():columns[cell]=preload("res://scripts/world_layout.gd").ground_column(cell,layer.get_cell_atlas_coords(cell).x)
	var geometry: Dictionary={}
	for chain: Dictionary in outlines(columns):
		var parts:=ribbon(rounded(chain.points,chain.closed),chain.closed)
		for key: Vector2i in parts:
			var part: Dictionary=parts[key]
			if not geometry.has(key):geometry[key]={"vertices":PackedVector2Array(),"uvs":PackedVector2Array(),"indices":PackedInt32Array()}
			var row: Dictionary=geometry[key];var offset: int=row.vertices.size()
			row.vertices.append_array(part.vertices);row.uvs.append_array(part.uvs)
			for index: int in part.indices:row.indices.append(index+offset)
	for key: Vector2i in geometry:
		var row: Dictionary=geometry[key];var origin:=Vector2(key)*CHUNK
		var vertices: PackedVector2Array=row.vertices
		for i: int in range(vertices.size()):vertices[i]-=origin
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=row.uvs;arrays[Mesh.ARRAY_INDEX]=row.indices
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var node:=MeshInstance2D.new();node.name="Bank_%d_%d"%[key.x,key.y];node.mesh=mesh;node.position=origin;node.material=bank_material
		add_child(node);chunks.append(node)
	GameState.clock_changed.connect(update_environment)
	GameState.world_changed.connect(update_environment)
	update_environment()

func update_environment() -> void:
	var snow:=float(ground.get_meta("painted_snow_cover",0.0))
	var stamp:="%d/%.3f"%[GameState.season_index(),snow]
	if stamp==environment_stamp:return
	environment_stamp=stamp
	bank_material.set_shader_parameter("season",GameState.season_index())
	bank_material.set_shader_parameter("snow_cover",snow)

static func rounded(points: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var current:=points.duplicate()
	if closed and current[0]==current[-1]:current.resize(current.size()-1)
	for iteration: int in range(2):
		var next:=PackedVector2Array()
		if not closed:next.append(current[0])
		var segments:=current.size() if closed else current.size()-1
		for i: int in range(segments):
			var a:=current[i];var b:=current[(i+1)%current.size()]
			next.append(a.lerp(b,.25));next.append(a.lerp(b,.75))
		if not closed:next.append(current[-1])
		current=next
	if closed:current.append(current[0])
	return current

static func ribbon(points: PackedVector2Array, closed: bool, width: float=WIDTH) -> Dictionary:
	var result: Dictionary={}
	if points.size()<2:return result
	var normals:=PackedVector2Array()
	for i: int in range(points.size()):
		var previous:=points[i-1] if i>0 else points[-2] if closed else points[i]
		var next:=points[i+1] if i<points.size()-1 else points[1] if closed else points[i]
		var tangent:=(next-previous).normalized()
		normals.append(Vector2(-tangent.y,tangent.x))
	var distance:=0.0
	for i: int in range(points.size()-1):
		var a:=points[i];var b:=points[i+1];var length:=a.distance_to(b)
		if length<.001:continue
		var key:=Vector2i(floori((a.x+b.x)*.5/CHUNK),floori((a.y+b.y)*.5/CHUNK))
		if not result.has(key):result[key]={"vertices":PackedVector2Array(),"uvs":PackedVector2Array(),"indices":PackedInt32Array()}
		var row: Dictionary=result[key];var offset: int=row.vertices.size()
		var n0:=normals[i]*width*.5;var n1:=normals[i+1]*width*.5
		row.vertices.append_array(PackedVector2Array([a-n0,a+n0,b-n1,b+n1]))
		row.uvs.append_array(PackedVector2Array([Vector2(distance/128.0,0),Vector2(distance/128.0,1),Vector2((distance+length)/128.0,0),Vector2((distance+length)/128.0,1)]))
		row.indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset+2,offset+1,offset+3]))
		distance+=length
	return result
