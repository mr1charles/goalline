class_name TouchUI
extends Control
# Layout (right-handed): stick floats on the left half. Right thumb arc, bottom-right corner:
#   SHOOT (big) bottom-right, PASS to its left, THRU above, LOB above-left, SPRINT + SKILL further left.

static var scale_f := 1.0
static var lefty := false
static var opacity := 1.0

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
var visible_buttons := true

const KEYS := {"A": KEY_J, "B": KEY_K, "X": KEY_L, "Y": KEY_I, "S": KEY_SHIFT, "Z": KEY_SPACE}
const COLS := {"A": Color(0.25, 0.8, 0.35), "B": Color(0.92, 0.28, 0.28), "X": Color(0.3, 0.55, 0.98), "Y": Color(0.98, 0.82, 0.2), "S": Color(0.9, 0.9, 0.95), "Z": Color(0.72, 0.42, 0.98)}

func _vs() -> Vector2:
	return get_viewport_rect().size

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _centers() -> Dictionary:
	var s := _vs()
	var k := scale_f
	var d := {
		"B": Vector2(s.x - 125.0 * k, s.y - 125.0 * k),
		"A": Vector2(s.x - 268.0 * k, s.y - 100.0 * k),
		"Y": Vector2(s.x - 118.0 * k, s.y - 278.0 * k),
		"X": Vector2(s.x - 250.0 * k, s.y - 245.0 * k),
		"S": Vector2(s.x - 385.0 * k, s.y - 118.0 * k),
		"Z": Vector2(s.x - 378.0 * k, s.y - 238.0 * k),
	}
	if lefty:
		for key in d:
			d[key].x = s.x - d[key].x
	return d

func _radius(b: String) -> float:
	var r := {"B": 66.0, "A": 58.0, "Y": 52.0, "X": 52.0, "S": 52.0, "Z": 44.0}
	return r[b] * scale_f

func _stick_zone(p: Vector2) -> bool:
	var s := _vs()
	if p.y < 90.0:
		return false
	return p.x > s.x * 0.55 if lefty else p.x < s.x * 0.45

func _hit(p: Vector2) -> String:
	var cs := _centers()
	var best := ""
	var bd := 1e9
	for k in cs:
		var d: float = p.distance_to(cs[k])
		if d < _radius(k) * 1.2 and d < bd:
			bd = d
			best = k
	return best

func _press(b: String) -> void:
	Telemetry.ev("btn", {"b": b})
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
			elif _stick_zone(p) and stick_id == -1:
				Telemetry.ev("stick_start", {"x": int(p.x), "y": int(p.y), "vs": [int(_vs().x), int(_vs().y)]})
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
			var reach := 90.0 * scale_f
			if d.length() > reach:
				stick_origin = stick_cur - d.normalized() * reach
				d = d.normalized() * reach
			move = (d / (reach * 0.85)).limit_length(1.0)
			if move.length() < 0.14:
				move = Vector2.ZERO
			if Telemetry.inst != null:
				Telemetry.inst.note_stick(move.length())

func _process(dt: float) -> void:
	for k in held:
		if held[k]:
			hold_t[k] += dt
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
	if not visible_buttons:
		return
	var font := ThemeDB.fallback_font
	var cs := _centers()
	var op := clampf(opacity, 0.3, 1.0)
	for k in cs:
		var r := _radius(k)
		var c: Color = COLS[k]
		var a := (0.55 if held[k] else 0.30) * op
		draw_circle(cs[k], r, Color(c.r, c.g, c.b, a))
		draw_arc(cs[k], r, 0, TAU, 40, Color(1, 1, 1, 0.75 * op), 2.5)
		if held[k]:
			draw_circle(cs[k], r * 0.82, Color(1, 1, 1, 0.18))
		var lab: String = labels[k]
		var fs := int((19 if k == "B" else 16 if k != "Z" else 13) * scale_f)
		var tw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, cs[k] + Vector2(-tw * 0.5, fs * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95 * op))
	var s := _vs()
	if stick_id != -1:
		draw_circle(stick_origin, 74.0 * scale_f, Color(1, 1, 1, 0.12 * op))
		draw_arc(stick_origin, 74.0 * scale_f, 0, TAU, 40, Color(1, 1, 1, 0.5 * op), 2.0)
		draw_circle(stick_cur, 34.0 * scale_f, Color(1, 1, 1, 0.42 * op))
	else:
		var hx := 160.0 * scale_f if not lefty else s.x - 160.0 * scale_f
		draw_circle(Vector2(hx, s.y - 150.0 * scale_f), 72.0 * scale_f, Color(1, 1, 1, 0.06 * op))
		draw_arc(Vector2(hx, s.y - 150.0 * scale_f), 72.0 * scale_f, 0, TAU, 40, Color(1, 1, 1, 0.28 * op), 2.0)
