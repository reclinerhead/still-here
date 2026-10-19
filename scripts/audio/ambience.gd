extends Node
## Procedurally generated sound, so the prototype ships with no audio files:
## a cold drone and air for the abandoned ward, a soft warm pad that rises with presence,
## running water and drips from the tunnel, each echo's music, wind whistling through broken
## windows (with the trees and a far-off car outside, close up), and one-shots for the bell,
## handling objects and the camera shutter.

const RATE := 22050

var _drone: AudioStreamPlayer
var _air: AudioStreamPlayer
var _warm: AudioStreamPlayer
var _ding: AudioStreamPlayer
var _thunk: AudioStreamPlayer
var _shutter: AudioStreamPlayer
var _water: AudioStreamPlayer
var _trickle: AudioStreamPlayer
var _drip: AudioStreamPlayer
var _water_pan := AudioEffectPanner.new()
var _trickle_pan := AudioEffectPanner.new()
var _drip_pan := AudioEffectPanner.new()
var _water_cfg: Dictionary = {}
var _water_wander := 0.6
var _trickle_level := 0.06
## [{id, player, filter, cfg, cue, revealed}] for every echo that has music
var _music: Array = []
## Where the broken windows' holes are (world positions); set before the node enters the tree.
var breaks: Array = []
## [{whistle, trees, car, gust, push, wait}] for each broken window
var _wind: Array = []
var _started := false
var _tasks: Array[int] = []
var _p := 0.0
var _u := 0.0
var _pos := Vector3.ZERO


func _ready() -> void:
	var verb := AudioEffectReverb.new()
	verb.room_size = 0.8
	verb.damping = 0.4
	verb.wet = 0.35
	verb.dry = 0.8
	_bus("Room", "Master", [verb])
	# the tunnel: a long, dark reverb that most of the water goes through
	var tverb := AudioEffectReverb.new()
	tverb.room_size = 0.95
	tverb.damping = 0.35
	tverb.predelay_msec = 60.0
	tverb.wet = 0.65
	tverb.dry = 0.3
	_bus("Tunnel", "Master", [tverb])
	_bus("Water", "Tunnel", [_water_pan])
	_bus("Trickle", "Tunnel", [_trickle_pan])
	_bus("Drip", "Tunnel", [_drip_pan])
	_drone = _player(_loop_drone(), -14.0)
	_air = _player(_loop_air(), -20.0)
	_warm = _player(null, -80.0)
	_ding = _player(_one_ding(), -6.0)
	_thunk = _player(_one_thunk(), -8.0)
	_shutter = _player(_one_shutter(), -10.0)
	# the slower sounds are synthesized off the main thread
	var warm := _warm
	_tasks.append(WorkerThreadPool.add_task(func(): _loop_ready.call_deferred(warm, _loop_pad())))
	_water_cfg = Data.zone.get("tunnel", {}).get("water", {})
	if not _water_cfg.is_empty():
		_water = _player(null, -80.0, "Water")
		_trickle = _player(null, -80.0, "Trickle")
		_drip = _player(_one_drip(), -20.0, "Drip")
		var water := _water
		var trickle := _trickle
		_tasks.append(WorkerThreadPool.add_task(func(): _loop_ready.call_deferred(water, _loop_water())))
		_tasks.append(WorkerThreadPool.add_task(func(): _loop_ready.call_deferred(trickle, _loop_trickle())))
	for at in breaks:
		var w := {"whistle": _player3d(at, 9.0), "trees": _player3d(at, 4.0), "car": _player3d(at, 4.0),
			"gust": 0.5, "push": 0.0, "wait": randf_range(20.0, 60.0)}
		_wind.append(w)
		var whistle: AudioStreamPlayer3D = w["whistle"]
		var trees: AudioStreamPlayer3D = w["trees"]
		var car: AudioStreamPlayer3D = w["car"]
		_tasks.append(WorkerThreadPool.add_task(func(): _loop_ready.call_deferred(whistle, _loop_whistle())))
		_tasks.append(WorkerThreadPool.add_task(func(): _loop_ready.call_deferred(trees, _loop_branches())))
		_tasks.append(WorkerThreadPool.add_task(func(): _loop_ready.call_deferred(car, _one_car(), false)))
	for eid in Data.echoes:
		var m: Dictionary = Data.echoes[eid].get("music", {})
		if m.is_empty():
			continue
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 650.0
		var bus: String = "Music " + str(eid)
		_bus(bus, "Room", [lp])
		var player := _player(null, -80.0, bus)
		_music.append({"id": eid, "player": player, "filter": lp, "cfg": m, "cue": 0.0, "revealed": false})
		_tasks.append(WorkerThreadPool.add_task(func(): _loop_ready.call_deferred(player, _loop_music(m))))


