extends Node3D
## Builds the stairwell down from the old bath room and the brick service tunnel under the
## grounds, from the zone's "stair" and "tunnel" data: shaft and steps, the barrel vault, wet
## pavers and puddles, pipes, bare bulbs, the stencil, and the collapse at the far end.
## The tunnel keeps its own look; nothing here responds to presence.

const Mats = preload("res://scripts/world/mats.gd")
const WardBuilder = preload("res://scripts/world/ward_builder.gd")
const Debris = preload("res://scripts/world/debris.gd")
const ProcTex = preload("res://scripts/world/proc_tex.gd")

const SHAFT_WALL := 0.2

## [{mat: StandardMaterial3D, light: OmniLight3D|null, flicker: bool}]
var bulbs: Array = []
var _rng := RandomNumberGenerator.new()


func build(z: Dictionary) -> void:
	if not z.has("stair") or not z.has("tunnel"):
		return
	_rng.seed = 1953
	var t: Dictionary = z["tunnel"]
	_stairs(z["stair"], t, z["dims"])
	_vault(t)
	_fittings(t)
	_collapse(t)
	var debris := Debris.new()
	add_child(debris)
	debris.scatter(t.get("debris", []), z.get("station", [18, 0]), float(t["floor"]))


func _box(a: Vector3, b: Vector3, mat: Material, solid := true, shadow := true) -> MeshInstance3D:
	return WardBuilder.make_box(self, a, b, mat, solid, shadow)


