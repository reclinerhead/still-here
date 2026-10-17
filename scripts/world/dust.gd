extends RefCounted
## Dust hanging in the air: tiny lit specks drifting on slow eddies. They are shaded like any
## surface, so they only show where light falls on them: in the flashlight beam, under a lamp,
## or in moonlight from a window.


## d: {"box": [x0, x1, z0, z1], "y": [y0, y1], "amount": n}
static func make(d: Dictionary) -> GPUParticles3D:
	var b: Array = d["box"]
	var y: Array = d.get("y", [0.2, 3.8])
	var size := Vector3(float(b[1]) - float(b[0]), float(y[1]) - float(y[0]), float(b[3]) - float(b[2]))
	var p := GPUParticles3D.new()
	p.position = Vector3((float(b[0]) + float(b[1])) / 2.0, (float(y[0]) + float(y[1])) / 2.0, (float(b[2]) + float(b[3])) / 2.0)
	p.amount = int(d.get("amount", 500))
	p.lifetime = 24.0
	p.preprocess = 24.0
	p.fixed_fps = 30
	p.visibility_aabb = AABB(-size / 2.0 - Vector3.ONE * 0.5, size + Vector3.ONE)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = size / 2.0
	pm.gravity = Vector3(0, -0.004, 0)
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.03
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.004, 0.004)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.6, 0.58, 0.52)
	mat.roughness = 1.0
	# added to what's behind: lit motes glint, unlit ones vanish instead of showing as dark specks
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = mat
	p.draw_pass_1 = q
	return p
