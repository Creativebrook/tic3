class_name BoardView
extends Node3D

signal cell_pressed(index: int)

var board: BoardLogic
var cell_nodes: Array[Node3D] = []
var piece_nodes: Dictionary = {}
var layer_roots: Array[Node3D] = []
var focused_layer := -1
var exploded := true
var spacing := 1.22
var layer_gap := 1.55

var mat_x: StandardMaterial3D
var mat_o: StandardMaterial3D
var mat_cell: ShaderMaterial
var mat_win: StandardMaterial3D

func setup(board_logic: BoardLogic) -> void:
	board = board_logic
	_build_materials()
	_rebuild()

func _build_materials() -> void:
	mat_x = StandardMaterial3D.new()
	mat_x.albedo_color = Color("#72E6FF")
	mat_x.metallic = 0.72
	mat_x.roughness = 0.18
	mat_x.emission_enabled = true
	mat_x.emission = Color("#1CB7D7")
	mat_x.emission_energy_multiplier = 1.35

	mat_o = StandardMaterial3D.new()
	mat_o.albedo_color = Color("#FFB36A")
	mat_o.metallic = 0.65
	mat_o.roughness = 0.20
	mat_o.emission_enabled = true
	mat_o.emission = Color("#E77A23")
	mat_o.emission_energy_multiplier = 1.25

	mat_win = StandardMaterial3D.new()
	mat_win.albedo_color = Color("#F9FCFF")
	mat_win.emission_enabled = true
	mat_win.emission = Color("#D7F8FF")
	mat_win.emission_energy_multiplier = 4.0
	mat_win.roughness = 0.08

	mat_cell = ShaderMaterial.new()
	mat_cell.shader = load("res://shaders/grid_glass.gdshader")

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	cell_nodes.clear()
	piece_nodes.clear()
	layer_roots.clear()
	if board == null:
		return
	cell_nodes.resize(board.cells.size())

	var center_offset := (board.size - 1) * spacing * 0.5
	for z in range(board.size):
		var layer := Node3D.new()
		layer.name = "Layer_%d" % (z + 1)
		add_child(layer)
		layer_roots.append(layer)
		for y in range(board.size):
			for x in range(board.size):
				var idx := board.index(x, y, z)
				var cell := _make_cell(idx)
				cell.position = Vector3(x * spacing - center_offset, 0.0, y * spacing - center_offset)
				layer.add_child(cell)
				cell_nodes[idx] = cell
	_apply_layer_positions()

func _make_cell(idx: int) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "Cell_%d" % idx
	body.set_meta("cell_index", idx)
	body.input_event.connect(_on_cell_input.bind(idx))

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.03, 0.055, 1.03)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat_cell
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.07, 0.18, 1.07)
	shape.shape = box
	body.add_child(shape)
	return body

func _on_cell_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cell_pressed.emit(idx)
	elif event is InputEventScreenTouch and event.pressed:
		cell_pressed.emit(idx)

func place_piece(idx: int, player: int, animate := true) -> void:
	if piece_nodes.has(idx):
		return
	var cell: Node3D = cell_nodes[idx]
	var piece := _make_x() if player == 1 else _make_o()
	piece.position.y = 0.18
	cell.add_child(piece)
	piece_nodes[idx] = piece
	if animate:
		piece.scale = Vector3.ONE * 0.12
		piece.rotation.y = -0.7
		var tween := piece.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.set_parallel(true)
		tween.tween_property(piece, "scale", Vector3.ONE, 0.28)
		tween.tween_property(piece, "rotation:y", 0.0, 0.28)

func _make_x() -> Node3D:
	var root := Node3D.new()
	for angle in [-PI / 4.0, PI / 4.0]:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.16, 0.17, 0.72)
		bar.mesh = mesh
		bar.rotation.y = angle
		bar.material_override = mat_x
		root.add_child(bar)
	return root

func _make_o() -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.23
	torus.outer_radius = 0.38
	torus.rings = 24
	torus.ring_segments = 12
	mesh_instance.mesh = torus
	mesh_instance.material_override = mat_o
	return mesh_instance

func show_winning_line(line: PackedInt32Array) -> void:
	if line.is_empty():
		return
	var a := global_position_for_cell(line[0])
	var b := global_position_for_cell(line[line.size() - 1])
	var midpoint := (a + b) * 0.5
	var length := a.distance_to(b) + 0.55
	var line_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.055
	cylinder.bottom_radius = 0.055
	cylinder.height = length
	cylinder.radial_segments = 14
	line_mesh.mesh = cylinder
	line_mesh.material_override = mat_win
	add_child(line_mesh)
	line_mesh.global_position = midpoint
	line_mesh.global_transform = _cylinder_transform(midpoint, a, b, line_mesh.global_transform)
	line_mesh.scale = Vector3(0.05, 0.05, 0.05)
	var tween := line_mesh.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(line_mesh, "scale", Vector3.ONE, 0.36)

func _cylinder_transform(midpoint: Vector3, a: Vector3, b: Vector3, current: Transform3D) -> Transform3D:
	var direction := (b - a).normalized()
	var q := Quaternion(Vector3.UP, direction)
	return Transform3D(Basis(q), midpoint)

func global_position_for_cell(idx: int) -> Vector3:
	var cell: Node3D = cell_nodes[idx]
	return cell.to_global(Vector3(0, 0.20, 0))

func set_focus_layer(layer: int) -> void:
	focused_layer = layer
	_apply_layer_positions()

func toggle_exploded() -> void:
	exploded = not exploded
	_apply_layer_positions(true)

func _apply_layer_positions(animated := false) -> void:
	if board == null:
		return
	var separation := layer_gap if exploded else 0.42
	var center := (board.size - 1) * separation * 0.5
	for z in range(layer_roots.size()):
		var target := Vector3(0, z * separation - center, 0)
		var target_scale := Vector3.ONE
		var visible_alpha := 1.0
		var interactive := focused_layer < 0 or z == focused_layer
		if focused_layer >= 0 and z != focused_layer:
			target.x += (z - focused_layer) * 0.12
			target_scale = Vector3.ONE * 0.94
			visible_alpha = 0.25
		_set_layer_alpha(layer_roots[z], visible_alpha)
		_set_layer_interactive(layer_roots[z], interactive)
		if animated:
			var tw := layer_roots[z].create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.set_parallel(true)
			tw.tween_property(layer_roots[z], "position", target, 0.32)
			tw.tween_property(layer_roots[z], "scale", target_scale, 0.32)
		else:
			layer_roots[z].position = target
			layer_roots[z].scale = target_scale

func _set_layer_alpha(layer: Node3D, alpha: float) -> void:
	for child in layer.get_children():
		if child is VisualInstance3D:
			child.transparency = 1.0 - alpha
		for grand in child.get_children():
			if grand is VisualInstance3D:
				grand.transparency = 1.0 - alpha

func _set_layer_interactive(layer: Node3D, enabled: bool) -> void:
	for child in layer.get_children():
		if child is StaticBody3D:
			child.input_ray_pickable = enabled
