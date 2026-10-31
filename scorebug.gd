class_name ScoreBug
extends Control

var m = null

func _draw() -> void:
	if m == null or m.tinfo[0].is_empty():
		return
	var f := ThemeDB.fallback_font
	var h := 36.0
	var w := 330.0
	draw_rect(Rect2(0, 0, w, h), Color(0.09, 0.07, 0.2, 0.86))
	draw_rect(Rect2(0, 0, 8, h), m.tinfo[0]["c1"])
	draw_rect(Rect2(w - 8, 0, 8, h), m.tinfo[1]["c1"])
	var hs: String = m.tinfo[0]["short"]
	var a_s: String = m.tinfo[1]["short"]
	draw_string(f, Vector2(18, 26), hs, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1))
	draw_string(f, Vector2(100, 26), str(m.score[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.95, 0.4))
	draw_string(f, Vector2(148, 26), "-", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.7))
	draw_string(f, Vector2(172, 26), str(m.score[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.95, 0.4))
	draw_string(f, Vector2(214, 26), a_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1))
	var mins := int(clampf(m.clock / m.match_len * 90.0, 0.0, 90.0))
	var secs := int(fmod(m.clock / m.match_len * 5400.0, 60.0))
	draw_rect(Rect2(0, h + 2, 92, 26), Color(0.09, 0.07, 0.2, 0.7))
	draw_string(f, Vector2(10, h + 22), "%02d:%02d" % [mins, secs], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.85, 0.85, 1))
	draw_string(f, Vector2(100, h + 22), "1ST HALF" if m.half == 1 else "2ND HALF", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.7, 0.9))

func _process(_d: float) -> void:
	queue_redraw()
