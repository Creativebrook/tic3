class_name CameraRig
extends Node3D

var camera: Camera3D
var yaw := deg_to_rad(-36.0)
var pitch := deg_to_rad(-28.0)
var distance := 14.0
var min_distance := 7.0
var max_distance := 30.0
var fit_distance := 14.0
var dragging := false
var last_pointer := Vector2.ZERO
var pinch_distance := 0.0
var touches: Dictionary = {}
var auto_rotating := false
var auto_rotate_speed := 0.28

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 42.0
	add_child(camera)
	_update_camera()

func _process(delta: float) -> void:
	if auto_rotating:
		yaw += auto_rotate_speed * delta
		_update_camera()

func reset_view(board_size := 3) -> void:
	auto_rotating = false
	yaw = deg_to_rad(-36.0)
	pitch = deg_to_rad(-28.0)
	_fit_distance_to_board(board_size)
	distance = fit_distance
	_update_camera()

func set_auto_rotate(enabled: bool) -> void:
	auto_rotating = enabled

func _fit_distance_to_board(board_size: int) -> void:
	if camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := max(0.35, viewport_size.x / max(1.0, viewport_size.y))
	var plane_half_extent := (float(board_size - 1) * 1.22 * 0.5) + 0.62
	var projected_half_width := plane_half_extent * (abs(cos(yaw)) + abs(sin(yaw))) + 0.20
	var tan_half_vertical := tan(deg_to_rad(camera.fov) * 0.5)
	var tan_half_horizontal := tan_half_vertical * aspect
	var horizontal_fit := projected_half_width / max(0.08, tan_half_horizontal * 0.84)
	var layer_half_extent := (float(board_size - 1) * 1.55 * 0.5) + 0.60
	var vertical_fit := layer_half_extent / max(0.08, tan_half_vertical * 0.70)
	fit_distance = max(horizontal_fit, vertical_fit, 9.5)
	min_distance = fit_distance * 0.58
	max_distance = fit_distance * 2.15

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
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
	elif event is InputEventMouseMotion and dragging:
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
		else:
			_apply_drag(event.relative * 0.7)
	elif event is InputEventMagnifyGesture:
		auto_rotating = false
		distance = clamp(distance / event.factor, min_distance, max_distance)
		_update_camera()

func _apply_drag(delta: Vector2) -> void:
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
