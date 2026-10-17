extends Node3D
## Seeded clutter: paper, plaster chunks and fallen slabs. As presence rises, decay recedes
## outward from the restored spot. Same layout every visit.

const Mats = preload("res://scripts/world/mats.gd")

var pieces: Array = []   # [{node, dist, scale}]
var origin := Vector2(18, 0)


## zones: [[x0, x1, z0, z1, count], ...]. floor_y lifts everything onto a lower floor (the tunnel).
func scatter(zones: Array, station: Array, floor_y := 0.0) -> void:
	origin = Vector2(float(station[0]), float(station[1]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1885
	var paper_mesh := QuadMesh.new()
	paper_mesh.size = Vector2(0.22, 0.29)
	for zdef in zones:
		var x0: float = zdef[0]
		var x1: float = zdef[1]
		var z0: float = zdef[2]
		var z1: float = zdef[3]
		var n: int = int(zdef[4])
		for i in n:
			var p := Vector3(rng.randf_range(x0, x1), 0, rng.randf_range(z0, z1))
			var mi := MeshInstance3D.new()
			var k := rng.randf()
			if k < 0.45:
				mi.mesh = paper_mesh
				mi.material_override = Mats.m("paper")
				mi.rotation = Vector3(-PI / 2 + rng.randf_range(-0.12, 0.12), rng.randf_range(0, TAU), 0)
				p.y = 0.004 + rng.randf() * 0.008
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif k < 0.85:
				var s := rng.randf_range(0.04, 0.16)
				var bm := BoxMesh.new()
				bm.size = Vector3(s, s * rng.randf_range(0.3, 0.7), s * rng.randf_range(0.6, 1.4))
				mi.mesh = bm
				mi.material_override = Mats.m("plaster")
				mi.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3))
				p.y = bm.size.y * 0.4
			else:
				var s2 := rng.randf_range(0.4, 0.9)
				var slab := BoxMesh.new()
				slab.size = Vector3(s2, 0.025, s2 * rng.randf_range(0.5, 0.9))
				mi.mesh = slab
				mi.material_override = Mats.m("plaster")
				mi.rotation = Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(0, TAU), rng.randf_range(-0.08, 0.08))
				p.y = 0.015
			p.y += floor_y
			mi.position = p
			add_child(mi)
			var dist := absf(p.x - origin.x) + absf(p.z - origin.y) * 0.5
			pieces.append({"node": mi, "dist": dist, "gone": false})


## Paint flakes in the ward's colours (cream, the green wainscot, bare plaster), plaster crumbs,
## and brick grit for the tunnel; all of it has lain in the dust for decades.
const PAINT := [Color(0.58, 0.55, 0.45), Color(0.62, 0.58, 0.5), Color(0.24, 0.33, 0.26), Color(0.6, 0.58, 0.53)]
const CEILING := [Color(0.62, 0.6, 0.55), Color(0.66, 0.64, 0.58), Color(0.55, 0.52, 0.46)]
const GRIT := [Color(0.5, 0.43, 0.34), Color(0.4, 0.35, 0.29), Color(0.56, 0.52, 0.46)]

## [{mm: MultiMesh, dist: PackedFloat32Array, order: PackedInt32Array, next: int}]
var _drifts: Array = []


## Thousands of paint flakes and plaster crumbs, most of them drifted against the edges of each
## zone (the wall bases), the rest strewn across it. `per_zone` scales each zone's count.
func drifts(zones: Array, palette: Array, per_zone := 1.0, floor_y := 0.0, flakes := true) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1953 + _drifts.size()
	var flake_mesh := PlaneMesh.new()
	flake_mesh.size = Vector2(0.035, 0.028)
	var crumb_mesh := BoxMesh.new()
	crumb_mesh.size = Vector3(0.026, 0.014, 0.02)
	var kinds: Array = [[crumb_mesh, 14.0]]
	if flakes:
		kinds.append([flake_mesh, 18.0])
	for kind in kinds:
		var xf: Array[Transform3D] = []
		var cols: Array[Color] = []
		for zdef in zones:
			var n := int(float(zdef[4]) * kind[1] * per_zone)
			for i in n:
				var p := _drift_point(rng, zdef)
				var s := rng.randf_range(0.5, 1.5)
				var b := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0, TAU), rng.randf_range(-0.4, 0.4))).scaled(Vector3.ONE * s)
				xf.append(Transform3D(b, Vector3(p.x, floor_y + 0.006 * s, p.y)))
				cols.append((palette[rng.randi() % palette.size()] as Color).darkened(rng.randf_range(0.05, 0.45)))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = kind[0]
		mm.instance_count = xf.size()
		var dist := PackedFloat32Array()
		dist.resize(xf.size())
		for i in xf.size():
			mm.set_instance_transform(i, xf[i])
			mm.set_instance_color(i, cols[i])
			dist[i] = absf(xf[i].origin.x - origin.x) + absf(xf[i].origin.z - origin.y) * 0.5
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.9
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		var order := PackedInt32Array()
		order.resize(xf.size())
		for i in xf.size():
			order[i] = i
		var sorted := Array(order)
		sorted.sort_custom(func(a, c): return dist[a] < dist[c])
		_drifts.append({"mm": mm, "dist": dist, "order": PackedInt32Array(sorted), "next": 0})


## Most points hug the zone's wall sides (the optional sixth entry, as in "nswe": n = z0,
## s = z1, w = x0, e = x1), falling off over about 20 cm; the rest are anywhere inside.
static func _drift_point(rng: RandomNumberGenerator, z: Array) -> Vector2:
	var x0: float = z[0]
	var x1: float = z[1]
	var z0: float = z[2]
	var z1: float = z[3]
	var walls: String = z[5] if z.size() > 5 else "nswe"
	var w := x1 - x0
	var d := z1 - z0
	var sides: Array = []
	var total := 0.0
	for s in walls:
		var length := w if s == "n" or s == "s" else d
		sides.append([s, length])
		total += length
	if total <= 0.0 or rng.randf() < 0.15:
		return Vector2(rng.randf_range(x0, x1), rng.randf_range(z0, z1))
	var t := rng.randf() * total
	var off := minf(absf(rng.randfn(0.0, 0.2)), minf(w, d) * 0.5)
	for side in sides:
		if t > side[1]:
			t -= side[1]
			continue
		match side[0]:
			"n": return Vector2(x0 + t, z0 + off)
			"s": return Vector2(x0 + t, z1 - off)
			"w": return Vector2(x0 + off, z0 + t)
			_: return Vector2(x1 - off, z0 + t)
	return Vector2(rng.randf_range(x0, x1), rng.randf_range(z0, z1))


## radius: everything closer to the restored spot than this shrinks away.
func recede(radius: float, dt: float) -> void:
	for d in _drifts:
		var order: PackedInt32Array = d["order"]
		var dist: PackedFloat32Array = d["dist"]
		var k: int = d["next"]
		while k < order.size() and dist[order[k]] <= radius:
			var mm: MultiMesh = d["mm"]
			mm.set_instance_transform(order[k], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			k += 1
		d["next"] = k
	for piece in pieces:
		if piece["gone"] or piece["dist"] > radius:
			continue
		var node: MeshInstance3D = piece["node"]
		var s := node.scale.x - dt * 1.5
		if s <= 0.02:
			node.visible = false
			piece["gone"] = true
		else:
			node.scale = Vector3.ONE * s
