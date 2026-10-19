extends CanvasLayer
## The player's phone: viewfinder, flash photo, and a chat with Bertha that streams her answer.
## No signal means the photo is saved and answered later, when the player is back in range.

const Bertha = preload("res://scripts/phone/bertha.gd")

var player                 # the explorer; has .cam
var hud
var echoes: Dictionary = {}   # echo id -> EchoGroup node
var audio

var is_open := false
var mode := "camera"
var bertha := Bertha.new()
var _cool := 0.0
var _pending: Array = []      # [{label: Label, text: String, entry: Dictionary}]
## Every photo taken: {tex, title, text, subject, state, pending, before}. The gallery reads this.
var entries: Array = []
var _stream_label: Label = null
var _stream_t := 0.0

var viewfinder: Control
var signal_label: Label
var chat: PanelContainer
var chat_list: VBoxContainer
var chat_scroll: ScrollContainer
var flash_rect: ColorRect
var flash_light: OmniLight3D


func _ready() -> void:
	layer = 6
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_viewfinder(root)
	_build_chat(root)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)
	viewfinder.visible = false
	chat.visible = false


func attach(p: Node3D) -> void:
	player = p
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1, 1, 1)
	flash_light.light_energy = 0.0
	flash_light.omni_range = 9.0
	p.cam.add_child(flash_light)


# --- UI ----------------------------------------------------------------------

func _type_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", hud.font_type)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_viewfinder(root: Control) -> void:
	viewfinder = Control.new()
	viewfinder.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewfinder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(viewfinder)
	# darkened margins around a centred 4:3 frame
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewfinder.add_child(frame)
	for side in ["top", "bottom", "left", "right"]:
		var shade := ColorRect.new()
		shade.color = Color(0.015, 0.02, 0.018, 0.55)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_meta("side", side)
		frame.add_child(shade)
	frame.set_meta("shades", true)
	viewfinder.set_meta("frame", frame)
	for corner in 4:
		for bar in 2:
			var r := ColorRect.new()
			r.color = Color(0.85, 0.82, 0.74, 0.85)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.set_meta("corner", corner)
			r.set_meta("bar", bar)
			frame.add_child(r)
	var dot := ColorRect.new()
	dot.color = Color(0.85, 0.82, 0.74, 0.7)
	dot.size = Vector2(6, 6)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-3, -3)
	viewfinder.add_child(dot)
	signal_label = _type_label("BERTHA  ·  SIGNAL", 15, Color(0.85, 0.82, 0.74))
	viewfinder.add_child(signal_label)
	var hint := _type_label("E or click to take a photo   ·   C to put the phone away", 15, Color(0.85, 0.82, 0.74))
	hint.set_meta("hint", true)
	viewfinder.add_child(hint)
	viewfinder.set_meta("hint", hint)


