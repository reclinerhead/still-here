extends CanvasLayer
## The phone's screens: Photos (a grid of every photo taken, and a detail view with Bertha's
## answer; photos of the same subject taken before and after a restoration are shown side by side)
## and People (the journal, scripts/phone/journal.gd).

const Journal = preload("res://scripts/phone/journal.gd")

var phone        # source of photo entries
var hud          # for fonts
var is_open := false
var tab := "photos"

var _root: ColorRect
var _tabs: Dictionary = {}     # tab name -> its Button
var _grid: GridContainer
var _grid_scroll: ScrollContainer
var _detail: VBoxContainer
var _empty: Label
var _journal: Journal

const INK := Color(0.86, 0.83, 0.75)
const DIM := Color(0.55, 0.56, 0.52)
const LAMP := Color(0.89, 0.69, 0.36)


func _ready() -> void:
	layer = 8
	_root = ColorRect.new()
	_root.color = Color(0.03, 0.035, 0.032, 0.96)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 64 if side in ["left", "right"] else 48)
	_root.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	margin.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 36)
	v.add_child(head)
	for name in ["Photos", "People"]:
		var b := Button.new()
		b.text = name
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", hud.font_display)
		b.add_theme_font_size_override("font_size", 44)
		b.pressed.connect(_set_tab.bind(name.to_lower()))
		head.add_child(b)
		_tabs[name.to_lower()] = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_label("G or Esc to close", hud.font_type, 15, DIM))

	_empty = _label("No photos yet. Press C to raise your phone, then E to take a picture.", hud.font_type, 18, DIM)
	v.add_child(_empty)

	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_grid_scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_grid_scroll.add_child(_grid)

	_detail = VBoxContainer.new()
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 16)
	v.add_child(_detail)
	_journal = Journal.new()
	_journal.hud = hud
	v.add_child(_journal)
	visible = false


func open() -> void:
	is_open = true
	visible = true
	hud.visible = false
	_set_tab("photos")


func open_people() -> void:
	open()
	_set_tab("people")


func _set_tab(name: String) -> void:
	tab = name
	for t in _tabs:
		_tabs[t].add_theme_color_override("font_color", INK if t == name else DIM)
		_tabs[t].add_theme_color_override("font_hover_color", INK)
		_tabs[t].add_theme_color_override("font_pressed_color", INK)
	_journal.visible = name == "people"
	if name == "people":
		_empty.visible = false
		_grid_scroll.visible = false
		_detail.visible = false
		_journal.show_list()
	else:
		_show_grid()


func close() -> void:
	is_open = false
	visible = false
	hud.visible = true


func _show_grid() -> void:
	_detail.visible = false
	for c in _grid.get_children():
		c.queue_free()
	var entries: Array = phone.entries
	_empty.visible = entries.is_empty()
	_grid_scroll.visible = not entries.is_empty()
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 220)
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		var col := VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		var tr := TextureRect.new()
		tr.texture = e["tex"]
		tr.custom_minimum_size = Vector2(300, 169)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(tr)
		var cap: String = e["title"]
		if e["before"] != null:
			cap += "  ·  before & after"
		if e["pending"]:
			cap += "  ·  waiting for signal"
		var l := _label(cap, hud.font_type, 15, INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(l)
		b.pressed.connect(_show_detail.bind(e))
		_grid.add_child(b)
	_grid_scroll.visible = not entries.is_empty()


func _show_detail(e: Dictionary) -> void:
	_grid_scroll.visible = false
	_detail.visible = true
	for c in _detail.get_children():
		c.queue_free()
	var back := Button.new()
	back.text = "‹  All photos"
	back.add_theme_font_override("font", hud.font_type)
	back.add_theme_font_size_override("font_size", 16)
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_show_grid)
	_detail.add_child(back)
	var pics := HBoxContainer.new()
	pics.add_theme_constant_override("separation", 20)
	_detail.add_child(pics)
	if e["before"] != null:
		pics.add_child(_figure(e["before"], "BEFORE", 560))
		pics.add_child(_figure(e["tex"], "AFTER", 560))
	else:
		pics.add_child(_figure(e["tex"], String(e["title"]).to_upper(), 760))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail.add_child(scroll)
	var text := _label("Waiting for signal. Bertha will answer when you're back in range." if e["pending"] else e["text"], null, 18, INK)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(900, 0)
	scroll.add_child(text)


func _figure(tex: Texture2D, caption: String, width: float) -> VBoxContainer:
	var f := VBoxContainer.new()
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(width, width * 9.0 / 16.0)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	f.add_child(tr)
	var l := _label(caption, hud.font_type, 14, DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	f.add_child(l)
	return f


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
