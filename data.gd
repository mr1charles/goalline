class_name Data
extends RefCounted

# Fictional clubs only (no licences). Names are editable in Settings.
static func default_teams() -> Array:
	return [
		{"name": "Harbor Rovers", "style": 0, "short": "HAR", "c1": Color(0.86, 0.12, 0.14), "c2": Color(1, 1, 1), "rating": 70},
		{"name": "Northgate United", "style": 1, "short": "NOR", "c1": Color(0.10, 0.30, 0.80), "c2": Color(1, 1, 1), "rating": 74},
		{"name": "Riverside City", "style": 0, "short": "RIV", "c1": Color(0.45, 0.78, 0.95), "c2": Color(0.05, 0.1, 0.3), "rating": 78},
		{"name": "Kingsford Athletic", "style": 2, "short": "KIN", "c1": Color(0.95, 0.80, 0.10), "c2": Color(0.1, 0.1, 0.1), "rating": 66},
		{"name": "Redwood FC", "style": 1, "short": "RED", "c1": Color(0.55, 0.08, 0.10), "c2": Color(0.95, 0.85, 0.3), "rating": 62},
		{"name": "Valley Town", "style": 3, "short": "VAL", "c1": Color(0.10, 0.55, 0.28), "c2": Color(1, 1, 1), "rating": 58},
		{"name": "Ironbridge", "style": 0, "short": "IRO", "c1": Color(0.25, 0.25, 0.30), "c2": Color(0.9, 0.4, 0.1), "rating": 68},
		{"name": "Seaview Albion", "style": 2, "short": "SEA", "c1": Color(0.95, 0.95, 0.95), "c2": Color(0.1, 0.35, 0.7), "rating": 64},
	]

static func teams() -> Array:
	var t = default_teams()
	var f = FileAccess.open("user://teams.json", FileAccess.READ)
	if f:
		var j = JSON.parse_string(f.get_as_text())
		if j is Dictionary:
			for i in t.size():
				var k = str(i)
				if j.has(k) and str(j[k]).strip_edges() != "":
					t[i]["name"] = str(j[k]).strip_edges().left(22)
					t[i]["short"] = t[i]["name"].replace(" ", "").left(3).to_upper()
	return t

static func save_team_names(names: Array) -> void:
	var d := {}
	for i in names.size():
		d[str(i)] = names[i]
	var f = FileAccess.open("user://teams.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

# 4-3-3: role, depth (0 own goal .. 1 opp goal), lateral (-1..1)
static func formation() -> Array:
	return [
		["GK", 0.02, 0.0],
		["DEF", 0.22, -0.80], ["DEF", 0.19, -0.27], ["DEF", 0.19, 0.27], ["DEF", 0.22, 0.80],
		["MID", 0.42, -0.45], ["MID", 0.37, 0.0], ["MID", 0.42, 0.45],
		["FWD", 0.66, -0.75], ["FWD", 0.72, 0.0], ["FWD", 0.66, 0.75],
	]

const FIRST := ["A.", "B.", "C.", "D.", "E.", "F.", "G.", "H.", "J.", "K.", "L.", "M.", "N.", "O.", "P.", "R.", "S.", "T.", "V.", "W."]
const LAST := ["Alder", "Brook", "Castell", "Dunmore", "Ellery", "Fenwick", "Garrow", "Hale", "Ivers", "Jarrow", "Kestrel", "Lowe", "Marlow", "Norcott", "Oakes", "Pryor", "Quill", "Rowan", "Strand", "Thorne", "Underhill", "Vance", "Wick", "Yarrow", "Zeller"]

static func roster(team_idx: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + team_idx * 77
	var out := []
	for i in 11:
		out.append("%s %s" % [FIRST[rng.randi() % FIRST.size()], LAST[rng.randi() % LAST.size()]])
	return out