func _layout_viewfinder() -> void:
	var vs := get_viewport().get_visible_rect().size
	var h := vs.y * 0.76
	var w := minf(vs.x * 0.74, h * 4.0 / 3.0)
	h = w * 3.0 / 4.0
	var r := Rect2((vs - Vector2(w, h)) / 2.0, Vector2(w, h))
	var frame: Control = viewfinder.get_meta("frame")
	for c in frame.get_children():
		if c.has_meta("side"):
			match c.get_meta("side"):
				"top": c.position = Vector2.ZERO; c.size = Vector2(vs.x, r.position.y)
				"bottom": c.position = Vector2(0, r.end.y); c.size = Vector2(vs.x, vs.y - r.end.y)
				"left": c.position = Vector2(0, r.position.y); c.size = Vector2(r.position.x, h)
				"right": c.position = Vector2(r.end.x, r.position.y); c.size = Vector2(vs.x - r.end.x, h)
		elif c.has_meta("corner"):
			var corner: int = c.get_meta("corner")
			var bar: int = c.get_meta("bar")
			var cx := r.position.x + 14.0 if corner % 2 == 0 else r.end.x - 14.0
			var cy := r.position.y + 14.0 if corner < 2 else r.end.y - 14.0
			var lx := 30.0 if bar == 0 else 2.0
			var ly := 2.0 if bar == 0 else 30.0
			c.size = Vector2(lx, ly)
			c.position = Vector2(cx if corner % 2 == 0 else cx - lx, cy if corner < 2 else cy - ly)
	signal_label.position = r.position + Vector2(52, 16)
	var hint: Label = viewfinder.get_meta("hint")
	hint.position = Vector2(r.position.x, r.end.y - 40)
	hint.size = Vector2(w, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_chat(root: Control) -> void:
	chat = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.063, 0.075, 0.067, 0.97)
	sb.border_color = Color(0.85, 0.82, 0.74, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(14)
	chat.add_theme_stylebox_override("panel", sb)
	chat.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	chat.custom_minimum_size = Vector2(380, 640)
	chat.position = Vector2(-410, -320)
	root.add_child(chat)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	chat.add_child(v)
	v.add_child(_type_label("Bertha", 18, Color(0.89, 0.69, 0.36)))
	chat_scroll = ScrollContainer.new()
	chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(chat_scroll)
	chat_list = VBoxContainer.new()
	chat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_list.add_theme_constant_override("separation", 12)
	chat_scroll.add_child(chat_list)
	v.add_child(_type_label("E: another photo   ·   C: put the phone away   ·   G: all photos", 13, Color(0.55, 0.56, 0.52)))


func _bubble(mine: bool) -> VBoxContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.13) if mine else Color(0.1, 0.11, 0.1)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_FILL
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	pc.add_child(inner)
	chat_list.add_child(pc)
	return inner


# --- behaviour -------------------------------------------------------------

func toggle() -> void:
	is_open = not is_open
	mode = "camera"
	_finish_stream()
	viewfinder.visible = is_open
	chat.visible = false
	if is_open:
		_layout_viewfinder()


func use() -> void:
	if not is_open or _cool > 0.0:
		return
	if mode == "chat":
		_finish_stream()
		mode = "camera"
		chat.visible = false
		viewfinder.visible = true
		return
	_cool = 0.8
	_take_photo()


func has_signal_here() -> bool:
	var p: Vector3 = player.global_position
	for box in Data.zone.get("signal", {}).get("dead_spaces", []):
		if p.x >= box[0] and p.x <= box[1] and p.z >= box[2] and p.z <= box[3]:
			return false
	return true


func _pick_subject() -> String:
	var cam: Camera3D = player.cam
	var vs := get_viewport().get_visible_rect().size
	var best := ""
	var best_score := 99.0
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for sid in Data.subjects:
		var s: Dictionary = Data.subjects[sid]
		if s.has("area"):
			continue
		var p: Vector3 = Data.vec3(s["pos"])
		if cam.is_position_behind(p):
			continue
		var dist := cam.global_position.distance_to(p)
		if dist > float(s.get("max_distance", 5.0)):
			continue
		var sp := cam.unproject_position(p)
		var off := ((sp - vs * 0.5) / (vs.y * 0.5)).length()
		if off > float(s.get("center", 0.5)):
			continue
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, p, 1)
		var hit: Dictionary = space.intersect_ray(q)
		if hit and cam.global_position.distance_to(hit["position"]) < dist - float(s.get("radius", 0.5)) - 0.15:
			continue
		var score := off - (1.0 if s.get("detail", false) else 0.0)
		if score < best_score:
			best_score = score
			best = sid
	if best == "":
		best = _area_subject()
	return best


## A subject for a whole place (the tunnel), chosen by where the player stands when nothing
## specific is in frame. "area" is [x0, x1, z0, z1].
func _area_subject() -> String:
	var p: Vector3 = player.global_position
	for sid in Data.subjects:
		var a: Array = Data.subjects[sid].get("area", [])
		if a.size() == 4 and p.x >= a[0] and p.x <= a[1] and p.z >= a[2] and p.z <= a[3]:
			return sid
	return ""


