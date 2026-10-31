class_name PracticeScene
extends MatchScene
# Practice mode: just you, a ball and a drill. Earn skill points from challenges or XP from free play.

const DRILLS := {
	"free": {"name": "Free Play", "desc": "Ball, goal and keeper. No rules. XP for touches, skill moves and goals (25 XP = 1 skill point, max 6 per session).", "cam": "behind"},
	"shoot": {"name": "Target Shooting", "desc": "10 shots. Hit the glowing target in the goal. Closer to the centre scores more.", "cam": "behind"},
	"freekick": {"name": "Free Kicks", "desc": "5 free kicks over a wall, with a keeper.", "cam": "behind"},
	"penalty": {"name": "Penalties", "desc": "5 penalties against the keeper.", "cam": "behind"},
	"slalom": {"name": "Cone Slalom", "desc": "Dribble through all cones as fast as you can. Touching a cone adds 1 second.", "cam": "side"},
	"passing": {"name": "Passing Accuracy", "desc": "10 passes. Pass to the glowing teammate.", "cam": "side"},
	"skill": {"name": "Skill Moves", "desc": "Pull off as many skill moves as you can in 60 seconds while dribbling.", "cam": "side"},
}
const ORDER := ["free", "shoot", "freekick", "penalty", "slalom", "passing", "skill"]

var drill := "free"
var dummies: Array = []
var wall_players: Array = []
var cone_pos: Array = []
var cone_nodes: Array = []
var cone_touched: Array = []
var target_nodes: Array = []
var target_pos: Array = []        # Vector2(z, y) in goal plane
var cur_target := -1
var spots: Array = []
var attempt := 0
var attempts_max := 10
var score_v := 0.0
var shot_live := false
var shot_t := 0.0
var wait_t := 0.0
var drill_clock := 0.0
var slalom_started := false
var slalom_time := 0.0
var slalom_i := 0
var lost_t := 0.0
var skill_count := 0
var xp := 0
var xp_points_given := 0
var started := false
var done := false
var hint: Label
var xp_bar: ProgressBar
var gk_p: Player = null
var prev_carrier: Player = null
var pass_target_p: Player = null
var timer_total := 60.0
var result_data := {}

func _ready() -> void:
	mode = "practice"
	human_team = 0
	diff = 1.0
	match_len = 99999.0
	drill = cfg.get("drill", "free")
	tinfo = [cfg["home"], cfg["away"]]
	cam_mode = DRILLS[drill]["cam"]
	rng.randomize()
	_build_world()
	_build_practice_actors()
	_build_hud()
	_build_sfx()
	bug.visible = false
	radar.visible = false
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 8)
	hint.position = Vector2(18, 14)
	hud.add_child(hint)
	xp_bar = ProgressBar.new()
	xp_bar.max_value = 25
	xp_bar.show_percentage = false
	xp_bar.position = Vector2(18, 112)
	xp_bar.custom_minimum_size = Vector2(240, 12)
	xp_bar.visible = drill == "free"
	hud.add_child(xp_bar)
	legend_player = teams_p[0][0]
	_set_controlled(legend_player)
	cam_fwd = Vector2(1, -0.3).normalized()
	cam_look = legend_player.position
	_setup_drill()
	_set_state("PLAY")
	Telemetry.ev("practice_start", {"drill": drill})

func _mk(team: int, idx: int, role: String, pname: String, gk: bool) -> Player:
	var p := Player.new()
	p.team = team
	p.idx = idx
	p.role = role
	p.pname = pname
	p.number = [9, 1, 5, 6, 7][idx % 5] if not gk else 1
	var ti: Dictionary = tinfo[team]
	var c1: Color = ti["c1"]
	var c2: Color = ti["c2"]
	if gk:
		c1 = Color(0.2, 0.85, 0.35)
		c2 = Color(0.1, 0.1, 0.1)
	p.build(c1, c2, gk, int(ti.get("style", 0)))
	p.stats = {"pas": 1.05, "sho": 1.05, "tkl": 1.0, "gk": 0.9}
	add_child(p)
	return p

