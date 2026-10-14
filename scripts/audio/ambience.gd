extends Node
## Procedurally generated sound, so the prototype ships with no audio files:
## a cold drone and air for the abandoned ward, a warm chord that rises with presence,
## and one-shots for the bell, handling objects and the camera shutter.

const RATE := 22050

var _drone: AudioStreamPlayer
var _air: AudioStreamPlayer
var _warm: AudioStreamPlayer
var _ding: AudioStreamPlayer
var _thunk: AudioStreamPlayer
var _shutter: AudioStreamPlayer
var _ticker: AudioStreamPlayer


func _ready() -> void:
	_make_room_bus()
	_drone = _player(_loop_drone(), -14.0)
	_air = _player(_loop_air(), -20.0)
	_warm = _player(_loop_warm(), -80.0)
	_ding = _player(_one_ding(), -6.0)
	_thunk = _player(_one_thunk(), -8.0)
	_shutter = _player(_one_shutter(), -10.0)


func start() -> void:
	_drone.play()
	_air.play()
	_warm.play()


func set_presence(p: float) -> void:
	_drone.volume_db = lerpf(-14.0, -30.0, p)
	_air.volume_db = lerpf(-20.0, -32.0, p)
	_warm.volume_db = -80.0 if p < 0.01 else lerpf(-34.0, -15.0, p)


func ding() -> void: _ding.play()
func thunk() -> void: _thunk.play()
func shutter() -> void: _shutter.play()


func _make_room_bus() -> void:
	if AudioServer.get_bus_index("Room") != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "Room")
	var verb := AudioEffectReverb.new()
	verb.room_size = 0.8
	verb.damping = 0.4
	verb.wet = 0.35
	verb.dry = 0.8
	AudioServer.add_bus_effect(i, verb)
	AudioServer.set_bus_send(i, "Master")


func _player(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.bus = "Room"
	add_child(p)
	return p


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


## Loops are exactly 5 s and every frequency completes whole cycles, so they loop without clicks.
static func _loop_drone() -> AudioStreamWAV:
	var n := RATE * 5
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = 0.5 * sin(TAU * 55.0 * t) + 0.4 * sin(TAU * 58.4 * t) + 0.12 * sin(TAU * 110.0 * t)
	return _wav(out, true)


static func _loop_air() -> AudioStreamWAV:
	var n := RATE * 5
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var y := 0.0
	for i in n:
		y = y * 0.985 + rng.randf_range(-1.0, 1.0) * 0.015
		out[i] = y * 3.0
	# crossfade the end into the start so the noise loops seamlessly
	var fade := RATE / 2
	for i in fade:
		var a := float(i) / fade
		out[n - fade + i] = out[n - fade + i] * (1.0 - a) + out[i] * a
	return _wav(out, true)


static func _loop_warm() -> AudioStreamWAV:
	var n := RATE * 5
	var out := PackedFloat32Array()
	out.resize(n)
	var freqs := [196.0, 247.0, 294.0, 392.0]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for f in freqs:
			v += sin(TAU * f * t) * (0.18 if f < 300.0 else 0.1)
		out[i] = v * (0.85 + 0.15 * sin(TAU * 0.2 * t))
	return _wav(out, true)


static func _one_ding() -> AudioStreamWAV:
	var n := int(RATE * 2.4)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 2.2)
		out[i] = env * (0.5 * sin(TAU * 1318.0 * t) + 0.25 * sin(TAU * 2637.0 * t) * exp(-t * 4.0) + 0.12 * sin(TAU * 3950.0 * t) * exp(-t * 6.0))
	return _wav(out, false)


static func _one_thunk() -> AudioStreamWAV:
	var n := int(RATE * 0.3)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 140.0 * pow(60.0 / 140.0, t / 0.2)
		ph += TAU * f / RATE
		out[i] = sin(ph) * exp(-t * 14.0) * 0.8
	return _wav(out, false)


static func _one_shutter() -> AudioStreamWAV:
	var n := int(RATE * 0.16)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in n:
		var t := float(i) / RATE
		var click := exp(-t * 90.0) + exp(-maxf(0.0, t - 0.07) * 90.0) * (1.0 if t > 0.07 else 0.0)
		out[i] = rng.randf_range(-1.0, 1.0) * click * 0.6
	return _wav(out, false)
