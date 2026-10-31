class_name PracticeData
extends RefCounted
# Persistent practice progress: best score + stars per drill, banked skill points.

const SAVE := "user://practice.json"
const STAR_PTS := [0, 1, 2, 4]

static func load_all() -> Dictionary:
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f:
		var j = JSON.parse_string(f.get_as_text())
		if j is Dictionary:
			return j
	return {"best": {}, "banked": 0, "free_xp_total": 0}

static func save_all(d: Dictionary) -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

static func stars(drill: String) -> int:
	var d := load_all()
	return int(d["best"].get(drill, {}).get("stars", 0))

static func best_score(drill: String):
	var d := load_all()
	return d["best"].get(drill, {}).get("score", null)

# returns points newly earned (only improvements over the previous best pay out)
static func record(drill: String, score: float, star_count: int) -> int:
	var d := load_all()
	var old: Dictionary = d["best"].get(drill, {})
	var old_pts := int(old.get("pts", 0))
	var new_pts: int = STAR_PTS[clampi(star_count, 0, 3)]
	var gain := maxi(0, new_pts - old_pts)
	var keep_score = score
	if old.has("score") and drill == "slalom":
		keep_score = minf(float(old["score"]), score)
	elif old.has("score"):
		keep_score = maxf(float(old["score"]), score)
	d["best"][drill] = {"score": keep_score, "stars": maxi(int(old.get("stars", 0)), star_count), "pts": maxi(old_pts, new_pts)}
	save_all(d)
	if gain > 0:
		bank(gain)
	return gain

static func bank(points: int) -> void:
	if points <= 0:
		return
	if Career.exists():
		var c := Career.new()
		if c.load_save():
			c.d["player"]["pts"] += points
			c.save()
			return
	var d := load_all()
	d["banked"] = int(d.get("banked", 0)) + points
	save_all(d)

static func take_banked() -> int:
	var d := load_all()
	var n := int(d.get("banked", 0))
	d["banked"] = 0
	save_all(d)
	return n

static func banked() -> int:
	return int(load_all().get("banked", 0))
