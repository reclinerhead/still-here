extends VBoxContainer
## The People tab of the phone's journal: a page per person, assembled from the traces the player
## has found (see docs/data-model.md, "The journal"). Nobody is listed before they are met, traces
## appear in the order they were found, and the only sign that a page is complete is the closing
## paragraph written for that person. There are deliberately no counters.

var hud          # for fonts

const INK := Color(0.86, 0.83, 0.75)
const DIM := Color(0.55, 0.56, 0.52)

var _empty: Label
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _page_scroll: ScrollContainer
var _page: VBoxContainer


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)
	_empty = _label("No one yet. The people of this ward are in what they left behind.", hud.font_type, 18, DIM)
	add_child(_empty)
	_list_scroll = _scroll()
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_list_scroll.add_child(_list)
	_page_scroll = _scroll()
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 14)
	_page_scroll.add_child(_page)


# --- assembly: pure over Data and State -----------------------------------------------------

## The encounter stamp for a trace, or 0 when the player hasn't found it yet.
func stamp_of(t: Dictionary) -> int:
	match t["kind"]:
		"doc": return int(State.read.get(t["ref"], 0))
		"frag": return int(State.told.get(t["ref"], 0))
		"echo": return int(State.seen.get(t["ref"], 0))
	return 0


## {"found": traces in the order found, "unfound": the rest}.
func assemble(cid: String) -> Dictionary:
	var found: Array = []
	var unfound: Array = []
	for t in Data.traces_about(cid):
		if stamp_of(t) > 0:
			found.append(t)
		else:
			unfound.append(t)
	found.sort_custom(func(a, b): return stamp_of(a) < stamp_of(b))
	return {"found": found, "unfound": unfound}


## Characters with at least one trace found, in the order the player first met them.
func people_met() -> Array:
	var first := {}
	for cid in Data.characters:
		for t in Data.traces_about(cid):
			var s := stamp_of(t)
			if s > 0 and (not first.has(cid) or s < first[cid]):
				first[cid] = s
	var ids := first.keys()
	ids.sort_custom(func(a, b): return first[a] < first[b])
	return ids


# --- the screens -----------------------------------------------------------------------------

func show_list() -> void:
	_page_scroll.visible = false
	for c in _list.get_children():
		c.queue_free()
	var people := people_met()
	_empty.visible = people.is_empty()
	_list_scroll.visible = not people.is_empty()
	for cid in people:
		var c: Dictionary = Data.characters[cid]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 64)
		var row := VBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 0)
		b.add_child(row)
		row.add_child(_label(c.get("name", cid), hud.font_display, 30, INK))
		row.add_child(_label(c.get("role", ""), hud.font_type, 14, DIM))
		b.pressed.connect(show_person.bind(cid))
		_list.add_child(b)


func show_person(cid: String) -> void:
	_empty.visible = false
	_list_scroll.visible = false
	_page_scroll.visible = true
	for c in _page.get_children():
		c.queue_free()
	var ch: Dictionary = Data.characters.get(cid, {})
	var back := Button.new()
	back.text = "‹  Everyone"
	back.add_theme_font_override("font", hud.font_type)
	back.add_theme_font_size_override("font_size", 16)
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(show_list)
	_page.add_child(back)
	_page.add_child(_label(ch.get("name", cid), hud.font_display, 44, INK))
	_page.add_child(_label(ch.get("role", ""), hud.font_type, 16, DIM))
	_page.add_child(_gap(10))
	var a := assemble(cid)
	for t in a["found"]:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 4)
		block.add_child(_label(String(t["label"]).to_upper(), hud.font_type, 13, DIM))
		if t["text"] != "":
			block.add_child(_label(t["text"], null, 18, INK, true))
		_page.add_child(block)
	_page.add_child(_gap(18))
	if a["unfound"].is_empty():
		_page.add_child(_label(ch.get("closing", ""), hud.font_display_italic, 22, INK, true))
	else:
		_page.add_child(_label("There is more to find.", hud.font_display_italic, 19, DIM))


func _scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.visible = false
	add_child(s)
	return s


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _label(text: String, font: Font, size: int, color: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(900, 0)
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l
