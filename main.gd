extends Node

var layer: CanvasLayer
var root: Control
var career := Career.new()
var match_node: MatchScene = null
var settings := {"minutes": 4, "diff": 1.0}
var rng := RandomNumberGenerator.new()
var ui_theme: Theme

func _ready() -> void:
	rng.randomize()
	var teams := Data.teams()
	var args := OS.get_cmdline_user_args()
	if "--shots" in args:
		Engine.time_scale = 2.0
		_shots(teams, "legend" if "--legend" in args else "kickoff")
		return
	if "--autotest" in args:
		var h: Dictionary = teams[0].duplicate()
		var a: Dictionary = teams[1].duplicate()
		h["idx"] = 0
		a["idx"] = 1
		h["rs"] = {"att": 70, "mid": 70, "def": 70, "gk": 70, "fit": 70}
		a["rs"] = {"att": 70, "mid": 70, "def": 70, "gk": 70, "fit": 70}
		Engine.time_scale = 30.0
		Engine.max_physics_steps_per_frame = 60
		var m := MatchScene.new()
		m.cfg = {"home": h, "away": a, "minutes": 2, "human_team": -1, "mode": "kickoff", "diff": 1.0, "debug": false}
		add_child(m)
		m.finished.connect(func(r): print("SUMMARY goals=%d,%d shots=%d,%d on=%d,%d passes=%d,%d tackles=%d kicks=%d throw=%d corner=%d gk=%d" % [r["score"][0], r["score"][1], r["shots"][0], r["shots"][1], r["shots_on"][0], r["shots_on"][1], m.passes_done[0], m.passes_done[1], r["log"]["tackles"], r["log"]["kicks"], r["log"]["throwins"], r["log"]["corners"], r["log"]["goalkicks"]]); get_tree().quit())
		return
	if "--practicetest" in args:
		Engine.time_scale = 3.0
		Engine.max_physics_steps_per_frame = 8
		_practice_test()
		return
	for arg in args:
		if arg.begins_with("--pshots="):
			_practice_shots(arg.substr(9))
			return
	if "--teltest" in args:
		var tel := Telemetry.new()
		add_child(tel)
		tel.hosts.push_front("http://127.0.0.1:8799")
		Telemetry.ev("hello", {"from": "teltest"})
		push_error("teltest deliberate error")
		push_warning("teltest deliberate warning")
		var m := MatchScene.new()
		var tm := Data.teams()
		tm[0]["idx"] = 0
		tm[1]["idx"] = 1
		tm[0]["rs"] = {"att": 70, "mid": 70, "def": 70, "gk": 70, "fit": 70}
		tm[1]["rs"] = tm[0]["rs"]
		m.cfg = {"home": tm[0], "away": tm[1], "minutes": 1, "human_team": 0, "mode": "legend", "diff": 1.0, "legend": {"name": "T. Est", "slot": 9, "number": 9, "pace": 60, "shoot": 60, "pass": 60, "defend": 40}}
		add_child(m)
		tel.in_match = true
		await get_tree().create_timer(14.0).timeout
		get_tree().quit()
		return
	if "--careertest" in args:
		Engine.time_scale = 30.0
		Engine.max_physics_steps_per_frame = 60
		_career_test()
		return
	_load_settings()
	TouchUI.scale_f = float(settings.get("btn_scale", 1.0))
	TouchUI.lefty = bool(settings.get("lefty", false))
	TouchUI.opacity = float(settings.get("btn_opacity", 1.0))
	var tel := Telemetry.new()
	add_child(tel)
	ui_theme = _make_theme()
	layer = CanvasLayer.new()
	add_child(layer)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = ui_theme
	layer.add_child(root)
	if "--uishots" in args:
		_ui_shots()
		return
	_main_menu()

# ------------------------------------------------------------ helpers

func _load_settings() -> void:
	var f := FileAccess.open("user://settings.json", FileAccess.READ)
	if f:
		var j = JSON.parse_string(f.get_as_text())
		if j is Dictionary:
			for k in j:
				settings[k] = j[k]

