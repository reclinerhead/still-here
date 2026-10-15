extends Node
## Turns the zone's presence value (0..1) into the look and sound of the place:
## fog, ambient light, wall tint, which lamps flicker on, how far decay recedes.

const Mats = preload("res://scripts/world/mats.gd")

const FOG_COLD := Color(0.5, 0.58, 0.72)
const FOG_WARM := Color(0.78, 0.7, 0.58)
const AMB_COLD := Color(0.4, 0.47, 0.6)
const AMB_WARM := Color(1.0, 0.82, 0.6)

var env: Environment
var lamps: Array = []
var debris
var audio


func _process(dt: float) -> void:
	State.presence = move_toward(State.presence, State.presence_target, dt * 0.3)
	var p := State.presence
	env.volumetric_fog_density = lerpf(0.035, 0.012, p)
	env.volumetric_fog_albedo = FOG_COLD.lerp(FOG_WARM, p)
	env.ambient_light_energy = lerpf(0.08, 0.22, p)
	env.ambient_light_color = AMB_COLD.lerp(AMB_WARM, p)
	Mats.set_tint(p)
	for l in lamps:
		if not l["on"] and p >= l["threshold"] - 0.001:
			l["on"] = true
			l["t"] = 0.0
		if not l["on"]:
			continue
		l["t"] += dt
		var flick := 1.0
		if l["t"] < 1.3:
			flick = 0.08 if randf() < 0.45 else 1.0
		l["mat"].emission_energy_multiplier = 3.0 * flick
		if l["light"]:
			l["light"].light_energy = 0.9 * flick
	if debris:
		debris.recede(p * 24.0, dt)
	if audio:
		audio.set_presence(p)
