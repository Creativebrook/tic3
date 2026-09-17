class_name ScoreStore
extends RefCounted

const PATH := "user://tic3_scores.json"
const MAX_PER_BUCKET := 10

func load_scores() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func record_score(size: int, difficulty: String, seconds: float, moves: int) -> Dictionary:
	var data := load_scores()
	var key := "%dx%dx%d_%s" % [size, size, size, difficulty]
	if not data.has(key):
		data[key] = []
	var entries: Array = data[key]
	entries.append({
		"time": snapped(seconds, 0.01),
		"moves": moves,
		"date": Time.get_date_string_from_system()
	})
	entries.sort_custom(func(a, b):
		if abs(float(a["time"]) - float(b["time"])) < 0.001:
			return int(a["moves"]) < int(b["moves"])
		return float(a["time"]) < float(b["time"])
	)
	if entries.size() > MAX_PER_BUCKET:
		entries.resize(MAX_PER_BUCKET)
	data[key] = entries
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	return {"rank": _find_rank(entries, seconds, moves), "entries": entries}

func get_scores(size: int, difficulty: String) -> Array:
	var data := load_scores()
	var key := "%dx%dx%d_%s" % [size, size, size, difficulty]
	return data.get(key, [])

func _find_rank(entries: Array, seconds: float, moves: int) -> int:
	for i in range(entries.size()):
		var e = entries[i]
		if abs(float(e["time"]) - snapped(seconds, 0.01)) < 0.011 and int(e["moves"]) == moves:
			return i + 1
	return -1