func _take_photo() -> void:
	var sid := _pick_subject()
	var ans := bertha.answer(sid)
	var title: String = Data.subjects.get(sid, {}).get("title", "Ward 3 North")
	# effects that change what the camera captures (the camera sees more than you do)
	var ghosts: Array = []
	for fx in ans["effects"]:
		if fx.get("type", "") == "ghost_in_photo" and echoes.has(fx["echo"]):
			echoes[fx["echo"]].forced = float(fx.get("reveal", 0.35))
			ghosts.append(echoes[fx["echo"]])
		elif fx.get("type", "") == "set_flag":
			State.set_flag(fx["flag"])
	if sid != "":
		bertha.escalate(sid)
	viewfinder.visible = false
	hud.visible = false
	flash_light.light_energy = 4.0
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	flash_light.light_energy = 0.0
	for g in ghosts:
		g.forced = -1.0
	hud.visible = true
	if audio:
		audio.shutter()
	var tw := create_tween()
	flash_rect.color.a = 0.9
	tw.tween_property(flash_rect, "color:a", 0.0, 0.45)
	img.resize(640, int(640.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(img)
	# pair with the most recent photo of the same subject taken in a different state
	var before: Texture2D = null
	if sid != "":
		for i in range(entries.size() - 1, -1, -1):
			var e: Dictionary = entries[i]
			if e["subject"] == sid and e["state"] != ans["state"]:
				before = e["tex"]
				break
	var entry := {"tex": tex, "title": title, "text": ans["text"], "subject": sid, "state": ans["state"], "ids": ans["ids"], "pending": not has_signal_here(), "before": before}
	entries.append(entry)
	_show_exchange(tex, title, ans["text"], entry)


func _show_exchange(tex: Texture2D, title: String, text: String, entry: Dictionary) -> void:
	mode = "chat"
	chat.visible = true
	var me := _bubble(true)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(240, 135)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	me.add_child(tr)
	me.add_child(_type_label("What am I looking at?", 14, Color(0.8, 0.78, 0.7)))
	var b := _bubble(false)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(300, 0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.86, 0.83, 0.75))
	b.add_child(label)
	if has_signal_here():
		_finish_stream()
		label.text = text
		label.visible_characters = 0
		_stream_label = label
		_stream_t = -1.1   # a short "thinking" pause first
		State.mark_told(entry["ids"])
	else:
		label.text = "No signal. Photo saved. Bertha will answer when you're back in range."
		label.add_theme_color_override("font_color", Color(0.55, 0.56, 0.52))
		_pending.append({"label": label, "text": text, "entry": entry})
	_scroll_down()


func _finish_stream() -> void:
	if _stream_label:
		_stream_label.visible_characters = -1
		_stream_label = null


func _scroll_down() -> void:
	await get_tree().process_frame
	chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)


func _process(dt: float) -> void:
	_cool = maxf(0.0, _cool - dt)
	if is_open and mode == "camera" and viewfinder.visible:
		_layout_viewfinder()
		signal_label.text = "BERTHA  ·  SIGNAL" if has_signal_here() else "BERTHA  ·  NO SIGNAL"
	if _stream_label:
		_stream_t += dt
		if _stream_t > 0.0:
			var n := int(_stream_t * 55.0)
			_stream_label.visible_characters = n
			if n >= _stream_label.get_total_character_count():
				_stream_label = null
			_scroll_down()
	if not _pending.is_empty() and player and has_signal_here():
		for p in _pending:
			p["entry"]["pending"] = false
			p["label"].text = p["text"]
			p["label"].add_theme_color_override("font_color", Color(0.86, 0.83, 0.75))
			State.mark_told(p["entry"]["ids"])
		hud.toast("Signal's back. Bertha answered %d photo%s." % [_pending.size(), "" if _pending.size() == 1 else "s"])
		_pending.clear()
