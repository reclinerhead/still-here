extends Node3D
## Builds a Kirkbride-style ward from the zone layout data: corridor, rooms, alcoves,
## doors, window openings, floor, ceiling, light fixtures and the night outside.

const Mats = preload("res://scripts/world/mats.gd")

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
		_back_wall(x0, x1, zb0, zb1, seg.get("win", ""), s)
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


func _back_wall(x0: float, x1: float, zb0: float, zb1: float, win: String, s: float) -> void:
	var cx := (x0 + x1) / 2.0
	var wins: Array = []
	match win:
		"glass": wins = [[cx, 1.0, 1.25, 2.75, "glass"]]
		"boarded": wins = [[cx, 1.0, 1.25, 2.75, "boarded"]]
		"pair": wins = [[cx - 2.0, 1.0, 1.25, 2.75, "glass"], [cx + 2.0, 1.0, 1.25, 2.75, "boarded"]]
		"bay": wins = [[cx - 2.2, 1.3, 0.9, 3.0, "glass"], [cx, 1.3, 0.9, 3.0, "glass"], [cx + 2.2, 1.3, 0.9, 3.0, "glass"]]
	if wins.is_empty():
		wall(Vector3(x0, 0, zb0), Vector3(x1, H, zb1))
		return
	var sill: float = wins[0][2]
	var top: float = wins[0][3]
	wall(Vector3(x0, 0, zb0), Vector3(x1, sill, zb1))
	wall(Vector3(x0, top, zb0), Vector3(x1, H, zb1))
	var cur := x0
	for w in wins:
		var a: float = w[0] - w[1] / 2.0
		var b: float = w[0] + w[1] / 2.0
		wall(Vector3(cur, sill, zb0), Vector3(a, top, zb1))
		_window(a, b, sill, top, zb0, zb1, w[4], s)
		cur = b
	wall(Vector3(cur, sill, zb0), Vector3(x1, top, zb1))


func _window(a: float, b: float, sill: float, top: float, zb0: float, zb1: float, kind: String, s: float) -> void:
	var zc := (zb0 + zb1) / 2.0
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


func _floor_ceiling() -> void:
	var zmax := CH + D + T
	# the floor is cut into rectangles around any holes; triplanar mapping keeps the tiles lined up
	var rects: Array = [[-0.6, L + 0.6, -zmax, zmax]]
	for hole in floor_holes:
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
	for r in rects:
		box(Vector3(r[0], -0.3, r[2]), Vector3(r[1], 0, r[3]), Mats.m("floor"))
	box(Vector3(-0.6, H, -zmax), Vector3(L + 0.6, H + 0.3, zmax), Mats.m("ceiling"))


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


## The night outside: a dim sky behind the windows and moonlight that only gets in through them.
func _night() -> void:
	var far := CH + D + T + 5.0
	# the sky stops short of the ground so the tunnel can run underneath it
	for s in [-1.0, 1.0]:
		box(Vector3(-6, -0.6, s * far), Vector3(L + 6, H + 8, s * (far + 0.2)), Mats.m("night"), false, false)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.66, 0.9)
	moon.light_energy = 1.1
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 45.0
	moon.light_volumetric_fog_energy = 3.0
	moon.rotation_degrees = Vector3(-32, 165, 0)
	add_child(moon)