func _exit_tree() -> void:
	for t in _tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_tasks.clear()


## p: an AudioStreamPlayer or AudioStreamPlayer3D. A one-shot (loop false) waits to be played.
func _loop_ready(p, stream: AudioStreamWAV, loop := true) -> void:
	if not is_inside_tree():
		return
	p.stream = stream
	if _started and loop:
		p.play()


func start() -> void:
	_started = true
	for p in [_drone, _air, _warm, _water, _trickle]:
		if p and p.stream:
			p.play()
	for m in _music:
		if m["player"].stream:
			m["player"].play()
	for w in _wind:
		for k in ["whistle", "trees"]:
			if w[k].stream:
				w[k].play()


func set_presence(p: float) -> void:
	_p = p


## Where the listener is, and how far underground (0 on the ward, 1 in the tunnel).
func set_place(pos: Vector3, under: float) -> void:
	_pos = pos
	_u = under


func ding() -> void: _ding.play()
func thunk() -> void: _thunk.play()
func shutter() -> void: _shutter.play()


func _process(dt: float) -> void:
	# the ward's own sounds duck underground
	var duck := -16.0 * _u
	_drone.volume_db = lerpf(-14.0, -30.0, _p) + duck
	_air.volume_db = lerpf(-20.0, -32.0, _p) + duck
	# subtle but noticeable: the pad sits well under everything else, even fully restored
	_warm.volume_db = (-80.0 if _p < 0.01 else lerpf(-40.0, -25.0, sqrt(_p))) + duck
	if _water:
		_mix_water(dt)
	for m in _music:
		_mix_music(m, dt)
	for w in _wind:
		_mix_wind(w, dt)


## Water close by but impossible to place: its level wanders, a trickle sparkles on and off,
## both drift slowly across the stereo field. Silent on the ward, barely there at the top of the
## stairs, rising as you go down to a low level in the tunnel: it is only water in the pipes.
func _mix_water(dt: float) -> void:
	var c: Array = _water_cfg.get("near", [0, 0])
	var d := Vector2(_pos.x - float(c[0]), _pos.z - float(c[1])).length()
	var near := maxf(0.0, 1.0 - d / float(_water_cfg.get("near_radius", 3.5)))
	var g := 0.24 * near * near * (1.0 - _u) + _u
	_water_wander = clampf(_water_wander + randf_range(-0.5, 0.5) * dt * 4.0, 0.3, 1.0)
	_water.volume_db = linear_to_db(maxf(g * _water_wander, 0.0001)) - 21.0
	var target := randf() * 0.7 if randf() < 0.25 else 0.06
	_trickle_level = lerpf(_trickle_level, target, minf(1.0, dt * 30.0))
	_trickle.volume_db = linear_to_db(maxf(g * _trickle_level, 0.0001)) - 19.0
	var now := Time.get_ticks_msec() / 1000.0
	_water_pan.pan = sin(now * 0.11) * 0.7 + sin(now * 0.31 + 2.0) * 0.25
	_trickle_pan.pan = -sin(now * 0.17 + 1.0) * 0.7
	if _started and _u > 0.4 and randf() < dt * 0.45:
		_drip_pan.pan = randf_range(-1.0, 1.0)
		_drip.pitch_scale = randf_range(0.75, 1.5)
		_drip.play()


