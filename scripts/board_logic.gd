class_name BoardLogic
extends RefCounted

var size: int
var cells: PackedInt32Array
var winning_lines: Array[PackedInt32Array] = []
var cell_to_lines: Array = []

func _init(board_size: int = 3) -> void:
	size = board_size
	cells.resize(size * size * size)
	cells.fill(0)
	winning_lines = _generate_winning_lines(size)
	cell_to_lines.resize(cells.size())
	for i in range(cell_to_lines.size()):
		cell_to_lines[i] = []
	for line_index in range(winning_lines.size()):
		for idx in winning_lines[line_index]:
			cell_to_lines[idx].append(line_index)

func reset() -> void:
	cells.fill(0)

func index(x: int, y: int, z: int) -> int:
	return x + y * size + z * size * size

func coords(idx: int) -> Vector3i:
	var z := int(idx / (size * size))
	var rem := idx % (size * size)
	var y := int(rem / size)
	var x := rem % size
	return Vector3i(x, y, z)

func is_empty(idx: int) -> bool:
	return idx >= 0 and idx < cells.size() and cells[idx] == 0

func play(idx: int, player: int) -> bool:
	if not is_empty(idx):
		return false
	cells[idx] = player
	return true

func undo(idx: int) -> void:
	if idx >= 0 and idx < cells.size():
		cells[idx] = 0

func legal_moves() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(cells.size()):
		if cells[i] == 0:
			out.append(i)
	return out

func is_full() -> bool:
	for value in cells:
		if value == 0:
			return false
	return true

func check_win_from(idx: int, player: int) -> PackedInt32Array:
	if idx < 0 or idx >= cell_to_lines.size():
		return PackedInt32Array()
	for line_idx in cell_to_lines[idx]:
		var line: PackedInt32Array = winning_lines[line_idx]
		var ok := true
		for cell_idx in line:
			if cells[cell_idx] != player:
				ok = false
				break
		if ok:
			return line
	return PackedInt32Array()

func winner() -> Dictionary:
	for line in winning_lines:
		var first := cells[line[0]]
		if first == 0:
			continue
		var ok := true
		for idx in line:
			if cells[idx] != first:
				ok = false
				break
		if ok:
			return {"player": first, "line": line}
	return {"player": 0, "line": PackedInt32Array()}

func _generate_winning_lines(n: int) -> Array[PackedInt32Array]:
	var lines: Array[PackedInt32Array] = []
	var dirs: Array[Vector3i] = []
	for dz in range(-1, 2):
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0 and dz == 0:
					continue
				# Canonical half-space to avoid reverse duplicates.
				if dz > 0 or (dz == 0 and dy > 0) or (dz == 0 and dy == 0 and dx > 0):
					dirs.append(Vector3i(dx, dy, dz))

	for z in range(n):
		for y in range(n):
			for x in range(n):
				var start := Vector3i(x, y, z)
				for d in dirs:
					var end := start + d * (n - 1)
					if not _inside(end, n):
						continue
					# Start must be the first in this direction; otherwise this is the same line shifted.
					var before := start - d
					if _inside(before, n):
						continue
					var line := PackedInt32Array()
					for step in range(n):
						var p := start + d * step
						line.append(p.x + p.y * n + p.z * n * n)
					lines.append(line)
	return lines

func _inside(p: Vector3i, n: int) -> bool:
	return p.x >= 0 and p.x < n and p.y >= 0 and p.y < n and p.z >= 0 and p.z < n