## An invisible wall (world layer), for edges the meshes don't close off by themselves.
func _collider(a: Vector3, b: Vector3, rot_x := 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = (b - a).abs()
	cs.shape = sh
	body.add_child(cs)
	body.position = (a + b) * 0.5
	body.rotation.x = rot_x
	add_child(body)


# --- stairs ----------------------------------------------------------------

func _stairs(st: Dictionary, t: Dictionary, dims: Dictionary) -> void:
	var x0: float = st["x0"]
	var x1: float = st["x1"]
	var z0: float = st["z0"]
	var z1: float = st["z1"]
	var bottom: float = st["bottom"]
	var n := int(st.get("steps", 16))
	var back: float = float(dims["corridor_half"]) + float(dims["room_depth"])
	var outside: float = back + float(dims["wall"])
	var brick := Mats.m("brick")
	var w := SHAFT_WALL
	# brick shaft walls either side; their tops are flush with the room floor
	_box(Vector3(x0, bottom - 0.2, z0), Vector3(x0 + w, 0, z1), brick)
	_box(Vector3(x1 - w, bottom - 0.2, z0), Vector3(x1, 0, z1), brick)
	# a thin roof where the shaft runs out under the grounds, and the header over the tunnel mouth
	_box(Vector3(x0, -0.1, outside), Vector3(x1, 0.0, z1), brick)
	var crown: float = float(t["axis_y"]) + float(t["radius"])
	_box(Vector3(x0 + w, crown - 0.2, z1 - 0.2), Vector3(x1 - w, -0.1, z1), brick)
	# steps, solid down to the tunnel floor; the last one is the floor itself
	var run := (z1 - z0) / n
	var rise := -bottom / n
	var concrete := Mats.m("concrete")
	for i in n - 1:
		var top := -(i + 1) * rise
		_box(Vector3(x0 + w, bottom - 0.2, z0 + run * i), Vector3(x1 - w, top, z0 + run * (i + 1)), concrete, false)
	# walking surface: one smooth ramp along the step nosings, so the player glides down
	var slope := atan2(-bottom, z1 - z0)
	var length := Vector2(z1 - z0, bottom).length()
	var mid := Vector3((x0 + x1) / 2.0, bottom / 2.0, (z0 + z1) / 2.0)
	var normal := Vector3(0, cos(slope), sin(slope))
	var c := mid - normal * 0.1
	_collider(c - Vector3((x1 - x0) / 2.0 - w, 0.1, length / 2.0), c + Vector3((x1 - x0) / 2.0 - w, 0.1, length / 2.0), slope)
	# rusty iron railings along both sides of the opening
	var rust := Mats.m("rust")
	for rx in [x0 + w / 2.0, x1 - w / 2.0]:
		_box(Vector3(rx - 0.025, 0.93, z0), Vector3(rx + 0.025, 0.98, back), rust, false)
		for pz in [z0 + 0.05, (z0 + back) / 2.0, back - 0.05]:
			_box(Vector3(rx - 0.02, 0.0, pz - 0.02), Vector3(rx + 0.02, 0.95, pz + 0.02), rust, false)
		_collider(Vector3(rx - 0.03, 0.0, z0), Vector3(rx + 0.03, 1.0, back))


# --- the vault ---------------------------------------------------------------

func _vault(t: Dictionary) -> void:
	var cx: float = t["x"]
	var fy: float = t["floor"]
	var r: float = t["radius"]
	var ay: float = t["axis_y"]
	var z0: float = t["z0"]
	var z1: float = t["z1"]
	# the curve runs from where it meets the floor on the east side, over the top, to the west side
	var a0 := asin((fy - ay) / r)
	var a1 := PI - a0
	var segs := 28
	var rows := int(ceil((z1 - z0) / 0.5))
	var damp := FastNoiseLite.new()
	damp.seed = 7
	damp.frequency = 0.15
	var verts: Array = []
	for j in rows + 1:
		var zz := z0 + (z1 - z0) * j / rows
		var row: Array = []
		for i in segs + 1:
			var a := a0 + (a1 - a0) * i / segs
			var p := Vector3(cx + r * cos(a), ay + r * sin(a), zz)
			# darker and wetter toward the floor, with damp patches along the length
			var h := clampf((p.y - fy) / (ay + r - fy), 0.0, 1.0)
			var k := clampf(0.3 + h * 0.85, 0.28, 1.0) * (0.82 + 0.18 * _rng.randf())
			k *= 1.0 - 0.4 * clampf(damp.get_noise_2d(a * 3.0, zz) + 0.15, 0.0, 1.0)
			row.append({"p": p, "n": Vector3(-cos(a), -sin(a), 0), "uv": Vector2(zz / 0.8, r * (a - a0) / 0.8), "c": Color(k, k * 0.96, k * 0.88)})
		verts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rows:
		for i in segs:
			# clockwise as seen from inside the tunnel
			for v in [verts[j][i], verts[j][i + 1], verts[j + 1][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]]:
				st.set_normal(v["n"])
				st.set_uv(v["uv"])
				st.set_color(v["c"])
				st.add_vertex(v["p"])
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Mats.m("brick_vault")
	# double-sided shadows keep the moon out: from above, the light only sees the vault's back
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	add_child(mi)
	# floor of wet pavers, and walls to keep the player off the curve
	var half := sqrt(r * r - (fy - ay) * (fy - ay))
	_box(Vector3(cx - half - 0.1, fy - 0.3, z0 - 0.2), Vector3(cx + half + 0.1, fy, z1), Mats.m("pavers"))
	_collider(Vector3(cx - half - 0.6, fy, z0), Vector3(cx - half + 0.02, ay + r, z1))
	_collider(Vector3(cx + half - 0.02, fy, z0), Vector3(cx + half + 0.6, ay + r, z1))
	# the north end, closed around the stair opening
	var brick := Mats.m("brick")
	var sx0 := cx - 0.7
	var sx1 := cx + 0.7
	_box(Vector3(cx - r - 0.1, fy - 0.2, z0 - 0.2), Vector3(sx0, ay + r + 0.1, z0), brick)
	_box(Vector3(sx1, fy - 0.2, z0 - 0.2), Vector3(cx + r + 0.1, ay + r + 0.1, z0), brick)
	# puddles: decals that darken the pavers and make them glossy and flat, so they reflect
	var wet := ProcTex.cached("puddle", func(): return ProcTex.puddle(5))
	var glossy := ProcTex.cached("decal_orm_wet", func(): return ProcTex.flat(Color(1.0, 0.04, 0.0)))
	var level := ProcTex.cached("decal_normal_flat", func(): return ProcTex.flat(Color(0.5, 0.5, 1.0)))
	for i in int(t.get("puddles", 9)):
		var d := Decal.new()
		d.texture_albedo = wet
		d.texture_orm = glossy
		d.texture_normal = level
		d.albedo_mix = 0.8
		d.size = Vector3(_rng.randf_range(0.5, 1.2), 0.3, _rng.randf_range(1.2, 3.6))
		d.position = Vector3(cx + _rng.randf_range(-0.45, 0.45), fy + 0.05, _rng.randf_range(z0 + 2.0, z1 - 4.0))
		d.rotation.y = _rng.randf_range(-0.3, 0.3)
		add_child(d)


# --- pipes, bulbs, stencil ---------------------------------------------------

func _pipe(radius: float, x: float, y: float, z0: float, z1: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = z1 - z0
	cyl.radial_segments = 10
	mi.mesh = cyl
	mi.material_override = mat
	mi.rotation.x = PI / 2.0
	mi.position = Vector3(x, y, (z0 + z1) / 2.0)
	mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	add_child(mi)


func _fittings(t: Dictionary) -> void:
	var cx: float = t["x"]
	var r: float = t["radius"]
	var ay: float = t["axis_y"]
	var z0: float = float(t["z0"]) + 0.2
	var z1: float = float(t["z1"]) - 0.2
	var pipe := Mats.m("pipe")
	var rust := Mats.m("rust")
	_pipe(0.07, cx - 1.18, ay + 0.62, z0, z1, pipe)
	_pipe(0.11, cx + 1.15, ay - 0.55, z0, z1, pipe)
	_pipe(0.025, cx + 1.28, ay + 0.5, z0, z1, Mats.m("black"))
	_pipe(0.02, cx, ay + r - 0.04, z0, z1, Mats.m("black"))
	var z := z0 + 1.3
	while z < z1 - 1.0:
		_box(Vector3(cx - 1.33, ay + 0.6, z - 0.025), Vector3(cx - 1.11, ay + 0.64, z + 0.025), rust, false)
		_box(Vector3(cx + 1.04, ay - 0.57, z - 0.03), Vector3(cx + 1.36, ay - 0.53, z + 0.03), rust, false)
		z += 3.0
	# bare bulbs down the centre line; every few casts light, one flickers, the far ones fade out
	var top := ay + r - 0.05
	var flicker: Array = t.get("flicker", [])
	var every := int(t.get("light_every", 2))
	var list: Array = t.get("bulbs", [])
	for i in list.size():
		var bz: float = list[i]
		_box(Vector3(cx - 0.006, top - 0.2, bz - 0.006), Vector3(cx + 0.006, top + 0.06, bz + 0.006), Mats.m("iron"), false, false)
		var glass := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.055
		sm.height = 0.11
		glass.mesh = sm
		var mat := Mats.emissive(Color(1.0, 0.88, 0.66), 4.0)
		glass.material_override = mat
		glass.position = Vector3(cx, top - 0.25, bz)
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glass)
		var light: OmniLight3D = null
		if i % every == 0:
			light = OmniLight3D.new()
			light.position = Vector3(cx, top - 0.36, bz)
			light.light_color = Color(1.0, 0.82, 0.58)
			light.light_energy = 0.7
			light.omni_range = 7.5
			light.omni_attenuation = 1.6
			light.shadow_enabled = true
			light.light_volumetric_fog_energy = 1.5
			add_child(light)
		bulbs.append({"mat": mat, "light": light, "flicker": flicker.has(bz) or flicker.has(int(bz)), "base": 0.7})
	_stencil(t.get("stencil", {}))


func _stencil(s: Dictionary) -> void:
	if s.is_empty():
		return
	var label := Label3D.new()
	label.text = s["text"]
	var font := FontFile.new()
	if font.load_dynamic_font("res://assets/fonts/SpecialElite-Regular.ttf") == OK:
		label.font = font
	label.font_size = 30
	label.pixel_size = 0.005
	label.outline_size = 0
	label.modulate = Color(0.7, 0.68, 0.6, 0.7)
	label.shaded = true
	label.double_sided = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = Data.vec3(s["pos"])
	label.rotation.y = PI / 2.0
	add_child(label)


# --- the collapse --------------------------------------------------------------

func _collapse(t: Dictionary) -> void:
	var cx: float = t["x"]
	var fy: float = t["floor"]
	var r: float = t["radius"]
	var ay: float = t["axis_y"]
	var z1: float = t["z1"]
	var cz: float = t.get("collapse_z", z1 - 2.5)
	var brick := Mats.m("brick")
	# the bricked-up end wall
	_box(Vector3(cx - r - 0.1, fy - 0.2, z1), Vector3(cx + r + 0.1, ay + r + 0.1, z1 + 0.25), brick)
	# a heap of fallen brick and plaster: a low mound of grit, buried under chunks
	var mound := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	mound.mesh = sm
	mound.material_override = Mats.m("grit")
	mound.scale = Vector3(r * 0.9, 1.0, (z1 - cz) * 0.85)
	mound.position = Vector3(cx, fy - 0.3, z1)
	mound.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	add_child(mound)
	for i in 110:
		var s := _rng.randf_range(0.1, 0.45)
		var zz := _rng.randf_range(cz, z1 - 0.15)
		var rise := (zz - cz) / (z1 - cz)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(s, s * _rng.randf_range(0.35, 0.7), s * _rng.randf_range(0.6, 1.3))
		mi.mesh = bm
		mi.material_override = brick if i % 4 != 0 else Mats.m("plaster")
		var spread := (1.0 - rise * 0.25) * 0.95
		mi.position = Vector3(cx + _rng.randf_range(-spread, spread), fy + s * 0.25 + rise * rise * 1.5 + _rng.randf_range(0.0, 0.2), zz)
		mi.rotation = Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0, TAU), _rng.randf_range(-0.5, 0.5))
		mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		add_child(mi)
	_collider(Vector3(cx - r, fy, cz - 0.3), Vector3(cx + r, ay + r, z1))


func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for b in bulbs:
		if not b["flicker"]:
			continue
		var on := 0.15 if sin(now * 17.0) > 0.6 and randf() < 0.5 else 1.0
		if randf() < 0.01:
			on = 0.0
		b["mat"].emission_energy_multiplier = 4.0 * on
		if b["light"]:
			b["light"].light_energy = b["base"] * on
