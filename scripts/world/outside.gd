extends Node3D
## The view from the windows, built from the site's "outside" data. Far off, a sky shader paints
## the sky, the moon, the bay, its far shores and their lights by compass bearing, so every window
## shows the same view in its own direction. Nearer, the hillside falls away from the north wall
## to the town, with trees and a few houses, placed in the world so each window sees them from
## where it is. Close by each broken window are bare branches swaying just outside, treetops below
## the sill, snow on the outside sill, snowflakes drifting in and a cold light at the hole. Fog is
## cleared outside the long walls, so the view stays crisp behind the room's own haze. Nothing
## here follows presence: the view is the present day, outdoors.

const Mats = preload("res://scripts/world/mats.gd")
const SKY := preload("res://shaders/night_sky.gdshader")
const PROFILE_W := 1440  # a quarter of a degree of bearing per texel
const GRADE := -0.12      # the ground's level around the building, just under the ward floor

var o: Dictionary
var origin: Vector3
var north_wall := -5.7
var drop := 10.0
var slope := 0.05
var to_moon := Vector3.UP
## Branches that sway: [{node, phase, amp, seen: VisibleOnScreenNotifier3D}]
var _sway: Array = []
var _t := 0.0


## moon: the light whose direction shades the hillside. breaks: the broken windows
## (ward_builder.breaks), each of which gets its close-up life.
func build(outside: Dictionary, env: Environment, zone: Dictionary, moon: DirectionalLight3D, breaks: Array) -> void:
	o = outside
	to_moon = moon.global_transform.basis.z
	origin = Data.vec3(o.get("origin", [0, 0, 0]))
	var d: Dictionary = zone["dims"]
	north_wall = -(float(d["corridor_half"]) + float(d["room_depth"]) + float(d["wall"]))
	var g: Dictionary = o.get("ground", {})
	drop = float(g.get("drop", 10.0))
	slope = float(g.get("slope", 0.05))
	_sky(env)
	_ground(float(g.get("reach", 600.0)), float(d["length"]))
	var colors: Dictionary = o.get("colors", {})
	_trees(Color(colors.get("land", "#05070a")))
	_houses(Color(colors.get("land", "#05070a")), Color(colors.get("light", "#ffb560")))
	_clear_fog(float(d["length"]), -north_wall)
	for b in breaks:
		_at_break(b)


# --- far: the sky shader ----------------------------------------------------

func _sky(env: Environment) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SKY
	mat.set_shader_parameter("profile", _profile())
	var c: Dictionary = o.get("colors", {})
	for k in ["zenith", "horizon", "glow", "land", "near_land", "water", "shallows", "glitter", "light"]:
		mat.set_shader_parameter(k, Color(c[k]))
	mat.set_shader_parameter("moon_color", Color(c["moon"]))
	var sky := Sky.new()
	sky.sky_material = mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	# the sky is only to be seen through the windows: it doesn't light the ward or show in it
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.sdfgi_read_sky_light = false


## One row of texels across all bearings: far land top, near shore, town and shore light density.
func _profile() -> ImageTexture:
	var img := Image.create(PROFILE_W, 1, false, Image.FORMAT_RGBAF)
	for i in PROFILE_W:
		var b := -180.0 + (i + 0.5) * 360.0 / PROFILE_W
		img.set_pixel(i, 0, Color(_curve(o["far_land"], b), _curve(o["near_shore"], b),
			_ranges(o.get("town_lights", []), b), _ranges(o.get("shore_lights", []), b)))
	return ImageTexture.create_from_image(img)


## Straight lines through [bearing, value] points, in order of bearing.
static func _curve(pts: Array, b: float) -> float:
	for i in range(1, pts.size()):
		if b <= float(pts[i][0]):
			var t := inverse_lerp(float(pts[i - 1][0]), float(pts[i][0]), b)
			return lerpf(float(pts[i - 1][1]), float(pts[i][1]), t)
	return float(pts[-1][1])


## The value of the [from, to, value] range a bearing falls in, or 0.
static func _ranges(rs: Array, b: float) -> float:
	for r in rs:
		if b >= float(r[0]) and b <= float(r[1]):
			return float(r[2])
	return 0.0