func _save_settings() -> void:
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.12, 0.42, 0.22), "hover": Color(0.16, 0.5, 0.27), "pressed": Color(0.08, 0.3, 0.16), "focus": Color(0.12, 0.42, 0.22), "disabled": Color(0.2, 0.2, 0.2)}[st]
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		if st == "focus":
			sb.bg_color = Color(0, 0, 0, 0)
			sb.set_border_width_all(3)
			sb.border_color = Color(1, 1, 1, 0.8)
		t.set_stylebox(st, "Button", sb)
	return t

func _screen(title: String, sub := "") -> VBoxContainer:
	Telemetry.ev("screen", {"name": title})
	for c in root.get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.12, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = Color(0.1, 0.3, 0.17)
	stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stripe.custom_minimum_size = Vector2(0, 10)
	root.add_child(stripe)
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		mc.add_theme_constant_override("margin_" + s, 56)
	mc.add_theme_constant_override("margin_top", 28)
	mc.add_theme_constant_override("margin_bottom", 28)
	root.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	mc.add_child(vb)
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 44)
	vb.add_child(tl)
	if sub != "":
		var sl := Label.new()
		sl.text = sub
		sl.add_theme_font_size_override("font_size", 22)
		sl.modulate = Color(0.8, 0.9, 0.8)
		vb.add_child(sl)
	return vb

