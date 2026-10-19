extends RefCounted
## Shared materials, built on first use. Architecture materials use world-space triplanar
## mapping, so geometry needs no UVs and textures line up across separate boxes.
## Walls, floors and ceilings use the decay shader over CC0 PBR sets in assets/textures
## (see CREDITS.md); smaller things use procedural textures or flat colours.

const ProcTex = preload("res://scripts/world/proc_tex.gd")
const DECAY = preload("res://shaders/decay.gdshader")
const TEX := "res://assets/textures/"

static var _cache: Dictionary = {}

## Materials whose colour is tinted by presence (cold and grey -> warm and clean).
const TINTED := ["wall_upper", "wall_lower", "floor", "ceiling"]


static func m(name: String) -> Material:
	if not _cache.has(name):
		_cache[name] = _make(name)
	return _cache[name]


## One map of a downloaded PBR set: "diff" (colour), "nor_gl" (normal) or "arm"
## (ambient occlusion, roughness and metal packed into red, green and blue).
static func tex(set: String, map: String) -> Texture2D:
	return load("%s%s/%s_%s_2k.jpg" % [TEX, set, set, map])


## A PBR set projected in world space; `metres` is the real-world size of one repeat.
static func _pbr(set: String, metres: float, tint := Color.WHITE, rough := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex(set, "diff")
	mat.albedo_color = tint
	mat.normal_enabled = true
	mat.normal_texture = tex(set, "nor_gl")
	var arm := tex(set, "arm")
	mat.ao_enabled = true
	mat.ao_texture = arm
	mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.ao_light_affect = 0.3
	mat.roughness_texture = arm
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.roughness = rough
	mat.metallic_texture = arm
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.metallic = 1.0
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_triplanar_sharpness = 4.0
	mat.uv1_scale = Vector3.ONE / metres
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


## Layer A breaking away to layer B (see shaders/decay.gdshader for the parameters).
static func _decay(a: String, a_metres: float, b: String, b_metres: float, params: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = DECAY
	for layer in [["a", a, a_metres], ["b", b, b_metres]]:
		mat.set_shader_parameter(layer[0] + "_albedo", tex(layer[1], "diff"))
		mat.set_shader_parameter(layer[0] + "_normal", tex(layer[1], "nor_gl"))
		mat.set_shader_parameter(layer[0] + "_arm", tex(layer[1], "arm"))
		mat.set_shader_parameter(layer[0] + "_metres", layer[2])
	mat.set_shader_parameter("mask", ProcTex.cached("decay_mask", func(): return ProcTex.decay_mask(19)))
	for k in params:
		mat.set_shader_parameter(k, params[k])
	return mat


## Weathered wood for doors, frames and furniture: the texture is re-tinted to one wood colour,
## keeping its grain and wear as light and dark, so it reads as worn varnish, not paint.
static func _wood(tint: Color, colour: Color, streaks := 0.0) -> ShaderMaterial:
	return _decay("wood_peeling_paint_weathered", 1.2, "wood_peeling_paint_weathered", 1.2,
		{"a_tint": tint, "a_colorize": colour, "a_colorize_amount": 1.0, "damage": 0.0, "floor_damage": 0.0, "grime": 0.3, "streaks": streaks})


static func _flat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	return mat


static func _make(name: String) -> Material:
	match name:
		# cream paint flaking off plaster, broken back to brick in places, streaked from above
		"wall_upper":
			return _decay("white_rough_plaster", 1.8, "damaged_plaster", 1.85,
				{"a_tint": Color(0.97, 0.92, 0.78), "a_gamma": 0.5, "damage": 0.14, "floor_damage": 0.0, "grime": 0.5, "streaks": 0.45})
		# green wainscot, cracked and peeling, worst near the floor
		"wall_lower":
			return _decay("peeling_painted_wall", 1.8, "damaged_plaster", 1.85,
				{"a_recolor": Color(0.3, 0.46, 0.34), "a_recolor_amount": 1.0, "damage": 0.18, "floor_damage": 0.3, "grime": 0.6, "streaks": 0.25})
		# checkered tiles with patches lifted to the concrete beneath
		"floor":
			return _decay("checkered_pavement_tiles", 2.0, "concrete_floor_worn_001", 3.0,
				{"a_tint": Color(1.05, 1.0, 0.92), "damage": 0.12, "floor_damage": 0.0, "grime": 0.7, "streaks": 0.0, "roughness_scale": 0.85})
		"ceiling":
			return _decay("white_rough_plaster", 1.8, "worn_cracked_plaster", 1.8,
				{"a_tint": Color(0.95, 0.93, 0.86), "a_gamma": 0.5, "b_tint": Color(1.1, 1.08, 1.0), "damage": 0.16, "floor_damage": 0.0, "grime": 0.35, "streaks": 0.0})
		# the underside of the floor above, where the ceiling has come down
		"lath": return _pbr("wood_peeling_paint_weathered", 1.6, Color(0.5, 0.42, 0.34))
		"wood": return _wood(Color(0.9, 0.8, 0.66), Color(0.3, 0.21, 0.14))
		"wood_dark": return _wood(Color(0.62, 0.52, 0.44), Color(0.2, 0.14, 0.09))
		"door": return _wood(Color(0.8, 0.72, 0.64), Color(0.2, 0.15, 0.1), 0.2)
		"rail": return _wood(Color(0.62, 0.56, 0.5), Color(0.18, 0.13, 0.09))
		"brick": return _pbr("white_bricks", 1.5, Color(1.0, 0.88, 0.66))
		"brick_vault":
			# mapped along the curve (UVs in 0.8 m units), darkened toward the floor by vertex colour
			var mat := _pbr("white_bricks", 1.5, Color(1.0, 0.88, 0.66), 0.8)
			mat.uv1_triplanar = false
			mat.uv1_world_triplanar = false
			mat.uv1_scale = Vector3(0.8 / 1.5, 0.8 / 1.5, 1.0)
			mat.vertex_color_use_as_albedo = true
			return mat
		"pavers": return _pbr("worn_brick_floor", 2.0, Color(0.8, 0.75, 0.68), 0.55)
		"concrete": return _pbr("concrete_floor_worn_001", 3.0)
		"grit": return _flat(Color(0.24, 0.21, 0.17), 1.0)
		"pipe": return _pbr("rusty_metal_02", 0.6, Color(0.55, 0.42, 0.33))
		"rust": return _pbr("rusty_metal_02", 0.8, Color(0.85, 0.82, 0.76))
		"iron": return _pbr("rusty_metal_02", 0.8, Color(0.4, 0.4, 0.38))
		"enamel": return _pbr("rusty_metal_02", 1.0, Color(0.95, 0.94, 0.9), 0.7)
		"brass": return _flat(Color(0.71, 0.55, 0.26), 0.32, 0.9)
		"mattress": return _flat(Color(0.44, 0.41, 0.34), 0.95)
		"plaster": return _pbr("white_rough_plaster", 1.0, Color(0.85, 0.83, 0.77))
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
			mat.roughness = 0.45
			return mat
		# grimed and frosted nearly opaque: the view outside is only a glow, lit by the moon behind it
		"glass_frosted":
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.albedo_color = Color(0.36, 0.4, 0.45, 0.9)
			mat.roughness = 0.9
			mat.backlight_enabled = true
			mat.backlight = Color(0.45, 0.53, 0.68)
			return mat
		# a little snow blown onto an outside sill
		"snow": return _flat(Color(0.82, 0.86, 0.92), 0.95)
		# broken glass: thin, dirty, catching the light
		"glass_shard":
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.albedo_color = Color(0.62, 0.68, 0.68, 0.45)
			mat.roughness = 0.12
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
	var c := Color(0.55, 0.57, 0.56).lerp(Color(1, 1, 1), t)
	for name in TINTED:
		if not _cache.has(name):
			continue
		var mat: Material = _cache[name]
		if mat is ShaderMaterial:
			mat.set_shader_parameter("tint", c)
		else:
			mat.albedo_color = c