# --- near: the hillside, trees and houses -----------------------------------

## Ground height: level with the building, then past the north wall a bank and the long fall
## toward the bay.
func height(x: float, z: float) -> float:
	var n := north_wall - z
	if n <= 0.0:
		return GRADE
	return GRADE - drop * smoothstep(2.0, 30.0, n) - slope * maxf(0.0, n - 30.0)


func _ground(reach: float, length: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# the hillside north of the building, finer close in where the bank falls away
	_grid(st, origin.x - reach, origin.x + reach, north_wall - reach, north_wall - 0.05, 48, 48, 2.0)
	# level ground on the other three sides, leaving the building's own floor alone
	_grid(st, origin.x - reach, origin.x + reach, -north_wall + 0.05, reach * 0.5, 8, 8, 1.0)
	_grid(st, origin.x - reach, -0.6, north_wall, -north_wall, 4, 1, 1.0)
	_grid(st, length + 0.6, origin.x + reach, north_wall, -north_wall, 4, 1, 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	# shaded by hand from the moon's direction, so the slope reads without taking any light
	var mat := _flat(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## A grid of quads facing up; with bias > 1 the rows bunch toward z1 (the building).
func _grid(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, nx: int, nz: int, bias: float) -> void:
	var c: Dictionary = o.get("colors", {})
	var dark := Color(c.get("near_land", "#030405"))
	var lit := Color(c.get("moonlit", "#1b2433"))
	var haze := Color(c.get("horizon", "#162033"))
	var pts: Array = []
	for j in nz + 1:
		var tz := 1.0 - pow(1.0 - float(j) / nz, bias)
		var row: Array = []
		for i in nx + 1:
			var x := lerpf(x0, x1, float(i) / nx)
			var z := lerpf(z0, z1, tz)
			row.append(Vector3(x, height(x, z), z))
		pts.append(row)
	for j in nz:
		for i in nx:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i + 1]
			var cc: Vector3 = pts[j + 1][i + 1]
			var dd: Vector3 = pts[j + 1][i]
			for v in [a, b, cc, a, cc, dd]:
				var n := Vector3(height(v.x - 1.0, v.z) - height(v.x + 1.0, v.z), 2.0, height(v.x, v.z - 1.0) - height(v.x, v.z + 1.0)).normalized()
				var col := dark.lerp(lit, clampf(n.dot(to_moon), 0.0, 1.0))
				st.set_color(col.lerp(haze, smoothstep(100.0, 700.0, Vector2(v.x - origin.x, v.z - origin.z).length()) * 0.35))
				st.add_vertex(v)


func _at(bearing: float, dist: float) -> Vector3:
	var b := deg_to_rad(bearing)
	var p := origin + Vector3(sin(b), 0.0, -cos(b)) * dist
	p.y = height(p.x, p.z)
	return p


## Bare winter trees, as dark crowns on the hillside and around the grounds.
func _trees(color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1885
	var xf: Array = []
	for band in o.get("trees", []):
		for i in int(band[4]):
			var p := _at(rng.randf_range(band[0], band[1]), rng.randf_range(band[2], band[3]))
			var h := rng.randf_range(9.0, 17.0)
			var r := rng.randf_range(2.5, 5.5)
			xf.append(Transform3D(Basis.from_scale(Vector3(r * 2.0, h * 0.75, r * 2.0)), p + Vector3(0, h * 0.6, 0)))
	var crown := SphereMesh.new()
	crown.radius = 0.5
	crown.height = 1.0
	crown.radial_segments = 8
	crown.rings = 4
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = crown
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _flat(color)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Houses on the slope below the hospital, a few windows still lit, turned toward the viewer.
func _houses(color: Color, glow: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1953
	var wall := _flat(color)
	var lit := _flat(glow)
	for band in o.get("houses", []):
		for i in int(band[4]):
			var p := _at(rng.randf_range(band[0], band[1]), rng.randf_range(band[2], band[3]))
			var w := rng.randf_range(7.0, 11.0)
			var h := rng.randf_range(5.0, 7.0)
			var house := Node3D.new()
			house.position = p
			house.rotation.y = atan2(origin.x - p.x, origin.z - p.z) + rng.randf_range(-0.4, 0.4)
			_box(house, Vector3(w, h, 8.0), Vector3(0, h / 2.0, 0), wall)
			var roof := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(w + 0.6, rng.randf_range(2.5, 4.0), 8.6)
			roof.mesh = pm
			roof.material_override = wall
			roof.position = Vector3(0, h + pm.size.y / 2.0, 0)
			house.add_child(roof)
			for k in rng.randi_range(0, 3):
				_box(house, Vector3(1.0, 1.3, 0.1), Vector3(rng.randf_range(-w / 2.0 + 1.0, w / 2.0 - 1.0), rng.randf_range(1.5, h - 1.5), 4.02), lit)
			add_child(house)


func _box(p: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)


static func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


# --- close: life at a broken window -----------------------------------------

## Built in the window's own frame (+z into the room, y up from the ward floor), seeded by where
## the window is, so each break looks a little different.
func _at_break(b: Dictionary) -> void:
	var frame: Transform3D = b["frame"]
	var hole: Rect2 = b["hole"]
	var z: float = b["z"]
	var sill: float = b["sill"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(frame.origin.x * 100.0)
	var root := Node3D.new()
	root.transform = frame
	add_child(root)
	var seen := VisibleOnScreenNotifier3D.new()
	seen.aabb = AABB(Vector3(-3.0, -1.0, z - 3.0), Vector3(6.0, 5.0, 3.0))
	root.add_child(seen)
	var bark := _bark()
	# one or two bare branches reaching across, close outside the glass
	for i in rng.randi_range(1, 2):
		var side := -1.0 if i == 0 else 1.0
		var arm := Node3D.new()
		arm.position = Vector3(side * rng.randf_range(1.6, 2.4), hole.get_center().y + rng.randf_range(-0.3, 0.6), z - rng.randf_range(0.9, 1.6))
		var dir := Vector3(-side, rng.randf_range(0.15, 0.45), rng.randf_range(-0.15, 0.1)).normalized()
		arm.add_child(_tree(rng, Vector3.ZERO, dir, rng.randf_range(1.5, 2.2), 0.035, 4, bark))
		root.add_child(arm)
		_sway.append({"node": arm, "phase": rng.randf() * TAU, "amp": rng.randf_range(0.015, 0.03), "seen": seen})
	# the tops of a few bare trees just below the sill, standing on the hillside
	for i in 3:
		var at := Vector3(rng.randf_range(-4.0, 4.0), 0.0, z - rng.randf_range(5.0, 12.0))
		var w := frame * at
		at.y = height(w.x, w.z)
		var crown := clampf((sill - 0.3 - at.y) / 5.0, 0.25, 1.0)
		var trunk := maxf(0.0, sill - rng.randf_range(0.3, 1.5) - at.y - 2.2 * crown)
		root.add_child(_tree(rng, at, Vector3(rng.randf_range(-0.1, 0.1), 1.0, rng.randf_range(-0.1, 0.1)).normalized(),
			trunk + 0.8 * crown, 0.14 * crown, 5, bark))
	# snow blown in: along the bar at the bottom of the hole, and across the inside sill below
	_snow(root, Vector3(hole.size.x, 0.007, 0.03), Vector3(hole.get_center().x, hole.position.y + 0.013, z))
	for i in 5:
		var drift := Decal.new()
		drift.texture_albedo = _soft_dot()
		drift.modulate = Color(0.85, 0.89, 0.95)
		drift.size = Vector3(rng.randf_range(0.12, 0.35), 0.06, rng.randf_range(0.06, 0.16))
		drift.position = Vector3(hole.get_center().x + rng.randf_range(-0.28, 0.28), sill + 0.04, rng.randf_range(-0.25, -0.08))
		drift.rotation.y = rng.randf_range(-0.5, 0.5)
		root.add_child(drift)
	root.add_child(_flakes(hole, z))
	# the cold coming in, as a faint blue in the light at the hole
	var cold := OmniLight3D.new()
	cold.position = Vector3(hole.get_center().x, hole.get_center().y, z + 0.3)
	cold.light_color = Color(0.55, 0.68, 0.95)
	cold.light_energy = 0.3
	cold.omni_range = 1.5
	cold.light_volumetric_fog_energy = 0.3
	root.add_child(cold)


func _snow(root: Node3D, size: Vector3, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Mats.m("snow")
	mi.position = at
	root.add_child(mi)


## Snowflakes drifting in through the hole and settling toward the floor.
func _flakes(hole: Rect2, z: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = Vector3(hole.get_center().x, hole.get_center().y, z)
	p.amount = 28
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.fixed_fps = 30
	p.visibility_aabb = AABB(Vector3(-1.5, -2.0, -0.2), Vector3(3.0, 2.6, 3.0))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(hole.size.x / 2.0, hole.size.y / 2.0, 0.02)
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0, -0.08, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.turbulence_noise_scale = 2.5
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.008, 0.008)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _soft_dot()
	mat.albedo_color = Color(0.92, 0.95, 1.0)
	mat.roughness = 1.0
	q.material = mat
	p.draw_pass_1 = q
	return p


## White in the middle fading to nothing at the edge: a snowflake, or a soft drift of snow.
static func _soft_dot() -> GradientTexture2D:
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.gradient = Gradient.new()
	dot.gradient.set_color(0, Color(1, 1, 1, 1))
	dot.gradient.set_color(1, Color(1, 1, 1, 0))
	return dot


## Dark bark, lit only by the moon and the flashlight, not the ward's ambient light.
static func _bark() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.09, 0.08)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_ambient_light = true
	return m


## A bare tree or branch: a tapering limb forking into thinner ones down to the twigs.
func _tree(rng: RandomNumberGenerator, start: Vector3, dir: Vector3, length: float, radius: float, depth: int, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_limb(st, rng, start, dir, length, radius, depth)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _limb(st: SurfaceTool, rng: RandomNumberGenerator, p: Vector3, dir: Vector3, length: float, radius: float, depth: int) -> void:
	var end := p + dir * length
	_tube(st, p, end, radius, radius * 0.65)
	if depth == 0:
		return
	for i in rng.randi_range(2, 3):
		var at := p.lerp(end, rng.randf_range(0.5, 1.0))
		var d := (dir + Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 1.0), rng.randf_range(-1.0, 1.0)) * 0.7).normalized()
		_limb(st, rng, at, d, length * rng.randf_range(0.45, 0.7), radius * 0.6, depth - 1)


## A five-sided tapering tube from a to b.
static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float) -> void:
	var axis := (b - a).normalized()
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	for i in 5:
		var o0 := u * cos(TAU * i / 5.0) + v * sin(TAU * i / 5.0)
		var o1 := u * cos(TAU * (i + 1) / 5.0) + v * sin(TAU * (i + 1) / 5.0)
		for q in [a + o0 * r0, b + o0 * r1, b + o1 * r1, a + o0 * r0, b + o1 * r1, a + o1 * r0]:
			st.add_vertex(q)


func _process(dt: float) -> void:
	_t += dt
	for s in _sway:
		if not s["seen"].is_on_screen():
			continue
		var ph: float = s["phase"]
		var gust := 0.6 + 0.4 * sin(_t * 0.23 + ph) * sin(_t * 0.61 + ph * 2.0)
		var amp: float = s["amp"] * gust
		s["node"].rotation = Vector3(sin(_t * 1.3 + ph) * amp, sin(_t * 0.7 + ph) * amp * 0.5, sin(_t * 0.9 + ph * 1.7) * amp)

## Takes the ward's fog out of the air beyond the long walls (but not below ground, where the
## tunnel keeps its own).
func _clear_fog(length: float, back: float) -> void:
	for s in [-1.0, 1.0]:
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		fv.size = Vector3(length + 120.0, 80.0, 60.0)
		fv.position = Vector3(length / 2.0, 40.0 if s > 0.0 else 0.0, s * (back + 0.05 + 30.0))
		var fm := FogMaterial.new()
		fm.density = -1.0
		fv.material = fm
		add_child(fv)
