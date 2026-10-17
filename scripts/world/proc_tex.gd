extends RefCounted
## Procedural textures. Generated once, then cached as PNGs in user://tex_cache.
## Bump CACHE_VERSION whenever a generator changes.

const CACHE_VERSION := 7
const S := 256


static func cached(key: String, gen: Callable) -> ImageTexture:
	var path := "user://tex_cache/%s_v%d.png" % [key, CACHE_VERSION]
	var img: Image = null
	if FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img == null or img.is_empty():
		img = gen.call()
		DirAccess.make_dir_recursive_absolute("user://tex_cache")
		img.save_png(path)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Seamless noise: blends four offset samples so the texture tiles.
static func _sn(n: FastNoiseLite, x: float, y: float, s: float) -> float:
	var fx := x / s
	var fy := y / s
	var a := n.get_noise_2d(x, y)
	var b := n.get_noise_2d(x - s, y)
	var c := n.get_noise_2d(x, y - s)
	var d := n.get_noise_2d(x - s, y - s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _noise(seed: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


## Puddle decal: a dark, wet blob with a ragged, soft edge. The alpha masks the decal's
## roughness and normal too, so the pavers underneath turn glossy and flat where it's wet.
static func puddle(seed: int) -> Image:
	var P := 128
	var img := Image.create(P, P, false, Image.FORMAT_RGBA8)
	var n := _noise(seed, 0.05, 3)
	for y in P:
		for x in P:
			var u := (x + 0.5) / P * 2.0 - 1.0
			var v := (y + 0.5) / P * 2.0 - 1.0
			var d := Vector2(u, v).length() + n.get_noise_2d(x, y) * 0.35
			var a := 1.0 - smoothstep(0.55, 0.85, d)
			img.set_pixel(x, y, Color(0.06, 0.05, 0.04, a * 0.9))
	return img


## Seamless, full-range noise for the decay shader's damage mask and streaks.
static func decay_mask(seed: int) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var n := _noise(seed, 0.012, 5)
	var vals := PackedFloat32Array()
	vals.resize(S * S)
	var lo := 1.0
	var hi := -1.0
	for y in S:
		for x in S:
			var v := _sn(n, x, y, S)
			vals[y * S + x] = v
			lo = minf(lo, v)
			hi = maxf(hi, v)
	for y in S:
		for x in S:
			var v := (vals[y * S + x] - lo) / maxf(hi - lo, 0.0001)
			img.set_pixel(x, y, Color(v, v, v))
	return img


## A tiny uniform texture, for decal channels that need one value everywhere.
static func flat(c: Color) -> Image:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img


## Dust decal: dusty everywhere except a clean silhouette where something sat for decades.
static func dust_shadow(shape: String) -> Image:
	var D := 128
	var img := Image.create(D, D, false, Image.FORMAT_RGBA8)
	var n := _noise(91, 0.06, 3)
	for y in D:
		for x in D:
			var u := (float(x) / D) * 2.0 - 1.0
			var v := (float(y) / D) * 2.0 - 1.0
			var inside := 0.0
			match shape:
				"round":
					inside = 1.0 - smoothstep(0.30, 0.38, sqrt(u * u + v * v))
				"round_small":
					inside = 1.0 - smoothstep(0.22, 0.30, sqrt(u * u + v * v))
				_:
					inside = (1.0 - smoothstep(0.42, 0.5, absf(u))) * (1.0 - smoothstep(0.30, 0.38, absf(v)))
			var border := 1.0 - smoothstep(0.65, 1.0, maxf(absf(u), absf(v)))
			var g := n.get_noise_2d(x, y) * 0.5 + 0.5
			var a := (0.35 + g * 0.35) * border * (1.0 - inside * 0.92)
			img.set_pixel(x, y, Color(0.62, 0.58, 0.5, a))
	return img


## Flashlight beam pattern for the spotlight's projector: a hot centre a touch off-axis, a
## dimmer corona with faint reflector rings, and a weak spill fading out at the cone's edge.
## Stored sRGB-encoded because the engine decodes projector textures as sRGB.
static func flashlight_beam() -> Image:
	var B := 256
	var img := Image.create(B, B, false, Image.FORMAT_RGBA8)
	var n := _noise(77, 0.035, 3)
	for y in B:
		for x in B:
			var u := (x + 0.5) / B * 2.0 - 1.0
			var v := (y + 0.5) / B * 2.0 - 1.0
			var r := Vector2(u - 0.025, v + 0.02).length()
			var hot := exp(-pow(r / 0.13, 2.0))
			var corona := 0.26 * exp(-pow(r / 0.33, 2.0))
			var spill := 0.06 * (1.0 - smoothstep(0.62, 1.0, r))
			var rings := 0.03 * exp(-pow((r - 0.26) / 0.022, 2.0)) - 0.035 * exp(-pow((r - 0.19) / 0.03, 2.0))
			var smudge := 1.0 + n.get_noise_2d(x, y) * 0.1
			var i := clampf((hot + corona + spill + rings) * smudge, 0.0, 1.0)
			# the spill runs slightly warmer than the core
			var warm := smoothstep(0.12, 0.6, r)
			img.set_pixel(x, y, Color(i, i * (1.0 - 0.05 * warm), i * (1.0 - 0.12 * warm)).linear_to_srgb())
	return img


## Lined paper for debris.
static func paper() -> Image:
	var img := Image.create(32, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.78, 0.75, 0.66))
	for y in range(6, 38, 4):
		for x in range(3, 29):
			img.set_pixel(x, y, Color(0.55, 0.55, 0.6))
	return img
