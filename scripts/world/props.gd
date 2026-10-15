extends RefCounted
## Builds props from primitives. Placeholder art: the plan is to replace these with
## Blender-scripted or CC0 models later, keeping the same model names.

const Mats = preload("res://scripts/world/mats.gd")


static func build(model: String) -> Node3D:
	var root := Node3D.new()
	root.name = model
	match model:
		"bed": _bed(root)
		"chair": _chair(root)
		"table": _table(root)
		"counter": _counter(root)
		"shelves": _shelves(root)
		"piano": _piano(root)
		"bench": _bench(root)
		"radiator": _radiator(root)
		"dumbwaiter": _dumbwaiter(root)
		"desk_lamp": _desk_lamp(root)
		"ledger": _ledger(root)
		"call_bell": _call_bell(root)
		"makers_plate": _b(root, Vector3(0.14, 0.05, 0.006), Vector3.ZERO, Mats.m("brass"))
		_: push_error("Unknown prop model: " + model)
	return root


# --- primitives ------------------------------------------------------------

static func _b(p: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


static func _cyl(p: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, segs := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


static func _sph(p: Node3D, r: float, pos: Vector3, mat: Material, hemi := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r if hemi else r * 2.0
	sm.is_hemisphere = hemi
	sm.radial_segments = 20
	sm.rings = 10
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	p.add_child(mi)
	return mi


## Adds a solid collision box (world layer) to a prop.
static func collide(p: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)
	p.add_child(body)


# --- furniture -------------------------------------------------------------

static func _bed(r: Node3D) -> void:
	var rust := Mats.m("rust")
	_b(r, Vector3(0.9, 0.05, 1.95), Vector3(0, 0.42, 0), rust)
	_b(r, Vector3(0.82, 0.14, 1.8), Vector3(0, 0.52, 0.05), Mats.m("mattress"), Vector3(0.0, 0.0, 0.02))
	for x in [-0.43, 0.43]:
		for z in [-0.95, 0.95]:
			_cyl(r, 0.02, 0.02, 0.45 if z > 0 else 1.05, Vector3(x, (0.45 if z > 0 else 1.05) / 2.0, z), rust)
	_cyl(r, 0.015, 0.015, 0.86, Vector3(0, 1.02, -0.95), rust, Vector3(0, 0, PI / 2))
	_cyl(r, 0.015, 0.015, 0.86, Vector3(0, 0.75, -0.95), rust, Vector3(0, 0, PI / 2))
	for i in 5:
		_cyl(r, 0.01, 0.01, 0.27, Vector3(-0.3 + i * 0.15, 0.885, -0.95), rust)
	collide(r, Vector3(0.95, 0.6, 2.0), Vector3(0, 0.3, 0))


static func _chair(r: Node3D) -> void:
	var w := Mats.m("wood")
	_b(r, Vector3(0.44, 0.05, 0.42), Vector3(0, 0.46, 0), w)
	for x in [-0.19, 0.19]:
		for z in [-0.18, 0.18]:
			_b(r, Vector3(0.04, 0.46, 0.04), Vector3(x, 0.23, z), w)
		_b(r, Vector3(0.04, 0.5, 0.04), Vector3(x, 0.73, 0.19), w)
	for y in [0.62, 0.78, 0.94]:
		_b(r, Vector3(0.38, 0.06, 0.02), Vector3(0, y, 0.19), w)


static func _table(r: Node3D) -> void:
	var w := Mats.m("wood")
	_b(r, Vector3(4.2, 0.06, 0.9), Vector3(0, 0.76, 0), w)
	_b(r, Vector3(4.0, 0.1, 0.75), Vector3(0, 0.68, 0), w)
	for x in [-2.0, 2.0]:
		for z in [-0.38, 0.38]:
			_b(r, Vector3(0.07, 0.73, 0.07), Vector3(x, 0.365, z), w)
	collide(r, Vector3(4.2, 0.8, 0.9), Vector3(0, 0.4, 0))


static func _counter(r: Node3D) -> void:
	var w := Mats.m("wood_dark")
	_b(r, Vector3(4.4, 1.0, 0.5), Vector3(0, 0.5, 0), w)
	_b(r, Vector3(4.6, 0.06, 0.66), Vector3(0, 1.08, -0.02), Mats.m("wood"))
	_b(r, Vector3(4.42, 0.1, 0.46), Vector3(0, 0.05, -0.03), Mats.m("black"))
	for i in 6:
		_b(r, Vector3(0.6, 0.7, 0.01), Vector3(-1.85 + i * 0.74, 0.5, -0.255), Mats.m("wood"))
	collide(r, Vector3(4.4, 1.1, 0.5), Vector3(0, 0.55, 0))


static func _shelves(r: Node3D) -> void:
	var w := Mats.m("wood_dark")
	_b(r, Vector3(3.6, 2.2, 0.03), Vector3(0, 1.1, 0.185), w)
	for x in [-1.8, 1.8]:
		_b(r, Vector3(0.04, 2.2, 0.4), Vector3(x, 1.1, 0), w)
	for y in [0.1, 0.65, 1.2, 1.75, 2.18]:
		_b(r, Vector3(3.56, 0.03, 0.38), Vector3(0, y, 0), Mats.m("wood"))
	# a few binders left behind
	var rng := RandomNumberGenerator.new()
	rng.seed = 50
	for i in 7:
		_b(r, Vector3(0.05, 0.3, 0.24), Vector3(rng.randf_range(-1.6, 1.6), 0.82, 0.02), Mats.m("book_cover"), Vector3(0, 0, rng.randf_range(-0.4, 0.4)))
	collide(r, Vector3(3.6, 2.2, 0.4), Vector3(0, 1.1, 0))


static func _piano(r: Node3D) -> void:
	var w := Mats.m("wood_dark")
	_b(r, Vector3(1.55, 1.3, 0.55), Vector3(0, 0.65, 0), w)
	_b(r, Vector3(1.62, 0.04, 0.62), Vector3(0, 1.32, 0), w)
	_b(r, Vector3(1.5, 0.08, 0.3), Vector3(0, 0.78, 0.4), w)
	_b(r, Vector3(1.38, 0.02, 0.14), Vector3(0, 0.83, 0.45), Mats.m("keys"))
	for i in 20:
		if i % 7 == 2 or i % 7 == 6:
			continue
		_b(r, Vector3(0.025, 0.02, 0.08), Vector3(-0.66 + i * 0.07, 0.85, 0.42), Mats.m("black"))
	_b(r, Vector3(1.48, 0.25, 0.03), Vector3(0, 0.98, 0.285), w, Vector3(-0.15, 0, 0))
	for x in [-0.65, 0.65]:
		_cyl(r, 0.04, 0.03, 0.74, Vector3(x, 0.37, 0.5), w)
	collide(r, Vector3(1.6, 1.35, 0.9), Vector3(0, 0.67, 0.15))


static func _bench(r: Node3D) -> void:
	var w := Mats.m("wood")
	_b(r, Vector3(2.4, 0.06, 0.45), Vector3(0, 0.45, 0), w)
	for x in [-1.1, 1.1]:
		_b(r, Vector3(0.06, 0.42, 0.4), Vector3(x, 0.21, 0), w)
	collide(r, Vector3(2.4, 0.48, 0.45), Vector3(0, 0.24, 0))


static func _radiator(r: Node3D) -> void:
	var iron := Mats.m("iron")
	for i in 9:
		_cyl(r, 0.035, 0.035, 0.8, Vector3(-0.36 + i * 0.09, 0.48, 0), iron)
	_b(r, Vector3(0.82, 0.06, 0.1), Vector3(0, 0.1, 0), iron)
	_b(r, Vector3(0.82, 0.06, 0.1), Vector3(0, 0.86, 0), iron)
	collide(r, Vector3(0.85, 0.9, 0.2), Vector3(0, 0.45, 0))


static func _dumbwaiter(r: Node3D) -> void:
	# opening in the wall: dark recess, wood frame, a little shelf
	_b(r, Vector3(0.72, 0.82, 0.02), Vector3(0, 1.3, -0.005), Mats.m("recess"))
	var w := Mats.m("wood")
	_b(r, Vector3(0.9, 0.08, 0.1), Vector3(0, 1.75, -0.04), w)
	_b(r, Vector3(0.08, 0.9, 0.1), Vector3(-0.41, 1.3, -0.04), w)
	_b(r, Vector3(0.08, 0.9, 0.1), Vector3(0.41, 1.3, -0.04), w)
	_b(r, Vector3(0.9, 0.04, 0.34), Vector3(0, 0.88, -0.16), w)


# --- restorable items ------------------------------------------------------

static func _desk_lamp(r: Node3D) -> void:
	_cyl(r, 0.1, 0.11, 0.03, Vector3(0, 0.015, 0), Mats.m("green_enamel"))
	_cyl(r, 0.012, 0.012, 0.36, Vector3(0, 0.2, 0), Mats.m("brass"))
	var shade := _cyl(r, 0.035, 0.13, 0.16, Vector3(0, 0.4, 0.05), Mats.m("green_enamel"), Vector3(0.45, 0, 0), 20)
	shade.name = "Shade"
	var bulb := _sph(r, 0.035, Vector3(0, 0.36, 0.07), Mats.emissive(Color(1.0, 0.85, 0.6), 0.0))
	bulb.name = "Bulb"
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0, 0.33, 0.12)
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 0.0
	light.omni_range = 6.0
	light.shadow_enabled = true
	r.add_child(light)


static func _ledger(r: Node3D) -> void:
	_b(r, Vector3(0.32, 0.05, 0.24), Vector3(0, 0.025, 0), Mats.m("book_cover"))
	_b(r, Vector3(0.3, 0.04, 0.235), Vector3(0.012, 0.025, 0), Mats.m("pages"))
	_b(r, Vector3(0.12, 0.002, 0.07), Vector3(0, 0.051, 0), Mats.m("pages"))


static func _call_bell(r: Node3D) -> void:
	_cyl(r, 0.07, 0.075, 0.02, Vector3(0, 0.01, 0), Mats.m("black"))
	_sph(r, 0.06, Vector3(0, 0.02, 0), Mats.m("brass"), true)
	_cyl(r, 0.008, 0.008, 0.03, Vector3(0, 0.09, 0), Mats.m("brass"))
