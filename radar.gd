class_name Radar
extends Control

var m = null

func _draw() -> void:
	if m == null or m.ball == null:
		return
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.25, 0.1, 0.55))
	draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.6), false, 1.5)
	draw_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, h), Color(1, 1, 1, 0.5), 1.0)
	draw_arc(Vector2(w * 0.5, h * 0.5), h * 0.14, 0, TAU, 20, Color(1, 1, 1, 0.5), 1.0)
	for p in m.players:
		var u: float = (p.position.x + Cfg.HALF_L) / (Cfg.HALF_L * 2.0) * w
		var v: float = (p.position.z + Cfg.HALF_W) / (Cfg.HALF_W * 2.0) * h
		var col: Color = m.tinfo[p.team]["c1"]
		if p.is_gk:
			col = Color(1, 0.85, 0.2)
		if p.human:
			draw_circle(Vector2(u, v), 4.5, Color(0.2, 1, 0.4))
		else:
			draw_circle(Vector2(u, v), 3.0, col)
	var bu: float = (m.ball.position.x + Cfg.HALF_L) / (Cfg.HALF_L * 2.0) * w
	var bv: float = (m.ball.position.z + Cfg.HALF_W) / (Cfg.HALF_W * 2.0) * h
	draw_circle(Vector2(bu, bv), 2.5, Color(1, 1, 1))

func _process(_d: float) -> void:
	queue_redraw()
