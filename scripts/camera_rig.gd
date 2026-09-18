class_name CameraRig
extends Node3D

var camera: Camera3D
var yaw := deg_to_rad(-36.0)
var pitch := deg_to_rad(-28.0)
var distance := 13.0
var min_distance := 7.0
var max_distance := 30.0
var fit_distance := 13.0
var dragging := false
var last_pointer := Vector2.ZERO
var pinch_distance := 0.0
var touches: Dictionary = {}
var auto_rotating := false
var auto_rotate_speed := 0.28

var stack_mode := false
var current_board_size := 3
var saved_yaw := deg_to_rad(-36.0)
var saved_pitch := deg_to_rad(-28.0)
var saved_distance := 13.0
var view_tween: Tween

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.near = 0.05
	camera.far = 100.0
	camera.current = true
	add_child(camera)
	_update_camera()

func _process(delta: float) -> void:
	if auto_rotating and not stack_mode:
		yaw += auto_rotate_speed * delta
		_update_camera()

func reset_view(board_size := 3) -> void:
	current_board_size = board_size
	auto_rotating = false
	if stack_mode:
		_apply_stack_limits(board_size)
		_animate_view(deg_to_rad(-45.0), deg_to_rad(-58.0), fit_distance, 0.28)
		return

	yaw = deg_to_rad(-36.0)
	pitch = deg_to_rad(-28.0)
	_apply_normal_limits(board_size)
	distance = fit_distance
	_update_camera()

func set_stack_mode(enabled: bool, board_size := 3) -> void:
	current_board_size = board_size
	if enabled == stack_mode:
		if enabled:
			reset_view(board_size)
		return

	auto_rotating = false
	dragging = false
	touches.clear()
	pinch_distance = 0.0

	if enabled:
		saved_yaw = yaw
		saved_pitch = pitch
		saved_distance = distance
		stack_mode = true
		_apply_stack_limits(board_size)
		_animate_view(deg_to_rad(-45.0), deg_to_rad(-58.0), fit_distance, 0.42)
	else:
		stack_mode = false
		_apply_normal_limits(board_size)
		var restore_distance := clamp(saved_distance, min_distance, max_distance)
		_animate_view(saved_yaw, saved_pitch, restore_distance, 0.38)

func is_stack_mode() -> bool:
	return stack_mode

func set_auto_rotate(enabled: bool) -> void:
	auto_rotating = enabled and not stack_mode

func _apply_normal_limits(board_size: int) -> void:
	match board_size:
		3:
			fit_distance = 13.0
		4:
			fit_distance = 17.0
		5:
			fit_distance = 21.0
		_:
			fit_distance = 13.0
	min_distance = fit_distance * 0.58
	max_distance = fit_distance * 1.9

func _apply_stack_limits(board_size: int) -> void:
	# Dedicated analytical 3/4 view: higher pitch and a slightly tighter frame.
	match board_size:
		3:
			fit_distance = 11.8
		4:
			fit_distance = 15.0
		5:
			fit_distance = 18.4
		_:
			fit_distance = 11.8
	min_distance = fit_distance * 0.88
	max_distance = fit_distance * 1.28

func _animate_view(target_yaw: float, target_pitch: float, target_distance: float, duration: float) -> void:
	if is_instance_valid(view_tween):
		view_tween.kill()
	var start := Vector3(yaw, pitch, distance)
	var target := Vector3(target_yaw, target_pitch, target_distance)
	view_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	view_tween.tween_method(_set_view_state, start, target, duration)

func _set_view_state(state: Vector3) -> void:
	yaw = state.x
	pitch = state.y
	distance = state.z
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if stack_mode:
				dragging = false
				return
			if event.pressed:
				auto_rotating = false
			dragging = event.pressed
			last_pointer = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			auto_rotating = false
			distance = max(min_distance, distance - fit_distance * 0.07)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			auto_rotating = false
			distance = min(max_distance, distance + fit_distance * 0.07)
			_update_camera()
	elif event is InputEventMouseMotion and dragging and not stack_mode:
		auto_rotating = false
		_apply_drag(event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed:
			auto_rotating = false
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		if touches.size() < 2:
			pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		auto_rotating = false
		touches[event.index] = event.position
		if touches.size() >= 2:
			var ids := touches.keys()
			var d := Vector2(touches[ids[0]]).distance_to(Vector2(touches[ids[1]]))
			if pinch_distance > 0.0:
				distance = clamp(distance - (d - pinch_distance) * fit_distance * 0.00125, min_distance, max_distance)
				_update_camera()
			pinch_distance = d
		elif not stack_mode:
			_apply_drag(event.relative * 0.7)
	elif event is InputEventMagnifyGesture:
		auto_rotating = false
		distance = clamp(distance / event.factor, min_distance, max_distance)
		_update_camera()

func _apply_drag(delta: Vector2) -> void:
	if stack_mode:
		return
	yaw -= delta.x * 0.006
	pitch = clamp(pitch - delta.y * 0.005, deg_to_rad(-65.0), deg_to_rad(-10.0))
	_update_camera()

func _update_camera() -> void:
	if camera == null:
		return
	var x := distance * cos(pitch) * sin(yaw)
	var y := -distance * sin(pitch)
	var z := distance * cos(pitch) * cos(yaw)
	camera.position = Vector3(x, y, z)
	camera.look_at(Vector3.ZERO, Vector3.UP)