## Before its echo is revealed, the music is a faint, muffled cue close to its place.
## After, it plays clearly, loudest there, and falls away with distance and underground.
func _mix_music(m: Dictionary, dt: float) -> void:
	var cfg: Dictionary = m["cfg"]
	var c: Array = cfg["center"]
	var d := Vector2(_pos.x - float(c[0]), _pos.z - float(c[1])).length()
	var revealed := State.revealed.has(m["id"])
	var p: AudioStreamPlayer = m["player"]
	if revealed and not m["revealed"]:
		m["revealed"] = true
		if p.stream:
			p.play(0.0)
	var g := 0.0
	if revealed:
		g = (0.04 + 0.75 * maxf(0.0, 1.0 - d / float(cfg.get("radius", 16.0)))) * (1.0 - _u * 0.93)
	else:
		var near := maxf(0.0, 1.0 - d / float(cfg.get("cue_radius", 6.0))) if _u < 0.3 else 0.0
		m["cue"] = lerpf(m["cue"], near, minf(1.0, dt * 2.0))
		g = 0.22 * pow(m["cue"], 1.4)
	p.volume_db = lerpf(p.volume_db, linear_to_db(maxf(g, 0.0001)) - 12.0, minf(1.0, dt * 2.5))
	var lp: AudioEffectLowPassFilter = m["filter"]
	lp.cutoff_hz = lerpf(lp.cutoff_hz, 9000.0 if revealed else 650.0, minf(1.0, dt * 1.5))


## Wind through a broken window: it gusts and fades on its own, the whistle rising in pitch as it
## blows harder. Close to the hole, the wind in the trees outside comes in too, and now and then
## a car passes somewhere far off.
func _mix_wind(w: Dictionary, dt: float) -> void:
	w["gust"] = clampf(w["gust"] + randf_range(-0.5, 0.5) * dt * 1.2, 0.2, 1.0)
	if randf() < dt * 0.05:
		w["push"] = 1.0
	w["push"] = maxf(0.0, w["push"] - dt * 0.35)
	var g := clampf(w["gust"] * 0.7 + w["push"] * 0.5, 0.0, 1.0) * (1.0 - _u)
	var whistle: AudioStreamPlayer3D = w["whistle"]
	whistle.volume_db = linear_to_db(maxf(g, 0.001)) - 20.0
	whistle.pitch_scale = 0.92 + 0.16 * g
	var close := clampf(1.0 - (_pos.distance_to(whistle.global_position) - 0.6) / 2.4, 0.0, 1.0)
	w["trees"].volume_db = linear_to_db(maxf(close * (0.5 + 0.5 * g), 0.0001)) - 22.0
	w["wait"] -= dt
	if w["wait"] <= 0.0:
		w["wait"] = randf_range(50.0, 140.0)
		if _started and close > 0.3 and w["car"].stream:
			w["car"].volume_db = -26.0
			w["car"].play()


func _bus(name: String, send: String, effects: Array) -> void:
	if AudioServer.get_bus_index(name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, name)
	for fx in effects:
		AudioServer.add_bus_effect(i, fx)
	AudioServer.set_bus_send(i, send)


func _player(stream: AudioStream, db: float, bus := "Room") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.bus = bus
	add_child(p)
	return p