func _build_practice_actors() -> void:
	var lg: Dictionary = cfg.get("legend", {"name": "You", "number": 10, "pace": 62, "shoot": 62, "pass": 60, "defend": 40})
	var me := _mk(0, 9, "FWD", lg.get("name", "You"), false)
	me.set_number(int(lg.get("number", 10)))
	me.spd_mult = 0.92 + float(lg.get("pace", 62)) / 100.0 * 0.2
	me.stats = {"pas": 0.78 + float(lg.get("pass", 60)) / 100.0 * 0.4, "sho": 0.78 + float(lg.get("shoot", 62)) / 100.0 * 0.4, "tkl": 1.0, "gk": 1.0}
	players.append(me)
	teams_p[0].append(me)
	if drill in ["free", "freekick", "penalty"]:
		gk_p = _mk(1, 0, "GK", "Keeper", true)
		gk_p.position = Vector3(Cfg.HALF_L - 1.5, 0, 0)
		gk_p.face = Vector2(-1, 0)
		players.append(gk_p)
		teams_p[1].append(gk_p)

func _make_cone(pos: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.3
	cm.height = 0.75
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.45, 0.05)
	mi.material_override = m
	mi.position = Vector3(pos.x, 0.375, pos.y)
	add_child(mi)
	return mi

func _make_target(z: float, y: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.1)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.3, 0.2, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3(Cfg.HALF_L - 0.2, y, z)
	mi.rotation.y = -PI * 0.5
	add_child(mi)
	return mi

func _setup_drill() -> void:
	var me: Player = teams_p[0][0]
	match drill:
		"free":
			spots = [Vector2(20, 0)]
			attempts_max = 9999
		"shoot":
			attempts_max = 10
			spots = [Vector2(33, -12), Vector2(31, 0), Vector2(33, 12)]
			var zs := [-2.7, 2.7, -2.7, 2.7]
			var ys := [0.7, 0.7, 1.9, 1.9]
			for i in 4:
				target_pos.append(Vector2(zs[i], ys[i]))
				target_nodes.append(_make_target(zs[i], ys[i]))
		"freekick":
			attempts_max = 5
			spots = [Vector2(33, 9), Vector2(34, -9), Vector2(31, 0), Vector2(35, 14), Vector2(35, -14)]
		"penalty":
			attempts_max = 5
			spots = [Vector2(Cfg.HALF_L - 11.0, 0)]
		"slalom":
			attempts_max = 1
			for i in 8:
				var cp := Vector2(-14.0 + i * 6.0, 0.0)
				cone_pos.append(cp)
				cone_nodes.append(_make_cone(cp))
				cone_touched.append(false)
			spots = [Vector2(-22, 0)]
		"passing":
			attempts_max = 10
			spots = [Vector2(0, 0)]
			for i in 4:
				var ang := i * PI * 0.5 + PI * 0.25
				var d := _mk(0, i + 1, "MID", "T%d" % (i + 1), false)
				d.position = Vector3(cos(ang) * 14.0, 0, sin(ang) * 11.0)
				d.face = (Vector2.ZERO - Vector2(d.position.x, d.position.z)).normalized()
				d.rotation.y = atan2(d.face.x, d.face.y)
				d.ring.visible = false
				dummies.append(d)
				teams_p[0].append(d)
		"skill":
			attempts_max = 1
			spots = [Vector2(0, 0)]
	_begin_attempt()

func _begin_attempt() -> void:
	var me: Player = teams_p[0][0]
	shot_live = false
	shot_t = 0.0
	wait_t = 0.0
	var sp: Vector2 = spots[attempt % spots.size()]
	me.vel = Vector3.ZERO
	me.stun = 0.0
	me.cd = 0.0
	ball.carrier = null
	ball.vel = Vector3.ZERO
	ball.position = Vector3(sp.x, Cfg.BALL_R, sp.y)
	me.position = Vector3(sp.x - 1.6, 0, sp.y)
	me.face = Vector2(1, 0)
	me.rotation.y = atan2(1.0, 0.0)
	if drill == "shoot":
		cur_target = rng.randi() % 4
		for i in target_nodes.size():
			var m: StandardMaterial3D = target_nodes[i].material_override
			m.albedo_color = Color(0.2, 1, 0.3, 0.75) if i == cur_target else Color(1, 0.3, 0.2, 0.12)
	elif drill == "freekick":
		_place_wall(sp)
	elif drill == "passing":
		cur_target = rng.randi() % dummies.size()
		for i in dummies.size():
			dummies[i].ring.visible = i == cur_target
			(dummies[i].ring.material_override as StandardMaterial3D).albedo_color = Color(0.2, 1, 0.3, 0.7)
		pass_target_p = dummies[cur_target]
	_hint_update()

