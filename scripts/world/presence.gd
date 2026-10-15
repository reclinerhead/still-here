extends Node
## Turns the zone's presence value (0..1) into the look and sound of the place:
## fog, ambient light, wall tint, which lamps flicker on, how far decay recedes.
## Underground, the tunnel's own air takes over, whatever the ward's presence.

const Mats = preload("res://scripts/world/mats.gd")

const FOG_COLD := Color(0.5, 0.58, 0.72)
const FOG_WARM := Color(0.78, 0.7, 0.58)
const AMB_COLD := Color(0.4, 0.47, 0.6)
const AMB_WARM := Color(1.0, 0.82, 0.6)
const FOG_TUNNEL := Color(0.46, 0.38, 0.27)
const AMB_TUNNEL := Color(0.5, 0.42, 0.32)

var env: Environment
var lamps: Array = []
var debris
var audio
var player
var moon: DirectionalLight3D
## 0 on the ward, 1 in the tunnel; blends with the depth of the player's eyes.
var under := 0.0
var _first := true


func _process(dt: float) -> void:
	State.presence = move_toward(State.presence, State.presence_target, dt * 0.3)
	var p := State.presence
	var eye := Vector3.ZERO
	if player:
		eye = player.cam.global_position
		var target := clampf((0.9 - eye.y) / 1.8, 0.0, 1.0)
		under = target if _first else lerpf(under, target, minf(1.0, dt * 3.0))
		_first = false
	var u := under
	env.volumetric_fog_density = lerpf(lerpf(0.035, 0.012, p), 0.05, u)
	env.volumetric_fog_albedo = FOG_COLD.lerp(FOG_WARM, p).lerp(FOG_TUNNEL, u)
	env.ambient_light_energy = lerpf(lerpf(0.08, 0.22, p), 0.03, u)
	env.ambient_light_color = AMB_COLD.lerp(AMB_WARM, p).lerp(AMB_TUNNEL, u)
	if moon:
		moon.light_volumetric_fog_energy = 1.2 * (1.0 - u)
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
		audio.set_place(eye, u)