## A sound placed in the world, fading out by max_distance.
func _player3d(at: Vector3, max_distance: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.position = at
	p.volume_db = -80.0
	p.unit_size = 1.2
	p.max_distance = max_distance
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


static func _normalize(out: PackedFloat32Array, peak_to: float) -> void:
	var peak := 0.0
	for i in out.size():
		peak = maxf(peak, absf(out[i]))
	var g := peak_to / maxf(peak, 0.0001)
	for i in out.size():
		out[i] *= g


## RBJ biquad over a whole buffer: "lp" low-pass or "bp" band-pass (0 dB peak).
static func _biquad(x: PackedFloat32Array, kind: String, f: float, q: float, rate: int) -> PackedFloat32Array:
	var w := TAU * f / rate
	var cw := cos(w)
	var alpha := sin(w) / (2.0 * q)
	var b0 := alpha if kind == "bp" else (1.0 - cw) / 2.0
	var b1 := 0.0 if kind == "bp" else 1.0 - cw
	var b2 := -alpha if kind == "bp" else (1.0 - cw) / 2.0
	var a0 := 1.0 + alpha
	var a1 := -2.0 * cw
	var a2 := 1.0 - alpha
	var y := PackedFloat32Array()
	y.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var v := (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1
		x1 = x[i]
		y2 = y1
		y1 = v
		y[i] = v
	return y


static func _noise_buf(n: int, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


## Takes a filtered stream `fade` samples longer than the loop and crossfades the overflow into
## the start, so the last sample flows straight into the first.
static func _seamless(buf: PackedFloat32Array, n: int, fade: int) -> PackedFloat32Array:
	var out := buf.slice(0, n)
	for i in fade:
		var a := float(i) / fade
		out[i] = buf[i] * a + buf[n + i] * (1.0 - a)
	return out


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


## Running water: band-passed noise around 850 Hz over a low rumble. 7 s loop.
static func _loop_water() -> AudioStreamWAV:
	var n := RATE * 7
	var fade := RATE / 2
	var body := _biquad(_noise_buf(n + fade, 21), "bp", 850.0, 0.8, RATE)
	var rumble := _biquad(_noise_buf(n + fade, 22), "lp", 260.0, 0.7, RATE)
	for i in body.size():
		body[i] += rumble[i] * 0.5
	var out := _seamless(body, n, fade)
	_normalize(out, 0.6)
	return _wav(out, true)


## The lighter trickle on top: narrow band-passed noise around 2.5 kHz. 5 s loop.
static func _loop_trickle() -> AudioStreamWAV:
	var n := RATE * 5
	var fade := RATE / 4
	var out := _seamless(_biquad(_noise_buf(n + fade, 23), "bp", 2500.0, 2.5, RATE), n, fade)
	_normalize(out, 0.6)
	return _wav(out, true)


## Wind through a broken pane: two narrow resonances, a thin whistle, over breathy noise.
## 6 s loop; the player's pitch and level do the gusting.
static func _loop_whistle() -> AudioStreamWAV:
	var n := RATE * 6
	var fade := RATE / 2
	var src := _noise_buf(n + fade, 41)
	var a := _biquad(src, "bp", 1150.0, 14.0, RATE)
	var b := _biquad(src, "bp", 1720.0, 20.0, RATE)
	var breath := _biquad(_noise_buf(n + fade, 42), "lp", 700.0, 0.7, RATE)
	for buf in [a, b, breath]:
		_normalize(buf, 1.0)
	for i in a.size():
		a[i] = a[i] + b[i] * 0.5 + breath[i] * 0.3
	var out := _seamless(a, n, fade)
	_normalize(out, 0.6)
	return _wav(out, true)


## Wind in bare trees outside: a soft hiss that swells and sinks (in whole cycles, so it loops).
## 8 s loop.
static func _loop_branches() -> AudioStreamWAV:
	var n := RATE * 8
	var fade := RATE / 2
	var hiss := _biquad(_noise_buf(n + fade, 43), "bp", 900.0, 0.5, RATE)
	var high := _biquad(_noise_buf(n + fade, 44), "bp", 3000.0, 0.8, RATE)
	_normalize(hiss, 1.0)
	_normalize(high, 1.0)
	for i in hiss.size():
		var t := float(i) / RATE
		var swell := 0.55 + 0.25 * sin(TAU * t * 2.0 / 8.0) + 0.2 * sin(TAU * t * 3.0 / 8.0 + 1.0)
		hiss[i] = (hiss[i] + high[i] * 0.35) * swell
	var out := _seamless(hiss, n, fade)
	_normalize(out, 0.6)
	return _wav(out, true)


## A car somewhere far off on a wet road: tyre hiss rising and falling as it passes, a low engine
## dropping in pitch under it. 7 s.
static func _one_car() -> AudioStreamWAV:
	var n := RATE * 7
	var hiss := _biquad(_noise_buf(n, 45), "bp", 1600.0, 0.6, RATE)
	_normalize(hiss, 1.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-pow((t - 3.4) / 1.4, 2.0))
		ph += TAU * (74.0 - 10.0 * (t - 3.4) / 3.4) / RATE
		out[i] = (hiss[i] * 0.8 + sin(ph) * 0.25) * env
	_normalize(out, 0.5)
	return _wav(out, false)


## A drip: a short sine blip that falls in pitch.
static func _one_drip() -> AudioStreamWAV:
	var n := int(RATE * 0.25)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 1200.0 * pow(0.45, minf(t, 0.09) / 0.09)
		ph += TAU * f / RATE
		out[i] = sin(ph) * exp(-t * 28.0) * 0.6
	return _wav(out, false)


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
	_normalize(out, 0.55)
	return _wav(out, true, PAD_RATE)


## An echo's music from its data: a soft piano melody with a quiet "choir" doubling it, over
## root, fifth and tenth in the bass. One loop of `loop_beats`; notes that ring past the end
## wrap around to the start, so the loop is seamless.
static func _loop_music(m: Dictionary) -> AudioStreamWAV:
	const MUSIC_RATE := 16000
	const TABLE := 2048
	var beat: float = m["beat_s"]
	var n := int(MUSIC_RATE * float(m["loop_beats"]) * beat)
	var out := PackedFloat32Array()
	out.resize(n)
	# wavetables: a soft triangle and a sine for the piano, a band-limited saw for the voices
	var tri := PackedFloat32Array()
	var sine := PackedFloat32Array()
	var saw := PackedFloat32Array()
	tri.resize(TABLE)
	sine.resize(TABLE)
	saw.resize(TABLE)
	for i in TABLE:
		var x := TAU * i / TABLE
		tri[i] = sin(x) - sin(3.0 * x) / 9.0 + sin(5.0 * x) / 25.0 - sin(7.0 * x) / 49.0
		sine[i] = sin(x)
		var s := 0.0
		for k in range(1, 9):
			s += sin(k * x) / k
		saw[i] = s * 0.55
	var t := 0.0
	for e in m["melody"]:
		var f := _mtof(float(e[0]))
		var dur := float(e[1]) * beat
		var at := int(t * beat * MUSIC_RATE)
		_piano_note(out, tri, sine, at, f, dur, 0.085, MUSIC_RATE)
		_choir_note(out, saw, at, f, dur, MUSIC_RATE)
		t += float(e[1])
	var bass: Dictionary = m.get("bass", {})
	var roots: Array = bass.get("roots", [])
	var intervals: Array = bass.get("intervals", [0])
	var every := float(bass.get("every", 3))
	for i in roots.size():
		var at := int((float(bass.get("first_beat", 0)) + i * every) * beat * MUSIC_RATE)
		for k in intervals.size():
			_piano_note(out, tri, sine, at, _mtof(float(roots[i]) + float(intervals[k])), every * beat, 0.06 if k == 0 else 0.035, MUSIC_RATE)
	_normalize(out, 0.6)
	return _wav(out, true, MUSIC_RATE)


static func _mtof(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func _piano_note(out: PackedFloat32Array, tri: PackedFloat32Array, sine: PackedFloat32Array, at: int, f: float, dur: float, v: float, rate: int) -> void:
	var n := out.size()
	var size := tri.size()
	var ring := dur + 0.8
	var count := int(ring * rate)
	var inc := f * size / rate
	var decay := log(v / 0.0008) / ring
	for j in count:
		var tt := float(j) / rate
		var env := v * (tt / 0.006 if tt < 0.006 else exp(-decay * (tt - 0.006)))
		var s := tri[int(fmod(inc * j, size))] + 0.3 * sine[int(fmod(inc * 2.0 * j, size))]
		out[posmod(at + j, n)] += s * env


static func _choir_note(out: PackedFloat32Array, saw: PackedFloat32Array, at: int, f: float, dur: float, rate: int) -> void:
	var n := out.size()
	var size := float(saw.size())
	var count := int((dur + 0.3) * rate)
	var a := exp(-TAU * 1100.0 / rate)
	var lp1 := 0.0
	var lp2 := 0.0
	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	var d1 := pow(2.0, -5.0 / 1200.0)
	var d2 := pow(2.0, 5.0 / 1200.0)
	for j in count:
		var tt := float(j) / rate
		var env := 0.02
		if tt < 0.12:
			env *= tt / 0.12
		elif tt > dur - 0.05:
			env *= maxf(0.0, 1.0 - (tt - (dur - 0.05)) / 0.3)
		var inc := f * (1.0 + 0.006 * sin(TAU * 5.2 * tt)) * size / rate
		p1 = fmod(p1 + inc * d1, size)
		p2 = fmod(p2 + inc * d2, size)
		p3 = fmod(p3 + inc, size)
		var s := saw[int(p1)] + saw[int(p2)] + saw[int(p3)]
		lp1 = (1.0 - a) * s + a * lp1
		lp2 = (1.0 - a) * lp1 + a * lp2
		out[posmod(at + j, n)] += lp2 * env


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