func _place_wall(sp: Vector2) -> void:
	for w in wall_players:
		w.queue_free()
	wall_players.clear()
	var gc := Vector2(Cfg.HALF_L, 0)
	var dg := (gc - sp).normalized()
	var perp := Vector2(-dg.y, dg.x)
	for i in 4:
		var w := _mk(1, i + 1, "DEF", "W%d" % i, false)
		var wp := sp + dg * 9.5 + perp * ((i - 1.5) * 0.85)
		w.position = Vector3(wp.x, 0, wp.y)
		w.face = -dg
		w.rotation.y = atan2(w.face.x, w.face.y)
		w.ring.visible = false
		wall_players.append(w)

func _hint_update() -> void:
	match drill:
		"free":
			hint.text = "FREE PLAY   XP %d" % xp
		"shoot":
			hint.text = "TARGET SHOOTING   shot %d/%d   score %d" % [mini(attempt + 1, attempts_max), attempts_max, int(score_v)]
		"freekick":
			hint.text = "FREE KICKS   %d/%d   goals %d" % [mini(attempt + 1, attempts_max), attempts_max, int(score_v)]
		"penalty":
			hint.text = "PENALTIES   %d/%d   goals %d" % [mini(attempt + 1, attempts_max), attempts_max, int(score_v)]
		"slalom":
			hint.text = "SLALOM   time %.1fs" % slalom_time if slalom_started else "SLALOM   dribble to the first cone to start"
		"passing":
			hint.text = "PASSING   %d/%d   accurate %d" % [mini(attempt + 1, attempts_max), attempts_max, int(score_v)]
		"skill":
			hint.text = "SKILL MOVES   %d   time %.0f" % [skill_count, maxf(0.0, timer_total - drill_clock)]

# ------------------------------------------------------------ overrides

func _ai(p: Player, dt: float) -> void:
	if p.is_gk:
		super._ai(p, dt)
	else:
		p.move_cmd = Vector2.ZERO

func _auto_switch(_dt: float) -> void:
	pass

func _goal(side: int) -> void:
	if shot_live:
		var yz := Vector2(ball.position.z, ball.position.y)
		_resolve_shot(side == 1, yz)
	else:
		_respawn_soon()
	if drill == "free" and side == 1:
		xp += 5
		sfx_cheer.play()
	ball.vel *= 0.1

func _ball_out_end(_side: int) -> void:
	if shot_live:
		_resolve_shot(false, Vector2.ZERO)
	else:
		_respawn_soon()

func _start_restart(_kind: String, _team: int, _pos: Vector2) -> void:
	if shot_live:
		_resolve_shot(false, Vector2.ZERO)
	else:
		_respawn_soon()

func _skill_move(p: Player, mv: Vector2) -> void:
	var before := p.skill_t
	super._skill_move(p, mv)
	if p == teams_p[0][0] and before <= 0.0 and ball.carrier == p and p.speed() > 2.5 and drill_clock - last_skill_t > 1.2:
		last_skill_t = drill_clock
		skill_count += 1
		xp += 3
		Telemetry.ev("skill_move", {"n": skill_count})

func _take(p: Player) -> void:
	super._take(p)
	if p == teams_p[0][0]:
		xp += 1

func _respawn_soon() -> void:
	wait_t = 1.0
	ball.vel *= 0.2

# ------------------------------------------------------------ drill logic

func _resolve_shot(scored_in_goal: bool, yz: Vector2) -> void:
	if not shot_live:
		return
	shot_live = false
	var pts := 0.0
	var msg := "MISS"
	match drill:
		"shoot":
			if scored_in_goal:
				var tp: Vector2 = target_pos[cur_target]
				var d := yz.distance_to(tp)
				if d < 0.8:
					pts = 3.0
					msg = "BULLSEYE +3"
				elif d < 1.6:
					pts = 2.0
					msg = "CLOSE +2"
				else:
					pts = 1.0
					msg = "GOAL +1"
			else:
				msg = "MISS"
		"freekick", "penalty":
			if scored_in_goal:
				pts = 1.0
				msg = "GOAL!"
			else:
				msg = "SAVED / MISSED"
	score_v += pts
	lbl_msg.text = msg
	lbl_sub.text = ""
	Telemetry.ev("practice_shot", {"drill": drill, "msg": msg, "score": score_v})
	attempt += 1
	wait_t = 1.6
	if pts > 0:
		sfx_cheer.play()
	_hint_update()

func _resolve_pass(ok: bool) -> void:
	shot_live = false
	if ok:
		score_v += 1.0
		lbl_msg.text = "NICE PASS"
		sfx_kick.play()
	else:
		lbl_msg.text = "OFF TARGET"
	attempt += 1
	wait_t = 1.2
	Telemetry.ev("practice_pass", {"ok": ok, "score": score_v})
	_hint_update()

