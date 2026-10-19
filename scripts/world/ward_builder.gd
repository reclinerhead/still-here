extends Node3D
## Builds a Kirkbride-style ward from the zone layout data: corridor, rooms, alcoves,
## doors, window openings, floor, ceiling, light fixtures and the night outside.

const Mats = preload("res://scripts/world/mats.gd")
const Props = preload("res://scripts/world/props.gd")

var L := 36.0
var CH := 1.8
var D := 3.7
var T := 0.2
var H := 4.0
var WAIN := 1.25
var station_x := 18.0

## [{globe: MeshInstance3D, mat: StandardMaterial3D, light: OmniLight3D|null, threshold: float}]
var lamps: Array = []
var moon: DirectionalLight3D
## Openings cut in the ward floor, as [x0, x1, z0, z1] (the stairwell down to the tunnel).
var floor_holes: Array = []
## Places where the ceiling plaster has come down, as [x0, x1, z0, z1].
var ceiling_holes: Array = []
## Window sizes (with the model built for each) and the layouts a segment's "win" names.
var window_types: Dictionary = {}
var window_layouts: Dictionary = {}

const LOCKED_MSGS := [
	"Locked. The ward key ring was taken too.",
	"Locked. Something heavy is pushed against the other side.",
	"Locked. The knob turns, but the bolt holds.",
]
var _locked_i := 0


func build(z: Dictionary) -> void:
	var d: Dictionary = z["dims"]
	L = d["length"]
	CH = d["corridor_half"]
	D = d["room_depth"]
	T = d["wall"]
	H = d["height"]
	WAIN = d["wainscot"]
	station_x = z.get("station", [18, 0])[0]
	if z.has("stair"):
		var st: Dictionary = z["stair"]
		floor_holes.append([st["x0"], st["x1"], st["z0"], CH + D + T])
	ceiling_holes = z.get("ceiling_holes", [])
	window_types = z.get("window_types", {})
	window_layouts = z.get("window_layouts", {})
	_build_side(z["north"], -1.0)
	_build_side(z["south"], 1.0)
	_floor_ceiling()
	_end_wall(-T / 2.0, "The stairwell you came up. Not until the ward is put right.")
	_end_wall(L + T / 2.0, "Locked tight. The next ward will have to wait.")
	_lamps(z.get("lamps", {}))
	_night()


# --- boxes -----------------------------------------------------------------

func box(a: Vector3, b: Vector3, mat: Material, solid := true, shadow := true) -> MeshInstance3D:
	return make_box(self, a, b, mat, solid, shadow)


## An axis-aligned box between two corners, optionally with a matching collider. Shared with
## the tunnel builder.
static func make_box(parent: Node3D, a: Vector3, b: Vector3, mat: Material, solid := true, shadow := true) -> MeshInstance3D:
	var mn := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var mx := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var size := mx - mn
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return null
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = (mn + mx) * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	parent.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		body.position = mi.position
		parent.add_child(body)
	return mi


## A wall box, two-tone: painted green below the chair rail, cream plaster above.
func wall(a: Vector3, b: Vector3) -> void:
	var y0 := minf(a.y, b.y)
	var y1 := maxf(a.y, b.y)
	if y0 < WAIN:
		box(Vector3(a.x, y0, a.z), Vector3(b.x, minf(y1, WAIN), b.z), Mats.m("wall_lower"))
	if y1 > WAIN:
		box(Vector3(a.x, maxf(y0, WAIN), a.z), Vector3(b.x, y1, b.z), Mats.m("wall_upper"))
	if y0 < WAIN and y1 > WAIN:
		var thin_x := absf(b.x - a.x) < absf(b.z - a.z)
		var pad := Vector3(0.025, 0, 0) if thin_x else Vector3(0, 0, 0.025)
		var lo := Vector3(minf(a.x, b.x), WAIN - 0.03, minf(a.z, b.z)) - pad
		var hi := Vector3(maxf(a.x, b.x), WAIN + 0.03, maxf(a.z, b.z)) + pad
		box(lo, hi, Mats.m("rail"), false)


# --- layout ----------------------------------------------------------------

