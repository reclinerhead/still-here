extends RefCounted
## Procedural textures. Generated once, then cached as PNGs in user://tex_cache.
## Bump CACHE_VERSION whenever a generator changes.

const CACHE_VERSION := 4
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


static func normal_from(key: String, gen: Callable, strength: float) -> ImageTexture:
	return cached(key + "_n", func():
		var img: Image = gen.call()
		img.convert(Image.FORMAT_RGBA8)
		img.bump_map_to_normal_map(strength)
		return img)


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


## Painted plaster or paint with grime, streaks and peeling patches.
static func paint(base: Color, seed: int, streaks: bool, peel: bool) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var n := _noise(seed, 0.012, 4)
	var m := _noise(seed + 11, 0.05, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for y in S:
		for x in S:
			var g := _sn(n, x, y, S)
			var f := _sn(m, x, y, S)
			var c := base.darkened(clampf(0.08 + g * 0.2, 0.0, 0.45))
			c = c.lerp(Color(0.3, 0.25, 0.16), clampf(0.05 + f * 0.14, 0.0, 0.25))
			var r := rng.randf_range(-0.02, 0.02)
			img.set_pixel(x, y, Color(c.r + r, c.g + r, c.b + r))
	if streaks:
		for i in 18:
			var sx := rng.randi_range(0, S - 1)
			var length := rng.randi_range(40, 230)
			var amount := rng.randf_range(0.05, 0.16)
			for y in length:
				var k := amount * (1.0 - float(y) / length)
				for w in 2:
					var px := (sx + w) % S
					img.set_pixel(px, y, img.get_pixel(px, y).darkened(k * (1.0 - w * 0.5)))
	if peel:
		for i in 6:
			_blob(img, rng, rng.randi_range(0, S - 1), rng.randi_range(0, S - 1), rng.randi_range(6, 20), base.lightened(0.12), base.darkened(0.3))
	return img


## An irregular patch (peeled paint, a stain): lobed outline, soft fill, thin ragged edge.
static func _blob(img: Image, rng: RandomNumberGenerator, cx: int, cy: int, r: int, fill: Color, edge: Color) -> void:
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var stretch := rng.randf_range(0.6, 1.4)
	for dy in range(-r * 2, r * 2 + 1):
		for dx in range(-r * 2, r * 2 + 1):
			var a := atan2(float(dy), float(dx) * stretch)
			var lobes := 0.75 + 0.22 * sin(3.0 * a + p1) + 0.12 * sin(7.0 * a + p2)
			var d := sqrt(float(dx * dx) * stretch + float(dy * dy) / stretch) / (float(r) * lobes)
			d *= rng.randf_range(0.94, 1.06)
			var px := posmod(cx + dx, S)
			var py := posmod(cy + dy, S)
			if d < 1.0:
				img.set_pixel(px, py, img.get_pixel(px, py).lerp(fill, 0.55))
			elif d < 1.07:
				img.set_pixel(px, py, img.get_pixel(px, py).lerp(edge, 0.6))


## Checkered linoleum tiles: 8 tiles across the texture (25 cm each at 2 m per repeat).
static func floor_tiles(seed: int) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var n := _noise(seed, 0.02, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a := Color(0.56, 0.53, 0.45)
	var b := Color(0.26, 0.25, 0.22)
	for y in S:
		for x in S:
			var tile := (int(x / 32) + int(y / 32)) % 2
			var c := a if tile == 0 else b
			var g := _sn(n, x, y, S)
			c = c.darkened(clampf(0.12 + g * 0.3, 0.0, 0.55))
			if x % 32 == 0 or y % 32 == 0:
				c = c.darkened(0.35)
			var r := rng.randf_range(-0.025, 0.025)
			img.set_pixel(x, y, Color(c.r + r, c.g + r, c.b + r))
	for i in 7:
		_blob(img, rng, rng.randi_range(0, S - 1), rng.randi_range(0, S - 1), rng.randi_range(8, 22), Color(0.12, 0.1, 0.08), Color(0.16, 0.14, 0.11))
	return img


## Plaster ceiling with water-stain rings.
static func ceiling(seed: int) -> Image:
	var img := paint(Color(0.62, 0.6, 0.53), seed, false, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 5
	for i in 4:
		var cx := rng.randi_range(20, S - 20)
		var cy := rng.randi_range(20, S - 20)
		var r0 := rng.randi_range(16, 40)
		for y in range(-r0 - 2, r0 + 3):
			for x in range(-r0 - 2, r0 + 3):
				var d := sqrt(float(x * x + y * y))
				var ring := absf(fmod(d, 9.0) - 4.5) < 0.9 and d < r0
				if d < r0:
					var px := posmod(cx + x, S)
					var py := posmod(cy + y, S)
					var c := img.get_pixel(px, py).lerp(Color(0.45, 0.35, 0.2), 0.12 + (0.2 if ring else 0.0))
					img.set_pixel(px, py, c)
	return img


## Wood grain.
static func wood(base: Color, seed: int) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var n := _noise(seed, 0.03, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for y in S:
		for x in S:
			var g := _sn(n, x, y, S)
			var grain := sin((float(y) + g * 40.0) * 0.45) * 0.5 + 0.5
			var c := base.darkened(0.05 + grain * 0.18 + g * 0.1)
			var r := rng.randf_range(-0.015, 0.015)
			img.set_pixel(x, y, Color(c.r + r, c.g + r, c.b + r))
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


## Lined paper for debris.
static func paper() -> Image:
	var img := Image.create(32, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.78, 0.75, 0.66))
	for y in range(6, 38, 4):
		for x in range(3, 29):
			img.set_pixel(x, y, Color(0.55, 0.55, 0.6))
	return img
