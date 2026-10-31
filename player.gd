class_name Player
extends Node3D

var team := 0
var idx := 0
var role := "MID"
var pname := ""
var number := 1
var home_depth := 0.5
var home_lat := 0.0
var vel := Vector3.ZERO
var face := Vector2(1, 0)
var cd := 0.0
var stun := 0.0
var slide_t := 0.0
var is_gk := false
var human := false
var ai_think := 0.0
var ai_tackle_cd := 0.0
var move_cmd := Vector2.ZERO
var want_sprint := false
var stamina := 1.0
var spd_mult := 1.0
var stats := {"pas": 1.0, "sho": 1.0, "tkl": 1.0, "gk": 1.0}
var run_t := 0.0
var body: MeshInstance3D
var ring: MeshInstance3D
var visual: Node3D
var gk_dive := 0.0
var name_tag: Label3D
var skill_t := 0.0

const RUN := 7.0
const SPRINT := 9.2
const ACCEL := 24.0
const DECEL := 32.0

var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var kick_anim := 0.0
var celebrate := false

func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _part(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D, detail := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	if detail:
		# small details: no shadow, culled beyond 24 m (big draw-call saving on phones)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 24.0
	parent.add_child(mi)
	return mi

func _box_mesh(sx: float, sy: float, sz: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(sx, sy, sz)
	return b

func _kit_tex(c1: Color, c2: Color, style: int) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(c1)
	if style == 1:
		for x in range(0, 64, 16):
			img.fill_rect(Rect2i(x + 8, 0, 8, 64), c2)
	elif style == 2:
		for y in range(0, 64, 16):
			img.fill_rect(Rect2i(0, y + 8, 64, 8), c2)
	elif style == 3:
		img.fill_rect(Rect2i(32, 0, 32, 64), c2)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

var num_label: Label3D
var kit_style := 0

func set_number(n: int) -> void:
	number = n
	if num_label != null:
		num_label.text = str(n)

func build(c1: Color, c2: Color, gk: bool, style := 0) -> void:
	visual = Node3D.new()
	add_child(visual)
	var skin := Color(0.9, 0.72, 0.58).lerp(Color(0.32, 0.2, 0.15), float((idx * 7 + team * 3) % 6) / 5.0)
	var shirt := _mat(c1)
	if style != 0 and not gk:
		shirt.albedo_texture = _kit_tex(c1, c2, style)
		shirt.albedo_color = Color(1, 1, 1)
	var shorts_m := _mat(c2)
	var skin_m := _mat(skin)
	var sock_m := _mat(c1 if not gk else Color(0.1, 0.1, 0.1))
	var boot_m := _mat(Color(0.08, 0.08, 0.08), 0.5)
	# torso
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 0.95
	body = _part(cap, Vector3(0, 1.22, 0), shirt, visual)
	body.scale = Vector3(1.18, 1.0, 0.82)
	var lum := c1.r * 0.3 + c1.g * 0.59 + c1.b * 0.11
	num_label = Label3D.new()
	num_label.text = str(number)
	num_label.font_size = 150
	num_label.pixel_size = 0.0036
	num_label.modulate = Color(0.05, 0.05, 0.08) if lum > 0.55 else Color(1, 1, 1)
	num_label.outline_size = 0
	num_label.position = Vector3(0, 1.25, -0.27)
	num_label.rotation.y = PI
	num_label.shaded = false
	num_label.visibility_range_end = 40.0
	visual.add_child(num_label)
	# shorts
	_part(_box_mesh(0.52, 0.32, 0.34), Vector3(0, 0.82, 0), shorts_m, visual)
	# head + hair
	var hs := SphereMesh.new()
	hs.radius = 0.19
	hs.height = 0.38
	_part(hs, Vector3(0, 1.82, 0), skin_m, visual)
	var hair := SphereMesh.new()
	hair.radius = 0.2
	hair.height = 0.26
	var hair_cols := [Color(0.08, 0.06, 0.05), Color(0.35, 0.22, 0.1), Color(0.75, 0.6, 0.3), Color(0.15, 0.1, 0.08), Color(0.5, 0.3, 0.15)]
	var hstyle := (idx * 3 + team * 2) % 6
	var hmat := _mat(hair_cols[(idx + team) % hair_cols.size()])
	if hstyle != 5:
		_part(hair, Vector3(0, 1.9, -0.02), hmat, visual, true)
	if hstyle == 1:
		var bun := SphereMesh.new()
		bun.radius = 0.09
		bun.height = 0.18
		_part(bun, Vector3(0, 2.08, -0.08), hmat, visual, true)
	elif hstyle == 2:
		var curl := SphereMesh.new()
		curl.radius = 0.24
		curl.height = 0.3
		_part(curl, Vector3(0, 1.93, -0.02), hmat, visual, true)
	if hstyle == 3 or hstyle == 4:
		var beard := SphereMesh.new()
		beard.radius = 0.17
		beard.height = 0.22
		_part(beard, Vector3(0, 1.74, 0.07), hmat, visual, true)
	# face: eyes + nose
	var eye := SphereMesh.new()
	eye.radius = 0.028
	eye.height = 0.056
	var eye_m := _mat(Color(0.05, 0.05, 0.06), 0.3)
	_part(eye, Vector3(-0.07, 1.84, 0.17), eye_m, visual, true)
	_part(eye, Vector3(0.07, 1.84, 0.17), eye_m, visual, true)
	var nose := SphereMesh.new()
	nose.radius = 0.035
	nose.height = 0.07
	_part(nose, Vector3(0, 1.78, 0.19), skin_m, visual, true)
	# legs (pivot at the hip)
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.14, 0.74, 0)
		visual.add_child(pivot)
		_part(_box_mesh(0.15, 0.36, 0.17), Vector3(0, -0.2, 0), skin_m, pivot)
		_part(_box_mesh(0.15, 0.34, 0.17), Vector3(0, -0.55, 0), sock_m, pivot)
		_part(_box_mesh(0.16, 0.1, 0.26), Vector3(0, -0.74, 0.04), boot_m, pivot, true)
		if side < 0:
			leg_l = pivot
		else:
			leg_r = pivot
	# arms (pivot at the shoulder)
	for side in [-1, 1]:
		var ap := Node3D.new()
		ap.position = Vector3(side * 0.38, 1.5, 0)
		visual.add_child(ap)
		_part(_box_mesh(0.12, 0.3, 0.13), Vector3(0, -0.14, 0), shirt, ap)
		_part(_box_mesh(0.1, 0.3, 0.11), Vector3(0, -0.4, 0), skin_m if not gk else _mat(Color(0.9, 0.9, 0.2)), ap, true)
		if side < 0:
			arm_l = ap
		else:
			arm_r = ap
	ring = MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.95
	rc.bottom_radius = 0.95
	rc.height = 0.02
	rc.radial_segments = 24
	ring.mesh = rc
	ring.position.y = 0.03
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1, 0.95, 0.2, 0.55)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	ring.visible = false
	add_child(ring)
	var blob := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.55
	bc.bottom_radius = 0.55
	bc.height = 0.01
	blob.mesh = bc
	blob.position.y = 0.015
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0, 0, 0, 0.35)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob.material_override = bm
	add_child(blob)
	name_tag = Label3D.new()
	name_tag.text = pname
	name_tag.font_size = 40
	name_tag.pixel_size = 0.006
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.outline_size = 10
	name_tag.modulate = Color(1, 1, 1, 0.9)
	name_tag.position = Vector3(0, 2.7, 0)
	name_tag.no_depth_test = true
	name_tag.visible = false
	add_child(name_tag)
	is_gk = gk
	visual.scale = Vector3(1.1, 1.1, 1.1)

