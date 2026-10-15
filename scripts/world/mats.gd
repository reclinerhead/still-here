extends RefCounted
## Shared materials, built on first use. Architecture materials use world-space triplanar
## mapping, so geometry needs no UVs and textures line up across separate boxes.

const ProcTex = preload("res://scripts/world/proc_tex.gd")

static var _cache: Dictionary = {}

## Materials whose colour is tinted by presence (cold and grey -> warm and clean).
const TINTED := ["wall_upper", "wall_lower", "floor", "ceiling"]

## Pale yellow-tan Markham brick, and the darker, muddier pavers of the tunnel floor.
const MARKHAM := [Color(0.62, 0.56, 0.43), Color(0.56, 0.5, 0.38), Color(0.66, 0.6, 0.47), Color(0.5, 0.45, 0.34), Color(0.6, 0.55, 0.43), Color(0.46, 0.41, 0.31)]
const PAVERS := [Color(0.34, 0.31, 0.26), Color(0.29, 0.26, 0.22), Color(0.38, 0.34, 0.28), Color(0.25, 0.23, 0.19)]


static func m(name: String) -> StandardMaterial3D:
	if not _cache.has(name):
		_cache[name] = _make(name)
	return _cache[name]


static func _tri(albedo: Texture2D, normal: Texture2D, rough: float, scale: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = albedo
	mat.roughness = rough
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if normal:
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = 0.8
	return mat


static func _flat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	return mat


static func _make(name: String) -> StandardMaterial3D:
	match name:
		"wall_upper":
			var gen := func(): return ProcTex.paint(Color(0.78, 0.74, 0.61), 11, true, true)
			return _tri(ProcTex.cached("wall_upper", gen), ProcTex.normal_from("wall_upper", gen, 3.0), 0.92, 0.5)
		"wall_lower":
			var gen := func(): return ProcTex.paint(Color(0.42, 0.52, 0.43), 23, false, true)
			return _tri(ProcTex.cached("wall_lower", gen), ProcTex.normal_from("wall_lower", gen, 3.0), 0.7, 0.5)
		"floor":
			var gen := func(): return ProcTex.floor_tiles(7)
			return _tri(ProcTex.cached("floor", gen), ProcTex.normal_from("floor", gen, 2.0), 0.75, 0.5)
		"ceiling":
			var gen := func(): return ProcTex.ceiling(31)
			return _tri(ProcTex.cached("ceiling", gen), null, 0.95, 0.4)
		"wood":
			var gen := func(): return ProcTex.wood(Color(0.42, 0.3, 0.2), 5)
			return _tri(ProcTex.cached("wood", gen), null, 0.7, 1.4)
		"wood_dark":
			var gen := func(): return ProcTex.wood(Color(0.27, 0.18, 0.12), 9)
			return _tri(ProcTex.cached("wood_dark", gen), null, 0.55, 1.4)
		"door":
			var gen := func(): return ProcTex.wood(Color(0.33, 0.25, 0.17), 17)
			return _tri(ProcTex.cached("door", gen), null, 0.75, 1.0)
		"brick":
			var gen := func(): return ProcTex.brick(41, MARKHAM, Color(0.2, 0.18, 0.15))
			return _tri(ProcTex.cached("brick", gen), ProcTex.normal_from("brick", gen, 4.0), 0.78, 1.25)
		"brick_vault":
			# mapped along the curve (UVs in 0.8 m units), darkened toward the floor by vertex colour
			var gen := func(): return ProcTex.brick(41, MARKHAM, Color(0.2, 0.18, 0.15))
			var mat := _tri(ProcTex.cached("brick", gen), ProcTex.normal_from("brick", gen, 4.0), 0.55, 1.0)
			mat.uv1_triplanar = false
			mat.uv1_world_triplanar = false
			mat.vertex_color_use_as_albedo = true
			return mat
		"pavers":
			var gen := func(): return ProcTex.brick(63, PAVERS, Color(0.13, 0.12, 0.1), 8, 4, 256)
			return _tri(ProcTex.cached("pavers", gen), ProcTex.normal_from("pavers", gen, 3.0), 0.4, 1.25)
		"concrete": return _flat(Color(0.38, 0.36, 0.31), 0.9)
		"grit": return _flat(Color(0.24, 0.21, 0.17), 1.0)
		"pipe": return _flat(Color(0.3, 0.22, 0.16), 0.6, 0.45)
		"rail": return _flat(Color(0.25, 0.2, 0.15), 0.6)
		"rust": return _flat(Color(0.33, 0.21, 0.14), 0.85, 0.3)
		"iron": return _flat(Color(0.17, 0.18, 0.17), 0.6, 0.6)
		"enamel": return _flat(Color(0.72, 0.7, 0.64), 0.35)
		"brass": return _flat(Color(0.71, 0.55, 0.26), 0.32, 0.9)
		"mattress": return _flat(Color(0.44, 0.41, 0.34), 0.95)
		"plaster": return _flat(Color(0.7, 0.67, 0.58), 0.95)
		"green_enamel": return _flat(Color(0.16, 0.34, 0.21), 0.35, 0.2)
		"book_cover": return _flat(Color(0.36, 0.13, 0.1), 0.7)
		"pages": return _flat(Color(0.75, 0.71, 0.6), 0.9)
		"keys": return _flat(Color(0.82, 0.79, 0.7), 0.4)
		"black": return _flat(Color(0.03, 0.03, 0.03), 0.6)
		"recess": return _flat(Color(0.015, 0.015, 0.015), 1.0)
		"paper":
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = ProcTex.cached("paper", func(): return ProcTex.paper())
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.roughness = 0.95
			return mat
		"glass":
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.55, 0.65, 0.75, 0.12)
			# old, grimy glass: the flashlight shows in it as a soft smear, not a mirror-bright spot
			mat.roughness = 0.3
			mat.metallic = 0.3
			return mat
		"night":
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.008, 0.013, 0.024)
			return mat
	push_error("Unknown material: " + name)
	return _flat(Color.MAGENTA)


## A fresh emissive material (each light fixture needs its own so it can switch independently).
static func emissive(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.6)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


static func set_tint(t: float) -> void:
	var cold := Color(0.55, 0.57, 0.56)
	var warm := Color(1, 1, 1)
	for name in TINTED:
		if _cache.has(name):
			_cache[name].albedo_color = cold.lerp(warm, t)
