extends Node3D
## The view from the windows, built from the site's "outside" data. Far off, a sky shader paints
## the sky, the moon, the bay, its far shores and their lights by compass bearing, so every window
## shows the same view in its own direction. Nearer, the hillside falls away from the north wall
## to the town, with trees and a few houses, placed in the world so each window sees them from
## where it is. Fog is cleared outside the long walls, so the view stays crisp behind the room's
## own haze. Nothing here follows presence: the view is the present day, outdoors.

const SKY := preload("res://shaders/night_sky.gdshader")
const PROFILE_W := 1440  # a quarter of a degree of bearing per texel
const GRADE := -0.12      # the ground's level around the building, just under the ward floor

var o: Dictionary
var origin: Vector3
var north_wall := -5.7
var drop := 10.0
var slope := 0.05
var to_moon := Vector3.UP


## moon: the light whose direction shades the hillside.
func build(outside: Dictionary, env: Environment, zone: Dictionary, moon: DirectionalLight3D) -> void:
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