func pos2() -> Vector2:
	return Vector2(position.x, position.z)

func speed() -> float:
	return Vector2(vel.x, vel.z).length()

func step(dt: float, has_ball: bool) -> void:
	cd = maxf(0.0, cd - dt)
	ai_tackle_cd = maxf(0.0, ai_tackle_cd - dt)
	skill_t = maxf(0.0, skill_t - dt)
	var cmd := move_cmd
	if cmd.length() > 1.0:
		cmd = cmd.normalized()
	var top := RUN
	if want_sprint and stamina > 0.05 and cmd.length() > 0.2:
		top = SPRINT * (0.88 + 0.12 * stamina)
		stamina = maxf(0.0, stamina - 0.10 * dt)
	else:
		stamina = minf(1.0, stamina + 0.06 * dt)
	top *= spd_mult
	if has_ball:
		top *= 0.93
	if stun > 0.0:
		stun -= dt
		cmd = Vector2.ZERO
	var target := Vector2(vel.x, vel.z)
	if slide_t > 0.0:
		slide_t -= dt
		target = Vector2(vel.x, vel.z).move_toward(Vector2.ZERO, 16.0 * dt)
	else:
		var want := cmd * top
		var cur := Vector2(vel.x, vel.z)
		var rate := ACCEL if want.length() > cur.length() * 0.9 else DECEL
		target = cur.move_toward(want, rate * dt)
	vel.x = target.x
	vel.z = target.y
	position.x = clampf(position.x + vel.x * dt, -Cfg.HALF_L - 6.0, Cfg.HALF_L + 6.0)
	position.z = clampf(position.z + vel.z * dt, -Cfg.HALF_W - 4.0, Cfg.HALF_W + 4.0)
	var sp := target.length()
	if sp > 0.6:
		var nf := target.normalized()
		face = face.lerp(nf, clampf(12.0 * dt, 0.0, 1.0)).normalized()
	rotation.y = atan2(face.x, face.y)
	run_t += sp * dt * 1.2
	var bob := absf(sin(run_t)) * 0.07 * clampf(sp / 6.0, 0.0, 1.0)
	visual.position.y = bob
	var lean := clampf(sp / 9.0, 0.0, 1.0) * 0.22
	if slide_t > 0.0:
		lean = 1.2
	visual.rotation.x = lean
	kick_anim = maxf(0.0, kick_anim - dt)
	var amp := clampf(sp / 6.5, 0.0, 1.0) * 1.0
	var sw := sin(run_t * 1.6)
	if slide_t > 0.0:
		leg_l.rotation.x = -1.3
		leg_r.rotation.x = -0.4
		arm_l.rotation.x = 0.4
		arm_r.rotation.x = 0.4
	else:
		leg_l.rotation.x = sw * amp
		leg_r.rotation.x = -sw * amp
		arm_l.rotation.x = -sw * amp * 0.8
		arm_r.rotation.x = sw * amp * 0.8
		if kick_anim > 0.0:
			leg_r.rotation.x = -1.5 * (kick_anim / 0.25)
			arm_l.rotation.x = 0.8
		if celebrate:
			arm_l.rotation.x = -3.0
			arm_r.rotation.x = -3.0
	visual.rotation.y = sin(skill_t * 22.0) * 0.6 if skill_t > 0.0 else 0.0
	if is_gk and gk_dive != 0.0:
		visual.rotation.z = gk_dive
		gk_dive = move_toward(gk_dive, 0.0, 2.2 * dt)
	else:
		visual.rotation.z = 0.0
