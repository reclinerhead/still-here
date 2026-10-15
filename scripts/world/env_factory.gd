extends RefCounted
## The ward's starting atmosphere. PresenceController changes fog and ambient light from here.

static func make() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.006, 0.008, 0.01)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.47, 0.6)
	e.ambient_light_energy = 0.08
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.5
	e.ssao_enabled = true
	e.ssao_intensity = 1.6
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_bloom = 0.04
	e.sdfgi_enabled = true
	e.sdfgi_use_occlusion = true
	e.sdfgi_energy = 0.8
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.035
	e.volumetric_fog_albedo = Color(0.5, 0.58, 0.72)
	e.volumetric_fog_length = 40.0
	e.volumetric_fog_anisotropy = 0.45
	return e