func _build_side(segs: Array, s: float) -> void:
	var zf0 := s * CH
	var zf1 := s * (CH + T)
	var zb0 := s * (CH + D)
	var zb1 := s * (CH + D + T)
	for i in segs.size():
		var seg: Dictionary = segs[i]
		var x0: float = seg["x0"]
		var x1: float = seg["x1"]
		var typ: String = seg["type"]
		if i > 0:
			var prev: Dictionary = segs[i - 1]
			if prev["type"] != "solid" or typ != "solid":
				wall(Vector3(x0 - T / 2.0, 0, zf1), Vector3(x0 + T / 2.0, H, zb0))
		if typ == "solid":
			wall(Vector3(x0, 0, zf0), Vector3(x1, H, zf1))
			continue
		_back_wall(x0, x1, zb0, zb1, seg.get("win", ""), seg.get("broken", []), s)
		if typ == "room":
			var dx: float = seg.get("door_at", (x0 + x1) / 2.0)
			var dw := 1.0
			var dh := 2.3
			wall(Vector3(x0, 0, zf0), Vector3(dx - dw / 2.0, H, zf1))
			wall(Vector3(dx + dw / 2.0, 0, zf0), Vector3(x1, H, zf1))
			wall(Vector3(dx - dw / 2.0, dh, zf0), Vector3(dx + dw / 2.0, H, zf1))
			box(Vector3(dx - dw / 2.0 - 0.06, 0, zf0 - s * 0.02), Vector3(dx - dw / 2.0, dh, zf1 + s * 0.02), Mats.m("rail"), false)
			box(Vector3(dx + dw / 2.0, 0, zf0 - s * 0.02), Vector3(dx + dw / 2.0 + 0.06, dh, zf1 + s * 0.02), Mats.m("rail"), false)
			_door(dx, s, seg.get("door", "locked"))


func _back_wall(x0: float, x1: float, zb0: float, zb1: float, win: String, broken: Array, s: float) -> void:
	var cx := (x0 + x1) / 2.0
	var wins: Array = []
	for w in window_layouts.get(win, []):
		var t: Dictionary = window_types[w["type"]]
		wins.append([cx + float(w["dx"]), float(t["width"]), float(t["sill"]), float(t["top"]), w["kind"], t.get("model", "")])
	if wins.is_empty():
		wall(Vector3(x0, 0, zb0), Vector3(x1, H, zb1))
		return
	var sill: float = wins[0][2]
	var top: float = wins[0][3]
	wall(Vector3(x0, 0, zb0), Vector3(x1, sill, zb1))
	wall(Vector3(x0, top, zb0), Vector3(x1, H, zb1))
	var cur := x0
	for i in wins.size():
		var w: Array = wins[i]
		var a: float = w[0] - w[1] / 2.0
		var b: float = w[0] + w[1] / 2.0
		wall(Vector3(cur, sill, zb0), Vector3(a, top, zb1))
		_window(a, b, sill, top, zb0, zb1, w[4], w[5], s, broken.has(float(i)) or broken.has(i))
		cur = b
	wall(Vector3(cur, sill, zb0), Vector3(x1, top, zb1))


## A window in the opening from a to b: the model built for its type (tools/blender/window.py)
## when there is one, otherwise bare primitives. Either way the glass is solid, to the player and
## to the phone's ray. Frosted windows' panes are grimed nearly opaque; a broken one has its
## eye-level panes smashed out (models only).
func _window(a: float, b: float, sill: float, top: float, zb0: float, zb1: float, kind: String, model: String, s: float, broken := false) -> void:
	var zc := (zb0 + zb1) / 2.0
	var win: Node3D = Props.imported(model) if model != "" else null
	if win:
		# models face +z, into the room: turn those on the south side around
		win.position = Vector3((a + b) / 2.0, 0, zb0)
		win.rotation.y = PI if s > 0.0 else 0.0
		if kind != "boarded":
			win.get_node("plywood").free()
		for pane in win.get_node("glass").get_children():
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if kind == "frosted":
				pane.material_override = Mats.m("glass_frosted")
		if broken:
			_break(win, sill, int(a * 100.0))
		add_child(win)
		_blocker(Vector3(a, sill, zc - 0.005), Vector3(b, top, zc + 0.005))
		return
	var frame := Mats.m("rail")
	# sill ledge on the room side
	box(Vector3(a - 0.05, sill - 0.04, zb0 - s * 0.08), Vector3(b + 0.05, sill, zb0 + s * 0.02), Mats.m("wood"), false)
	if kind == "boarded":
		var plank := Mats.m("door")
		var y := sill + 0.06
		while y < top - 0.05:
			box(Vector3(a - 0.06, y, zb0 - s * 0.01), Vector3(b + 0.06, minf(y + 0.2, top), zb0 - s * 0.04), plank)
			y += 0.3
		box(Vector3(a, sill, zc - 0.005), Vector3(b, top, zc + 0.005), Mats.m("glass"), true, false)
		return
	# mullions: their shadows draw the window pattern across the floor
	var mx := (a + b) / 2.0
	box(Vector3(mx - 0.025, sill, zc - 0.03), Vector3(mx + 0.025, top, zc + 0.03), frame, false)
	var y2 := sill + (top - sill) / 3.0
	var y3 := sill + (top - sill) * 2.0 / 3.0
	for yy in [y2, y3]:
		box(Vector3(a, yy - 0.02, zc - 0.03), Vector3(b, yy + 0.02, zc + 0.03), frame, false)
	box(Vector3(a, sill, zc - 0.005), Vector3(b, top, zc + 0.005), Mats.m("glass"), true, false)


