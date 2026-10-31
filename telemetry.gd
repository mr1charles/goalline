class_name Telemetry
extends Node
# Sends diagnostics (events, errors, fps, screenshots) to the developer's laptop over Wi-Fi.
# Nothing personal is collected: only gameplay/performance/error data.

static var inst: Telemetry = null

var hosts := ["http://cachyos-x8664.local:8799", "http://192.168.1.129:8799", "http://100.113.48.66:8799"]
var host_i := 0
var enabled := true
var sid := ""
var queue: Array = []
var recent: Array = []
var mutex := Mutex.new()
var http: HTTPRequest
var shot_http: HTTPRequest
var sending := false
var sending_count := 0
var shot_sending := false
var seq := 0
var shot_n := 0
var t_flush := 0.0
var t_perf := 0.0
var t_shot := 0.0
var t_save := 0.0
var in_match := false
var sent_device := false
var fails := 0
var logger_obj = null
var touch_press := 0
var max_stick := 0.0
var min_fps := 999.0
var last_ok_host := ""
var t0 := 0

class TLogger extends Logger:
	var owner_t = null
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array) -> void:
		if owner_t == null:
			return
		var kind := "error"
		if error_type == 1:
			kind = "warning"
		elif error_type == 2:
			kind = "script_error"
		elif error_type == 3:
			kind = "shader_error"
		owner_t.push_threadsafe(kind, {"fn": function, "file": file, "line": line, "code": code, "msg": rationale})
	func _log_message(message: String, error: bool) -> void:
		if owner_t != null and error:
			owner_t.push_threadsafe("stderr", {"msg": message.left(300)})

static func ev(kind: String, data := {}) -> void:
	if inst != null:
		inst._add(kind, data)

func push_threadsafe(kind: String, data: Dictionary) -> void:
	mutex.lock()
	if queue.size() < 1500:
		queue.append({"t": Time.get_ticks_msec() - t0, "k": kind, "d": data, "n": seq})
		seq += 1
	mutex.unlock()

func _add(kind: String, data: Dictionary) -> void:
	push_threadsafe(kind, data)
	recent.append({"t": Time.get_ticks_msec() - t0, "k": kind, "d": data})
	if recent.size() > 60:
		recent.pop_front()

func _ready() -> void:
	inst = self
	t0 = Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	sid = "%s_%03d" % [Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_"), randi() % 1000]
	var f := FileAccess.open("user://telemetry.json", FileAccess.READ)
	if f:
		var j = JSON.parse_string(f.get_as_text())
		if j is Dictionary:
			enabled = j.get("enabled", true)
			if j.get("host", "") != "":
				hosts.push_front(str(j["host"]))
	http = HTTPRequest.new()
	http.timeout = 6.0
	add_child(http)
	http.request_completed.connect(_on_sent)
	shot_http = HTTPRequest.new()
	shot_http.timeout = 10.0
	add_child(shot_http)
	shot_http.request_completed.connect(func(_r, code, _h, _b): shot_sending = false)
	logger_obj = TLogger.new()
	logger_obj.owner_t = self
	OS.add_logger(logger_obj)
	# crash detection: marker file exists from a previous run that never exited cleanly
	if FileAccess.file_exists("user://running.marker"):
		var tail := []
		var lf := FileAccess.open("user://last_events.json", FileAccess.READ)
		if lf:
			var lj = JSON.parse_string(lf.get_as_text())
			if lj is Array:
				tail = lj
		_add("prev_session_crashed", {"tail": tail})
	_write_marker()
	_add("session_start", {"os": OS.get_name(), "model": OS.get_model_name(), "version": Engine.get_version_info().get("string", ""),
		"renderer": RenderingServer.get_video_adapter_name(), "api": RenderingServer.get_video_adapter_api_version(),
		"screen": [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y], "dpi": DisplayServer.screen_get_dpi(),
		"touch": DisplayServer.is_touchscreen_available(), "locale": OS.get_locale(), "memory_mb": OS.get_static_memory_peak_usage() / 1048576})

func _write_marker() -> void:
	var f := FileAccess.open("user://running.marker", FileAccess.WRITE)
	if f:
		f.store_string(str(Time.get_unix_time_from_system()))

func _clear_marker() -> void:
	if FileAccess.file_exists("user://running.marker"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://running.marker"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_add("app_pause_or_close", {"what": what})
		_save_recent()
		_clear_marker()
		_flush(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_add("app_resumed", {})
		_write_marker()

func _save_recent() -> void:
	var f := FileAccess.open("user://last_events.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(recent))

func _process(dt: float) -> void:
	if not enabled:
		return
	t_flush += dt
	t_perf += dt
	t_save += dt
	if in_match:
		t_shot += dt
	var fps := Engine.get_frames_per_second()
	if fps > 0:
		min_fps = minf(min_fps, fps)
	if t_save > 3.0:
		t_save = 0.0
		_save_recent()
	if t_perf > 5.0:
		t_perf = 0.0
		_add("perf", {"fps": fps, "min_fps": min_fps, "mem_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
			"draw": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "objs": Performance.get_monitor(Performance.OBJECT_COUNT),
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "touches": touch_press, "max_stick": snappedf(max_stick, 0.01), "in_match": in_match})
		min_fps = 999.0
		max_stick = 0.0
	if in_match and t_shot > 12.0 and not shot_sending:
		t_shot = 0.0
		_send_shot()
	if t_flush > 2.0 and not sending:
		t_flush = 0.0
		_flush(false)

func note_touch(b: String) -> void:
	touch_press += 1
	_add("touch", {"b": b})

func note_stick(v: float) -> void:
	max_stick = maxf(max_stick, v)

func _flush(_final: bool) -> void:
	if not enabled or sending:
		return
	mutex.lock()
	var batch := queue.slice(0, 60)
	mutex.unlock()
	if batch.is_empty():
		return
	sending = true
	sending_count = batch.size()
	var body := {"sid": sid, "events": batch}
	if not sent_device:
		body["device"] = {"os": OS.get_name(), "model": OS.get_model_name()}
	var url: String = hosts[host_i % hosts.size()] + "/log"
	var err := http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		sending = false
		host_i += 1

func _on_sent(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	sending = false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		mutex.lock()
		queue = queue.slice(sending_count)
		mutex.unlock()
		sent_device = true
		fails = 0
		last_ok_host = hosts[host_i % hosts.size()]
	else:
		fails += 1
		host_i += 1
		if fails > 12:
			fails = 0
			t_flush = -20.0

func _send_shot() -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	var w := 800
	var h := int(float(img.get_height()) * w / float(img.get_width()))
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var buf := img.save_jpg_to_buffer(0.6)
	shot_sending = true
	shot_n += 1
	var host: String = last_ok_host if last_ok_host != "" else hosts[host_i % hosts.size()]
	var err := shot_http.request_raw(host + "/shot?sid=%s&n=%d" % [sid, shot_n], ["Content-Type: image/jpeg"], HTTPClient.METHOD_POST, buf)
	if err != OK:
		shot_sending = false
