class_name Career
extends RefCounted
# "Become a Legend"-style career: one created player, one club, a league season.

const SAVE := "user://career.json"
const POS := {
	"ST": 9, "LW": 8, "RW": 10, "CAM": 5, "CM": 7, "CDM": 6, "CB": 2, "LB": 1, "RB": 4,
}
const ARCH := {
	"Pace merchant": {"pace": 74, "shoot": 58, "pass": 55, "defend": 30},
	"Finisher": {"pace": 62, "shoot": 72, "pass": 52, "defend": 28},
	"Playmaker": {"pace": 58, "shoot": 56, "pass": 72, "defend": 38},
	"Ball winner": {"pace": 60, "shoot": 40, "pass": 58, "defend": 68},
}

var d := {}

static func exists() -> bool:
	return FileAccess.file_exists(SAVE)

static func delete_save() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

func load_save() -> bool:
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return false
	var j = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		d = j
		return true
	return false

func save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

static func team_rs(rating: float, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"att": rating + rng.randi_range(-4, 4), "mid": rating + rng.randi_range(-4, 4),
		"def": rating + rng.randi_range(-4, 4), "gk": rating + rng.randi_range(-5, 5), "fit": rating,
	}

func new_career(pname: String, pos: String, number: int, arch: String, club: int) -> void:
	var base: Dictionary = ARCH[arch]
	var teams := Data.teams()
	var ratings := []
	for t in teams:
		ratings.append(float(t["rating"]))
	d = {
		"player": {"name": pname, "pos": pos, "slot": POS[pos], "number": number, "age": 17,
			"pace": base["pace"], "shoot": base["shoot"], "pass": base["pass"], "defend": base["defend"], "pts": 3},
		"club": club, "season": 1, "year": 2026, "round": 0,
		"ratings": ratings,
		"stats": {"apps": 0, "goals": 0, "assists": 0, "rating_sum": 0.0},
		"season_stats": {"apps": 0, "goals": 0, "assists": 0, "rating_sum": 0.0},
		"trophies": [], "history": [],
	}
	_start_season()
	save()

func _start_season() -> void:
	d["fixtures"] = _make_fixtures(8)
	d["round"] = 0
	d["results"] = []
	d["season_stats"] = {"apps": 0, "goals": 0, "assists": 0, "rating_sum": 0.0}
	var tb := {}
	for i in 8:
		tb[str(i)] = {"p": 0, "w": 0, "dr": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}
	d["table"] = tb

static func _make_fixtures(n: int) -> Array:
	var ids := []
	for i in n:
		ids.append(i)
	var rounds := []
	for r in n - 1:
		var rd := []
		for i in n / 2:
			var a: int = ids[i]
			var b: int = ids[n - 1 - i]
			if r % 2 == 0:
				rd.append([a, b])
			else:
				rd.append([b, a])
		rounds.append(rd)
		var last: int = ids.pop_back()
		ids.insert(1, last)
	var second := []
	for rd in rounds:
		var rr := []
		for f in rd:
			rr.append([f[1], f[0]])
		second.append(rr)
	return rounds + second

func total_rounds() -> int:
	return d["fixtures"].size()

func season_over() -> bool:
	return d["round"] >= total_rounds()

func next_fixture() -> Array:
	for f in d["fixtures"][d["round"]]:
		if f[0] == d["club"] or f[1] == d["club"]:
			return f
	return []

func ovr() -> int:
	var p: Dictionary = d["player"]
	var pos: String = p["pos"]
	var v := 0.0
	if pos in ["ST", "LW", "RW"]:
		v = p["pace"] * 0.3 + p["shoot"] * 0.4 + p["pass"] * 0.2 + p["defend"] * 0.1
	elif pos in ["CAM", "CM"]:
		v = p["pace"] * 0.2 + p["shoot"] * 0.2 + p["pass"] * 0.45 + p["defend"] * 0.15
	else:
		v = p["pace"] * 0.2 + p["shoot"] * 0.05 + p["pass"] * 0.25 + p["defend"] * 0.5
	return int(round(v))

static func _poisson(lam: float, rng: RandomNumberGenerator) -> int:
	var l := exp(-lam)
	var k := 0
	var p := 1.0
	while true:
		k += 1
		p *= rng.randf()
		if p <= l:
			break
		if k > 10:
			break
	return k - 1