func _btn(parent: Node, text: String, cb: Callable, min_h := 64) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _lab(parent: Node, text: String, size := 24, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(400, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l

func _opt(parent: Node, items: Array, sel := 0) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(sel)
	o.custom_minimum_size = Vector2(0, 58)
	parent.add_child(o)
	return o

func _team_cfg(idx: int, rating: float) -> Dictionary:
	var t: Dictionary = Data.teams()[idx].duplicate()
	t["idx"] = idx
	t["rs"] = Career.team_rs(rating, rng)
	return t

func _fix_clash(h: Dictionary, a: Dictionary) -> Dictionary:
	var c1: Color = h["c1"]
	var c2: Color = a["c1"]
	var dist := absf(c1.r - c2.r) + absf(c1.g - c2.g) + absf(c1.b - c2.b)
	if dist < 0.9:
		var b := a.duplicate()
		b["c1"] = a["c2"]
		b["c2"] = a["c1"]
		return b
	return a

func _launch_match(cfgm: Dictionary, on_done: Callable) -> void:
	Telemetry.ev("match_launch", {"mode": cfgm.get("mode"), "home": cfgm["home"].get("name"), "away": cfgm["away"].get("name"), "minutes": cfgm.get("minutes"), "tod": cfgm.get("tod", "auto")})
	if Telemetry.inst != null:
		Telemetry.inst.in_match = true
	layer.visible = false
	match_node = MatchScene.new()
	match_node.cfg = cfgm
	add_child(match_node)
	match_node.finished.connect(func(r):
		Telemetry.ev("match_end", {"score": r.get("score"), "rating": r.get("rating"), "quit": r.get("quit", false), "legend": r.get("legend"), "log": r.get("log")})
		if Telemetry.inst != null:
			Telemetry.inst.in_match = false
		match_node.queue_free()
		match_node = null
		layer.visible = true
		on_done.call(r))

# ------------------------------------------------------------ main menu

func _main_menu() -> void:
	var vb := _screen("GOALLINE", "Offline football. No licences, no internet needed.")
	vb.add_spacer(false)
	_btn(vb, "Kick Off", _kickoff_setup, 74)
	_btn(vb, "Become a Legend  (Career)", _career_entry, 74)
	_btn(vb, "Practice", _practice_menu, 74)
	_btn(vb, "Settings", _settings, 74)
	vb.add_spacer(false)
	_lab(vb, "Left thumb moves. Right thumb: SHOOT / PASS / THRU / LOB, hold SPRINT, tap SKILL. On defence: B tackle, X slide, A/Y switch or call.", 18, true)

func _kickoff_setup() -> void:
	var vb := _screen("Kick Off")
	var teams := Data.teams()
	var names := []
	for t in teams:
		names.append(t["name"])
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 10)
	vb.add_child(g)
	_lab(g, "Your team").custom_minimum_size.x = 300
	var o1 := _opt(g, names, 0)
	o1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lab(g, "Opponent")
	var o2 := _opt(g, names, 1)
	o2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lab(g, "Match length (min)")
	var mins := [1, 2, 3, 5, 8, 10]
	var o3 := _opt(g, mins, mins.find(settings["minutes"]) if mins.has(settings["minutes"]) else 2)
	o3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lab(g, "Difficulty")
	var diffs := ["Easy", "Normal", "Hard"]
	var o4 := _opt(g, diffs, 1)
	o4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_spacer(false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	vb.add_child(row)
	_btn(row, "Back", _main_menu).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var go := _btn(row, "Play", func():
		var hi := o1.selected
		var ai := o2.selected
		if hi == ai:
			ai = (hi + 1) % teams.size()
		var h := _team_cfg(hi, teams[hi]["rating"])
		var a := _fix_clash(h, _team_cfg(ai, teams[ai]["rating"]))
		var dv = [0.85, 1.0, 1.15][o4.selected]
		_launch_match({"home": h, "away": a, "minutes": mins[o3.selected], "human_team": 0, "mode": "kickoff", "diff": dv}, func(_r): _main_menu()))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _settings() -> void:
	var vb := _screen("Settings", "Controls, diagnostics and club names (saved on this device).")
	var teams := Data.teams()
	var edits := []
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	sc.add_child(inner)
	var mins := [2, 3, 4, 5, 8, 10]
	_lab(inner, "Career match length (min)")
	var o := _opt(inner, mins, mins.find(settings["minutes"]) if mins.has(settings["minutes"]) else 2)
	_lab(inner, "Touch controls")
	var sizes := [0.85, 1.0, 1.2]
	var size_o := _opt(inner, ["Small buttons", "Normal buttons", "Large buttons"], sizes.find(TouchUI.scale_f) if sizes.has(TouchUI.scale_f) else 1)
	var left_cb := CheckBox.new()
	left_cb.text = "Left-handed layout"
	left_cb.button_pressed = TouchUI.lefty
	left_cb.custom_minimum_size = Vector2(0, 56)
	inner.add_child(left_cb)
	var ops := [1.0, 0.75, 0.5]
	var op_o := _opt(inner, ["Buttons 100% visible", "Buttons 75% visible", "Buttons 50% visible"], ops.find(TouchUI.opacity) if ops.has(TouchUI.opacity) else 0)
	var tel_cb := CheckBox.new()
	tel_cb.text = "Send diagnostics to the developer's laptop (Wi-Fi)"
	tel_cb.button_pressed = Telemetry.inst == null or Telemetry.inst.enabled
	tel_cb.custom_minimum_size = Vector2(0, 56)
	inner.add_child(tel_cb)
	var host_le := LineEdit.new()
	host_le.placeholder_text = "Log server (optional), e.g. http://192.168.1.129:8799"
	host_le.custom_minimum_size = Vector2(0, 56)
	inner.add_child(host_le)
	_lab(inner, "Club names")
	for i in teams.size():
		var le := LineEdit.new()
		le.text = teams[i]["name"]
		le.custom_minimum_size = Vector2(0, 56)
		inner.add_child(le)
		edits.append(le)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	vb.add_child(row)
	_btn(row, "Cancel", _main_menu).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn(row, "Save", func():
		var names := []
		for e in edits:
			names.append(e.text)
		Data.save_team_names(names)
		settings["minutes"] = mins[o.selected]
		settings["btn_scale"] = sizes[size_o.selected]
		settings["lefty"] = left_cb.button_pressed
		settings["btn_opacity"] = ops[op_o.selected]
		TouchUI.scale_f = sizes[size_o.selected]
		TouchUI.lefty = left_cb.button_pressed
		TouchUI.opacity = ops[op_o.selected]
		_save_settings()
		var tf := FileAccess.open("user://telemetry.json", FileAccess.WRITE)
		if tf:
			tf.store_string(JSON.stringify({"enabled": tel_cb.button_pressed, "host": host_le.text.strip_edges()}))
		if Telemetry.inst != null:
			Telemetry.inst.enabled = tel_cb.button_pressed
			if host_le.text.strip_edges() != "":
				Telemetry.inst.hosts.push_front(host_le.text.strip_edges())
		_main_menu()).size_flags_horizontal = Control.SIZE_EXPAND_FILL

# ------------------------------------------------------------ practice

var practice_note := ""

func _skill_points_text() -> String:
	if Career.exists():
		var c := Career.new()
		if c.load_save():
			return "Career skill points: %d" % c.d["player"]["pts"]
	return "Banked skill points: %d (added to your first career)" % PracticeData.banked()

func _practice_menu() -> void:
	var vb := _screen("Practice", _skill_points_text() + ("   |   " + practice_note if practice_note != "" else ""))
	practice_note = ""
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(g)
	for id in PracticeScene.ORDER:
		var info: Dictionary = PracticeScene.DRILLS[id]
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st := PracticeData.stars(id)
		var best = PracticeData.best_score(id)
		var tag := "" if id == "free" else ("   " + "★".repeat(st) + "☆".repeat(3 - st) + ("   best %s" % ("%.1fs" % best if id == "slalom" else str(int(best))) if best != null else ""))
		_btn(card, info["name"] + tag, func(): _launch_practice(id), 58)
		_lab(card, info["desc"], 15, true)
		g.add_child(card)
	_btn(vb, "Back", _main_menu, 60)

func _launch_practice(drill: String) -> void:
	var teams := Data.teams()
	var club := 0
	var lg := {"name": "You", "number": 10, "pace": 62, "shoot": 62, "pass": 60, "defend": 40}
	if Career.exists():
		var c := Career.new()
		if c.load_save():
			club = c.d["club"]
			var pl: Dictionary = c.d["player"]
			lg = {"name": pl["name"], "number": pl["number"], "pace": pl["pace"], "shoot": pl["shoot"], "pass": pl["pass"], "defend": pl["defend"]}
	var h := _team_cfg(club, teams[club]["rating"])
	var a := _fix_clash(h, _team_cfg((club + 1) % teams.size(), 65.0))
	Telemetry.ev("practice_launch", {"drill": drill})
	if Telemetry.inst != null:
		Telemetry.inst.in_match = true
	layer.visible = false
	var ps := PracticeScene.new()
	ps.cfg = {"home": h, "away": a, "drill": drill, "legend": lg, "tod": ["day", "dusk"][rng.randi() % 2]}
	match_node = ps
	add_child(ps)
	ps.finished.connect(func(r):
		Telemetry.ev("practice_end", r)
		if Telemetry.inst != null:
			Telemetry.inst.in_match = false
		ps.queue_free()
		match_node = null
		layer.visible = true
		if r.get("points", 0) > 0:
			practice_note = "+%d skill points earned" % r["points"]
		_practice_menu())

# ------------------------------------------------------------ career

func _career_entry() -> void:
	var vb := _screen("Become a Legend", "Create a young player, sign for a club, and play every match as them.")
	vb.add_spacer(false)
	if Career.exists():
		_btn(vb, "Continue career", func():
			if career.load_save():
				_career_hub()
			else:
				_career_create(), 76)
	_btn(vb, "New career", _career_create, 76)
	_btn(vb, "Back", _main_menu, 76)
	vb.add_spacer(false)

func _career_create() -> void:
	var vb := _screen("Create your player")
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 10)
	vb.add_child(g)
	_lab(g, "Name").custom_minimum_size.x = 300
	var le := LineEdit.new()
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text = "Jay Rivera"
	le.max_length = 18
	le.custom_minimum_size = Vector2(0, 58)
	g.add_child(le)
	_lab(g, "Position")
	var pos_keys := Career.POS.keys()
	var o1 := _opt(g, pos_keys, pos_keys.find("ST"))
	o1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lab(g, "Shirt number")
	var sp := SpinBox.new()
	sp.min_value = 1
	sp.max_value = 99
	sp.value = 10
	sp.custom_minimum_size = Vector2(0, 58)
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(sp)
	_lab(g, "Play style")
	var arch_keys := Career.ARCH.keys()
	var o2 := _opt(g, arch_keys, 1)
	o2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lab(g, "First club")
	var teams := Data.teams()
	var starters := [3, 4, 5, 6, 7]
	var names := []
	for i in starters:
		names.append("%s  (%d)" % [teams[i]["name"], teams[i]["rating"]])
	var o3 := _opt(g, names, 0)
	o3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_spacer(false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	vb.add_child(row)
	_btn(row, "Back", _career_entry).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn(row, "Sign contract", func():
		var nm := le.text.strip_edges()
		if nm == "":
			nm = "Rookie"
		career = Career.new()
		career.new_career(nm, pos_keys[o1.selected], int(sp.value), arch_keys[o2.selected], starters[o3.selected])
		var extra := PracticeData.take_banked()
		if extra > 0:
			career.d["player"]["pts"] += extra
			career.save()
		_career_intro()).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _career_intro() -> void:
	var teams := Data.teams()
	var p: Dictionary = career.d["player"]
	var vb := _screen("January %d" % career.d["year"])
	vb.add_spacer(false)
	_lab(vb, "%s signs for %s." % [p["name"], teams[career.d["club"]]["name"]], 34, true)
	_lab(vb, "Season %d.  Your career is in your hands." % career.d["season"], 28, true)
	vb.add_spacer(false)
	_btn(vb, "Walk out", _career_hub, 76)

func _career_hub() -> void:
	var teams := Data.teams()
	var p: Dictionary = career.d["player"]
	if career.season_over():
		_career_season_end()
		return
	var fx := career.next_fixture()
	var club: int = career.d["club"]
	var vb := _screen("%s  #%d" % [p["name"], p["number"]], "%s  |  %s  |  OVR %d  |  Age %d  |  Season %d" % [p["pos"], teams[club]["name"], career.ovr(), p["age"], career.d["season"]])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	for k in ["pace", "shoot", "pass", "defend"]:
		var l := _lab(left, "%s  %d" % [k.capitalize(), p[k]], 26)
		var bar := ProgressBar.new()
		bar.max_value = 99
		bar.value = p[k]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		left.add_child(bar)
	var s: Dictionary = career.d["stats"]
	_lab(left, "Career: %d apps, %d goals, %d assists, avg %.1f" % [s["apps"], s["goals"], s["assists"], s["rating_sum"] / maxf(1.0, float(s["apps"]))], 20, true)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	_lab(right, "Round %d of %d" % [career.d["round"] + 1, career.total_rounds()], 22)
	_lab(right, "%s  vs  %s" % [teams[fx[0]]["name"], teams[fx[1]]["name"]], 30)
	_btn(right, "Play match", _career_play, 80)
	_btn(right, "Training  (%d points)" % p["pts"], _career_training, 64)
	_btn(right, "League table", func(): _career_table(false), 64)
	_btn(right, "Main menu", _main_menu, 64)

func _career_play() -> void:
	var fx := career.next_fixture()
	var club: int = career.d["club"]
	var h := _team_cfg(fx[0], career.d["ratings"][fx[0]])
	var a := _fix_clash(h, _team_cfg(fx[1], career.d["ratings"][fx[1]]))
	var ht := 0 if fx[0] == club else 1
	var p: Dictionary = career.d["player"]
	var lg := {"name": p["name"], "slot": p["slot"], "number": p["number"], "pace": p["pace"], "shoot": p["shoot"], "pass": p["pass"], "defend": p["defend"]}
	_launch_match({"home": h, "away": a, "minutes": settings["minutes"], "human_team": ht, "mode": "legend", "diff": settings["diff"], "legend": lg},
		func(r): _career_match_done(r, ht))

func _career_match_done(r: Dictionary, ht: int) -> void:
	if r.get("quit", false):
		_career_hub()
		return
	var teams := Data.teams()
	var fx := career.next_fixture()
	var lg: Dictionary = r["legend"]
	var res := career.apply_result(r["score"][0], r["score"][1], r["rating"], lg["goals"], lg["assists"], rng)
	var vb := _screen("Full time", "%s  %d - %d  %s" % [teams[fx[0]]["name"], r["score"][0], r["score"][1], teams[fx[1]]["name"]])
	vb.add_spacer(false)
	_lab(vb, "Your match rating: %.1f" % r["rating"], 40)
	_lab(vb, "%d goals, %d assists, %d completed passes, %d tackles won" % [lg["goals"], lg["assists"], lg["passes"], lg["tackles"]], 26, true)
	_lab(vb, "+%d training points" % res["pts"], 28)
	vb.add_spacer(false)
	_btn(vb, "Continue", _career_hub, 76)

func _career_training() -> void:
	var p: Dictionary = career.d["player"]
	var vb := _screen("Training", "%d points to spend. Each point adds +1." % p["pts"])
	for k in ["pace", "shoot", "pass", "defend"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		vb.add_child(row)
		var l := _lab(row, "%s  %d" % [k.capitalize(), p[k]], 30)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := _btn(row, "+1", func():
			career.train(k)
			_career_training())
		b.custom_minimum_size = Vector2(120, 64)
		b.disabled = p["pts"] < 1 or p[k] >= 99
	vb.add_spacer(false)
	_btn(vb, "Done", _career_hub, 72)

func _career_table(after_season: bool) -> void:
	var teams := Data.teams()
	var vb := _screen("League table", "Season %d" % career.d["season"])
	var g := GridContainer.new()
	g.columns = 9
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 6)
	vb.add_child(g)
	var widths := [50, 340, 70, 70, 70, 70, 80, 80, 90]
	for i in 9:
		var l := _lab(g, ["#", "Club", "P", "W", "D", "L", "GF", "GA", "Pts"][i], 22)
		l.custom_minimum_size.x = widths[i]
		l.modulate = Color(0.7, 0.9, 0.7)
	var rows := career.table_sorted()
	for i in rows.size():
		var r: Dictionary = rows[i]
		var mine: bool = r["team"] == career.d["club"]
		var vals := [str(i + 1), teams[r["team"]]["name"], str(r["p"]), str(r["w"]), str(r["dr"]), str(r["l"]), str(r["gf"]), str(r["ga"]), str(r["pts"])]
		for j in vals.size():
			var l := _lab(g, vals[j], 24)
			l.custom_minimum_size.x = widths[j]
			if mine:
				l.modulate = Color(1, 0.9, 0.3)
	vb.add_spacer(false)
	_btn(vb, "Back", _career_season_end if after_season else _career_hub, 72)

func _career_season_end() -> void:
	var teams := Data.teams()
	if not career.d.has("season_done") or career.d["season_done"] != career.d["season"]:
		var res := career.finish_season()
		career.d["season_done"] = career.d["season"]
		career.save()
	var pos := career.position()
	var vb := _screen("Season %d complete" % career.d["season"], "Finished %s in the league." % _ord(pos))
	if pos == 1:
		_lab(vb, "CHAMPIONS!  A league title for %s." % teams[career.d["club"]]["name"], 34)
	var ss: Dictionary = career.d["season_stats"]
	_lab(vb, "Your season: %d apps, %d goals, %d assists, avg rating %.2f" % [ss["apps"], ss["goals"], ss["assists"], career.avg_rating()], 26, true)
	_btn(vb, "View final table", func(): _career_table(true), 60)
	_lab(vb, "Contract offers", 30)
	var offers := career.offers(rng)
	for o in offers:
		_btn(vb, "Join %s  (strength %d)" % [teams[o]["name"], int(career.d["ratings"][o])], func():
			career.next_season(o, rng)
			_career_intro(), 64)
	_btn(vb, "Stay at %s" % teams[career.d["club"]]["name"], func():
		career.next_season(career.d["club"], rng)
		_career_intro(), 64)

func _ord(n: int) -> String:
	var s := {1: "1st", 2: "2nd", 3: "3rd"}
	return s.get(n, "%dth" % n)


func _shots(teams: Array, mode: String) -> void:
	var h: Dictionary = teams[0].duplicate()
	var a: Dictionary = teams[1].duplicate()
	h["idx"] = 0
	a["idx"] = 1
	var rs := {"att": 70, "mid": 70, "def": 70, "gk": 70, "fit": 70}
	h["rs"] = rs
	a["rs"] = rs
	var m := MatchScene.new()
	m.cfg = {"home": h, "away": a, "minutes": 3, "human_team": 0, "mode": mode, "diff": 1.0,
		"legend": {"name": "J. Rivera", "slot": 9, "number": 10, "pace": 70, "shoot": 65, "pass": 60, "defend": 40}}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tod="):
			m.cfg["tod"] = arg.substr(6)
	add_child(m)
	var times := [1.5, 6.0, 12.0, 20.0]
	var i := 0
	var t0 := Time.get_ticks_msec()
	while i < times.size():
		await get_tree().create_timer(0.25).timeout
		var el := (Time.get_ticks_msec() - t0) / 1000.0 * Engine.time_scale
		if el >= times[i]:
			var img := get_viewport().get_texture().get_image()
			img.save_png("res://shots/%s_%d.png" % [mode, i])
			i += 1
	get_tree().quit()

func _career_test() -> void:
	var c := Career.new()
	c.new_career("Test Player", "ST", 9, "Finisher", 3)
	var teams := Data.teams()
	var total := c.total_rounds()
	var n_rounds := 14
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rounds="):
			n_rounds = int(a.substr(9))
	for i in n_rounds:
		var fx := c.next_fixture()
		var club: int = c.d["club"]
		var h := _team_cfg(fx[0], c.d["ratings"][fx[0]])
		var a := _fix_clash(h, _team_cfg(fx[1], c.d["ratings"][fx[1]]))
		var ht := 0 if fx[0] == club else 1
		var p: Dictionary = c.d["player"]
		var lg := {"name": p["name"], "slot": p["slot"], "number": p["number"], "pace": p["pace"], "shoot": p["shoot"], "pass": p["pass"], "defend": p["defend"]}
		var m := MatchScene.new()
		m.cfg = {"home": h, "away": a, "minutes": 2, "human_team": ht, "mode": "legend", "diff": 1.0, "legend": lg}
		add_child(m)
		var bot := _drive_bot(m)
		var t0 := Time.get_ticks_msec()
		var r = await m.finished
		print("wall ms: ", Time.get_ticks_msec() - t0)
		bot.cancel = true
		m.queue_free()
		var res := c.apply_result(r["score"][0], r["score"][1], r["rating"], r["legend"]["goals"], r["legend"]["assists"], rng)
		print("ROUND %d ht=%d %s %d-%d rating=%.1f legend=%s pts=%d" % [i + 1, ht, teams[fx[0]]["short"] + "v" + teams[fx[1]]["short"], r["score"][0], r["score"][1], r["rating"], r["legend"], res["pts"]])
		await get_tree().process_frame
	var fin := c.finish_season()
	print("SEASON ", fin, " pos=", c.position(), " offers=", c.offers(rng))
	for row in c.table_sorted():
		print("TABLE ", teams[row["team"]]["short"], row["pts"], row["gf"], row["ga"])
	c.next_season(c.offers(rng)[0], rng)
	print("NEXT SEASON ok round=", c.d["round"], " club=", c.d["club"], " ovr=", c.ovr())
	get_tree().quit()

class Bot:
	var cancel := false

func _drive_bot(m: MatchScene) -> Bot:
	var bot := Bot.new()
	var r := RandomNumberGenerator.new()
	r.randomize()
	_bot_loop(m, bot, r)
	return bot

func _bot_loop(m: MatchScene, bot: Bot, r: RandomNumberGenerator) -> void:
	while not bot.cancel and is_instance_valid(m):
		await get_tree().process_frame
		if m.state == "FULLTIME" and m.state_t > 1.0:
			m._send_finished(false)
		if m.controlled == null or m.finished_sent:
			continue
		m.ui.stick_id = 999
		var p: Player = m.controlled
		var ball: Ball = m.ball
		var to := Vector2(ball.position.x - p.position.x, ball.position.z - p.position.z)
		if ball.carrier == p:
			var goal := Vector2(m.attack_dir[p.team] * Cfg.HALF_L - p.position.x, -p.position.z)
			m.ui.move = goal.normalized()
			var roll := r.randf()
			if roll < 0.04:
				m.ui.just["A"] = true
			elif roll < 0.06:
				m.ui.just["Y"] = true
			elif roll < 0.08:
				m.ui.just["B"] = true
				m.ui.rel["B"] = 0.5
		else:
			m.ui.move = to.normalized() if to.length() > 1.0 else Vector2.ZERO
			var roll2 := r.randf()
			if roll2 < 0.03:
				m.ui.just["B"] = true
			elif roll2 < 0.04:
				m.ui.just["X"] = true
			elif roll2 < 0.06:
				m.ui.just["Y"] = true
		m.ui.held["S"] = true

func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png("res://shots/ui_%s.png" % name)

func _ui_shots() -> void:
	_main_menu()
	await _snap("1_main")
	_kickoff_setup()
	await _snap("2_kickoff")
	_settings()
	await _snap("3_settings")
	_career_entry()
	await _snap("4_entry")
	_practice_menu()
	await _snap("4b_practice")
	_career_create()
	await _snap("5_create")
	career = Career.new()
	career.new_career("Jay Rivera", "ST", 10, "Finisher", 3)
	_career_intro()
	await _snap("6_intro")
	_career_hub()
	await _snap("7_hub")
	_career_training()
	await _snap("8_training")
	for i in 14:
		career.apply_result(rng.randi_range(0, 3), rng.randi_range(0, 3), 6.5, 1, 0, rng)
	_career_table(false)
	await _snap("9_table")
	career.d.erase("season_done")
	_career_hub()
	await _snap("10_seasonend")
	get_tree().quit()

func _stick_for(m: MatchScene, w: Vector2) -> Vector2:
	var f := m.cam_fwd
	var r := Vector2(-f.y, f.x)
	return Vector2(w.dot(r), -w.dot(f)).limit_length(1.0)

func _practice_test() -> void:
	var teams := Data.teams()
	for drill in PracticeScene.ORDER:
		var h := _team_cfg(0, 70.0)
		var a := _fix_clash(h, _team_cfg(1, 70.0))
		var ps := PracticeScene.new()
		ps.cfg = {"home": h, "away": a, "drill": drill, "tod": "day"}
		add_child(ps)
		var done := [false]
		var res := [{}]
		ps.finished.connect(func(r): done[0] = true; res[0] = r)
		var frames := 0
		while not done[0] and frames < 60 * 300:
			await get_tree().process_frame
			frames += 1
			if not is_instance_valid(ps) or ps.finished_sent:
				break
			ps.ui.stick_id = 999
			var me: Player = ps.controlled
			var ball: Ball = ps.ball
			var carry = (ball.carrier == me)
			var goal := Vector2(Cfg.HALF_L - me.position.x, -me.position.z)
			var tobal := Vector2(ball.position.x - me.position.x, ball.position.z - me.position.z)
			if ps.done:
				ps._send_finished(false)
				continue
			match drill:
				"slalom":
					ps.ui.move = _stick_for(ps, Vector2(1, sin(me.position.x * 0.5) * 0.35)) if carry else _stick_for(ps, tobal)
					ps.ui.held["S"] = true
				"skill":
					ps.ui.move = _stick_for(ps, Vector2(cos(ps.drill_clock), sin(ps.drill_clock * 0.7))) if carry else _stick_for(ps, tobal)
					if carry and frames % 20 == 0:
						ps.ui.just["Z"] = true
				"passing":
					if carry and ps.pass_target_p != null:
						var tw := Vector2(ps.pass_target_p.position.x - me.position.x, ps.pass_target_p.position.z - me.position.z)
						ps.ui.move = _stick_for(ps, tw)
						if frames % 30 == 0:
							ps.ui.just["A"] = true
					else:
						ps.ui.move = _stick_for(ps, tobal)
				_:
					if carry:
						ps.ui.move = _stick_for(ps, goal) if goal.length() > 15.0 and drill == "free" else _stick_for(ps, Vector2(1, 0.1))
						if goal.length() < 26.0 and frames % 25 == 0:
							ps.ui.just["B"] = true
							ps.ui.rel["B"] = 0.55
					else:
						ps.ui.move = _stick_for(ps, tobal)
						ps.ui.held["S"] = true
		print("DRILL ", drill, " done=", done[0], " frames=", frames, " result=", res[0])
		if is_instance_valid(ps):
			ps.queue_free()
		await get_tree().process_frame
	get_tree().quit()

func _practice_shots(drill: String) -> void:
	var h := _team_cfg(0, 70.0)
	var a := _fix_clash(h, _team_cfg(1, 70.0))
	var ps := PracticeScene.new()
	ps.cfg = {"home": h, "away": a, "drill": drill, "tod": "day"}
	add_child(ps)
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(3.0).timeout
	get_viewport().get_texture().get_image().save_png("res://shots/practice_%s.png" % drill)
	get_tree().quit()
