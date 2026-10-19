extends CanvasLayer
## On-screen text only where it's needed: a prompt, short toasts, memory captions and found notes.
## There are deliberately no progress counters; the world shows progress.

var font_type: Font
var font_display: Font
var font_display_italic: Font

var crosshair: ColorRect
var prompt: Label
var toast_label: Label
var caption: Label
var note_panel: PanelContainer
var note_kicker: Label
var note_title: Label
var note_body: Label
var title: Control
var pause: Label
var note_open := false
var _toast_t := 0.0
var _caption_queue: Array = []
var _caption_t := 0.0


func _ready() -> void:
	layer = 5
	font_type = _font("res://assets/fonts/SpecialElite-Regular.ttf")
	font_display = _font("res://assets/fonts/IMFePIrm28P.ttf")
	font_display_italic = _font("res://assets/fonts/IMFePIit28P.ttf")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	crosshair = ColorRect.new()
	crosshair.color = Color(0.85, 0.82, 0.74, 0.6)
	crosshair.size = Vector2(4, 4)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-2, -2)
	root.add_child(crosshair)

	prompt = _label(root, font_type, 20, Color(0.88, 0.85, 0.76))
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_top = -90
	prompt.offset_bottom = -60
	prompt.offset_left = -400
	prompt.offset_right = 400

	toast_label = _label(root, font_type, 17, Color(0.62, 0.62, 0.58))
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_top = -130
	toast_label.offset_bottom = -100
	toast_label.offset_left = -500
	toast_label.offset_right = 500

	caption = _label(root, font_display_italic, 28, Color(0.98, 0.88, 0.68))
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caption.offset_top = -330
	caption.offset_bottom = -170
	caption.offset_left = -480
	caption.offset_right = 480
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.modulate.a = 0.0

	_build_note(root)
	_build_title(root)
	pause = _label(root, font_type, 22, Color(0.9, 0.87, 0.78))
	pause.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause.offset_left = -300
	pause.offset_right = 300
	pause.text = "PAUSED\nClick to keep exploring"
	pause.visible = false


func _font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	var f := FontFile.new()
	if f.load_dynamic_font(path) == OK:
		return f
	return ThemeDB.fallback_font


func _label(parent: Control, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_note(root: Control) -> void:
	note_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.83, 0.73)
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
	note_panel.add_theme_stylebox_override("panel", sb)
	note_panel.set_anchors_preset(Control.PRESET_CENTER)
	note_panel.custom_minimum_size = Vector2(560, 0)
	note_panel.position = Vector2(-280, -220)
	note_panel.rotation = deg_to_rad(-0.6)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	note_panel.add_child(v)
	var ink := Color(0.16, 0.13, 0.1)
	note_kicker = Label.new()
	note_kicker.add_theme_font_override("font", font_type)
	note_kicker.add_theme_font_size_override("font_size", 14)
	note_kicker.add_theme_color_override("font_color", Color(0.42, 0.36, 0.27))
	v.add_child(note_kicker)
	note_title = Label.new()
	note_title.add_theme_font_override("font", font_display)
	note_title.add_theme_font_size_override("font_size", 32)
	note_title.add_theme_color_override("font_color", ink)
	v.add_child(note_title)
	note_body = Label.new()
	note_body.add_theme_font_override("font", font_type)
	note_body.add_theme_font_size_override("font_size", 18)
	note_body.add_theme_color_override("font_color", ink)
	note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_body.custom_minimum_size = Vector2(504, 0)
	v.add_child(note_body)
	var hint := Label.new()
	hint.text = "E or click to keep exploring"
	hint.add_theme_font_override("font", font_type)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.42, 0.36, 0.27))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)
	note_panel.visible = false
	note_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(note_panel)


func _build_title(root: Control) -> void:
	title = ColorRect.new()
	(title as ColorRect).color = Color(0.02, 0.025, 0.022, 0.93)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(title)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	v.offset_left = 120
	v.offset_top = -200
	v.offset_right = 900
	v.add_theme_constant_override("separation", 18)
	title.add_child(v)
	var eyebrow := Label.new()
	eyebrow.text = "NORTHERN MICHIGAN ASYLUM  ·  BUILDING 50  ·  TRAVERSE CITY"
	eyebrow.add_theme_font_override("font", font_type)
	eyebrow.add_theme_font_size_override("font_size", 15)
	eyebrow.add_theme_color_override("font_color", Color(0.49, 0.58, 0.5))
	v.add_child(eyebrow)
	var t := Label.new()
	t.text = "Still Here"
	t.add_theme_font_override("font", font_display)
	t.add_theme_font_size_override("font_size", 96)
	t.add_theme_color_override("font_color", Color(0.85, 0.82, 0.74))
	v.add_child(t)
	var sub := Label.new()
	sub.text = "Ward 3 North"
	sub.add_theme_font_override("font", font_display_italic)
	sub.add_theme_font_size_override("font_size", 40)
	sub.add_theme_color_override("font_color", Color(0.89, 0.69, 0.36))
	v.add_child(sub)
	var lede := Label.new()
	lede.text = "You know this building. Opened in 1885 on the Kirkbride plan, closed in 1989, more than fifty thousand patients. You don't know a single one of them.\nThis wing stood empty for years after the doors closed. Scrappers and vandals have been through."
	lede.add_theme_font_size_override("font_size", 18)
	lede.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
	lede.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lede.custom_minimum_size = Vector2(760, 0)
	v.add_child(lede)
	var keys := Label.new()
	keys.text = "WASD walk  ·  Shift hurry  ·  Mouse look  ·  E use  ·  F flashlight  ·  C phone  ·  G photos  ·  Esc release mouse\n\nClick to enter the ward"
	keys.add_theme_font_override("font", font_type)
	keys.add_theme_font_size_override("font_size", 15)
	keys.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	v.add_child(keys)


func set_prompt(text: String) -> void:
	if prompt.text != text:
		prompt.text = text
	crosshair.color.a = 1.0 if text != "" else 0.6


func toast(msg: String) -> void:
	toast_label.text = msg
	_toast_t = 3.2


func queue_caption(text: String) -> void:
	_caption_queue.append(text)


func show_note(doc_id: String) -> void:
	var d: Dictionary = Data.documents.get(doc_id, {})
	note_kicker.text = String(d.get("kicker", "")).to_upper()
	note_title.text = d.get("title", "")
	note_body.text = d.get("text", "")
	note_panel.visible = true
	note_open = true


func hide_note() -> void:
	note_panel.visible = false
	note_open = false


func _process(dt: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= dt
		toast_label.modulate.a = clampf(_toast_t / 0.6, 0.0, 1.0)
	if _caption_t > 0.0:
		_caption_t -= dt
		var shown := 14.0 - _caption_t
		caption.modulate.a = clampf(minf(shown / 2.5, _caption_t / 2.5), 0.0, 1.0)
	elif not _caption_queue.is_empty():
		caption.text = _caption_queue.pop_front()
		_caption_t = 14.0