## A window's eye-level panes (the lower sash's upper row), smashed out of a model.
const BROKEN_PANES := ["lower_1_0", "lower_1_1"]


## Smashes the eye-level panes: jagged teeth of glass left in the frame, the wire guard over them
## torn back, and bits of glass on the sill and the floor below.
func _break(win: Node3D, sill: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for pane_name in BROKEN_PANES:
		var pane: MeshInstance3D = win.get_node("glass/" + pane_name)
		_teeth(win.get_node("glass"), pane, rng)
		pane.free()
		var flap: Node3D = win.get_node("guard/mesh_" + pane_name)
		flap.rotation = Vector3(deg_to_rad(rng.randf_range(55.0, 80.0)), 0.0, deg_to_rad(rng.randf_range(-12.0, 12.0)))
	_grit(win, sill, rng)


## Teeth of glass along the edges of a smashed pane, on the pane's own patch of texture.
func _teeth(glass: Node3D, pane: MeshInstance3D, rng: RandomNumberGenerator) -> void:
	var aabb := pane.mesh.get_aabb()
	var lo := Vector2(aabb.position.x, aabb.position.y)
	var hi := Vector2(aabb.end.x, aabb.end.y)
	var mid := (lo + hi) / 2.0
	var z := aabb.get_center().z
	# the texture coordinates at the pane's corners, keyed by (right, top)
	var arrays := pane.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var corner := {}
	for i in verts.size():
		corner[Vector2i(int(verts[i].x > mid.x), int(verts[i].y > mid.y))] = uvs[i]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := [[lo, Vector2(hi.x, lo.y)], [Vector2(hi.x, lo.y), hi], [hi, Vector2(lo.x, hi.y)], [Vector2(lo.x, hi.y), lo]]
	for side in sides:
		var t := 0.0
		while t < 1.0:
			var t1 := minf(1.0, t + rng.randf_range(0.15, 0.4))
			if rng.randf() < 0.75:
				var p0: Vector2 = side[0].lerp(side[1], t)
				var p1: Vector2 = side[0].lerp(side[1], t1)
				var tip := p0.lerp(p1, rng.randf_range(0.3, 0.7)).lerp(mid, rng.randf_range(0.1, 0.55))
				for p in [p0, p1, tip]:
					var u := inverse_lerp(lo.x, hi.x, p.x)
					var v := inverse_lerp(lo.y, hi.y, p.y)
					st.set_uv(corner[Vector2i(0, 0)].lerp(corner[Vector2i(1, 0)], u).lerp(corner[Vector2i(0, 1)].lerp(corner[Vector2i(1, 1)], u), v))
					st.add_vertex(Vector3(p.x, p.y, z))
			t = t1
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = pane.mesh.surface_get_material(0)
	mi.transform = pane.transform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.add_child(mi)


## Bits of glass fallen on the inside sill and the floor below it, in the window's own frame.
func _grit(win: Node3D, sill: float, rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 36:
		var on_sill := i < 12
		var c := Vector3(rng.randf_range(-0.45, 0.45), sill + 0.031 if on_sill else 0.004,
			rng.randf_range(-0.25, 0.02) if on_sill else rng.randf_range(0.06, 0.8))
		var r := rng.randf_range(0.01, 0.045)
		var ang := rng.randf() * TAU
		for k in 3:
			var a2 := ang + k * TAU / 3.0 + rng.randf_range(-0.5, 0.5)
			st.add_vertex(c + Vector3(cos(a2) * r, 0.0, sin(a2) * r))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Mats.m("glass_shard")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	win.add_child(mi)

## An invisible solid box (layer 1, like the walls).
func _blocker(a: Vector3, b: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = (b - a).abs()
	cs.shape = sh
	body.add_child(cs)
	body.position = (a + b) / 2.0
	add_child(body)


func _door(dx: float, s: float, state: String) -> void:
	if state == "locked":
		var body := StaticBody3D.new()
		body.collision_layer = 1 | 2
		body.collision_mask = 0
		body.position = Vector3(dx, 1.15, s * (CH + T / 2.0))
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1.0, 2.3, 0.06)
		cs.shape = sh
		body.add_child(cs)
		_door_mesh(body, s)
		body.set_meta("interact", {"kind": "locked", "msg": LOCKED_MSGS[_locked_i % LOCKED_MSGS.size()]})
		_locked_i += 1
		add_child(body)
	else:
		var pivot := Node3D.new()
		pivot.position = Vector3(dx - 0.5, 0, s * (CH + T / 2.0) + s * 0.06)
		pivot.rotation.y = -s * 1.75
		var leaf := Node3D.new()
		leaf.position = Vector3(0.5, 1.15, 0)
		_door_mesh(leaf, s)
		pivot.add_child(leaf)
		add_child(pivot)


func _door_mesh(p: Node3D, s: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 2.3, 0.05)
	mi.mesh = bm
	mi.material_override = Mats.m("door")
	p.add_child(mi)
	var pane := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.36, 0.36, 0.055)
	pane.mesh = pm
	pane.material_override = Mats.m("recess")
	pane.position = Vector3(0, 0.6, 0)
	p.add_child(pane)
	var knob := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.03
	km.height = 0.06
	knob.mesh = km
	knob.material_override = Mats.m("brass")
	knob.position = Vector3(0.4, -0.1, -s * 0.05)
	p.add_child(knob)


## Splits rectangles [x0, x1, z0, z1] around holes, leaving the rest covered.
static func _cut(rects: Array, holes: Array) -> Array:
	for hole in holes:
		var next: Array = []
		for r in rects:
			if hole[0] >= r[1] or hole[1] <= r[0] or hole[2] >= r[3] or hole[3] <= r[2]:
				next.append(r)
				continue
			next.append([r[0], hole[0], r[2], r[3]])
			next.append([hole[1], r[1], r[2], r[3]])
			next.append([maxf(r[0], hole[0]), minf(r[1], hole[1]), r[2], hole[2]])
			next.append([maxf(r[0], hole[0]), minf(r[1], hole[1]), hole[3], r[3]])
		rects = next
	return rects


func _floor_ceiling() -> void:
	var zmax := CH + D + T
	var whole: Array = [[-0.6, L + 0.6, -zmax, zmax]]
	# triplanar mapping keeps the tiles lined up across the pieces
	for r in _cut(whole, floor_holes):
		box(Vector3(r[0], -0.3, r[2]), Vector3(r[1], 0, r[3]), Mats.m("floor"))
	# the ceiling is a thin skin of plaster under the floor above; where it has fallen,
	# the lath and joists show through
	for r in _cut(whole, ceiling_holes):
		box(Vector3(r[0], H, r[2]), Vector3(r[1], H + 0.03, r[3]), Mats.m("ceiling"))
	box(Vector3(-0.6, H + 0.32, -zmax), Vector3(L + 0.6, H + 0.42, zmax), Mats.m("lath"))
	for hole in ceiling_holes:
		_fallen_ceiling(hole)


## Where the plaster has come down: joists across the gap, lath strips nailed beneath them
## (some missing, some hanging), a few slabs still dangling, and a ragged plaster edge.
func _fallen_ceiling(h: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(h[0] * 131.0 + h[2] * 17.0)
	var x0: float = h[0]
	var x1: float = h[1]
	var z0: float = h[2]
	var z1: float = h[3]
	var lath := Mats.m("lath")
	var x := floorf(x0 / 0.4) * 0.4
	while x < x1 + 0.4:
		box(Vector3(x - 0.025, H + 0.06, z0 - 0.4), Vector3(x + 0.025, H + 0.32, z1 + 0.4), Mats.m("wood_dark"), false)
		x += 0.4
	var z := z0 - 0.01
	while z < z1:
		var roll := rng.randf()
		if roll < 0.12:
			_dangle(Vector3(x0 + rng.randf_range(0.0, x1 - x0), H + 0.04, z + 0.016), Vector3(rng.randf_range(0.4, 1.0), 0.012, 0.032), Vector3(0, rng.randf_range(-0.3, 0.3), rng.randf_range(0.5, 1.2)), lath)
		elif roll > 0.2:
			box(Vector3(x0 - 0.05, H + 0.034, z), Vector3(x1 + 0.05, H + 0.05, z + 0.032), lath, false, false)
		z += 0.045
	var plaster := Mats.m("ceiling")
	for i in rng.randi_range(2, 3):
		var at := Vector3(rng.randf_range(x0, x1), H + 0.01, z0 if rng.randf() < 0.5 else z1)
		_dangle(at, Vector3(rng.randf_range(0.3, 0.6), 0.025, rng.randf_range(0.25, 0.45)), Vector3(rng.randf_range(0.6, 1.1) * signf(at.z - (z0 + z1) / 2.0), rng.randf_range(0, TAU), 0), plaster)
	# break up the straight cut with small pieces sagging along the edge
	for i in 10:
		var along := rng.randf()
		var edge := Vector3(lerpf(x0, x1, along), H - 0.005, z0 if i % 2 == 0 else z1)
		if i >= 6:
			edge = Vector3(x0 if i % 2 == 0 else x1, H - 0.005, lerpf(z0, z1, along))
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.12, 0.3), 0.025, rng.randf_range(0.1, 0.22))
		mi.mesh = bm
		mi.material_override = plaster
		mi.position = edge
		mi.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(0, TAU), rng.randf_range(-0.25, 0.25))
		add_child(mi)


