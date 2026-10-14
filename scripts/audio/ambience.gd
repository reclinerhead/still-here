extends Node
## Procedurally generated sound, so the prototype ships with no audio files:
## a cold drone and air for the abandoned ward, a soft warm pad that rises with presence,
## and one-shots for the bell, handling objects and the camera shutter.

const RATE := 22050

var _drone: AudioStreamPlayer
var _air: AudioStreamPlayer
var _warm: AudioStreamPlayer
var _ding: AudioStreamPlayer
var _thunk: AudioStreamPlayer
var _shutter: AudioStreamPlayer
var _started := false
var _pad_task := -1


func _ready() -> void:
	_make_room_bus()
	_drone = _player(_loop_drone(), -14.0)
	_air = _player(_loop_air(), -20.0)
	_warm = _player(null, -80.0)
	_ding = _player(_one_ding(), -6.0)
	_thunk = _player(_one_thunk(), -8.0)
	_shutter = _player(_one_shutter(), -10.0)
	# the pad takes a moment to synthesize, so build it off the main thread
	_pad_task = WorkerThreadPool.add_task(func(): _pad_ready.call_deferred(_loop_pad()))


func _exit_tree() -> void:
	if _pad_task != -1:
		WorkerThreadPool.wait_for_task_completion(_pad_task)


func _pad_ready(stream: AudioStreamWAV) -> void:
	if not is_inside_tree():
		return
	_warm.stream = stream
	if _started:
		_warm.play()


func start() -> void:
	_started = true
	_drone.play()
	_air.play()
	if _warm.stream:
		_warm.play()


func set_presence(p: float) -> void:
	_drone.volume_db = lerpf(-14.0, -30.0, p)
	_air.volume_db = lerpf(-20.0, -32.0, p)
	# subtle but noticeable: the pad sits well under everything else, even fully restored
	_warm.volume_db = -80.0 if p < 0.01 else lerpf(-40.0, -25.0, sqrt(p))


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


static func _wav(samples: PackedFloat32Array, loop: bool, rate := RATE) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
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


## A slow, warm pad: G, E minor, C, D, four seconds each, crossfading into one another.
## Mellow tones (a fundamental with soft overtones), each voice doubled and detuned a
## quarter-hertz for a gentle chorus. 16 s loop; every frequency completes whole cycles.
static func _loop_pad() -> AudioStreamWAV:
	const PAD_RATE := 16000
	const LOOP_S := 16.0
	const TABLE := 2048
	var table := PackedFloat32Array()
	table.resize(TABLE)
	for i in TABLE:
		var x := TAU * i / TABLE
		table[i] = sin(x) + 0.22 * sin(2.0 * x) + 0.06 * sin(3.0 * x)
	var chords := [
		[98.0, 196.0, 247.0, 294.0],   # G
		[82.0, 165.0, 196.0, 247.0],   # E minor
		[65.0, 131.0, 196.0, 262.0],   # C
		[73.0, 147.0, 185.0, 220.0],   # D
	]
	var n := int(PAD_RATE * LOOP_S)
	var out := PackedFloat32Array()
	out.resize(n)
	var step := LOOP_S / chords.size()
	for c in chords.size():
		var center := step * (c + 0.5)
		for k in chords[c].size():
			var f: float = chords[c][k]
			var amp := 0.5 if k == 0 else 0.32
			var half := step * 0.85
			var i0 := int((center - half) * PAD_RATE)
			var count := int(half * 2.0 * PAD_RATE)
			for det in [-0.25, 0.25]:
				var inc: float = (f + det) * TABLE / PAD_RATE
				for j in count:
					var i := posmod(i0 + j, n)
					var dt := (float(j) / PAD_RATE) - half
					var e := cos(PI * 0.5 * dt / half)
					# phase from the absolute sample index keeps the loop seamless
					var ph := fmod(inc * i, TABLE)
					out[i] += table[int(ph)] * amp * e * e
	var peak := 0.0
	for i in n:
		peak = maxf(peak, absf(out[i]))
	var g := 0.55 / maxf(peak, 0.001)
	for i in n:
		out[i] *= g
	return _wav(out, true, PAD_RATE)


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
