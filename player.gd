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

func build(c1: Color, c2: Color, gk: bool) -> void:
	visual = Node3D.new()
	add_child(visual)
	body = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.36
	cap.height = 1.5
	body.mesh = cap
	body.position.y = 0.95
	var m := StandardMaterial3D.new()
	m.albedo_color = c1
	m.roughness = 0.8
	body.material_override = m
	visual.add_child(body)
	var shorts := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.37
	sc.bottom_radius = 0.37
	sc.height = 0.4
	shorts.mesh = sc
	shorts.position.y = 0.55
	var sm := StandardMaterial3D.new()
	sm.albedo_color = c2
	shorts.material_override = sm
	visual.add_child(shorts)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.2
	hs.height = 0.4
	head.mesh = hs
	head.position.y = 1.85
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.85, 0.66, 0.52)
	head.material_override = hm
	visual.add_child(head)
	var nose := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(0.18, 0.12, 0.22)
	nose.mesh = nb
	nose.position = Vector3(0, 1.1, 0.34)
	var nm := StandardMaterial3D.new()
	nm.albedo_color = c2
	nose.material_override = nm
	visual.add_child(nose)
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
	visual.scale = Vector3(1.12, 1.12, 1.12)

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
	var lean := clampf(sp / 9.0, 0.0, 1.0) * 0.28
	if slide_t > 0.0:
		lean = 1.2
	visual.rotation.x = lean
	visual.rotation.y = sin(skill_t * 22.0) * 0.6 if skill_t > 0.0 else 0.0
	if is_gk and gk_dive != 0.0:
		visual.rotation.z = gk_dive
		gk_dive = move_toward(gk_dive, 0.0, 2.2 * dt)
	else:
		visual.rotation.z = 0.0