func _physics_process(dt: float) -> void:
	if paused or finished_sent:
		return
	dt = minf(dt, 0.05)
	state_t += dt
	var me: Player = teams_p[0][0]
	if done:
		_step_all(dt, false)
		_update_camera(dt)
		_update_hud(dt)
		ui.end_frame()
		return
	# keeper catching the ball ends the attempt
	if ball.carrier != null and ball.carrier.is_gk:
		if shot_live:
			_resolve_shot(false, Vector2.ZERO)
		ball.carrier = null
		ball.vel = Vector3.ZERO
		ball.position = Vector3(Cfg.HALF_L - 6.0, Cfg.BALL_R, 0)
		wait_t = maxf(wait_t, 1.2)
	_step_all(dt, true)
	# wall blocks the ball
	for w in wall_players:
		var dx: float = ball.position.x - w.position.x
		var dz: float = ball.position.z - w.position.z
		if dx * dx + dz * dz < 0.55 and ball.position.y < 2.0 and ball.carrier == null:
			ball.vel = Vector3(-ball.vel.x * 0.25, 1.5, ball.vel.z * 0.3)
			ball.position.x = w.position.x - 0.8
	# release detection
	if prev_carrier == me and ball.carrier == null and ball.planar_speed() > 5.0 and wait_t <= 0.0:
		if drill in ["shoot", "freekick", "penalty"]:
			shot_live = true
			shot_t = 0.0
			if drill == "shoot":
				shots[0] += 1
		elif drill == "passing":
			shot_live = true
			shot_t = 0.0
	prev_carrier = ball.carrier
	if shot_live:
		shot_t += dt
		if drill == "passing":
			var tp: Player = pass_target_p
			var d2 := Vector2(ball.position.x - tp.position.x, ball.position.z - tp.position.z).length()
			if d2 < 1.6 and ball.position.y < 1.8:
				_resolve_pass(true)
			elif shot_t > 4.0 or (shot_t > 0.8 and ball.planar_speed() < 1.0):
				_resolve_pass(false)
			else:
				for i in dummies.size():
					if i != cur_target and Vector2(ball.position.x - dummies[i].position.x, ball.position.z - dummies[i].position.z).length() < 1.3:
						_resolve_pass(false)
						break
		elif shot_t > 4.5 or (shot_t > 1.0 and ball.planar_speed() < 1.0):
			_resolve_shot(false, Vector2.ZERO)
	# between-attempt waiting and respawn
	if wait_t > 0.0:
		wait_t -= dt
		if wait_t <= 0.0:
			lbl_msg.text = ""
			if drill in ["shoot", "freekick", "penalty", "passing"] and attempt >= attempts_max:
				_finish()
			elif drill == "free":
				_begin_attempt()
			elif drill in ["shoot", "freekick", "penalty", "passing"]:
				_begin_attempt()
			else:
				_begin_attempt()
	elif drill == "free":
		drill_clock += dt
		# keep the ball near the player: out of play respawn
		if absf(ball.position.x) > Cfg.HALF_L + 1.0 or absf(ball.position.z) > Cfg.HALF_W + 1.0:
			wait_t = 0.8
	_drill_tick(dt, me)
	xp_bar.value = xp % 25
	var pts_free := mini(6, xp / 25)
	if drill == "free" and pts_free > xp_points_given:
		xp_points_given = pts_free
		lbl_msg.text = "+1 SKILL POINT"
		PracticeData.bank(1)
		get_tree().create_timer(1.6).timeout.connect(func(): if lbl_msg.text == "+1 SKILL POINT": lbl_msg.text = "")
	_update_camera(dt)
	_update_hud(dt)
	ui.end_frame()
	hint_t += dt
	if hint_t > 0.2:
		hint_t = 0.0
		_hint_update()

var hint_t := 0.0
var last_skill_t := -9.0

