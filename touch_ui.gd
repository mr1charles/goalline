class_name TouchUI
extends Control

var move := Vector2.ZERO
var held := {"A": false, "B": false, "X": false, "Y": false, "S": false, "Z": false}
var just := {"A": false, "B": false, "X": false, "Y": false, "S": false, "Z": false}
var rel := {"A": -1.0, "B": -1.0, "X": -1.0, "Y": -1.0, "S": -1.0, "Z": -1.0}
var hold_t := {"A": 0.0, "B": 0.0, "X": 0.0, "Y": 0.0, "S": 0.0, "Z": 0.0}
var labels := {"A": "PASS", "B": "SHOOT", "X": "LOB", "Y": "THRU", "S": "SPRINT", "Z": "SKILL"}
var touches := {}
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_cur := Vector2.ZERO
var kb_prev := {}
var touch_active := false

const KEYS := {"A": KEY_J, "B": KEY_K, "X": KEY_L, "Y": KEY_I, "S": KEY_SHIFT, "Z": KEY_SPACE}

func _vs() -> Vector2:
	return get_viewport_rect().size

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _centers() -> Dictionary:
	var s := _vs()
	var c := Vector2(s.x - 190.0, s.y - 150.0)
	return {
		"A": c + Vector2(0, 78), "B": c + Vector2(78, 0),
		"X": c + Vector2(-78, 0), "Y": c + Vector2(0, -78),
		"S": Vector2(s.x - 360.0, s.y - 90.0),
		"Z": Vector2(s.x - 360.0, s.y - 205.0),
	}

func _hit(p: Vector2) -> String:
	var cs := _centers()
	for k in cs:
		var r := 62.0 if (k != "S" and k != "Z") else 56.0
		if p.distance_to(cs[k]) < r:
			return k
	return ""

func _press(b: String) -> void:
	held[b] = true
	just[b] = true
	hold_t[b] = 0.0

func _release(b: String) -> void:
	if held[b]:
		rel[b] = hold_t[b]
	held[b] = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_active = true
		var p: Vector2 = event.position
		if event.pressed:
			var b := _hit(p)
			if b != "":
				touches[event.index] = b
				_press(b)
			elif p.x < _vs().x * 0.5 and p.y > 90.0 and stick_id == -1:
				stick_id = event.index
				stick_origin = p
				stick_cur = p
		else:
			if touches.has(event.index):
				_release(touches[event.index])
				touches.erase(event.index)
			if event.index == stick_id:
				stick_id = -1
				move = Vector2.ZERO
	elif event is InputEventScreenDrag:
		if event.index == stick_id:
			stick_cur = event.position
			var d: Vector2 = stick_cur - stick_origin
			if d.length() > 95.0:
				stick_origin = stick_cur - d.normalized() * 95.0
				d = d.normalized() * 95.0
			move = (d / 80.0).limit_length(1.0)
			if move.length() < 0.12:
				move = Vector2.ZERO

func _process(dt: float) -> void:
	for k in held:
		if held[k]:
			hold_t[k] += dt
	# keyboard
	for k in KEYS:
		var down := Input.is_key_pressed(KEYS[k])
		var was: bool = kb_prev.get(k, false)
		if down and not was:
			_press(k)
		elif was and not down:
			_release(k)
		kb_prev[k] = down
	if stick_id == -1:
		var v := Vector2(
			float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
			float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
		move = v.limit_length(1.0)
	queue_redraw()

func end_frame() -> void:
	for k in just:
		just[k] = false
		rel[k] = -1.0

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var cs := _centers()
	var cols := {"A": Color(0.2, 0.75, 0.3), "B": Color(0.9, 0.25, 0.25), "X": Color(0.25, 0.5, 0.95), "Y": Color(0.95, 0.8, 0.15), "S": Color(0.8, 0.8, 0.85), "Z": Color(0.7, 0.4, 0.95)}
	for k in cs:
		var r := 54.0 if (k != "S" and k != "Z") else 46.0
		var a := 0.55 if held[k] else 0.28
		draw_circle(cs[k], r, Color(cols[k].r, cols[k].g, cols[k].b, a))
		draw_arc(cs[k], r, 0, TAU, 32, Color(1, 1, 1, 0.7), 2.5)
		var lab: String = labels[k]
		var fs := 15
		var tw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, cs[k] + Vector2(-tw * 0.5, 6), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
	if stick_id != -1:
		draw_circle(stick_origin, 70.0, Color(1, 1, 1, 0.12))
		draw_arc(stick_origin, 70.0, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
		draw_circle(stick_cur, 34.0, Color(1, 1, 1, 0.4))
	elif touch_active:
		draw_circle(Vector2(150, _vs().y - 140), 70.0, Color(1, 1, 1, 0.07))
		draw_arc(Vector2(150, _vs().y - 140), 70.0, 0, TAU, 32, Color(1, 1, 1, 0.3), 2.0)
