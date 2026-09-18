extends Node

const BG := Color("#07090E")
const PANEL := Color("#111722")
const PANEL_2 := Color("#171E2B")
const TEXT := Color("#F5F7FA")
const MUTED := Color("#8C98AA")
const CYAN := Color("#72E6FF")
const ORANGE := Color("#FFB36A")
const GREEN := Color("#79F2B0")

var world: Node3D
var board_view: BoardView
var camera_rig: CameraRig
var ui: CanvasLayer
var overlay_root: Control
var hud: Control
var board: BoardLogic
var ai: AIEngine
var score_store := ScoreStore.new()

var mode := "CPU"
var difficulty := "SMART"
var board_size := 3
var current_player := 1
var game_over := false
var player_times := {1: 0.0, 2: 0.0}
var human_moves := 0
var total_moves := 0
var ai_busy := false
var last_move := -1

var timer_p1: Label
var timer_p2: Label
var turn_label: Label
var layer_box: VBoxContainer
var result_panel: PanelContainer
var layer_buttons: Array[Button] = []
var stack_button: Button

func _ready() -> void:
	_build_world()
	_build_ui()
	_show_home()

func _process(delta: float) -> void:
	if board != null and not game_over and not ai_busy:
		if mode == "PVP" or current_player == 1:
			player_times[current_player] += delta
			_refresh_timers()

func _build_world() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#A9C7E8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.18
	env_node.environment = env
	world.add_child(env_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, -32, 0)
	key.light_color = Color("#DDEAFF")
	key.light_energy = 1.18
	key.shadow_enabled = true
	key.shadow_opacity = 0.20
	key.shadow_blur = 5.0
	world.add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-4, 5, 4)
	fill.light_color = CYAN
	fill.light_energy = 5.0
	fill.omni_range = 10.0
	world.add_child(fill)

	var rim := OmniLight3D.new()
	rim.position = Vector3(5, 2, -4)
	rim.light_color = ORANGE
	rim.light_energy = 3.8
	rim.omni_range = 9.0
	world.add_child(rim)

	camera_rig = CameraRig.new()
	world.add_child(camera_rig)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	overlay_root = Control.new()
	overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay_root)

func _clear_ui() -> void:
	for child in overlay_root.get_children():
		child.queue_free()

func _show_home() -> void:
	_clear_board()
	_clear_ui()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.035, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.add_child(bg)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-390, -360)
	v.size = Vector2(780, 720)
	overlay_root.add_child(v)

	var logo := Label.new()
	logo.text = "TIC³"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 92)
	logo.add_theme_color_override("font_color", TEXT)
	v.add_child(logo)

	var subtitle := Label.new()
	subtitle.text = "THINK IN THREE DIMENSIONS"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 23)
	subtitle.add_theme_color_override("font_color", MUTED)
	v.add_child(subtitle)

	v.add_child(_spacer(34))
	v.add_child(_big_button("PLAYER vs COMPUTER", func(): _show_setup("CPU")))
	v.add_child(_big_button("PLAYER vs PLAYER", func(): _show_setup("PVP")))
	v.add_child(_ghost_button("HIGHSCORES", _show_highscores))

	var hint := Label.new()
	hint.text = "3×3×3  •  4×4×4  •  5×5×5"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", MUTED)
	v.add_child(hint)

	var version_label := Label.new()
	version_label.text = "v%s" % String(ProjectSettings.get_setting("application/config/version", "dev"))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 17)
	version_label.add_theme_color_override("font_color", Color(0.45, 0.50, 0.58, 0.82))
	v.add_child(version_label)

