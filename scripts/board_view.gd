class_name BoardView
extends Node3D

signal cell_pressed(index: int)

const TAP_SLOP := 22.0

var board: BoardLogic
var cell_nodes: Array[Node3D] = []
var piece_nodes: Dictionary = {}
var layer_roots: Array[Node3D] = []
var layer_materials: Array[ShaderMaterial] = []
var focused_layer := -1
var exploded := true
var stack_mode := false
var spacing := 1.22
var layer_gap := 1.55

var mat_x: StandardMaterial3D
var mat_o: StandardMaterial3D
var mat_cell: ShaderMaterial
var mat_win: StandardMaterial3D

var touch_starts: Dictionary = {}
var touch_moved: Dictionary = {}
var multitouch_gesture := false
var mouse_start := Vector2.ZERO
var mouse_tracking := false
var mouse_moved := false

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
	layer_materials.clear()
	if board == null:
		return
	cell_nodes.resize(board.cells.size())

	var center_offset := (board.size - 1) * spacing * 0.5
	for z in range(board.size):
		var layer := Node3D.new()
		layer.name = "Layer_%d" % (z + 1)
		add_child(layer)
		layer_roots.append(layer)
		var layer_material := mat_cell.duplicate() as ShaderMaterial
		layer_material.set_shader_parameter("layer_opacity", 1.0)
		layer_material.set_shader_parameter("layer_dim", 1.0)
		layer_materials.append(layer_material)
		for y in range(board.size):
			for x in range(board.size):
				var idx := board.index(x, y, z)
				var cell := _make_cell(idx, layer_material)
				cell.position = Vector3(x * spacing - center_offset, 0.0, y * spacing - center_offset)
				layer.add_child(cell)
				cell_nodes[idx] = cell
	_apply_layer_positions()

func _make_cell(idx: int, cell_material: ShaderMaterial) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "Cell_%d" % idx
	body.set_meta("cell_index", idx)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Surface"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.03, 0.055, 1.03)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = cell_material
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.07, 0.18, 1.07)
	shape.shape = box
	body.add_child(shape)
	return body

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not touch_starts.is_empty():
				multitouch_gesture = true
				for key in touch_moved.keys():
					touch_moved[key] = true
			touch_starts[event.index] = event.position
			touch_moved[event.index] = multitouch_gesture
		else:
			var should_tap := touch_starts.has(event.index) and not bool(touch_moved.get(event.index, true)) and not multitouch_gesture
			touch_starts.erase(event.index)
			touch_moved.erase(event.index)
			if touch_starts.is_empty():
				multitouch_gesture = false
			if should_tap:
				_emit_tap_at(event.position)
	elif event is InputEventScreenDrag:
		if touch_starts.has(event.index):
			if Vector2(touch_starts[event.index]).distance_to(event.position) > TAP_SLOP:
				touch_moved[event.index] = true
		if touch_starts.size() > 1:
			multitouch_gesture = true
			for key in touch_moved.keys():
				touch_moved[key] = true
	elif not DisplayServer.is_touchscreen_available():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_tracking = true
				mouse_moved = false
				mouse_start = event.position
			else:
				if mouse_tracking and not mouse_moved:
					_emit_tap_at(event.position)
				mouse_tracking = false
		elif event is InputEventMouseMotion and mouse_tracking:
			if mouse_start.distance_to(event.position) > TAP_SLOP:
				mouse_moved = true

