class_name Ball
extends Node3D

var vel := Vector3.ZERO
var carrier = null          # Player holding the ball, or null
var last_team := -1
var last_player = null
var mesh: MeshInstance3D
var shadow: MeshInstance3D
var roll := Basis.IDENTITY
var beacon: Label3D

func _ready() -> void:
	mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = Cfg.BALL_R
	s.height = Cfg.BALL_R * 2.0
	s.radial_segments = 20
	s.rings = 10
	mesh.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_texture = _ball_texture()
	m.roughness = 0.6
	mesh.material_override = m
	mesh.scale = Vector3.ONE * 1.5
	add_child(mesh)
	beacon = Label3D.new()
	beacon.text = "▼"
	beacon.font_size = 64
	beacon.pixel_size = 0.0065
	beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	beacon.modulate = Color(1, 1, 1)
	beacon.outline_size = 10
	beacon.no_depth_test = true
	beacon.top_level = true
	add_child(beacon)
	shadow = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.34
	c.bottom_radius = 0.34
	c.height = 0.01
	c.radial_segments = 16
	shadow.mesh = c
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.4)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = sm
	shadow.top_level = true
	add_child(shadow)

func _ball_texture() -> ImageTexture:
	var img := Image.create(128, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.97, 0.97, 0.97))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 14:
		var cx := rng.randi_range(0, 127)
		var cy := rng.randi_range(8, 56)
		for dx in range(-5, 6):
			for dy in range(-4, 5):
				if dx * dx + dy * dy * 1.6 <= 22:
					img.set_pixel((cx + dx + 128) % 128, cy + dy, Color(0.12, 0.12, 0.14))
	return ImageTexture.create_from_image(img)

func planar_speed() -> float:
	return Vector2(vel.x, vel.z).length()

func kick(v: Vector3, p) -> void:
	carrier = null
	vel = v
	if p != null:
		last_team = p.team
		last_player = p

func _process(_d: float) -> void:
	if beacon != null:
		beacon.global_position = position + Vector3(0, 1.1, 0)
		beacon.visible = carrier == null

func step(dt: float) -> void:
	if carrier != null:
		shadow.global_position = Vector3(position.x, 0.02, position.z)
		return
	vel.y -= Cfg.GRAV * dt
	position += vel * dt
	var on_ground := false
	if position.y <= Cfg.BALL_R:
		position.y = Cfg.BALL_R
		if vel.y < -1.6:
			vel.y = -vel.y * 0.56
			vel.x *= 0.93
			vel.z *= 0.93
		else:
			vel.y = 0.0
			on_ground = true
	var h := Vector2(vel.x, vel.z)
	var sp := h.length()
	if on_ground:
		sp = maxf(0.0, sp - 1.5 * dt) * exp(-0.5 * dt)
	else:
		sp *= exp(-0.07 * dt)
	if sp < 0.05:
		h = Vector2.ZERO
	elif h.length() > 0.001:
		h = h.normalized() * sp
	vel.x = h.x
	vel.z = h.y
	# rolling visual
	var sv := Vector3(vel.x, 0, vel.z)
	if sv.length() > 0.05:
		var axis := Vector3.UP.cross(sv.normalized())
		if axis.length() > 0.001:
			mesh.rotate(axis.normalized(), sv.length() * dt / Cfg.BALL_R)
	shadow.global_position = Vector3(position.x, 0.02, position.z)
	var sc := clampf(1.0 - position.y * 0.08, 0.4, 1.0)
	shadow.scale = Vector3(sc, 1, sc)
