class_name CameraRig
extends Node3D

var camera: Camera3D
var yaw := deg_to_rad(-36.0)
var pitch := deg_to_rad(-28.0)
var distance := 10.5
var dragging := false
var last_pointer := Vector2.ZERO
var pinch_distance := 0.0
var touches: Dictionary = {}

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 42.0
	add_child(camera)
	_update_camera()

func reset_view(board_size := 3) -> void:
	yaw = deg_to_rad(-36.0)
	pitch = deg_to_rad(-28.0)
	distance = 8.6 + float(board_size - 3) * 1.35
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			last_pointer = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = max(5.0, distance - 0.6)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = min(18.0, distance + 0.6)
			_update_camera()
	elif event is InputEventMouseMotion and dragging:
		_apply_drag(event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		if touches.size() < 2:
			pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() >= 2:
			var ids := touches.keys()
			var d := Vector2(touches[ids[0]]).distance_to(Vector2(touches[ids[1]]))
			if pinch_distance > 0.0:
				distance = clamp(distance - (d - pinch_distance) * 0.012, 5.0, 18.0)
				_update_camera()
			pinch_distance = d
		else:
			_apply_drag(event.relative * 0.7)
	elif event is InputEventMagnifyGesture:
		distance = clamp(distance / event.factor, 5.0, 18.0)
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