func _drill_tick(dt: float, me: Player) -> void:
	if drill == "slalom":
		if not slalom_started and me.position.x > -16.0:
			slalom_started = true
		if slalom_started:
			slalom_time += dt
			for i in cone_pos.size():
				if not cone_touched[i] and Vector2(me.position.x - cone_pos[i].x, me.position.z - cone_pos[i].y).length() < 0.85:
					cone_touched[i] = true
					slalom_time += 1.0
					(cone_nodes[i].material_override as StandardMaterial3D).albedo_color = Color(0.9, 0.1, 0.1)
					lbl_msg.text = "+1s"
					get_tree().create_timer(0.8).timeout.connect(func(): if lbl_msg.text == "+1s": lbl_msg.text = "")
			if ball.carrier != me:
				lost_t += dt
				if lost_t > 2.5:
					lost_t = 0.0
					slalom_time += 2.0
					ball.carrier = null
					ball.vel = Vector3.ZERO
					ball.position = Vector3(me.position.x + 1.2, Cfg.BALL_R, me.position.z)
					lbl_msg.text = "BALL LOST +2s"
					get_tree().create_timer(1.0).timeout.connect(func(): if lbl_msg.text == "BALL LOST +2s": lbl_msg.text = "")
			else:
				lost_t = 0.0
			if me.position.x > cone_pos[cone_pos.size() - 1].x + 5.0:
				_finish()
	elif drill == "skill":
		drill_clock += dt
		if ball.carrier != me:
			lost_t += dt
			if lost_t > 3.0 or ball.position.distance_to(me.position) > 14.0:
				lost_t = 0.0
				ball.carrier = null
				ball.vel = Vector3.ZERO
				ball.position = Vector3(me.position.x + 1.2, Cfg.BALL_R, me.position.z)
		else:
			lost_t = 0.0
		if drill_clock >= timer_total:
			_finish()

func _finish() -> void:
	if done:
		return
	done = true
	var st := 0
	var sc := 0.0
	match drill:
		"shoot":
			sc = score_v
			st = 3 if sc >= 20.0 else 2 if sc >= 14.0 else 1 if sc >= 8.0 else 0
		"freekick":
			sc = score_v
			st = 3 if sc >= 3.0 else 2 if sc >= 2.0 else 1 if sc >= 1.0 else 0
		"penalty":
			sc = score_v
			st = 3 if sc >= 4.0 else 2 if sc >= 3.0 else 1 if sc >= 2.0 else 0
		"slalom":
			sc = snappedf(slalom_time, 0.1)
			st = 3 if sc <= 16.0 else 2 if sc <= 22.0 else 1 if sc <= 30.0 else 0
		"passing":
			sc = score_v
			st = 3 if sc >= 9.0 else 2 if sc >= 7.0 else 1 if sc >= 5.0 else 0
		"skill":
			sc = float(skill_count)
			st = 3 if sc >= 20.0 else 2 if sc >= 12.0 else 1 if sc >= 6.0 else 0
	var gain := 0
	if drill != "free":
		gain = PracticeData.record(drill, sc, st)
	result_data = {"drill": drill, "score": sc, "stars": st, "points": gain, "quit": false}
	Telemetry.ev("practice_done", result_data)
	_build_practice_end()

func _build_end_panel() -> void:
	_build_practice_end()

func _build_practice_end() -> void:
	end_panel.visible = true
	for c in end_panel.get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 24
	vb.offset_right = -24
	vb.offset_top = 20
	vb.offset_bottom = -20
	vb.add_theme_constant_override("separation", 12)
	var t := Label.new()
	t.text = DRILLS[drill]["name"]
	t.add_theme_font_size_override("font_size", 34)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var s := Label.new()
	var st: int = result_data.get("stars", 0)
	s.text = "%s   %s" % ["★".repeat(st) + "☆".repeat(3 - st), "Time %.1fs" % result_data["score"] if drill == "slalom" else "Score %d" % int(result_data["score"])]
	s.add_theme_font_size_override("font_size", 28)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)
	var g := Label.new()
	g.text = "+%d skill points" % result_data["points"] if result_data["points"] > 0 else "Beat your best to earn more points"
	g.add_theme_font_size_override("font_size", 24)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(g)
	var b := Button.new()
	b.text = "Continue"
	b.add_theme_font_size_override("font_size", 28)
	b.custom_minimum_size = Vector2(0, 72)
	b.pressed.connect(func(): _send_finished(false))
	vb.add_child(b)
	end_panel.add_child(vb)

func _quit_match() -> void:
	paused = false
	if drill == "free":
		result_data = {"drill": "free", "score": xp, "stars": 0, "points": xp_points_given, "quit": false}
	else:
		result_data = {"drill": drill, "score": 0, "stars": 0, "points": 0, "quit": true}
	_send_finished(true)

func _send_finished(quit: bool) -> void:
	if finished_sent:
		return
	finished_sent = true
	var r := result_data.duplicate()
	if r.is_empty():
		r = {"drill": drill, "score": xp, "stars": 0, "points": xp_points_given, "quit": quit}
	r["quit"] = quit and drill != "free"
	finished.emit(r)