func _emit_tap_at(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var ray_from := camera.project_ray_origin(screen_pos)
	var ray_to := ray_from + camera.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider = hit.get("collider")
	if collider is StaticBody3D and collider.has_meta("cell_index") and collider.input_ray_pickable:
		cell_pressed.emit(int(collider.get_meta("cell_index")))

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
	line_mesh.global_transform = _cylinder_transform(midpoint, a, b)
	line_mesh.scale = Vector3(0.05, 0.05, 0.05)
	var tween := line_mesh.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(line_mesh, "scale", Vector3.ONE, 0.36)

func _cylinder_transform(midpoint: Vector3, a: Vector3, b: Vector3) -> Transform3D:
	var direction := (b - a).normalized()
	var q := Quaternion(Vector3.UP, direction)
	return Transform3D(Basis(q), midpoint)

func global_position_for_cell(idx: int) -> Vector3:
	var cell: Node3D = cell_nodes[idx]
	return cell.to_global(Vector3(0, 0.20, 0))

func set_focus_layer(layer: int) -> void:
	stack_mode = false
	exploded = true
	focused_layer = layer
	_apply_layer_positions(true)

func set_stack_mode(enabled: bool) -> void:
	stack_mode = enabled
	focused_layer = -1
	exploded = not enabled
	_apply_layer_positions(true)

func reset_view_state(animated := true) -> void:
	# Canonical board presentation used by RESET VIEW and end-of-game framing.
	stack_mode = false
	exploded = true
	focused_layer = -1
	_apply_layer_positions(animated)

func is_stack_mode() -> bool:
	return stack_mode

func _apply_layer_positions(animated := false) -> void:
	if board == null:
		return
	var separation := layer_gap if exploded else 0.42
	var center := (board.size - 1) * separation * 0.5
	var focus_base_y := 0.0
	if focused_layer >= 0:
		focus_base_y = focused_layer * separation - center

	for z in range(layer_roots.size()):
		var target := Vector3(0, z * separation - center, 0)
		var target_scale := Vector3.ONE
		var panel_opacity := 1.0
		var panel_dim := 1.0
		var piece_opacity := 1.0
		var interactive := focused_layer < 0 or z == focused_layer

		if stack_mode:
			# B2: use a compact diagonal cascade instead of placing every level on
			# the exact same footprint. The offset is small enough to read columns,
			# but large enough to expose level order in a 3/4 camera.
			var stack_center := (float(board.size) - 1.0) * 0.5
			var level_offset := float(z) - stack_center
			target = Vector3(level_offset * 0.16, level_offset * 0.34, -level_offset * 0.13)
			target_scale = Vector3.ONE * 0.94
			# Slight depth gradient helps the planes separate without becoming
			# opaque. Piece-specific depth cues remain a B3 task.
			var depth_t := 0.5 if board.size <= 1 else float(z) / float(board.size - 1)
			panel_opacity = lerp(0.26, 0.38, depth_t)
			panel_dim = lerp(0.48, 0.72, depth_t)
			piece_opacity = 1.0
		elif focused_layer >= 0:
			if z == focused_layer:
				target.y = focus_base_y
				target_scale = Vector3.ONE * 1.10
			else:
				var direction := -1.0 if z < focused_layer else 1.0
				var rank := abs(z - focused_layer)
				# Keep inactive layers grouped like a compact stack on each side
				# while leaving a larger interaction gap around the active layer.
				target.y = focus_base_y + direction * (2.32 + float(rank - 1) * 0.20)
				target_scale = Vector3.ONE * 0.68
				panel_opacity = 0.24
				panel_dim = 0.34
				piece_opacity = 0.58

		_set_layer_visual(z, panel_opacity, panel_dim, piece_opacity)
		_set_layer_interactive(layer_roots[z], interactive)

		if animated:
			var tw := layer_roots[z].create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.set_parallel(true)
			tw.tween_property(layer_roots[z], "position", target, 0.34)
			tw.tween_property(layer_roots[z], "scale", target_scale, 0.34)
		else:
			layer_roots[z].position = target
			layer_roots[z].scale = target_scale

func _set_layer_visual(layer_index: int, panel_opacity: float, dim_factor: float, piece_opacity: float) -> void:
	if layer_index < 0 or layer_index >= layer_roots.size():
		return

	# Each layer owns its ShaderMaterial instance, so alpha/dimming can be changed
	# independently. The shader uses blend_mix + depth_draw_never: unlike the old
	# alpha pre-pass, translucent panels no longer write depth and hide layers below.
	var material := layer_materials[layer_index]
	material.set_shader_parameter("layer_opacity", panel_opacity)
	material.set_shader_parameter("layer_dim", dim_factor)

	for cell in layer_roots[layer_index].get_children():
		if cell is StaticBody3D:
			var surface := cell.get_node_or_null("Surface") as MeshInstance3D
			if surface:
				surface.material_override = material
				surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if panel_opacity >= 0.95 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_set_piece_alpha_recursive(layer_roots[layer_index], piece_opacity)

func _set_piece_alpha_recursive(node: Node, alpha: float) -> void:
	# Pieces use StandardMaterial3D, where instance transparency is reliable.
	# Cell meshes are excluded because their opacity is controlled by the shader.
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		var material = geometry.material_override
		if not (material is ShaderMaterial):
			geometry.transparency = 1.0 - alpha
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if alpha < 0.5 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_set_piece_alpha_recursive(child, alpha)

func _set_layer_interactive(layer: Node3D, enabled: bool) -> void:
	for child in layer.get_children():
		if child is StaticBody3D:
			child.input_ray_pickable = enabled
