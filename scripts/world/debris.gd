extends Node3D
## Seeded clutter: paper, plaster chunks and fallen slabs. As presence rises, decay recedes
## outward from the restored spot. Same layout every visit.

const Mats = preload("res://scripts/world/mats.gd")

var pieces: Array = []   # [{node, dist, scale}]
var origin := Vector2(18, 0)


func scatter(zones: Array, station: Array) -> void:
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
			mi.position = p
			add_child(mi)
			var dist := absf(p.x - origin.x) + absf(p.z - origin.y) * 0.5
			pieces.append({"node": mi, "dist": dist, "gone": false})


## radius: everything closer to the restored spot than this shrinks away.
func recede(radius: float, dt: float) -> void:
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
