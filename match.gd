class_name MatchScene
extends Node3D

signal finished(result)

var cfg := {}
var mode := "kickoff"           # "kickoff" or "legend"
var ball: Ball
var players: Array = []
var teams_p := [[], []]
var tinfo := [{}, {}]
var human_team := 0
var controlled: Player = null
var legend_player: Player = null
var score := [0, 0]
var shots := [0, 0]
var shots_on := [0, 0]
var passes_done := [0, 0]
var state := "KICKOFF"
var state_t := 0.0
var half := 1
var clock := 0.0
var match_len := 180.0
var attack_dir := [1, -1]
var kicking_team := 0
var taker: Player = null
var restart_kind := ""
var restart_team := 0
var restart_pos := Vector2.ZERO
var ui: TouchUI
var cam: Camera3D
var cam_look := Vector3.ZERO
var cam_fwd := Vector2(0, -1)
var hud: CanvasLayer
var lbl_score: Label
var bug: ScoreBug
var lbl_msg: Label
var lbl_sub: Label
var power_bar: ProgressBar
var radar: Radar
var pause_panel: Panel
var end_panel: Panel
var diff := 1.0
var rng := RandomNumberGenerator.new()
var paused := false
var celeb_player: Player = null
var celeb_slid := false
var last_passer: Player = null
var last_pass_time := 0.0
var pass_target: Player = null
var pass_t := 0.0
var chaser := [null, null]
var chaser2 := [null, null]
var switch_t := 0.0
var marker: Label3D
var stam_bg: MeshInstance3D
var stam_fill: MeshInstance3D
var sfx_kick: AudioStreamPlayer
var sfx_whistle: AudioStreamPlayer
var sfx_cheer: AudioStreamPlayer
var legend_stats := {"goals": 0, "assists": 0, "passes": 0, "shots": 0, "tackles": 0, "touches": 0, "key_passes": 0}
var auto_log := {"goals": 0, "kicks": 0, "throwins": 0, "corners": 0, "goalkicks": 0, "tackles": 0}
var charge := 0.0
var prev_ball_x := 0.0
var finished_sent := false
var gk_hold_t := 0.0
var dbg_t := 0.0
var tel_t := 0.0

func _ready() -> void:
	mode = cfg.get("mode", "kickoff")
	match_len = float(cfg.get("minutes", 3)) * 60.0
	diff = float(cfg.get("diff", 1.0))
	human_team = int(cfg.get("human_team", 0))
	tinfo = [cfg["home"], cfg["away"]]
	if human_team == 1:
		attack_dir = [-1, 1]
	rng.randomize()
	_build_world()
	_build_teams()
	_build_hud()
	_build_sfx()
	_reset_kickoff(0)
	if human_team >= 0:
		var slot := 9
		if mode == "legend":
			slot = int(cfg.get("legend", {}).get("slot", 9))
		legend_player = teams_p[human_team][slot]
		_set_controlled(legend_player)
		if mode == "legend":
			cam_fwd = Vector2(attack_dir[human_team], -0.3).normalized()
			cam_look = legend_player.position
	_set_state("KICKOFF")

# ---------------------------------------------------------------- world