## A piece hanging from one end: its top edge at `at`, swung by `tilt`.
func _dangle(at: Vector3, size: Vector3, tilt: Vector3, mat: Material) -> void:
	var pivot := Node3D.new()
	pivot.position = at
	pivot.rotation = tilt
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = Vector3(size.x / 2.0, 0, 0)
	pivot.add_child(mi)
	add_child(pivot)


func _end_wall(x: float, msg: String) -> void:
	wall(Vector3(x - T / 2.0, 0, -CH), Vector3(x + T / 2.0, H, -0.6))
	wall(Vector3(x - T / 2.0, 0, 0.6), Vector3(x + T / 2.0, H, CH))
	wall(Vector3(x - T / 2.0, 2.3, -0.6), Vector3(x + T / 2.0, H, 0.6))
	var body := StaticBody3D.new()
	body.collision_layer = 1 | 2
	body.collision_mask = 0
	body.position = Vector3(x, 1.15, 0)
	body.rotation.y = PI / 2.0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.2, 2.3, 0.08)
	cs.shape = sh
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 2.3, 0.08)
	mi.mesh = bm
	mi.material_override = Mats.m("door")
	body.add_child(mi)
	body.set_meta("interact", {"kind": "locked", "msg": msg})
	add_child(body)


func _lamps(cfg: Dictionary) -> void:
	var start: float = cfg.get("start", 2)
	var spacing: float = cfg.get("spacing", 4)
	var every: int = int(cfg.get("light_every", 2))
	var x := start
	var i := 0
	while x <= L - 1.0:
		box(Vector3(x - 0.01, H - 0.35, -0.01), Vector3(x + 0.01, H, 0.01), Mats.m("iron"), false, false)
		var globe := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.14
		sm.height = 0.28
		globe.mesh = sm
		var mat := Mats.emissive(Color(1.0, 0.86, 0.62), 0.0)
		globe.material_override = mat
		globe.position = Vector3(x, H - 0.45, 0)
		globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(globe)
		var light: OmniLight3D = null
		if i % every == 0:
			light = OmniLight3D.new()
			light.position = Vector3(x, H - 0.65, 0)
			light.light_color = Color(1.0, 0.82, 0.58)
			light.light_energy = 0.0
			light.omni_range = 9.0
			light.shadow_enabled = absf(x - station_x) < 9.0
			add_child(light)
		var dist := absf(x - station_x)
		var threshold := 0.25 if dist < 1.0 else (0.5 if dist <= 4.0 else (0.75 if dist <= 12.0 else 1.0))
		lamps.append({"globe": globe, "mat": mat, "light": light, "threshold": threshold, "on": false, "t": 0.0})
		x += spacing
		i += 1


## Moonlight from the north, which only gets in through the windows. The view outside them is
## outside.gd's.
func _night() -> void:
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.66, 0.9)
	moon.light_energy = 1.1
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 45.0
	moon.light_volumetric_fog_energy = 1.2
	moon.rotation_degrees = Vector3(-32, 165, 0)
	add_child(moon)