func _show_setup(selected_mode: String) -> void:
	mode = selected_mode
	_clear_ui()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.035, 0.90)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.add_child(bg)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-410, -500)
	v.size = Vector2(820, 1000)
	overlay_root.add_child(v)

	var back := _ghost_button("← BACK", _show_home)
	v.add_child(back)
	var title := _title("PLAYER vs COMPUTER" if mode == "CPU" else "PLAYER vs PLAYER")
	v.add_child(title)
	v.add_child(_section_label("BOARD"))
	for n in [3, 4, 5]:
		var btn := _big_button("%d × %d × %d" % [n, n, n], func(size = n): board_size = size; _refresh_setup(v))
		btn.set_meta("board_size", n)
		v.add_child(btn)
	if mode == "CPU":
		v.add_child(_section_label("COMPUTER"))
		for d in ["CASUAL", "SMART", "EXPERT"]:
			var dbtn := _choice_button(d, func(diff = d): difficulty = diff; _refresh_setup(v))
			dbtn.set_meta("difficulty", d)
			v.add_child(dbtn)
	v.add_child(_spacer(16))
	v.add_child(_accent_button("START GAME", _start_game))
	_refresh_setup(v)

func _refresh_setup(container: VBoxContainer) -> void:
	for child in container.get_children():
		if child.has_meta("board_size"):
			_style_choice(child, int(child.get_meta("board_size")) == board_size)
		if child.has_meta("difficulty"):
			_style_choice(child, String(child.get_meta("difficulty")) == difficulty)

func _start_game() -> void:
	_clear_ui()
	_clear_board()
	camera_rig.stop_victory_orbit()
	camera_rig.set_interaction_enabled(true)
	board = BoardLogic.new(board_size)
	ai = AIEngine.new(board)
	current_player = 1
	game_over = false
	ai_busy = false
	player_times = {1: 0.0, 2: 0.0}
	human_moves = 0
	total_moves = 0
	last_move = -1

	board_view = BoardView.new()
	board_view.cell_pressed.connect(_on_cell_pressed)
	world.add_child(board_view)
	board_view.setup(board)
	camera_rig.set_auto_rotate(false)
	camera_rig.reset_view(board_size, false)
	_build_hud()
	_refresh_hud()