const GRASS_SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
void fragment(){
	vec3 c = texture(tex, UV).rgb;
	float g = n(UV*520.0)*0.45 + n(UV*110.0)*0.35 + n(UV*22.0)*0.30;
	c *= 0.84 + g*0.26;
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
"""

func _build_world() -> void:
	var tod: String = cfg.get("tod", ["day", "dusk", "night"][int(tinfo[0].get("idx", 0)) % 3])
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var sun := DirectionalLight3D.new()
	var sun_col := Color(1, 1, 1)
	var sun_e := 1.15
	var sun_rot := Vector3(-50, 32, 0)
	env.ambient_light_color = Color(0.62, 0.7, 0.86)
	env.ambient_light_energy = 0.62
	sm.sky_top_color = Color(0.2, 0.42, 0.8)
	sm.sky_horizon_color = Color(0.72, 0.84, 0.96)
	sm.ground_bottom_color = Color(0.2, 0.25, 0.22)
	sm.ground_horizon_color = Color(0.6, 0.68, 0.72)
	if tod == "dusk":
		sm.sky_top_color = Color(0.25, 0.3, 0.6)
		sm.sky_horizon_color = Color(0.98, 0.62, 0.42)
		sm.ground_horizon_color = Color(0.9, 0.6, 0.45)
		env.ambient_light_color = Color(0.62, 0.52, 0.66)
		env.ambient_light_energy = 0.55
		sun_col = Color(1.0, 0.7, 0.46)
		sun_e = 1.35
		sun_rot = Vector3(-22, 62, 0)
	elif tod == "night":
		sm.sky_top_color = Color(0.01, 0.02, 0.07)
		sm.sky_horizon_color = Color(0.06, 0.08, 0.17)
		sm.ground_horizon_color = Color(0.06, 0.08, 0.17)
		sm.ground_bottom_color = Color(0.02, 0.03, 0.06)
		env.ambient_light_color = Color(0.42, 0.5, 0.78)
		env.ambient_light_energy = 0.5
		sun_col = Color(0.75, 0.82, 1.0)
		sun_e = 0.55
		sun_rot = Vector3(-62, 20, 0)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.04
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun.rotation_degrees = sun_rot
	sun.light_energy = sun_e
	sun.light_color = sun_col
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 95.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	add_child(sun)
	if tod == "night":
		_make_floodlights()
	var pm := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(111, 74)
	pm.mesh = plane
	var sh := Shader.new()
	sh.code = GRASS_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tex", _pitch_texture())
	pm.material_override = mat
	add_child(pm)
	var outer := MeshInstance3D.new()
	var op := PlaneMesh.new()
	op.size = Vector2(420, 320)
	outer.mesh = op
	outer.position.y = -0.04
	var om := StandardMaterial3D.new()
	om.albedo_color = Color(0.12, 0.3, 0.14)
	outer.material_override = om
	add_child(outer)
	_make_goal(1)
	_make_goal(-1)
	_make_boards()
	_make_stands()
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.near = 0.4
	cam.far = 600.0
	cam.position = Vector3(0, 14, 26)
	add_child(cam)
	cam.make_current()
	ball = Ball.new()
	add_child(ball)
	ball.position = Vector3(0, Cfg.BALL_R, 0)

func _rect_m(img: Image, x0: float, z0: float, x1: float, z1: float, col: Color) -> void:
	var px0 := int(round((x0 + 55.5) * 10.0))
	var pz0 := int(round((z0 + 37.0) * 10.0))
	var px1 := int(round((x1 + 55.5) * 10.0))
	var pz1 := int(round((z1 + 37.0) * 10.0))
	var r := Rect2i(mini(px0, px1), mini(pz0, pz1), absi(px1 - px0) + 1, absi(pz1 - pz0) + 1)
	img.fill_rect(r, col)

func _line_m(img: Image, x0: float, z0: float, x1: float, z1: float) -> void:
	var t := 0.1
	var col := Color(0.95, 0.95, 0.95)
	if is_equal_approx(x0, x1):
		_rect_m(img, x0 - t, z0, x0 + t, z1, col)
	else:
		_rect_m(img, x0, z0 - t, x1, z0 + t, col)

func _arc_m(img: Image, cx: float, cz: float, r: float, a0: float, a1: float, clip_x: float, keep_greater: bool) -> void:
	var steps := int(r * 80)
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / float(steps))
		var x := cx + cos(a) * r
		var z := cz + sin(a) * r
		if clip_x != 999.0:
			if keep_greater and x < clip_x:
				continue
			if not keep_greater and x > clip_x:
				continue
		_rect_m(img, x - 0.1, z - 0.1, x + 0.1, z + 0.1, Color(0.95, 0.95, 0.95))

func _pitch_texture() -> ImageTexture:
	var img := Image.create(1110, 740, false, Image.FORMAT_RGB8)
	var c1 := Color(0.10, 0.39, 0.14)
	var c2 := Color(0.15, 0.48, 0.18)
	for i in 15:
		var x0 := -55.5 + i * 7.4
		_rect_m(img, x0, -37.0, x0 + 7.4, 37.0, c1 if i % 2 == 0 else c2)
	var L := Cfg.HALF_L
	var W := Cfg.HALF_W
	_line_m(img, -L, -W, L, -W)
	_line_m(img, -L, W, L, W)
	_line_m(img, -L, -W, -L, W)
	_line_m(img, L, -W, L, W)
	_line_m(img, 0, -W, 0, W)
	_arc_m(img, 0, 0, 9.15, 0, TAU, 999.0, true)
	_rect_m(img, -0.3, -0.3, 0.3, 0.3, Color(0.95, 0.95, 0.95))
	for s in [-1, 1]:
		var gx: float = s * L
		var bx: float = s * (L - 16.5)
		_line_m(img, gx, -20.16, bx, -20.16)
		_line_m(img, gx, 20.16, bx, 20.16)
		_line_m(img, bx, -20.16, bx, 20.16)
		var sx: float = s * (L - 5.5)
		_line_m(img, gx, -9.16, sx, -9.16)
		_line_m(img, gx, 9.16, sx, 9.16)
		_line_m(img, sx, -9.16, sx, 9.16)
		var spot: float = s * (L - 11.0)
		_rect_m(img, spot - 0.3, -0.3, spot + 0.3, 0.3, Color(0.95, 0.95, 0.95))
		if s == 1:
			_arc_m(img, spot, 0, 9.15, 0, TAU, bx, false)
		else:
			_arc_m(img, spot, 0, 9.15, 0, TAU, bx, true)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi

func _make_goal(side: int) -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.97, 0.97, 0.97)
	var net := StandardMaterial3D.new()
	net.albedo_color = Color(1, 1, 1, 0.22)
	net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net.cull_mode = BaseMaterial3D.CULL_DISABLED
	net.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var gx: float = side * Cfg.HALF_L
	var gh := Cfg.GOAL_H
	var gw := Cfg.GOAL_HALF
	_box(Vector3(0.12, gh, 0.12), Vector3(gx, gh * 0.5, -gw), white)
	_box(Vector3(0.12, gh, 0.12), Vector3(gx, gh * 0.5, gw), white)
	_box(Vector3(0.12, 0.12, gw * 2.0 + 0.12), Vector3(gx, gh, 0), white)
	_box(Vector3(0.04, gh, gw * 2.0), Vector3(gx + side * 2.2, gh * 0.5, 0), net)
	_box(Vector3(2.2, gh, 0.04), Vector3(gx + side * 1.1, gh * 0.5, -gw), net)
	_box(Vector3(2.2, gh, 0.04), Vector3(gx + side * 1.1, gh * 0.5, gw), net)
	_box(Vector3(2.2, 0.04, gw * 2.0), Vector3(gx + side * 1.1, gh, 0), net)

func _make_floodlights() -> void:
	var pole := StandardMaterial3D.new()
	pole.albedo_color = Color(0.5, 0.5, 0.55)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 1, 0.9)
	glow.emission_enabled = true
	glow.emission = Color(1, 0.97, 0.85)
	glow.emission_energy_multiplier = 3.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var x: float = sx * 62.0
			var z: float = sz * 44.0
			_box(Vector3(0.6, 30, 0.6), Vector3(x, 15, z), pole)
			for i in 3:
				_box(Vector3(5, 1.4, 0.6), Vector3(x, 30.5 + i * 1.7, z), glow)
			var sp := SpotLight3D.new()
			sp.position = Vector3(x, 31, z)
			sp.spot_range = 130.0
			sp.spot_angle = 48.0
			sp.light_energy = 4.0
			sp.light_color = Color(1, 0.97, 0.88)
			add_child(sp)
			sp.look_at(Vector3(0, 0, 0))


func _make_boards() -> void:
	var base := StandardMaterial3D.new()
	base.albedo_color = Color(0.06, 0.07, 0.12)
	var names := ["VOLTA", "NOVABANK", "ZEPHYR AIR", "KICKOFF TV", "ARCLIGHT", "MERIDIAN", "HALCYON", "ORBITAL"]
	var cols := [Color(0.9, 0.2, 0.25), Color(0.15, 0.55, 0.95), Color(1.0, 0.75, 0.1), Color(0.2, 0.85, 0.5), Color(0.95, 0.4, 0.9), Color(0.95, 0.95, 0.95)]
	# long sides
	for side in [-1, 1]:
		var z: float = side * (Cfg.HALF_W + 3.4)
		_box(Vector3(118, 1.0, 0.3), Vector3(0, 0.5, z), base)
		for i in 16:
			var x := -56.0 + i * 7.5
			var lab := Label3D.new()
			lab.text = names[(i + (0 if side < 0 else 3)) % names.size()]
			lab.font_size = 110
			lab.pixel_size = 0.0075
			lab.modulate = cols[(i + (0 if side < 0 else 2)) % cols.size()]
			lab.outline_size = 6
			lab.shaded = false
			lab.position = Vector3(x, 0.55, z - side * 0.17)
			if side > 0:
				lab.rotation.y = PI
			add_child(lab)
	# ends
	for side in [-1, 1]:
		var x: float = side * (Cfg.HALF_L + 4.5)
		_box(Vector3(0.3, 1.0, 76), Vector3(x, 0.5, 0), base)
		for i in 9:
			var z := -32.0 + i * 8.0
			var lab := Label3D.new()
			lab.text = names[(i + 2) % names.size()]
			lab.font_size = 110
			lab.pixel_size = 0.0075
			lab.modulate = cols[(i + 1) % cols.size()]
			lab.outline_size = 6
			lab.shaded = false
			lab.position = Vector3(x - side * 0.17, 0.55, z)
			lab.rotation.y = -side * PI * 0.5
			add_child(lab)

func _crowd_texture() -> ImageTexture:
	var W := 1024
	var H := 256
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(Color(0.09, 0.09, 0.12))
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var home: Color = tinfo[0]["c1"]
	var away: Color = tinfo[1]["c1"]
	var skins := [Color(0.85, 0.66, 0.52), Color(0.62, 0.43, 0.32), Color(0.4, 0.27, 0.2), Color(0.93, 0.78, 0.65)]
	var row := 0
	var y := 6
	while y < H - 10:
		if row % 9 == 8:
			img.fill_rect(Rect2i(0, y, W, 5), Color(0.28, 0.28, 0.32))
			y += 7
			row += 1
			continue
		var x := 2
		while x < W - 6:
			var roll := r.randf()
			var col: Color
			if roll < 0.55:
				col = home.lerp(Color(1, 1, 1), r.randf() * 0.2).darkened(0.25 + r.randf() * 0.35)
			elif roll < 0.68:
				col = away.darkened(0.3 + r.randf() * 0.3)
			else:
				col = Color.from_hsv(r.randf(), r.randf_range(0.0, 0.35), r.randf_range(0.18, 0.6))
			img.fill_rect(Rect2i(x, y + 3, 5, 5), col)
			img.fill_rect(Rect2i(x + 1, y, 3, 3), skins[r.randi() % 4])
			x += 6
		y += 8
		row += 1
	# aisles
	for ax in range(100, W, 170):
		img.fill_rect(Rect2i(ax, 0, 8, H), Color(0.34, 0.34, 0.38))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _stand(center: Vector3, length: float, rise: float, run: float, yaw: float, mat: Material) -> void:
	# slanted seating slab: bottom edge at `center`, rises by `rise` over `run` metres away from the pitch
	var slope := sqrt(rise * rise + run * run)
	var ang := atan2(rise, run)
	var root := Node3D.new()
	root.position = center
	root.rotation.y = yaw
	add_child(root)
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(length, 0.6, slope)
	slab.mesh = bm
	slab.material_override = mat
	slab.position = Vector3(0, rise * 0.5, -run * 0.5)
	slab.rotation.x = ang
	root.add_child(slab)
	var back := StandardMaterial3D.new()
	back.albedo_color = Color(0.16, 0.16, 0.2)
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(length, rise + 3.0, 1.0)
	wall.mesh = wm
	wall.material_override = back
	wall.position = Vector3(0, (rise + 3.0) * 0.5, -run - 0.5)
	root.add_child(wall)
	# roof
	var roof_m := StandardMaterial3D.new()
	roof_m.albedo_color = Color(0.2, 0.21, 0.25)
	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(length, 0.5, run * 0.75)
	roof.mesh = rm
	roof.material_override = roof_m
	roof.position = Vector3(0, rise + 3.2, -run * 0.5 - 1.0)
	root.add_child(roof)
	# trusses
	var n := int(length / 22.0)
	for i in n + 1:
		var tx := -length * 0.5 + i * (length / maxf(n, 1))
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.5, rise + 3.0, 0.5)
		post.mesh = pm
		post.material_override = roof_m
		post.position = Vector3(tx, (rise + 3.0) * 0.5, -run * 0.8)
		root.add_child(post)
	# banner strip along the front
	var banner := Label3D.new()
	banner.text = BANNERS[int(abs(center.x + center.z)) % BANNERS.size()]
	banner.font_size = 96
	banner.pixel_size = 0.02
	banner.modulate = Color(1, 1, 1)
	banner.outline_size = 12
	banner.outline_modulate = Color(0.6, 0.05, 0.1)
	banner.position = Vector3(0, rise * 0.22 + 1.6, -run * 0.22 + 0.3)
	banner.rotation.x = ang * 0.1
	root.add_child(banner)

const BANNERS := ["ONE CITY  ONE CLUB  ONE LOVE", "WE ARE GOALLINE", "FOREVER LOYAL  FOREVER HERE", "THE FINAL WHISTLE IS NEVER THE END"]

func _make_stands() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _crowd_texture()
	m.uv1_scale = Vector3(5, 3, 1)
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var rise := 22.0
	var run := 30.0
	# long sides (far side faces camera) and ends
	_stand(Vector3(0, 0, -(Cfg.HALF_W + 9.0)), 135.0, rise, run, 0.0, m)
	_stand(Vector3(0, 0, Cfg.HALF_W + 9.0), 135.0, rise, run, PI, m)
	_stand(Vector3(-(Cfg.HALF_L + 15.0), 0, 0), 90.0, rise * 0.8, run * 0.8, PI * 0.5, m)
	_stand(Vector3(Cfg.HALF_L + 15.0, 0, 0), 90.0, rise * 0.8, run * 0.8, -PI * 0.5, m)

# ---------------------------------------------------------------- teams

func _m(r: float) -> float:
	return 0.85 + r / 100.0 * 0.3

func _build_teams() -> void:
	var form := Data.formation()
	var numbers := [1, 3, 4, 5, 2, 8, 6, 10, 11, 9, 7]
	for t in 2:
		var ti: Dictionary = tinfo[t]
		var names: Array = Data.roster(int(ti.get("idx", t)))
		var rt: Dictionary = ti.get("rs", {"att": 65, "mid": 65, "def": 65, "gk": 65, "fit": 65})
		for i in 11:
			var p := Player.new()
			p.team = t
			p.idx = i
			p.role = form[i][0]
			p.home_depth = form[i][1]
			p.home_lat = form[i][2]
			p.number = numbers[i]
			p.pname = names[i]
			var c1: Color = ti["c1"]
			var c2: Color = ti["c2"]
			if i == 0:
				c1 = Color(0.95, 0.8, 0.1) if t == 0 else Color(0.2, 0.85, 0.35)
				c2 = Color(0.1, 0.1, 0.1)
			p.build(c1, c2, i == 0, int(ti.get("style", 0)))
			p.stats = {"pas": _m(rt["mid"]), "sho": _m(rt["att"]), "tkl": _m(rt["def"]), "gk": _m(rt["gk"])}
			p.spd_mult = 0.94 + float(rt["fit"]) / 100.0 * 0.12
			if t != human_team and human_team >= 0:
				p.spd_mult *= 0.94 + 0.06 * diff
			add_child(p)
			players.append(p)
			teams_p[t].append(p)
	if mode == "legend" and human_team >= 0:
		var lg: Dictionary = cfg.get("legend", {})
		var lp: Player = teams_p[human_team][int(lg.get("slot", 9))]
		lp.pname = lg.get("name", "You")
		lp.set_number(int(lg.get("number", 10)))
		lp.spd_mult = 0.90 + float(lg.get("pace", 60)) / 100.0 * 0.2
		lp.stats = {"pas": 0.75 + float(lg.get("pass", 60)) / 100.0 * 0.4,
			"sho": 0.75 + float(lg.get("shoot", 60)) / 100.0 * 0.4,
			"tkl": 0.75 + float(lg.get("defend", 40)) / 100.0 * 0.4, "gk": 1.0}

# ---------------------------------------------------------------- hud

func _style(c: Color, r := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	ui = TouchUI.new()
	hud.add_child(ui)
	lbl_score = Label.new()
	lbl_score.visible = false
	hud.add_child(lbl_score)
	bug = ScoreBug.new()
	bug.m = self
	bug.position = Vector2(14, 10)
	bug.custom_minimum_size = Vector2(330, 74)
	bug.size = Vector2(330, 74)
	bug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bug)
	lbl_msg = Label.new()
	lbl_msg.add_theme_font_size_override("font_size", 64)
	lbl_msg.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl_msg.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl_msg.add_theme_constant_override("outline_size", 10)
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl_msg.position = Vector2(0, 120)
	lbl_msg.custom_minimum_size = Vector2(900, 80)
	lbl_msg.anchor_left = 0.5
	lbl_msg.anchor_right = 0.5
	lbl_msg.offset_left = -450
	lbl_msg.offset_right = 450
	hud.add_child(lbl_msg)
	lbl_sub = Label.new()
	lbl_sub.add_theme_font_size_override("font_size", 28)
	lbl_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl_sub.add_theme_constant_override("outline_size", 8)
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.anchor_left = 0.5
	lbl_sub.anchor_right = 0.5
	lbl_sub.offset_left = -450
	lbl_sub.offset_right = 450
	lbl_sub.offset_top = 205
	hud.add_child(lbl_sub)
	power_bar = ProgressBar.new()
	power_bar.min_value = 0
	power_bar.max_value = 1
	power_bar.show_percentage = false
	power_bar.custom_minimum_size = Vector2(220, 16)
	power_bar.anchor_left = 0.5
	power_bar.anchor_right = 0.5
	power_bar.anchor_top = 1.0
	power_bar.anchor_bottom = 1.0
	power_bar.offset_left = -110
	power_bar.offset_right = 110
	power_bar.offset_top = -150
	power_bar.offset_bottom = -134
	power_bar.visible = false
	hud.add_child(power_bar)
	radar = Radar.new()
	radar.m = self
	radar.anchor_left = 0.5
	radar.anchor_right = 0.5
	radar.anchor_top = 1.0
	radar.anchor_bottom = 1.0
	radar.offset_left = -90
	radar.offset_right = 90
	radar.offset_top = -78
	radar.offset_bottom = -12
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(radar)
	var pb := Button.new()
	pb.text = "II"
	pb.add_theme_font_size_override("font_size", 26)
	pb.custom_minimum_size = Vector2(64, 52)
	pb.anchor_left = 1.0
	pb.anchor_right = 1.0
	pb.offset_left = -84
	pb.offset_top = 12
	pb.pressed.connect(_toggle_pause)
	hud.add_child(pb)
	pause_panel = Panel.new()
	pause_panel.anchor_left = 0.5
	pause_panel.anchor_right = 0.5
	pause_panel.anchor_top = 0.5
	pause_panel.anchor_bottom = 0.5
	pause_panel.offset_left = -200
	pause_panel.offset_right = 200
	pause_panel.offset_top = -130
	pause_panel.offset_bottom = 130
	pause_panel.visible = false
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 30
	vb.offset_right = -30
	vb.offset_top = 30
	vb.offset_bottom = -30
	vb.add_theme_constant_override("separation", 20)
	var b1 := Button.new()
	b1.text = "Resume"
	b1.add_theme_font_size_override("font_size", 28)
	b1.custom_minimum_size = Vector2(0, 70)
	b1.pressed.connect(_toggle_pause)
	var b2 := Button.new()
	b2.text = "Quit match"
	b2.add_theme_font_size_override("font_size", 28)
	b2.custom_minimum_size = Vector2(0, 70)
	b2.pressed.connect(_quit_match)
	vb.add_child(b1)
	vb.add_child(b2)
	pause_panel.add_child(vb)
	hud.add_child(pause_panel)
	end_panel = Panel.new()
	end_panel.anchor_left = 0.5
	end_panel.anchor_right = 0.5
	end_panel.anchor_top = 0.5
	end_panel.anchor_bottom = 0.5
	end_panel.offset_left = -300
	end_panel.offset_right = 300
	end_panel.offset_top = -200
	end_panel.offset_bottom = 200
	end_panel.visible = false
	hud.add_child(end_panel)
	marker = Label3D.new()
	marker.text = "▼"
	marker.font_size = 90
	marker.pixel_size = 0.0028
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.modulate = Color(0.2, 1, 0.4)
	marker.outline_size = 12
	marker.no_depth_test = true
	marker.position = Vector3(0, 2.8, 0)
	add_child(marker)
	stam_bg = _bar_quad(Color(0, 0, 0, 0.6), 1.1, 0.1)
	stam_fill = _bar_quad(Color(0.3, 1, 0.4, 0.95), 1.04, 0.06)
	add_child(stam_bg)
	add_child(stam_fill)

func _bar_quad(col: Color, w: float, h: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	mi.material_override = m
	return mi

func _toggle_pause() -> void:
	paused = not paused
	pause_panel.visible = paused

func _quit_match() -> void:
	paused = false
	_send_finished(true)

func _build_sfx() -> void:
	sfx_kick = AudioStreamPlayer.new()
	sfx_kick.stream = _wav(_kick_samples())
	sfx_kick.volume_db = -4
	add_child(sfx_kick)
	sfx_whistle = AudioStreamPlayer.new()
	sfx_whistle.stream = _wav(_whistle_samples())
	sfx_whistle.volume_db = -8
	add_child(sfx_whistle)
	sfx_cheer = AudioStreamPlayer.new()
	sfx_cheer.stream = _wav(_cheer_samples())
	sfx_cheer.volume_db = -6
	add_child(sfx_cheer)

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	w.data = bytes
	return w

func _kick_samples() -> PackedFloat32Array:
	var n := 2000
	var a := PackedFloat32Array()
	a.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in n:
		var t := float(i) / 22050.0
		a[i] = (r.randf_range(-1, 1) * 0.5 + sin(t * TAU * 110.0) * 0.8) * exp(-t * 55.0)
	return a

func _whistle_samples() -> PackedFloat32Array:
	var n := 11000
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / 22050.0
		var trill := 0.6 + 0.4 * sin(t * TAU * 28.0)
		a[i] = sin(t * TAU * (2850.0 + 60.0 * sin(t * 40.0))) * 0.5 * trill * minf(1.0, (0.5 - t) * 8.0)
	return a

func _cheer_samples() -> PackedFloat32Array:
	var n := 55000
	var a := PackedFloat32Array()
	a.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 11
	var lp := 0.0
	for i in n:
		var t := float(i) / 22050.0
		lp += (r.randf_range(-1, 1) - lp) * 0.18
		var env := minf(t * 3.0, 1.0) * exp(-maxf(0.0, t - 0.8) * 1.0)
		a[i] = lp * 1.4 * env
	return a

# ---------------------------------------------------------------- state

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	Telemetry.ev("state", {"s": s, "score": score, "clock": snappedf(clock, 0.1)})

func _set_controlled(p: Player) -> void:
	if controlled != null:
		controlled.human = false
		controlled.ring.visible = false
	controlled = p
	if p != null:
		p.human = true
		p.ring.visible = true
		if marker.get_parent() != null:
			marker.get_parent().remove_child(marker)
		p.add_child(marker)
		marker.position = Vector3(0, 2.5, 0)
		marker.text = "▼"

func _shape_depth_shift(t: int) -> float:
	var dir: int = attack_dir[t]
	var bd: float = (ball.position.x * dir + Cfg.HALF_L) / (Cfg.HALF_L * 2.0)
	return (bd - 0.5) * 0.42

func _home_pos(p: Player, bias: float) -> Vector2:
	var dir: int = attack_dir[p.team]
	var depth := clampf(p.home_depth + bias, 0.0, 1.0)
	var x := -dir * Cfg.HALF_L + dir * depth * 2.0 * Cfg.HALF_L
	var z := p.home_lat * Cfg.HALF_W * 0.85
	return Vector2(x, z)

func _reset_positions() -> void:
	for p in players:
		var h := _home_pos(p, 0.0)
		var dir: int = attack_dir[p.team]
		# everyone in own half at kickoff
		if h.x * dir > -1.5:
			h.x = -dir * 2.5
		p.position = Vector3(h.x, 0, h.y)
		p.vel = Vector3.ZERO
		p.cd = 0.0
		p.stun = 0.0
		p.slide_t = 0.0
		p.move_cmd = Vector2.ZERO
		p.face = Vector2(dir, 0)

func _reset_kickoff(team: int) -> void:
	for pl in players:
		pl.celebrate = false
	kicking_team = team
	_reset_positions()
	ball.carrier = null
	ball.vel = Vector3.ZERO
	ball.position = Vector3(0, Cfg.BALL_R, 0)
	var dir: int = attack_dir[team]
	var tk: Player = teams_p[team][9]
	tk.position = Vector3(-dir * 0.9, 0, 0)
	teams_p[team][8].position = Vector3(-dir * 1.5, 0, 4.0)
	teams_p[team][10].position = Vector3(-dir * 1.5, 0, -4.0)
	taker = tk
	ball.carrier = tk
	ball.last_team = team
	restart_kind = "kickoff"
	restart_team = team
	_set_state("KICKOFF")
	pass_target = null
	if human_team == team and controlled != null and mode == "kickoff":
		_set_controlled(tk)
	lbl_msg.text = ""
	lbl_sub.text = ""

# ---------------------------------------------------------------- main loop

func _physics_process(dt: float) -> void:
	if paused or finished_sent:
		return
	dt = minf(dt, 0.05)
	state_t += dt
	if Input.is_key_pressed(KEY_ESCAPE) and state_t > 0.3:
		pass
	match state:
		"INTRO":
			_tick_intro(dt)
		"KICKOFF", "RESTART":
			_tick_restart(dt)
		"PLAY":
			_tick_play(dt)
		"GOAL":
			_tick_goal(dt)
		"HALFTIME":
			_tick_halftime(dt)
		"FULLTIME":
			_tick_fulltime(dt)
		"REPLAY":
			_tick_replay(dt)
	_update_camera(dt)
	_update_hud(dt)
	ui.end_frame()
	tel_t += dt
	if tel_t > 5.0:
		tel_t = 0.0
		var cp := controlled
		Telemetry.ev("match_tick", {"state": state, "score": score, "clock": snappedf(clock, 0.1), "ball": [snappedf(ball.position.x, 0.1), snappedf(ball.position.z, 0.1)],
			"me": [snappedf(cp.position.x, 0.1), snappedf(cp.position.z, 0.1)] if cp != null else null, "stam": snappedf(cp.stamina, 0.01) if cp != null else null,
			"carrier": ball.carrier.pname if ball.carrier != null else "", "stick": [snappedf(ui.move.x, 0.01), snappedf(ui.move.y, 0.01)], "shots": shots})
	if cfg.get("debug", false):
		dbg_t += dt
		if dbg_t > 10.0:
			dbg_t = 0.0
			print("t=%.0f state=%s score=%s shots=%s ball=(%.0f,%.1f,%.0f) log=%s" % [clock, state, score, shots, ball.position.x, ball.position.y, ball.position.z, auto_log])

func _step_all(dt: float, human_ok: bool) -> void:
	_update_chasers()
	for p in players:
		if p == controlled and human_team >= 0 and human_ok:
			_human_control(p, dt)
		else:
			_ai(p, dt)
	for p in players:
		p.step(dt, ball.carrier == p)
	_separate_players()
	if ball.carrier != null:
		_carry(dt)
	else:
		ball.step(dt)
		_check_bounds()
	if state == "PLAY":
		_possession_check()
	pass_t = maxf(0.0, pass_t - dt)
	if pass_t <= 0.0:
		pass_target = null

func _record() -> void:
	var f := PackedFloat32Array()
	f.resize(3 + players.size() * 4)
	f[0] = ball.position.x
	f[1] = ball.position.y
	f[2] = ball.position.z
	for i in players.size():
		var p: Player = players[i]
		f[3 + i * 4] = p.position.x
		f[4 + i * 4] = p.position.z
		f[5 + i * 4] = p.rotation.y
		f[6 + i * 4] = p.slide_t
	rec.append(f)
	if rec.size() > 360:
		rec.pop_front()

func _tick_replay(dt: float) -> void:
	replay_i += dt * 60.0 * 0.7
	var i := int(replay_i)
	if i >= replay_frames.size() or ui.just["A"] or ui.just["B"] or ui.just["X"] or ui.just["Y"]:
		lbl_msg.text = ""
		_reset_kickoff(1 - restart_team)
		return
	var f: PackedFloat32Array = replay_frames[i]
	ball.position = Vector3(f[0], f[1], f[2])
	ball.shadow.global_position = Vector3(f[0], 0.02, f[2])
	for k in players.size():
		var p: Player = players[k]
		p.position = Vector3(f[3 + k * 4], 0, f[4 + k * 4])
		p.rotation.y = f[5 + k * 4]
		p.visual.rotation.x = 1.2 if f[6 + k * 4] > 0.0 else 0.25

func _tick_play(dt: float) -> void:
	clock += dt
	_auto_switch(dt)
	_step_all(dt, true)
	_record()
	if half == 1 and clock >= match_len * 0.5:
		_set_state("HALFTIME")
		lbl_msg.text = "HALF TIME"
		lbl_sub.text = "%s %d - %d %s" % [tinfo[0]["short"], score[0], score[1], tinfo[1]["short"]]
		sfx_whistle.play()
	elif half == 2 and clock >= match_len:
		_full_time()

func _tick_intro(_dt: float) -> void:
	_hold_ball_for_taker()
	var skip = ui.just["A"] or ui.just["B"] or ui.just["X"] or ui.just["Y"]
	if state_t > 4.2 or (skip and state_t > 0.5):
		lbl_msg.text = ""
		lbl_sub.text = ""
		_set_state("KICKOFF")

func _tick_restart(dt: float) -> void:
	# taker holds the ball; others take shape
	_step_all(dt, true)
	if taker == null:
		return
	taker.move_cmd = Vector2.ZERO
	taker.vel = Vector3.ZERO
	_hold_ball_for_taker()
	if state_t < 0.9:
		return
	if taker == controlled and human_team >= 0:
		if state_t > 6.0:
			_ai_restart_kick()
		return
	var wait := 1.3 if restart_kind != "kickoff" else 1.0
	if state_t > wait + rng.randf() * 0.01:
		_ai_restart_kick()

func _hold_ball_for_taker() -> void:
	var y := Cfg.BALL_R
	if restart_kind == "throwin":
		y = 1.5
	if restart_kind == "freekick" or restart_kind == "penalty":
		ball.position = Vector3(restart_pos.x, Cfg.BALL_R, restart_pos.y)
		ball.vel = Vector3.ZERO
		return
	ball.position = Vector3(taker.position.x + taker.face.x * 0.55, y, taker.position.z + taker.face.y * 0.55)
	ball.vel = Vector3.ZERO

func _tick_goal(dt: float) -> void:
	_step_all(dt, false)
	if celeb_player != null:
		var dir: int = attack_dir[celeb_player.team]
		if state_t < 1.6:
			var corner := Vector2(dir * (Cfg.HALF_L - 6.0), signf(celeb_player.position.z + 0.01) * (Cfg.HALF_W - 6.0))
			var d := corner - celeb_player.pos2()
			celeb_player.move_cmd = d.normalized()
			celeb_player.want_sprint = true
		elif not celeb_slid:
			celeb_slid = true
			celeb_player.celebrate = true
			celeb_player.slide_t = 1.0
			celeb_player.vel = Vector3(celeb_player.face.x * 7.0, 0, celeb_player.face.y * 7.0)
		else:
			celeb_player.move_cmd = Vector2.ZERO
		for p in teams_p[celeb_player.team]:
			if p != celeb_player and not p.is_gk and state_t > 0.8:
				var dd = celeb_player.pos2() - p.pos2()
				p.move_cmd = dd.normalized() if dd.length() > 3.0 else Vector2.ZERO
				p.want_sprint = true
	if state_t > 3.4:
		if rec.size() > 90 and not cfg.get("no_replay", false) and human_team >= 0:
			replay_frames = rec.slice(maxi(0, rec.size() - 330))
			replay_i = 0.0
			lbl_msg.text = "REPLAY"
			lbl_sub.text = ""
			_set_state("REPLAY")
		else:
			_reset_kickoff(1 - restart_team)

func _tick_halftime(dt: float) -> void:
	for p in players:
		p.move_cmd = Vector2.ZERO
	_step_all(dt, false)
	if state_t > 3.5:
		half = 2
		attack_dir = [-attack_dir[0], -attack_dir[1]]
		_reset_kickoff(1)

func _full_time() -> void:
	_set_state("FULLTIME")
	sfx_whistle.play()
	lbl_msg.text = "FULL TIME"
	lbl_sub.text = "%s %d - %d %s" % [tinfo[0]["short"], score[0], score[1], tinfo[1]["short"]]
	_build_end_panel()

func _tick_fulltime(dt: float) -> void:
	for p in players:
		p.move_cmd = Vector2.ZERO
	_step_all(dt, false)
	if human_team < 0 and state_t > 1.0:
		_send_finished(false)

func _legend_rating() -> float:
	var r := 6.0
	r += legend_stats["goals"] * 1.0 + legend_stats["assists"] * 0.7
	r += legend_stats["passes"] * 0.06 + legend_stats["tackles"] * 0.25 + legend_stats["shots"] * 0.08 + legend_stats["key_passes"] * 0.2
	if human_team >= 0:
		var diff_g: int = score[human_team] - score[1 - human_team]
		r += clampf(diff_g * 0.25, -0.75, 0.75)
	return clampf(r, 3.0, 10.0)

func _result() -> Dictionary:
	return {
		"score": score.duplicate(), "shots": shots.duplicate(), "shots_on": shots_on.duplicate(),
		"human_team": human_team, "legend": legend_stats.duplicate(), "rating": _legend_rating(),
		"log": auto_log.duplicate(),
	}

func _build_end_panel() -> void:
	end_panel.visible = true
	for c in end_panel.get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 24
	vb.offset_right = -24
	vb.offset_top = 20
	vb.offset_bottom = -20
	vb.add_theme_constant_override("separation", 10)
	var t := Label.new()
	t.text = "%s  %d - %d  %s" % [tinfo[0]["name"], score[0], score[1], tinfo[1]["name"]]
	t.add_theme_font_size_override("font_size", 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var s := Label.new()
	s.text = "Shots %d - %d   On target %d - %d" % [shots[0], shots[1], shots_on[0], shots_on[1]]
	s.add_theme_font_size_override("font_size", 22)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)
	if mode == "legend":
		var l := Label.new()
		l.text = "%s: %d goals, %d assists, %d passes, %d tackles   Rating %.1f" % [legend_player.pname, legend_stats["goals"], legend_stats["assists"], legend_stats["passes"], legend_stats["tackles"], _legend_rating()]
		l.add_theme_font_size_override("font_size", 22)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)
	var b := Button.new()
	b.text = "Continue"
	b.add_theme_font_size_override("font_size", 28)
	b.custom_minimum_size = Vector2(0, 72)
	b.pressed.connect(func(): _send_finished(false))
	vb.add_child(b)
	end_panel.add_child(vb)

func _send_finished(quit: bool) -> void:
	if finished_sent:
		return
	finished_sent = true
	var r := _result()
	r["quit"] = quit
	finished.emit(r)

func _auto_switch(dt: float) -> void:
	if mode != "kickoff" or human_team < 0:
		return
	switch_t -= dt
	if ball.carrier != null and ball.carrier.team == human_team:
		if controlled != ball.carrier and not ball.carrier.is_gk:
			_set_controlled(ball.carrier)
		return
	if switch_t > 0.0:
		return
	switch_t = 0.15
	var ref := Vector2(ball.position.x, ball.position.z) + Vector2(ball.vel.x, ball.vel.z) * 0.25
	if ball.carrier != null:
		ref = ball.carrier.pos2()
	var best: Player = null
	var bd := 999.0
	for p in teams_p[human_team]:
		if p.is_gk:
			continue
		var d = p.pos2().distance_to(ref)
		if d < bd:
			bd = d
			best = p
	if best != null and best != controlled and bd < controlled.pos2().distance_to(ref) - 2.5:
		_set_controlled(best)

func _update_chasers() -> void:
	var ref := Vector2(ball.position.x, ball.position.z)
	if ball.carrier != null:
		ref = ball.carrier.pos2()
	else:
		ref += Vector2(ball.vel.x, ball.vel.z) * 0.35
	for t in 2:
		var b1: Player = null
		var b2: Player = null
		var d1 := 999.0
		var d2 := 999.0
		for p in teams_p[t]:
			if p.is_gk:
				continue
			var d = p.pos2().distance_to(ref)
			if p.stun > 0.0:
				d += 6.0
			if d < d1:
				b2 = b1
				d2 = d1
				b1 = p
				d1 = d
			elif d < d2:
				b2 = p
				d2 = d
		chaser[t] = b1
		chaser2[t] = b2

func _separate_players() -> void:
	var n := players.size()
	for i in n:
		var a: Player = players[i]
		for j in range(i + 1, n):
			var b: Player = players[j]
			var dx := a.position.x - b.position.x
			var dz := a.position.z - b.position.z
			var d2 := dx * dx + dz * dz
			if d2 < 0.49 and d2 > 0.0001:
				var d := sqrt(d2)
				var push := (0.7 - d) * 0.5
				var nx := dx / d
				var nz := dz / d
				a.position.x += nx * push
				a.position.z += nz * push
				b.position.x -= nx * push
				b.position.z -= nz * push

# ---------------------------------------------------------------- ball / possession

func _carry(dt: float) -> void:
	var c: Player = ball.carrier
	var lead := 0.62 + c.speed() * 0.05 + 0.34 * (0.5 + 0.5 * sin(c.run_t * 1.6)) * clampf(c.speed() / 4.0, 0.0, 1.0)
	var target := Vector3(c.position.x + c.face.x * lead, Cfg.BALL_R, c.position.z + c.face.y * lead)
	ball.position = ball.position.lerp(target, clampf(16.0 * dt, 0.0, 1.0))
	ball.vel = c.vel
	ball.last_team = c.team
	ball.last_player = c
	# roll visual
	var sv := Vector3(c.vel.x, 0, c.vel.z)
	if sv.length() > 0.05:
		var axis := Vector3.UP.cross(sv.normalized())
		if axis.length() > 0.001:
			ball.mesh.rotate(axis.normalized(), sv.length() * dt / Cfg.BALL_R)
	ball.shadow.global_position = Vector3(ball.position.x, 0.02, ball.position.z)
	prev_ball_x = ball.position.x

func _take(p: Player) -> void:
	var prev: Player = ball.last_player
	ball.carrier = p
	ball.last_team = p.team
	ball.last_player = p
	if prev != null and prev != p and prev.team == p.team and pass_t > 0.0 and prev == last_passer:
		passes_done[p.team] += 1
		if legend_player != null and prev == legend_player:
			legend_stats["passes"] += 1
			if p.role == "FWD" and absf(p.position.x) > Cfg.HALF_L - 25.0:
				legend_stats["key_passes"] += 1
	if p == legend_player:
		legend_stats["touches"] += 1
	if p == pass_target:
		pass_target = null
	if mode == "kickoff" and human_team >= 0 and p.team == human_team and not p.is_gk:
		_set_controlled(p)
	p.cd = 0.0

func _possession_check() -> void:
	if ball.carrier != null:
		return
	var bp := ball.position
	var best: Player = null
	var bd := 99.0
	for p in players:
		if p.cd > 0.0 or p.stun > 0.0:
			continue
		var d := Vector2(p.position.x - bp.x, p.position.z - bp.z).length()
		var reach := 1.05
		var hmax := 1.3
		if p.is_gk:
			reach = 1.7
			hmax = 2.6
		if p.slide_t > 0.0:
			reach = 1.8
			hmax = 0.9
		if d < reach and bp.y < hmax and d < bd:
			bd = d
			best = p
	if best == null:
		return
	var sp := ball.planar_speed()
	if best.is_gk:
		_gk_contact(best, sp)
		return
	if sp > 20.0:
		ball.vel = ball.vel * 0.35 + Vector3(rng.randf_range(-3, 3), rng.randf_range(0.5, 3.5), rng.randf_range(-3, 3))
		best.cd = 0.3
		ball.last_team = best.team
		ball.last_player = best
		return
	var skill: float = best.stats["pas"]
	if sp > 16.0 and rng.randf() > 0.7 * skill + 0.25:
		ball.vel = ball.vel * 0.45 + Vector3(rng.randf_range(-2, 2), rng.randf_range(0, 1.5), rng.randf_range(-2, 2))
		best.cd = 0.3
		ball.last_team = best.team
		ball.last_player = best
		return
	_take(best)

func _gk_contact(g: Player, sp: float) -> void:
	var toward = (ball.vel.x * attack_dir[g.team]) < 0.0 or sp < 2.0
	if sp < 3.0:
		_take(g)
		gk_hold_t = 0.0
		g.ai_think = rng.randf_range(1.0, 2.0)
		return
	var chance = clampf(0.95 - (sp - 10.0) * 0.016, 0.28, 0.93) * g.stats["gk"]
	if not toward:
		chance = 0.9
	var zdiff := ball.position.z - g.position.z
	g.gk_dive = clampf(zdiff * 0.5, -1.2, 1.2)
	if rng.randf() < chance:
		if sp < 17.0 and rng.randf() < 0.7:
			_take(g)
			g.ai_think = rng.randf_range(1.0, 2.0)
			g.stun = 0.0
		else:
			# parry
			ball.vel = Vector3(-ball.vel.x * 0.35, rng.randf_range(1.0, 4.0), rng.randf_range(-6.0, 6.0))
			ball.last_team = g.team
			ball.last_player = g
			g.cd = 0.45
	else:
		# beaten: ball deflects but may continue; small slowdown
		ball.vel *= 0.8
		g.cd = 0.4

func _try_tackle(d: Player, slide: bool) -> bool:
	var c: Player = ball.carrier
	if c == null or c.team == d.team:
		return false
	var dist := d.pos2().distance_to(c.pos2())
	var rng_t := 2.3 if slide else 1.65
	if dist > rng_t:
		return false
	var chance = 0.36 * d.stats["tkl"] * (0.35 if c.skill_t > 0.0 else 1.0) - 0.10 * (c.speed() / 9.0) + (0.12 if slide else 0.0)
	if d.pos2().direction_to(c.pos2()).dot(c.face) < -0.2:
		chance += 0.12
	chance = clampf(chance, 0.15, 0.82)
	if slide:
		d.slide_t = 0.55
		var dv := (c.pos2() - d.pos2()).normalized()
		d.vel = Vector3(dv.x * 9.5, 0, dv.y * 9.5)
		d.face = dv
	if rng.randf() < chance:
		var pop := (d.face * 4.0 + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)))
		ball.carrier = null
		ball.position = Vector3(c.position.x + c.face.x * 0.7, Cfg.BALL_R, c.position.z + c.face.y * 0.7)
		ball.vel = Vector3(pop.x, 1.0, pop.y)
		ball.last_team = d.team
		ball.last_player = d
		c.cd = 0.6
		c.stun = 0.15
		d.cd = 0.0
		auto_log["tackles"] += 1
		if d == legend_player:
			legend_stats["tackles"] += 1
		return true
	d.stun = 0.5 if not slide else 0.8
	if slide and dist < 2.0 and rng.randf() < 0.6 and state == "PLAY":
		_foul(d, c)
	return false

# ---------------------------------------------------------------- passing / shooting

func _pick_target(p: Player, aim: Vector2, kind: String) -> Player:
	var dir_in := aim if aim.length() > 0.25 else p.face
	dir_in = dir_in.normalized()
	var best: Player = null
	var bs := -99.0
	var dirx: int = attack_dir[p.team]
	for t in teams_p[p.team]:
		if t == p:
			continue
		var v: Vector2 = t.pos2() - p.pos2()
		var d := v.length()
		if d < 3.0 or d > 60.0:
			continue
		if t.is_gk and absf(p.position.x - (-dirx * Cfg.HALF_L)) > 30.0:
			continue
		var cosang := dir_in.dot(v / d)
		if cosang < 0.4:
			continue
		var open := 6.0
		for o in teams_p[1 - p.team]:
			open = minf(open, o.pos2().distance_to(t.pos2()))
		var s := cosang * 2.0 - d * 0.015 + open * 0.06
		if kind == "thru":
			s += (v.x * dirx) * 0.02
		if kind == "lob" and d < 14.0:
			s -= 0.6
		if s > bs:
			bs = s
			best = t
	return best

func _do_pass(p: Player, kind: String, aim: Vector2) -> void:
	var tm := _pick_target(p, aim, kind)
	if tm == null:
		var dirv := aim if aim.length() > 0.25 else p.face
		var tgt := p.pos2() + dirv.normalized() * (22.0 if kind == "lob" else 12.0)
		_kick_to_point(p, tgt, kind, null)
		return
	_pass_to(p, tm, kind)

func _pass_to(p: Player, tm: Player, kind: String) -> void:
	var from := p.pos2()
	var dist := from.distance_to(tm.pos2())
	var tgt := tm.pos2()
	var dirx: int = attack_dir[p.team]
	if kind == "thru":
		tgt += Vector2(dirx * (6.0 + dist * 0.15), 0) + Vector2(tm.vel.x, tm.vel.z) * 0.4
	elif kind == "lob":
		tgt += Vector2(tm.vel.x, tm.vel.z) * 0.9
	else:
		var sp := clampf(7.0 + dist * 1.1, 9.0, 26.0)
		tgt += Vector2(tm.vel.x, tm.vel.z) * (dist / sp) * 0.85
	tgt.x = clampf(tgt.x, -Cfg.HALF_L + 1.0, Cfg.HALF_L - 1.0)
	tgt.y = clampf(tgt.y, -Cfg.HALF_W + 1.0, Cfg.HALF_W - 1.0)
	_kick_to_point(p, tgt, kind, tm)
	if mode == "kickoff" and p == controlled and human_team >= 0 and state == "PLAY":
		_set_controlled(tm)

func _kick_to_point(p: Player, tgt: Vector2, kind: String, rcv) -> void:
	var from := Vector2(ball.position.x, ball.position.z)
	var d := tgt - from
	var dist := d.length()
	if dist < 0.6:
		d = p.face
		dist = 0.6
	var hs := 10.0
	var vy := 0.0
	if kind == "lob":
		hs = clampf(dist * 0.62 + 6.0, 9.0, 22.0)
		vy = Cfg.GRAV * (dist / hs) * 0.5
	elif kind == "thru":
		hs = clampf(9.0 + dist * 1.15, 11.0, 28.0)
	else:
		hs = clampf(7.0 + dist * 0.95, 9.0, 23.0)
	var ang := rng.randfn(0.0, 0.025 / p.stats["pas"]) * (1.0 + hs * 0.03)
	var dd := d.normalized().rotated(ang)
	ball.carrier = null
	ball.position = Vector3(p.position.x + dd.x * 0.5, Cfg.BALL_R + 0.1, p.position.z + dd.y * 0.5)
	ball.kick(Vector3(dd.x * hs, vy, dd.y * hs), p)
	p.cd = 0.4
	p.kick_anim = 0.25
	p.face = dd
	last_passer = p
	last_pass_time = clock
	pass_target = rcv
	pass_t = 2.2
	auto_log["kicks"] += 1
	if state != "PLAY":
		_set_state("PLAY")
	sfx_kick.play()

func _do_shot(p: Player, ch: float, aim: Vector2) -> void:
	var dirx: int = attack_dir[p.team]
	var gx: float = dirx * Cfg.HALF_L
	var tz := -signf(p.position.z + 0.001) * rng.randf_range(1.8, 3.0)
	if aim.length() > 0.35 and absf(aim.y) > 0.3:
		tz = clampf(aim.y * 3.2, -3.2, 3.2)
	var ty := 0.45 + ch * 1.2 + rng.randf_range(-0.2, 0.3)
	var from := Vector3(p.position.x + p.face.x * 0.5, Cfg.BALL_R + 0.1, p.position.z + p.face.y * 0.5)
	var hv := Vector2(gx - from.x, tz - from.z)
	var dist := maxf(hv.length(), 1.0)
	var s := (19.0 + ch * 15.0) * sqrt(p.stats["sho"])
	s = clampf(s, 16.0, 36.0)
	var tt := dist / s
	var vy := (ty - from.y) / tt + 0.5 * Cfg.GRAV * tt
	vy = minf(vy, 13.0)
	var over := maxf(0.0, ch - 0.85)
	var sig = (0.018 + over * 0.12 + (dist / 60.0) * 0.035) / p.stats["sho"]
	var hd := hv.normalized().rotated(rng.randfn(0.0, sig))
	ball.carrier = null
	ball.position = from
	ball.kick(Vector3(hd.x * s, vy + rng.randfn(0.0, sig * 6.0), hd.y * s), p)
	p.cd = 0.45
	p.kick_anim = 0.25
	p.face = hd
	last_passer = null
	pass_t = 0.0
	shots[p.team] += 1
	auto_log["kicks"] += 1
	if p == legend_player:
		legend_stats["shots"] += 1
	# estimate on target
	var tcross := (gx - from.x) / (hd.x * s) if absf(hd.x * s) > 0.1 else 99.0
	var zc := from.z + hd.y * s * tcross
	if absf(zc) < Cfg.GOAL_HALF:
		shots_on[p.team] += 1
	if state != "PLAY":
		_set_state("PLAY")
	sfx_kick.play()

# ---------------------------------------------------------------- bounds / goals / restarts

func _check_bounds() -> void:
	var b := ball.position
	var px := prev_ball_x
	prev_ball_x = b.x
	if state == "GOAL":
		_clamp_in_net()
		return
	if state != "PLAY":
		return
	if absf(b.x) > Cfg.HALF_L and absf(px) <= Cfg.HALF_L:
		var side := int(signf(b.x))
		var inside_w := absf(b.z) < Cfg.GOAL_HALF + 0.3 and b.y < Cfg.GOAL_H + 0.3
		if inside_w:
			var post_d := absf(absf(b.z) - Cfg.GOAL_HALF)
			if post_d < 0.3 and b.y < Cfg.GOAL_H:
				ball.vel.x *= -0.5
				ball.vel.z += rng.randf_range(-3.0, 3.0)
				ball.position.x = side * (Cfg.HALF_L - 0.35)
				sfx_kick.play()
				return
			if absf(b.y - Cfg.GOAL_H) < 0.3 and absf(b.z) < Cfg.GOAL_HALF:
				ball.vel.x *= -0.5
				ball.vel.y = -absf(ball.vel.y) * 0.5 - 1.5
				ball.position.x = side * (Cfg.HALF_L - 0.35)
				sfx_kick.play()
				return
			if absf(b.z) < Cfg.GOAL_HALF and b.y < Cfg.GOAL_H:
				_goal(side)
				return
		_ball_out_end(side)
		return
	if absf(b.z) > Cfg.HALF_W + 0.05 and absf(b.x) <= Cfg.HALF_L:
		var tm := 1 - maxi(ball.last_team, 0)
		var pos := Vector2(clampf(b.x, -Cfg.HALF_L + 1.5, Cfg.HALF_L - 1.5), signf(b.z) * Cfg.HALF_W)
		auto_log["throwins"] += 1
		_start_restart("throwin", tm, pos)
		sfx_whistle.play()

func _clamp_in_net() -> void:
	var b := ball.position
	if absf(b.x) > Cfg.HALF_L + 2.1:
		ball.position.x = signf(b.x) * (Cfg.HALF_L + 2.1)
		ball.vel.x *= -0.15
	if absf(b.x) > Cfg.HALF_L and absf(b.z) > Cfg.GOAL_HALF - 0.2:
		ball.position.z = signf(b.z) * (Cfg.GOAL_HALF - 0.2)
		ball.vel.z *= -0.2
	if absf(b.x) > Cfg.HALF_L and b.y > Cfg.GOAL_H - 0.2:
		ball.position.y = Cfg.GOAL_H - 0.2
		ball.vel.y = -1.0

func _ball_out_end(side: int) -> void:
	var def_team := 0 if attack_dir[0] == -side else 1
	var lt := ball.last_team
	if lt == def_team:
		var att := 1 - def_team
		var pos := Vector2(side * Cfg.HALF_L, signf(ball.position.z + 0.001) * Cfg.HALF_W)
		auto_log["corners"] += 1
		_start_restart("corner", att, pos)
	else:
		auto_log["goalkicks"] += 1
		_start_restart("goalkick", def_team, Vector2(side * (Cfg.HALF_L - 5.5), 0.0))
	sfx_whistle.play()

func _start_restart(kind: String, team: int, pos: Vector2) -> void:
	Telemetry.ev("restart", {"kind": kind, "team": team})
	restart_kind = kind
	restart_team = team
	restart_pos = pos
	var tk: Player = null
	wall = []
	if kind == "goalkick":
		tk = teams_p[team][0]
	elif kind == "penalty":
		tk = teams_p[team][9]
		if legend_player != null and legend_player.team == team and mode == "legend":
			tk = legend_player
	elif kind == "freekick":
		var bdd := 999.0
		for p in teams_p[team]:
			if p.is_gk:
				continue
			var dd: float = p.pos2().distance_to(pos)
			if dd < bdd:
				bdd = dd
				tk = p
		if legend_player != null and legend_player.team == team and mode == "legend" and bdd > 0.0:
			if legend_player.pos2().distance_to(pos) < 30.0:
				tk = legend_player
	else:
		var bd := 999.0
		for p in teams_p[team]:
			if p.is_gk:
				continue
			if kind == "corner" and p.role == "DEF":
				continue
			var d: float = p.pos2().distance_to(pos)
			if d < bd:
				bd = d
				tk = p
	taker = tk
	tk.position = Vector3(pos.x, 0, pos.y)
	tk.vel = Vector3.ZERO
	tk.move_cmd = Vector2.ZERO
	tk.cd = 0.0
	tk.stun = 0.0
	tk.slide_t = 0.0
	if kind == "throwin":
		tk.face = Vector2(0, -signf(pos.y))
	elif kind == "freekick" or kind == "penalty":
		var gdir: int = attack_dir[team]
		tk.face = (Vector2(gdir * Cfg.HALF_L, 0.0) - pos).normalized()
		tk.position = Vector3(pos.x - tk.face.x * 1.3, 0, pos.y - tk.face.y * 1.3)
		if kind == "freekick":
			var gc := Vector2(gdir * Cfg.HALF_L, 0.0)
			var cands := []
			for q in teams_p[1 - team]:
				if not q.is_gk:
					cands.append(q)
			cands.sort_custom(func(a, b): return a.pos2().distance_to(pos) < b.pos2().distance_to(pos))
			var n := 4 if pos.distance_to(gc) < 24.0 else 3
			if pos.distance_to(gc) < 40.0:
				for i in mini(n, cands.size()):
					wall.append(cands[i])
	elif kind == "corner":
		tk.face = (Vector2.ZERO - pos).normalized()
	else:
		tk.face = Vector2(-signf(pos.x), 0)
	ball.carrier = tk
	ball.last_team = team
	ball.last_player = tk
	ball.vel = Vector3.ZERO
	pass_target = null
	pass_t = 0.0
	_set_state("RESTART")
	if human_team == team and mode == "kickoff":
		_set_controlled(tk)

var wall: Array = []
var rec: Array = []
var replay_i := 0.0
var replay_frames: Array = []


func _foul(def: Player, victim: Player) -> void:
	var v: int = attack_dir[victim.team]
	var pos := Vector2(clampf(victim.position.x, -Cfg.HALF_L + 1.0, Cfg.HALF_L - 1.0), clampf(victim.position.z, -Cfg.HALF_W + 1.0, Cfg.HALF_W - 1.0))
	auto_log["fouls"] = auto_log.get("fouls", 0) + 1
	Telemetry.ev("foul", {"def": def.pname, "victim": victim.pname})
	sfx_whistle.play()
	lbl_msg.text = "FOUL"
	if v * pos.x > Cfg.HALF_L - 16.5 and absf(pos.y) < 20.16:
		auto_log["penalties"] = auto_log.get("penalties", 0) + 1
		_start_restart("penalty", victim.team, Vector2(v * (Cfg.HALF_L - 11.0), 0.0))
	else:
		_start_restart("freekick", victim.team, pos)

func _goal(side: int) -> void:
	var st := 0 if attack_dir[0] == side else 1
	score[st] += 1
	auto_log["goals"] += 1
	restart_team = st
	var scorer: Player = ball.last_player
	celeb_slid = false
	if scorer != null and scorer.team == st:
		celeb_player = scorer
		if scorer == legend_player:
			legend_stats["goals"] += 1
		if last_passer != null and last_passer != scorer and last_passer.team == st and clock - last_pass_time < 6.0:
			if last_passer == legend_player:
				legend_stats["assists"] += 1
	else:
		celeb_player = teams_p[st][9]
	Telemetry.ev("goal", {"team": st, "scorer": celeb_player.pname, "score": score, "minute": int(clock / match_len * 90.0)})
	lbl_msg.text = "GOAL!"
	lbl_sub.text = "%s  %d'" % [celeb_player.pname, int(clock / match_len * 90.0)]
	sfx_cheer.play()
	_set_state("GOAL")

func _ai_restart_kick() -> void:
	var p := taker
	if p == null:
		return
	match restart_kind:
		"kickoff":
			_pass_to(p, teams_p[p.team][6], "ground")
		"throwin":
			var best: Player = null
			var bd := 999.0
			for t in teams_p[p.team]:
				if t == p or t.is_gk:
					continue
				var d: float = t.pos2().distance_to(p.pos2())
				if d > 5.0 and d < bd:
					bd = d
					best = t
			if best == null:
				best = teams_p[p.team][6]
			_pass_to(p, best, "ground")
		"goalkick":
			var opts := [5, 7, 9, 8, 10]
			_pass_to(p, teams_p[p.team][opts[rng.randi() % opts.size()]], "lob")
		"corner":
			var tgt := Vector2(restart_pos.x - signf(restart_pos.x) * 9.0, rng.randf_range(-4.0, 4.0))
			_kick_to_point(p, tgt, "lob", null)
		"penalty":
			_do_shot(p, rng.randf_range(0.45, 0.75), Vector2(0, (1.0 if rng.randf() < 0.5 else -1.0) * 0.9))
		"freekick":
			var gcc := Vector2(attack_dir[p.team] * Cfg.HALF_L, 0.0)
			if restart_pos.distance_to(gcc) < 30.0 and rng.randf() < 0.7:
				_do_shot(p, rng.randf_range(0.5, 0.8), Vector2(0, (1.0 if rng.randf() < 0.5 else -1.0) * 0.9))
			else:
				var best2: Player = null
				var bs := -99.0
				for t in teams_p[p.team]:
					if t == p or t.is_gk:
						continue
					var sc = (t.pos2().x - p.pos2().x) * attack_dir[p.team] - t.pos2().distance_to(p.pos2()) * 0.3
					if sc > bs:
						bs = sc
						best2 = t
				_pass_to(p, best2 if best2 != null else teams_p[p.team][6], "lob")
		_:
			_pass_to(p, teams_p[p.team][6], "ground")

# ---------------------------------------------------------------- human control

func _skill_move(p: Player, mv: Vector2) -> void:
	if p.skill_t > 0.0:
		return
	var perp := Vector2(-p.face.y, p.face.x)
	var sg := signf(mv.dot(perp)) if mv.length() > 0.2 else (1.0 if rng.randf() < 0.5 else -1.0)
	if sg == 0.0:
		sg = 1.0
	p.skill_t = 0.55
	p.vel += Vector3(perp.x * sg * 4.8, 0, perp.y * sg * 4.8) + Vector3(p.face.x, 0, p.face.y) * 1.0

func _manual_switch() -> void:
	if human_team < 0:
		return
	var ref := Vector2(ball.position.x, ball.position.z)
	var best: Player = null
	var bd := 999.0
	for p in teams_p[human_team]:
		if p.is_gk or p == controlled:
			continue
		var d = p.pos2().distance_to(ref)
		if d < bd:
			bd = d
			best = p
	if best != null:
		_set_controlled(best)

func _stick_to_world(v: Vector2) -> Vector2:
	var f := cam_fwd
	var r := Vector2(-f.y, f.x)
	return (f * (-v.y) + r * v.x).limit_length(1.0)

func _human_control(p: Player, dt: float) -> void:
	var mv := _stick_to_world(ui.move)
	var has = ball.carrier == p
	p.move_cmd = mv
	p.want_sprint = ui.held["S"]
	if has:
		ui.labels = {"A": "PASS", "B": "SHOOT", "X": "LOB", "Y": "THRU", "S": "SPRINT", "Z": "SKILL"}
	elif mode == "legend":
		ui.labels = {"A": "PRESS", "B": "TACKLE", "X": "SLIDE", "Y": "CALL", "S": "SPRINT", "Z": "SKILL"}
	else:
		ui.labels = {"A": "SWITCH", "B": "TACKLE", "X": "SLIDE", "Y": "SWITCH", "S": "SPRINT", "Z": "SKILL"}
	if state != "PLAY" and has:
		p.move_cmd = Vector2.ZERO
		p.vel = Vector3.ZERO
		if mv.length() > 0.3:
			p.face = mv.normalized()
	if has:
		if ui.just["Z"] and state == "PLAY":
			_skill_move(p, mv)
		if ui.just["A"]:
			_do_pass(p, "ground", mv)
			charge = 0.0
			return
		if ui.just["X"]:
			_do_pass(p, "lob", mv)
			charge = 0.0
			return
		if ui.just["Y"]:
			_do_pass(p, "thru", mv)
			charge = 0.0
			return
		if ui.held["B"]:
			charge = minf(ui.hold_t["B"] / 0.9, 1.0)
		if ui.rel["B"] >= 0.0:
			var ch := clampf(ui.rel["B"] / 0.9, 0.15, 1.0)
			_do_shot(p, ch, mv)
			charge = 0.0
	else:
		charge = 0.0
		if ui.just["B"]:
			p.vel += Vector3(p.face.x, 0, p.face.y) * 1.2
			_try_tackle(p, false)
		elif ui.just["X"]:
			_try_tackle(p, true)
			if p.slide_t <= 0.0:
				p.slide_t = 0.55
				p.vel = Vector3(p.face.x * 9.0, 0, p.face.y * 9.0)
		elif ui.just["Y"]:
			if mode == "legend":
				request_t = 1.6
			else:
				_manual_switch()
		elif ui.just["A"]:
			if mode == "kickoff":
				_manual_switch()
	if mode == "legend":
		request_t = maxf(0.0, request_t - dt)

var request_t := 0.0

# ---------------------------------------------------------------- AI

func _goto(p: Player, tgt: Vector2, sprint: bool) -> void:
	var d := tgt - p.pos2()
	var l := d.length()
	if l > 0.5:
		p.move_cmd = d / l * clampf(l / 2.5, 0.0, 1.0)
	else:
		p.move_cmd = Vector2.ZERO
	p.want_sprint = sprint

func _restart_target(p: Player) -> Vector2:
	if restart_kind == "penalty":
		var v: int = attack_dir[restart_team]
		var k := p.idx
		return Vector2(v * (Cfg.HALF_L - 21.0) + (k % 2) * 2.0 * -v, -16.0 + k * 3.0)
	if restart_kind == "freekick" and p in wall:
		var v2: int = attack_dir[restart_team]
		var gc := Vector2(v2 * Cfg.HALF_L, 0.0)
		var dirg := (gc - restart_pos).normalized()
		var perp := Vector2(-dirg.y, dirg.x)
		var i := wall.find(p)
		return restart_pos + dirg * 9.5 + perp * ((i - (wall.size() - 1) * 0.5) * 0.85)
	if restart_kind == "corner":
		var gx := signf(restart_pos.x) * Cfg.HALF_L
		var inward := -signf(restart_pos.x)
		var k := p.idx % 5
		if p.team == restart_team and (p.role != "DEF" or p.idx in [2, 3]):
			return Vector2(gx + inward * (6.0 + k * 2.0), -6.0 + k * 3.0)
		if p.team != restart_team and p.role != "FWD":
			return Vector2(gx + inward * (3.0 + k * 1.5), -5.0 + k * 2.5)
	var h := _home_pos(p, _shape_depth_shift(p.team))
	if restart_kind == "kickoff":
		var dir: int = attack_dir[p.team]
		if h.x * dir > -2.0:
			h.x = -dir * 2.5
		if p.team != kicking_team and absf(h.x) < 10.0:
			h.x = -dir * 10.0
	else:
		h.y = lerpf(h.y, restart_pos.y, 0.3)
	return h

func _lane_clear(a: Vector2, b: Vector2, team: int, margin: float) -> bool:
	var ab := b - a
	var l2 := maxf(ab.length_squared(), 0.01)
	for o in teams_p[1 - team]:
		var q: Vector2 = o.pos2()
		var t := clampf((q - a).dot(ab) / l2, 0.0, 1.0)
		if (a + ab * t).distance_to(q) < margin:
			return false
	return true

func _ai(p: Player, dt: float) -> void:
	if p.is_gk:
		_ai_gk(p, dt)
		return
	if state != "PLAY":
		if p == taker:
			p.move_cmd = Vector2.ZERO
			p.want_sprint = false
			return
		_goto(p, _restart_target(p), false)
		return
	var c: Player = ball.carrier
	if c == p:
		_ai_carrier(p, dt)
		return
	var my_poss := c != null and c.team == p.team
	var opp_poss := c != null and c.team != p.team
	var pp := p.pos2()
	var dir: int = attack_dir[p.team]
	var bias := _shape_depth_shift(p.team)
	if my_poss:
		bias += 0.07
	var h := _home_pos(p, bias)
	h.y = lerpf(h.y, ball.position.z, 0.26)
	var tgt := h
	var sprint := false
	var dfac := diff if p.team != human_team else 1.0
	if pass_target == p and pass_t > 0.0 and c == null:
		tgt = Vector2(ball.position.x, ball.position.z) + Vector2(ball.vel.x, ball.vel.z) * 0.45
		sprint = true
	elif c == null:
		if chaser[p.team] == p:
			tgt = Vector2(ball.position.x, ball.position.z) + Vector2(ball.vel.x, ball.vel.z) * 0.4
			sprint = true
	elif opp_poss:
		if chaser[p.team] == p:
			tgt = c.pos2() + Vector2(c.vel.x, c.vel.z) * 0.25
			sprint = pp.distance_to(tgt) > 2.5
			if pp.distance_to(c.pos2()) < 1.5 and p.ai_tackle_cd <= 0.0 and p.stun <= 0.0:
				p.ai_tackle_cd = 1.2 / dfac
				_try_tackle(p, false)
		elif chaser2[p.team] == p:
			var og := Vector2(-dir * Cfg.HALF_L, 0.0)
			tgt = c.pos2() + (og - c.pos2()).normalized() * 5.0
		elif p.role != "FWD":
			var mk: Player = null
			var md := 14.0
			for o in teams_p[1 - p.team]:
				if o == c:
					continue
				var d: float = o.pos2().distance_to(h)
				if d < md:
					md = d
					mk = o
			if mk != null:
				var og2 := Vector2(-dir * Cfg.HALF_L, 0.0)
				tgt = h.lerp(mk.pos2() + (og2 - mk.pos2()).normalized() * 2.0, 0.55)
	elif my_poss:
		if p.role == "FWD":
			tgt.x += dir * 6.0
			tgt.y += sin(clock * 0.7 + p.idx * 2.0) * 4.0
		elif p.role == "MID":
			tgt.x += dir * 2.0
		# find space away from the nearest opponent
		var nd := 99.0
		var nq := Vector2.ZERO
		for o in teams_p[1 - p.team]:
			var d2: float = o.pos2().distance_to(tgt)
			if d2 < nd:
				nd = d2
				nq = o.pos2()
		if nd < 5.0:
			tgt += (tgt - nq).normalized() * 3.0
	tgt.x = clampf(tgt.x, -Cfg.HALF_L + 1.0, Cfg.HALF_L - 1.0)
	tgt.y = clampf(tgt.y, -Cfg.HALF_W + 1.0, Cfg.HALF_W - 1.0)
	_goto(p, tgt, sprint)

func _ai_best_pass(p: Player, pressured: bool) -> Dictionary:
	var dirx: int = attack_dir[p.team]
	var best := {"target": null, "value": -9.0, "kind": "ground"}
	var pp := p.pos2()
	for t in teams_p[p.team]:
		if t == p:
			continue
		var tp: Vector2 = t.pos2()
		var v := tp - pp
		var d := v.length()
		if d < 4.0 or d > 40.0:
			continue
		if t.is_gk and not pressured:
			continue
		var margin := 1.3
		if not _lane_clear(pp, tp, p.team, margin):
			continue
		var fwd := v.x * dirx
		var open := 8.0
		for o in teams_p[1 - p.team]:
			open = minf(open, o.pos2().distance_to(tp))
		var val := 0.2 + clampf(fwd / 35.0, -0.3, 0.6) + open * 0.05
		if d > 30.0:
			val -= 0.2
		if t == legend_player:
			val += 0.3
			if request_t > 0.0:
				val += 0.9
		val += rng.randf() * 0.15
		if val > best["value"]:
			var kind := "lob" if d > 28.0 else "ground"
			if fwd > 12.0 and t.role == "FWD" and rng.randf() < 0.3 and kind == "ground":
				kind = "thru"
			best = {"target": t, "value": val, "kind": kind}
	return best

func _ai_carrier(p: Player, dt: float) -> void:
	var dirx: int = attack_dir[p.team]
	var pp := p.pos2()
	var goal := Vector2(dirx * Cfg.HALF_L, 0.0)
	var to_goal := goal - pp
	var dg := to_goal.length()
	var near_o: Player = null
	var near_d := 99.0
	for o in teams_p[1 - p.team]:
		var d: float = pp.distance_to(o.pos2())
		if d < near_d:
			near_d = d
			near_o = o
	var steer := to_goal.normalized()
	if near_o != null and near_d < 4.5:
		var away: Vector2 = (pp - near_o.pos2()).normalized()
		var side := Vector2(-steer.y, steer.x)
		var sg := signf(side.dot(away))
		if sg == 0.0:
			sg = 1.0
		steer = (steer + side * sg * clampf(1.5 - near_d / 3.0, 0.0, 1.2)).normalized()
	if absf(pp.y) > Cfg.HALF_W - 3.5:
		steer.y -= signf(pp.y) * 0.9
		steer = steer.normalized()
	p.move_cmd = steer
	p.want_sprint = near_d > 3.0
	p.ai_think -= dt
	if p.ai_think > 0.0:
		return
	var dfac := diff if p.team != human_team else 1.0
	p.ai_think = rng.randf_range(0.25, 0.55) / dfac
	var pressured := near_d < 2.6
	if near_d < 2.0 and p.skill_t <= 0.0 and rng.randf() < 0.22:
		_skill_move(p, Vector2.ZERO)
	if dg < 30.0:
		var sv := 1.0 - dg / 34.0
		var clear := _lane_clear(pp, goal, p.team, 1.1)
		if (clear or dg < 14.0) and rng.randf() < sv * 1.5:
			_do_shot(p, clampf(0.3 + sv * 0.5, 0.3, 0.8), Vector2.ZERO)
			return
	var best := _ai_best_pass(p, pressured)
	var thr := 0.75 if not pressured else 0.15
	if best["target"] != null and best["value"] > thr and (pressured or rng.randf() < 0.55):
		_pass_to(p, best["target"], best["kind"])
		return
	if pressured and absf(pp.x - (-dirx * Cfg.HALF_L)) < 18.0:
		_kick_to_point(p, Vector2(dirx * 20.0, rng.randf_range(-20.0, 20.0)), "lob", null)

func _ai_gk(p: Player, dt: float) -> void:
	var dir: int = attack_dir[p.team]
	var gx: float = -dir * Cfg.HALF_L
	if p == taker and state != "PLAY":
		p.move_cmd = Vector2.ZERO
		return
	if state != "PLAY":
		_goto(p, Vector2(gx + dir * 1.5, 0.0), false)
		return
	if ball.carrier == p:
		p.move_cmd = Vector2.ZERO
		p.ai_think -= dt
		if p.ai_think <= 0.0:
			var opts := [1, 2, 3, 4, 5, 7]
			var tm: Player = teams_p[p.team][opts[rng.randi() % opts.size()]]
			if rng.randf() < 0.45:
				tm = teams_p[p.team][[8, 9, 10][rng.randi() % 3]]
				_pass_to(p, tm, "lob")
			else:
				_pass_to(p, tm, "ground")
		return
	var bp := Vector2(ball.position.x, ball.position.z)
	var goal_c := Vector2(gx, 0.0)
	var bdir := (bp - goal_c).normalized()
	var bdist := bp.distance_to(goal_c)
	var tgt := goal_c + bdir * clampf(1.4 + bdist * 0.05, 1.4, 4.8)
	tgt.y = clampf(tgt.y, -Cfg.GOAL_HALF - 0.5, Cfg.GOAL_HALF + 0.5)
	var sprint := false
	var in_box := absf(ball.position.x - gx) < 16.0 and absf(ball.position.z) < 20.0
	if ball.carrier == null and in_box and ball.planar_speed() < 8.0 and p.pos2().distance_to(bp) < 9.0:
		var closer := true
		for t in teams_p[p.team]:
			if t != p and t.pos2().distance_to(bp) < p.pos2().distance_to(bp) - 1.0:
				closer = false
		if closer:
			tgt = bp
			sprint = true
	if ball.carrier == null and (ball.vel.x * -dir) > 4.0:
		var tg := (gx - ball.position.x) / ball.vel.x
		if tg > 0.0 and tg < 1.1:
			var zc := ball.position.z + ball.vel.z * tg
			var yc := ball.position.y + ball.vel.y * tg - 0.5 * Cfg.GRAV * tg * tg
			if absf(zc) < Cfg.GOAL_HALF + 1.8 and yc < Cfg.GOAL_H + 0.8:
				tgt = Vector2(gx + dir * 0.7, clampf(zc, -Cfg.GOAL_HALF, Cfg.GOAL_HALF))
				sprint = true
				if tg < 0.38:
					var dz := tgt.y - p.position.z
					p.vel.z = clampf(dz / maxf(tg, 0.12), -11.0, 11.0) * p.stats["gk"] * 0.95
					p.gk_dive = clampf(dz * 0.4, -1.2, 1.2)
	_goto(p, tgt, sprint)

# ---------------------------------------------------------------- camera / hud


func _update_camera(dt: float) -> void:
	var look := Vector3.ZERO
	var pos_off := Vector3(0, 13.0, 26.0)
	var fov_t := 40.0
	var target_fwd := Vector2(0, -1)
	var follow := true
	if state == "INTRO":
		var a := state_t * 0.32 - 0.6
		cam.position = Vector3(sin(a) * 78.0, 22.0 + state_t * 1.5, cos(a) * 52.0)
		cam.look_at(Vector3(0, 2, 0), Vector3.UP)
		cam.fov = 52.0
		return
	if state == "GOAL" and celeb_player != null:
		look = celeb_player.position + Vector3(0, 1.2, 0)
		pos_off = Vector3(5, 2.6, 8)
		fov_t = 34.0
	elif state == "REPLAY":
		look = ball.position
		pos_off = Vector3(0, 8.0, 15.0)
		fov_t = 40.0
	elif mode == "legend" and controlled != null and human_team >= 0:
		var dirv: int = attack_dir[human_team]
		target_fwd = Vector2(dirv, -0.3).normalized()
		cam_fwd = cam_fwd.lerp(target_fwd, clampf(2.5 * dt, 0.0, 1.0)).normalized()
		var f3 := Vector3(cam_fwd.x, 0, cam_fwd.y)
		var focus := controlled.position + (ball.position - controlled.position).limit_length(7.0) * 0.5 + f3 * 5.0
		focus.y = 0.8
		cam_look = cam_look.lerp(focus, clampf(7.0 * dt, 0.0, 1.0))
		cam.position = cam_look - f3 * 14.0 + Vector3(0, 6.6, 0)
		cam.look_at(cam_look + f3 * 6.0 + Vector3(0, 0.2, 0), Vector3.UP)
		cam.fov = lerpf(cam.fov, 52.0, clampf(3.0 * dt, 0.0, 1.0))
		return
	else:
		var bpos := ball.position
		look = Vector3(clampf(bpos.x + ball.vel.x * 0.18, -Cfg.HALF_L + 8.0, Cfg.HALF_L - 8.0), 0, bpos.z * 0.35)
		cam_fwd = Vector2(0, -1)
	cam_look = cam_look.lerp(look, clampf(4.0 * dt, 0.0, 1.0))
	cam.position = cam_look + pos_off
	cam.look_at(cam_look, Vector3.UP)
	cam.fov = lerpf(cam.fov, fov_t, clampf(3.0 * dt, 0.0, 1.0))

func _update_tags() -> void:
	if controlled == null:
		stam_bg.visible = false
		stam_fill.visible = false
		return
	var c := controlled
	stam_bg.visible = true
	stam_fill.visible = true
	stam_bg.position = c.position + Vector3(0, 0.15, 1.0)
	var st := clampf(c.stamina, 0.02, 1.0)
	stam_fill.scale = Vector3(st, 1, 1)
	stam_fill.position = c.position + Vector3(-(1.0 - st) * 0.52, 0.16, 1.0)
	(stam_fill.material_override as StandardMaterial3D).albedo_color = Color(1.0 - st * 0.7, 0.3 + st * 0.7, 0.3, 0.95)
	var ref := c.pos2()
	for p in players:
		var show: bool = p == c or p == ball.carrier or (p.pos2().distance_to(ref) < 11.0)
		p.name_tag.visible = show
		if show:
			p.name_tag.text = p.pname if p == c else (p.pname.get_slice(" ", 1) if " " in p.pname else p.pname)
			p.name_tag.modulate = Color(0.35, 1.0, 0.5) if p == c else tinfo[p.team]["c1"].lightened(0.55)
			p.name_tag.position = Vector3(0, 2.95 if p == c else 2.5, 0)

func _update_hud(_dt: float) -> void:
	_update_tags()
	var mins := int(clampf(clock / match_len * 90.0, 0.0, 90.0))
	lbl_score.text = "%s %d - %d %s   %d'" % [tinfo[0]["short"], score[0], score[1], tinfo[1]["short"], mins]
	power_bar.visible = charge > 0.01
	power_bar.value = charge
	if state == "PLAY" or state == "RESTART" or state == "KICKOFF":
		if state_t > 1.2 and lbl_msg.text in ["GOAL!"]:
			lbl_msg.text = ""
			lbl_sub.text = ""
		elif state == "KICKOFF" and state_t < 1.0:
			lbl_msg.text = ""
	if state == "RESTART" and state_t < 1.5:
		match restart_kind:
			"throwin": lbl_sub.text = "THROW-IN"
			"corner": lbl_sub.text = "CORNER KICK"
			"goalkick": lbl_sub.text = "GOAL KICK"
			"freekick": lbl_sub.text = "FREE KICK"
			"penalty": lbl_sub.text = "PENALTY"
	elif state == "PLAY" and state_t < 0.2 and lbl_msg.text == "":
		lbl_sub.text = ""