func _record(h: int, a: int, gh: int, ga: int) -> void:
	var tb: Dictionary = d["table"]
	var th: Dictionary = tb[str(h)]
	var ta: Dictionary = tb[str(a)]
	th["p"] += 1
	ta["p"] += 1
	th["gf"] += gh
	th["ga"] += ga
	ta["gf"] += ga
	ta["ga"] += gh
	if gh > ga:
		th["w"] += 1
		th["pts"] += 3
		ta["l"] += 1
	elif gh < ga:
		ta["w"] += 1
		ta["pts"] += 3
		th["l"] += 1
	else:
		th["dr"] += 1
		ta["dr"] += 1
		th["pts"] += 1
		ta["pts"] += 1

# Called after the user's match. Simulates every other match in the round.
func apply_result(gh: int, ga: int, rating: float, goals: int, assists: int, rng: RandomNumberGenerator) -> Dictionary:
	var fx := next_fixture()
	var rd: Array = d["fixtures"][d["round"]]
	for f in rd:
		if f == fx:
			_record(f[0], f[1], gh, ga)
		else:
			var rh: float = d["ratings"][f[0]]
			var ra: float = d["ratings"][f[1]]
			var lh := 1.35 * pow(rh / ra, 1.6) * 1.1
			var la := 1.1 * pow(ra / rh, 1.6)
			_record(f[0], f[1], _poisson(lh, rng), _poisson(la, rng))
	d["results"].append({"round": d["round"], "h": fx[0], "a": fx[1], "gh": gh, "ga": ga, "rating": rating})
	for k in ["stats", "season_stats"]:
		var s: Dictionary = d[k]
		s["apps"] += 1
		s["goals"] += goals
		s["assists"] += assists
		s["rating_sum"] += rating
	var pts := maxi(1, int(round(rating)) - 4 + goals * 2 + assists)
	d["player"]["pts"] += pts
	d["round"] += 1
	save()
	return {"pts": pts}

func train(stat: String) -> bool:
	var p: Dictionary = d["player"]
	if p["pts"] < 1 or p[stat] >= 99:
		return false
	p["pts"] -= 1
	p[stat] += 1
	save()
	return true

func table_sorted() -> Array:
	var rows := []
	for k in d["table"]:
		var r: Dictionary = d["table"][k].duplicate()
		r["team"] = int(k)
		r["gd"] = r["gf"] - r["ga"]
		rows.append(r)
	rows.sort_custom(func(a, b):
		if a["pts"] != b["pts"]:
			return a["pts"] > b["pts"]
		if a["gd"] != b["gd"]:
			return a["gd"] > b["gd"]
		return a["gf"] > b["gf"])
	return rows

func position() -> int:
	var t := table_sorted()
	for i in t.size():
		if t[i]["team"] == d["club"]:
			return i + 1
	return 8

func avg_rating() -> float:
	var s: Dictionary = d["season_stats"]
	return s["rating_sum"] / maxf(1.0, float(s["apps"]))

func offers(rng: RandomNumberGenerator) -> Array:
	# better seasons attract stronger clubs
	var strength := clampf((avg_rating() - 6.0) / 2.0, 0.0, 1.0) + (0.25 if position() <= 2 else 0.0)
	var cands := []
	for i in 8:
		if i == d["club"]:
			continue
		cands.append(i)
	cands.sort_custom(func(a, b): return d["ratings"][a] > d["ratings"][b])
	var out := []
	var span := cands.size()
	var start := int(round((1.0 - clampf(strength, 0.0, 1.0)) * (span - 3)))
	for i in 3:
		out.append(cands[mini(start + i, span - 1)])
	return out

func finish_season() -> Dictionary:
	var pos := position()
	var res := {"position": pos, "champion": pos == 1}
	if pos == 1:
		d["trophies"].append("Season %d League Title" % d["season"])
	d["history"].append({"season": d["season"], "club": d["club"], "pos": pos, "goals": d["season_stats"]["goals"], "assists": d["season_stats"]["assists"], "avg": avg_rating()})
	return res

func next_season(club: int, rng: RandomNumberGenerator) -> void:
	d["club"] = club
	d["season"] += 1
	d["year"] += 1
	d["player"]["age"] += 1
	d["player"]["pts"] += 4
	# league drift
	for i in 8:
		d["ratings"][i] = clampf(d["ratings"][i] + rng.randi_range(-3, 3), 50, 88)
	_start_season()
	save()