func _clear_board() -> void:
	if is_instance_valid(camera_rig):
		camera_rig.stop_victory_orbit()
		camera_rig.set_interaction_enabled(true)
	if is_instance_valid(board_view):
		board_view.queue_free()
	board_view = null
	board = null

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(hud)

	var top := HBoxContainer.new()
	top.position = Vector2(34, 34)
	top.size = Vector2(1012, 110)
	top.add_theme_constant_override("separation", 12)
	hud.add_child(top)
	var home_btn := _small_button("‹", _show_home)
	home_btn.custom_minimum_size = Vector2(72, 72)
	top.add_child(home_btn)
	var mode_label := Label.new()
	mode_label.text = "%d×%d×%d  •  %s" % [board_size, board_size, board_size, difficulty if mode == "CPU" else "LOCAL"]
	mode_label.add_theme_font_size_override("font_size", 29)
	mode_label.add_theme_color_override("font_color", TEXT)
	mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(mode_label)
	var reset_btn := _small_button("RESET VIEW", _reset_game_view)
	top.add_child(reset_btn)

	var clocks := HBoxContainer.new()
	clocks.position = Vector2(34, 158)
	clocks.size = Vector2(1012, 108)
	clocks.add_theme_constant_override("separation", 12)
	hud.add_child(clocks)
	var p1_panel := _clock_panel("X", CYAN)
	timer_p1 = p1_panel.get_node("Margin/V/Time")
	clocks.add_child(p1_panel)
	var p2_panel := _clock_panel("CPU" if mode == "CPU" else "O", ORANGE)
	timer_p2 = p2_panel.get_node("Margin/V/Time")
	clocks.add_child(p2_panel)

	turn_label = Label.new()
	turn_label.position = Vector2(34, 284)
	turn_label.size = Vector2(1012, 52)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 29)
	turn_label.add_theme_color_override("font_color", MUTED)
	hud.add_child(turn_label)

	var right_panel := PanelContainer.new()
	right_panel.position = Vector2(868, 430)
	right_panel.size = Vector2(174, 700)
	_apply_panel_style(right_panel, Color(0.055, 0.075, 0.105, 0.90), 24)
	hud.add_child(right_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	right_panel.add_child(margin)
	layer_box = VBoxContainer.new()
	layer_buttons.clear()
	layer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	layer_box.add_theme_constant_override("separation", 10)
	margin.add_child(layer_box)
	var all_btn := _layer_button("ALL", -1)
	layer_box.add_child(all_btn)
	layer_buttons.append(all_btn)
	for z in range(board_size - 1, -1, -1):
		var layer_btn := _layer_button(str(z + 1), z)
		layer_box.add_child(layer_btn)
		layer_buttons.append(layer_btn)
	_refresh_layer_buttons()
	layer_box.add_child(_spacer(16))
	stack_button = _small_button("STACK", _toggle_stack_mode)
	layer_box.add_child(stack_button)
	_refresh_stack_button()

	var help := Label.new()
	help.text = "Drag to rotate  •  Pinch / wheel to zoom\nTap a layer number to isolate it"
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 48
	help.offset_right = 930
	help.offset_top = -122
	help.offset_bottom = -42
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", MUTED)
	hud.add_child(help)

func _clock_panel(name_text: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 108)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_panel_style(panel, PANEL, 24)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.name = "V"
	margin.add_child(v)
	var who := Label.new()
	who.text = name_text
	who.add_theme_font_size_override("font_size", 20)
	who.add_theme_color_override("font_color", accent)
	v.add_child(who)
	var time := Label.new()
	time.name = "Time"
	time.text = "00:00.00"
	time.add_theme_font_size_override("font_size", 38)
	time.add_theme_color_override("font_color", TEXT)
	v.add_child(time)
	return panel

func _layer_button(text: String, layer: int) -> Button:
	var b := _small_button(text, func(): _select_layer(layer))
	b.custom_minimum_size = Vector2(126, 70)
	b.set_meta("layer", layer)
	return b

func _select_layer(layer: int) -> void:
	if board_view == null:
		return
	if board_view.is_stack_mode():
		board_view.set_stack_mode(false)
		camera_rig.set_stack_mode(false, board_size)
	board_view.set_focus_layer(layer)
	_refresh_layer_buttons()
	_refresh_stack_button()

func _toggle_stack_mode() -> void:
	if board_view == null:
		return
	var enabled := not board_view.is_stack_mode()
	board_view.set_stack_mode(enabled)
	camera_rig.set_stack_mode(enabled, board_size)
	_refresh_layer_buttons()
	_refresh_stack_button()

func _reset_game_view(animated := true) -> void:
	if board_view == null:
		return
	board_view.reset_view_state(animated)
	camera_rig.reset_view(board_size, animated)
	_refresh_layer_buttons()
	_refresh_stack_button()
	if game_over:
		if animated:
			var timer := get_tree().create_timer(0.38)
			timer.timeout.connect(func(): camera_rig.start_victory_orbit(board_size), CONNECT_ONE_SHOT)
		else:
			camera_rig.start_victory_orbit(board_size)

func _set_view_controls_locked(locked: bool) -> void:
	for button in layer_buttons:
		button.disabled = locked
		button.modulate = Color(1, 1, 1, 0.45) if locked else Color.WHITE
	if stack_button:
		stack_button.disabled = locked
		stack_button.modulate = Color(1, 1, 1, 0.45) if locked else Color.WHITE

func _refresh_stack_button() -> void:
	if stack_button == null or board_view == null:
		return
	var active := board_view.is_stack_mode()
	_style_button(stack_button, Color(0.08, 0.34, 0.42, 1.0) if active else Color(0.07, 0.09, 0.13, 0.93), CYAN if active else TEXT, 18)

func _refresh_layer_buttons() -> void:
	if board_view == null:
		return
	for b in layer_buttons:
		var layer := int(b.get_meta("layer"))
		var active := not board_view.is_stack_mode() and layer == board_view.focused_layer
		b.add_theme_font_size_override("font_size", 23)
		_style_button(b, Color(0.08, 0.34, 0.42, 1.0) if active else Color(0.07, 0.09, 0.13, 0.93), CYAN if active else TEXT, 18)

func _on_cell_pressed(idx: int) -> void:
	if game_over or ai_busy or board == null:
		return
	if mode == "CPU" and current_player != 1:
		return
	_play_move(idx, current_player)

func _play_move(idx: int, player: int) -> void:
	if not board.play(idx, player):
		return
	board_view.place_piece(idx, player)
	last_move = idx
	total_moves += 1
	if mode == "CPU" and player == 1:
		human_moves += 1
	Input.vibrate_handheld(18)
	var win_line := board.check_win_from(idx, player)
	if not win_line.is_empty():
		_finish_game(player, win_line)
		return
	if board.is_full():
		_finish_game(0, PackedInt32Array())
		return
	current_player = 2 if current_player == 1 else 1
	_refresh_hud()
	if mode == "CPU" and current_player == 2:
		_take_ai_turn()

func _take_ai_turn() -> void:
	ai_busy = true
	_refresh_hud()
	await get_tree().create_timer(0.16).timeout
	var move := ai.choose_move(difficulty, 2)
	ai_busy = false
	if move >= 0 and not game_over:
		_play_move(move, 2)

func _finish_game(winner: int, line: PackedInt32Array) -> void:
	game_over = true
	ai_busy = false
	_set_view_controls_locked(true)
	camera_rig.stop_victory_orbit()
	camera_rig.set_interaction_enabled(false)

	# Smoothly normalize both the board and camera first. The winning line is
	# created only after the transition finishes, so its world-space endpoints
	# are guaranteed to match the canonical exploded layout.
	board_view.reset_view_state(true)
	camera_rig.reset_view(board_size, true)
	_refresh_layer_buttons()
	_refresh_stack_button()

	var transition_timer := get_tree().create_timer(0.42)
	transition_timer.timeout.connect(func():
		if not game_over or board_view == null:
			return
		if winner != 0:
			board_view.show_winning_line(line)
			Input.vibrate_handheld(80)
		_show_result(winner)
		camera_rig.start_victory_orbit(board_size)
	, CONNECT_ONE_SHOT)

func _show_result(winner: int) -> void:
	result_panel = PanelContainer.new()
	result_panel.anchor_left = 0.5
	result_panel.anchor_right = 0.5
	result_panel.anchor_top = 0.70
	result_panel.anchor_bottom = 0.70
	result_panel.offset_left = -420
	result_panel.offset_right = 420
	result_panel.offset_top = -155
	result_panel.offset_bottom = 190
	_apply_panel_style(result_panel, Color(0.04, 0.055, 0.08, 0.97), 32)
	hud.add_child(result_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	result_panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	margin.add_child(v)

	var top_row := HBoxContainer.new()
	top_row.custom_minimum_size = Vector2(0, 82)
	top_row.add_theme_constant_override("separation", 18)
	v.add_child(top_row)

	var title := Label.new()
	var extra := ""
	if winner == 0:
		title.text = "DRAW"
	elif mode == "CPU" and winner == 1:
		title.text = "YOU WIN"
		var r := score_store.record_score(board_size, difficulty, player_times[1], human_moves)
		extra = "  •  #%d" % int(r["rank"]) if int(r["rank"]) > 0 else ""
	elif mode == "CPU":
		title.text = "CPU WINS"
	else:
		title.text = "PLAYER %d WINS" % winner
	title.add_theme_font_size_override("font_size", 50)
	title.add_theme_color_override("font_color", GREEN if winner == 1 else TEXT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title)

	var meta := Label.new()
	if mode == "CPU":
		meta.text = "%s%s  •  %d moves" % [_format_time(player_times[1]), extra, human_moves]
	else:
		meta.text = "X %s  •  O %s" % [_format_time(player_times[1]), _format_time(player_times[2])]
	meta.custom_minimum_size = Vector2(300, 0)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta.add_theme_font_size_override("font_size", 24)
	meta.add_theme_color_override("font_color", MUTED)
	top_row.add_child(meta)

	v.add_child(_spacer(12))

	var buttons := HBoxContainer.new()
	buttons.custom_minimum_size = Vector2(0, 100)
	buttons.add_theme_constant_override("separation", 16)
	v.add_child(buttons)

	var rematch_btn := _accent_button("REMATCH", _start_game)
	rematch_btn.custom_minimum_size = Vector2(0, 96)
	rematch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(rematch_btn)

	var home_btn := _ghost_button("HOME", _show_home)
	home_btn.custom_minimum_size = Vector2(0, 96)
	home_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(home_btn)

func _refresh_hud() -> void:
	_refresh_timers()
	if turn_label == null:
		return
	if ai_busy:
		turn_label.text = "CPU THINKING…"
	elif current_player == 1:
		turn_label.text = "YOUR TURN — X" if mode == "CPU" else "PLAYER 1 — X"
	else:
		turn_label.text = "CPU — O" if mode == "CPU" else "PLAYER 2 — O"

func _refresh_timers() -> void:
	if timer_p1:
		timer_p1.text = _format_time(player_times[1])
	if timer_p2:
		timer_p2.text = "THINKING…" if mode == "CPU" and ai_busy else (_format_time(player_times[2]) if mode == "PVP" else "—")

func _show_highscores() -> void:
	_clear_ui()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.035, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.add_child(bg)
	var v := VBoxContainer.new()
	v.position = Vector2(70, 100)
	v.size = Vector2(940, 1650)
	v.add_theme_constant_override("separation", 12)
	overlay_root.add_child(v)
	v.add_child(_ghost_button("← BACK", _show_home))
	v.add_child(_title("HIGHSCORES"))
	for n in [3, 4, 5]:
		for d in ["CASUAL", "SMART", "EXPERT"]:
			var entries := score_store.get_scores(n, d)
			if entries.is_empty():
				continue
			v.add_child(_section_label("%d×%d×%d  •  %s" % [n, n, n, d]))
			for i in range(min(5, entries.size())):
				var e = entries[i]
				var row := Label.new()
				row.text = "#%d     %s     %d moves     %s" % [i + 1, _format_time(float(e["time"])), int(e["moves"]), String(e["date"])]
				row.add_theme_font_size_override("font_size", 27)
				row.add_theme_color_override("font_color", TEXT if i == 0 else MUTED)
				v.add_child(row)
	if v.get_child_count() <= 2:
		var empty := Label.new()
		empty.text = "No records yet. Beat the computer to set the first one."
		empty.add_theme_font_size_override("font_size", 27)
		empty.add_theme_color_override("font_color", MUTED)
		v.add_child(empty)

func _format_time(seconds: float) -> String:
	var total_cs := int(seconds * 100.0)
	var mins := int(total_cs / 6000)
	var secs := int(total_cs / 100) % 60
	var cs := total_cs % 100
	return "%02d:%02d.%02d" % [mins, secs, cs]

func _big_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(760, 98)
	b.add_theme_font_size_override("font_size", 31)
	b.pressed.connect(callback)
	_style_button(b, PANEL_2, TEXT, 24)
	return b

func _choice_button(text: String, callback: Callable) -> Button:
	return _big_button(text, callback)

func _accent_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 86)
	b.add_theme_font_size_override("font_size", 29)
	b.pressed.connect(callback)
	_style_button(b, CYAN, Color("#031019"), 22)
	return b

func _ghost_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 74)
	b.add_theme_font_size_override("font_size", 27)
	b.pressed.connect(callback)
	_style_button(b, Color(0.08, 0.10, 0.14, 0.70), TEXT, 20)
	return b

func _small_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(130, 70)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(callback)
	_style_button(b, Color(0.07, 0.09, 0.13, 0.93), TEXT, 18)
	return b

func _style_choice(b: Button, active: bool) -> void:
	_style_button(b, Color(0.12, 0.20, 0.25, 1.0) if active else PANEL_2, CYAN if active else TEXT, 24)

func _style_button(b: Button, color: Color, font_color: Color, radius: int) -> void:
	b.add_theme_color_override("font_color", font_color)
	b.add_theme_color_override("font_hover_color", font_color)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color.lightened(0.05) if state == "hover" else (color.darkened(0.08) if state == "pressed" else color)
		sb.corner_radius_top_left = radius
		sb.corner_radius_top_right = radius
		sb.corner_radius_bottom_left = radius
		sb.corner_radius_bottom_right = radius
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		b.add_theme_stylebox_override(state, sb)

func _apply_panel_style(panel: PanelContainer, color: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	panel.add_theme_stylebox_override("panel", sb)

func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 54)
	l.add_theme_color_override("font_color", TEXT)
	return l

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", MUTED)
	return l

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(1, h)
	return c
