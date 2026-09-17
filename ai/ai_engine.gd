class_name AIEngine
extends RefCounted

var board: BoardLogic
var rng := RandomNumberGenerator.new()
var deadline_ms := 0
var aborted := false
var nodes := 0

func _init(board_logic: BoardLogic) -> void:
	board = board_logic
	rng.randomize()

func choose_move(difficulty: String, ai_player: int = 2) -> int:
	var legal := board.legal_moves()
	if legal.is_empty():
		return -1
	var human := 1 if ai_player == 2 else 2

	var win_move := _find_immediate(ai_player)
	if win_move != -1 and (difficulty != "CASUAL" or rng.randf() > 0.08):
		return win_move

	var block_move := _find_immediate(human)
	if block_move != -1 and (difficulty != "CASUAL" or rng.randf() > 0.25):
		return block_move

	match difficulty:
		"CASUAL":
			return _choose_weighted_random(ai_player)
		"SMART":
			return _search_best(ai_player, 2 if board.size >= 5 else 3, 180)
		_:
			var depth := 4
			var budget := 550
			if board.size == 3:
				depth = 6
				budget = 700
			elif board.size == 4:
				depth = 4
				budget = 650
			else:
				depth = 3
				budget = 600
			return _iterative_deepening(ai_player, depth, budget)

func _find_immediate(player: int) -> int:
	for idx in board.legal_moves():
		board.play(idx, player)
		var won := not board.check_win_from(idx, player).is_empty()
		board.undo(idx)
		if won:
			return idx
	return -1

func _choose_weighted_random(player: int) -> int:
	var legal := board.legal_moves()
	var best_score := -INF
	var pool: Array[int] = []
	for idx in legal:
		var score := _move_static_score(idx, player)
		if score > best_score:
			best_score = score
			pool.clear()
			pool.append(idx)
		elif score >= best_score - 4.0:
			pool.append(idx)
	if rng.randf() < 0.45:
		return legal[rng.randi_range(0, legal.size() - 1)]
	return pool[rng.randi_range(0, pool.size() - 1)]

func _iterative_deepening(player: int, max_depth: int, budget_ms: int) -> int:
	deadline_ms = Time.get_ticks_msec() + budget_ms
	aborted = false
	var best := _choose_weighted_random(player)
	for depth in range(1, max_depth + 1):
		var candidate := _search_best(player, depth, max(1, deadline_ms - Time.get_ticks_msec()))
		if aborted:
			break
		if candidate != -1:
			best = candidate
	return best

func _search_best(player: int, depth: int, budget_ms: int) -> int:
	deadline_ms = Time.get_ticks_msec() + budget_ms
	aborted = false
	nodes = 0
	var opponent := 1 if player == 2 else 2
	var legal := _ordered_moves(player)
	var best_move := legal[0] if not legal.is_empty() else -1
	var best_score := -INF
	var alpha := -INF
	var beta := INF
	for idx in legal:
		if _out_of_time():
			aborted = true
			break
		board.play(idx, player)
		var won := not board.check_win_from(idx, player).is_empty()
		var score := 1_000_000.0 if won else -_negamax(opponent, player, depth - 1, -beta, -alpha)
		board.undo(idx)
		if score > best_score:
			best_score = score
			best_move = idx
		alpha = max(alpha, score)
	return best_move

func _negamax(player: int, root_player: int, depth: int, alpha_in: float, beta: float) -> float:
	nodes += 1
	if nodes % 128 == 0 and _out_of_time():
		aborted = true
		return 0.0
	if depth <= 0 or board.is_full():
		return _evaluate(player)

	var alpha := alpha_in
	var opponent := 1 if player == 2 else 2
	var legal := _ordered_moves(player)
	for idx in legal:
		board.play(idx, player)
		if not board.check_win_from(idx, player).is_empty():
			board.undo(idx)
			return 900_000.0 + depth * 100.0
		var score := -_negamax(opponent, root_player, depth - 1, -beta, -alpha)
		board.undo(idx)
		if aborted:
			return 0.0
		if score >= beta:
			return score
		alpha = max(alpha, score)
	return alpha

func _ordered_moves(player: int) -> Array[int]:
	var moves: Array[int] = []
	for idx in board.legal_moves():
		moves.append(idx)
	moves.sort_custom(func(a: int, b: int) -> bool: return _move_static_score(a, player) > _move_static_score(b, player))
	if board.size == 5 and moves.size() > 24:
		moves.resize(24)
	elif board.size == 4 and moves.size() > 32:
		moves.resize(32)
	return moves

func _move_static_score(idx: int, player: int) -> float:
	var p := board.coords(idx)
	var center := Vector3((board.size - 1) * 0.5, (board.size - 1) * 0.5, (board.size - 1) * 0.5)
	var dist := Vector3(p).distance_to(center)
	var score := 12.0 - dist * 2.0
	for line_idx in board.cell_to_lines[idx]:
		var line: PackedInt32Array = board.winning_lines[line_idx]
		var mine := 0
		var theirs := 0
		for c in line:
			if board.cells[c] == player:
				mine += 1
			elif board.cells[c] != 0:
				theirs += 1
		if theirs == 0:
			score += pow(3.0, mine)
		if mine == 0 and theirs > 0:
			score += pow(2.5, theirs) * 0.7
	return score

func _evaluate(player: int) -> float:
	var opponent := 1 if player == 2 else 2
	var score := 0.0
	for line in board.winning_lines:
		var mine := 0
		var theirs := 0
		for idx in line:
			if board.cells[idx] == player:
				mine += 1
			elif board.cells[idx] == opponent:
				theirs += 1
		if mine > 0 and theirs > 0:
			continue
		if mine > 0:
			score += pow(5.0, mine)
		elif theirs > 0:
			score -= pow(5.2, theirs)
	return score

func _out_of_time() -> bool:
	return Time.get_ticks_msec() >= deadline_ms
