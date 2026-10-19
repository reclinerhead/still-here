extends Node3D
## A group of residents remembered by the building. They never notice or react to the player.
## Fade in by degrees once their restoration is complete; before that, only brief glimpses.

const GHOST := preload("res://shaders/ghost.gdshader")

var id := ""
var data: Dictionary = {}
var player: Node3D
var mat := ShaderMaterial.new()
var figures: Array = []
var started := false
var t := 0.0
var glimpse := 0.0
var forced := -1.0      # set by the phone for a single photo frame
var center := Vector2.ZERO


func setup(d: Dictionary) -> void:
	data = d
	id = d["id"]
	mat.shader = GHOST
	var tint: Array = d.get("tint", [1.0, 0.86, 0.66])
	mat.set_shader_parameter("tint", Color(tint[0], tint[1], tint[2]))
	mat.set_shader_parameter("reveal", 0.0)
	center = Vector2(float(d["center"][0]), float(d["center"][1]))
	for f in d["figures"]:
		var fig := _figure(f)
		add_child(fig)
		figures.append(fig)
	visible = false


func start() -> void:
	started = true
	t = 0.0
	State.revealed[id] = true


func _process(dt: float) -> void:
	var r := 0.0
	if forced >= 0.0:
		r = forced
	elif started:
		t += dt
		var base := minf(1.0, t / 7.0)
		r = base * (0.65 + 0.35 * absf(sin(t * 7.3) * sin(t * 2.1 + 1.0))) if t < 4.5 else base
	elif player:
		var p := Vector2(player.global_position.x, player.global_position.z)
		var g: Dictionary = data.get("glimpse", {})
		if glimpse <= 0.0 and p.distance_to(center) < float(g.get("radius", 7.0)) and randf() < dt * float(g.get("chance_per_s", 0.1)):
			glimpse = 0.45
		if glimpse > 0.0:
			glimpse -= dt
			r = 0.2 * sin(maxf(0.0, glimpse) / 0.45 * PI)
	visible = r > 0.005
	mat.set_shader_parameter("reveal", r)
	# once revealed, the figures count as seen when the player is close enough to make them out
	if started and r > 0.5 and player and not State.seen.has(id):
		var p := Vector2(player.global_position.x, player.global_position.z)
		if p.distance_to(center) < float(data.get("glimpse", {}).get("radius", 7.0)):
			State.mark_seen(id)
	if visible:
		var now := Time.get_ticks_msec() / 1000.0
		for fig in figures:
			_animate(fig, now)


func _figure(f: Dictionary) -> Node3D:
	var g := Node3D.new()
	var seated: bool = f.get("pose", "standing") == "seated"
	var sh := 1.04 if seated else 1.42
	if seated:
		_mesh(g, _box(Vector3(0.34, 0.14, 0.44)), Vector3(0, 0.5, -0.16))
		_mesh(g, _box(Vector3(0.3, 0.46, 0.13)), Vector3(0, 0.24, -0.36))
		_mesh(g, _cyl(0.14, 0.18, 0.55), Vector3(0, 0.82, 0))
	else:
		_mesh(g, _cyl(0.17, 0.3, 1.0), Vector3(0, 0.5, 0))
		_mesh(g, _cyl(0.14, 0.17, 0.45), Vector3(0, 1.22, 0))
	var head := _mesh(g, _sph(0.1), Vector3(0, sh + 0.18, -0.02))
	_mesh(g, _sph(0.055), Vector3(0, sh + 0.21, 0.08))
	if f.get("cap", false):
		_mesh(g, _box(Vector3(0.2, 0.06, 0.12)), Vector3(0, sh + 0.29, -0.01))
	var arms: Array = []
	for s in [-1.0, 1.0]:
		var pv := Node3D.new()
		pv.position = Vector3(s * 0.17, sh - 0.03, 0)
		pv.rotation.x = float(f.get("reach", 0.0))
		_mesh(pv, _box(Vector3(0.07, 0.42, 0.07)), Vector3(0, -0.2, 0))
		g.add_child(pv)
		arms.append(pv)
	g.position = Data.vec3(f["pos"])
	# figures face -Z; "face": [x, z] turns one toward a point (the piano, a window)
	if f.has("face"):
		var to := Vector2(float(f["face"][0]) - g.position.x, float(f["face"][1]) - g.position.z)
		g.rotation.y = atan2(-to.x, -to.y)
	else:
		g.rotation.y = deg_to_rad(float(f.get("rot_deg", 0)))
	g.set_meta("arms", arms)
	g.set_meta("head", head)
	g.set_meta("routine", f.get("routine", "still"))
	g.set_meta("reach", float(f.get("reach", 0.0)))
	g.set_meta("phase", randf() * TAU)
	return g


func _animate(fig: Node3D, now: float) -> void:
	var arms: Array = fig.get_meta("arms")
	var reach: float = fig.get_meta("reach")
	var ph: float = fig.get_meta("phase")
	match fig.get_meta("routine"):
		"write":
			arms[1].rotation.x = reach + sin(now * 9.0) * 0.05
			fig.get_meta("head").rotation.x = 0.3
		"sway":
			fig.rotation.z = sin(now * 1.4 + ph) * 0.05
		"play":
			arms[0].rotation.x = reach + sin(now * 6.0 + ph) * 0.12
			arms[1].rotation.x = reach + sin(now * 5.3 + ph + 1.0) * 0.12
		"sip":
			arms[1].rotation.x = reach + maxf(0.0, sin(now * 0.7 + ph)) * 1.1


func _mesh(p: Node3D, m: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 14
	return c


func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s
