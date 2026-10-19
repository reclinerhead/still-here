extends Node3D
## Builds the Ward 3 North core slice from data and wires the systems together.
##
## Screenshot mode (used by tools and Claude Code to check visuals without playing):
##   godot --path . -- --shot=user://shot.png --pose=12,0,0,-90,0 [--restore] [--photo] [--frames=90] [--no-flashlight]

const InputSetup = preload("res://scripts/core/input_setup.gd")
const EnvFactory = preload("res://scripts/world/env_factory.gd")
const WardBuilder = preload("res://scripts/world/ward_builder.gd")
const TunnelBuilder = preload("res://scripts/world/tunnel_builder.gd")
const Outside = preload("res://scripts/world/outside.gd")
const Debris = preload("res://scripts/world/debris.gd")
const Dust = preload("res://scripts/world/dust.gd")
const RestoreSystem = preload("res://scripts/world/restore_system.gd")
const EchoGroup = preload("res://scripts/world/echo_group.gd")
const Presence = preload("res://scripts/world/presence.gd")
const PlayerScript = preload("res://scripts/player/player.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const Phone = preload("res://scripts/phone/phone.gd")
const Gallery = preload("res://scripts/phone/gallery.gd")
const Ambience = preload("res://scripts/audio/ambience.gd")

var env: Environment
var player: PlayerScript
var hud: Hud
var phone: Phone
var gallery: Gallery
var restore: RestoreSystem
var audio: Ambience
var echoes: Dictionary = {}
var started := false


func _ready() -> void:
	InputSetup.ensure()
	var we := WorldEnvironment.new()
	env = EnvFactory.make()
	we.environment = env
	add_child(we)

	var ward := WardBuilder.new()
	add_child(ward)
	ward.build(Data.zone)
	var tunnel := TunnelBuilder.new()
	add_child(tunnel)
	tunnel.build(Data.zone)
	var outside := Outside.new()
	add_child(outside)
	outside.build(Data.outside, env, Data.zone, ward.moon)

	var debris := Debris.new()
	add_child(debris)
	debris.scatter(Data.zone.get("debris", []), Data.zone.get("station", [18, 2.5]))
	debris.drifts(Data.zone.get("debris", []), Debris.PAINT)
	# what came down with the ceiling lies under each hole
	var fallen: Array = []
	for h in Data.zone.get("ceiling_holes", []):
		fallen.append([h[0] - 0.3, h[1] + 0.3, h[2] - 0.3, h[3] + 0.3, 8, ""])
	debris.scatter(fallen, Data.zone.get("station", [18, 2.5]))
	debris.drifts(fallen, Debris.CEILING, 4.0)
	for d in Data.zone.get("dust", []):
		add_child(Dust.make(d))

	audio = Ambience.new()
	add_child(audio)

	restore = RestoreSystem.new()
	restore.audio = audio
	add_child(restore)
	restore.build()

	player = PlayerScript.new()
	add_child(player)
	var spawn: Array = Data.zone.get("spawn", [1, 0, 0])
	player.set_pose(Data.vec3(spawn), float(Data.zone.get("spawn_yaw_deg", -90)))

	for eid in Data.echoes:
		var e := EchoGroup.new()
		add_child(e)
		e.setup(Data.echoes[eid])
		e.player = player
		echoes[eid] = e

	hud = Hud.new()
	add_child(hud)
	phone = Phone.new()
	phone.hud = hud
	phone.audio = audio
	phone.echoes = echoes
	add_child(phone)
	phone.attach(player)
	gallery = Gallery.new()
	gallery.hud = hud
	gallery.phone = phone
	add_child(gallery)

	var presence := Presence.new()
	presence.env = env
	presence.lamps = ward.lamps
	presence.debris = debris
	presence.audio = audio
	presence.player = player
	presence.moon = ward.moon
	add_child(presence)

	restore.toast.connect(hud.toast)
	restore.note.connect(hud.show_note)
	State.group_done.connect(_on_group_done)

	var args := _user_args()
	if args.has("bertha"):
		_preview_bertha(args)
	elif args.has("shot"):
		_screenshot(args)


func _on_group_done(gid: String) -> void:
	var g: Dictionary = Data.groups.get(gid, {})
	var eid: String = g.get("on_complete", {}).get("echo", "")
	if eid == "" or not echoes.has(eid):
		return
	await get_tree().create_timer(1.6).timeout
	echoes[eid].start()
	var cap: String = Data.echoes[eid].get("caption", "")
	if cap != "":
		hud.queue_caption(Data.documents.get(cap, {}).get("text", ""))


func _start() -> void:
	started = true
	hud.title.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	audio.start()
	hud.toast("Find the nurses' station, halfway down on the right.")


func _unhandled_input(e: InputEvent) -> void:
	if not started:
		if (e is InputEventMouseButton or e is InputEventKey) and e.is_pressed():
			_start()
		return
	if gallery.is_open:
		if e.is_action_pressed("gallery") or e.is_action_pressed("ui_cancel"):
			gallery.close()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if hud.note_open:
		if e.is_action_pressed("interact") or e.is_action_pressed("shoot"):
			hud.hide_note()
			get_viewport().set_input_as_handled()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if e is InputEventMouseButton and e.is_pressed():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			hud.pause.visible = false
		return
	if e.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.pause.visible = true
	elif e.is_action_pressed("phone"):
		phone.toggle()
	elif e.is_action_pressed("gallery"):
		if phone.is_open:
			phone.toggle()
		gallery.open()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e.is_action_pressed("flashlight"):
		player.toggle_flashlight()
		audio.thunk()
	elif e.is_action_pressed("interact") or e.is_action_pressed("shoot"):
		if phone.is_open:
			phone.use()
		elif e.is_action_pressed("interact"):
			restore.interact(player.focus)


func _process(_dt: float) -> void:
	player.enabled = started and not hud.note_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not started or hud.note_open or phone.is_open or gallery.is_open:
		hud.set_prompt("")
		hud.crosshair.visible = not phone.is_open and started
	else:
		hud.crosshair.visible = true
		hud.set_prompt(restore.prompt_for(player.focus))
	if started:
		_check_triggers()


## One-time toasts from the zone's trigger boxes ([x0, x1, z0, z1], with a y range).
func _check_triggers() -> void:
	var p := player.global_position
	for t in Data.zone.get("triggers", []):
		var key: String = "trigger." + t["id"]
		if State.has_flag(key):
			continue
		var b: Array = t["box"]
		var y: Array = t.get("y", [-100, 100])
		if p.x >= b[0] and p.x <= b[1] and p.z >= b[2] and p.z <= b[3] and p.y >= y[0] and p.y <= y[1]:
			State.set_flag(key)
			hud.toast(t["toast"])


# --- preview Bertha ----------------------------------------------------------
## godot --headless --path . -- --bertha=station [--restore] [--photos=2]
## Prints Bertha's answer for a subject in a given state, then quits.

func _preview_bertha(args: Dictionary) -> void:
	await get_tree().process_frame
	if args.has("restore"):
		restore.force_all()
	var b := preload("res://scripts/phone/bertha.gd").new()
	var sid: String = args["bertha"]
	for i in int(args.get("photos", "1")):
		var ans: Dictionary = b.answer(sid)
		print("\n--- Bertha: photo %d of %s ---\n%s\n" % [i + 1, sid, ans["text"]])
		if not ans["effects"].is_empty():
			print("effects: ", ans["effects"])
			for fx in ans["effects"]:
				if fx.get("type", "") == "set_flag":
					State.set_flag(fx["flag"])
		b.escalate(sid)
	get_tree().quit()


# --- screenshot mode ---------------------------------------------------------

func _user_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		var kv := s.split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return out


func _screenshot(args: Dictionary) -> void:
	started = true
	hud.title.visible = false
	if args.has("pose"):
		var p: PackedStringArray = args["pose"].split(",")
		player.set_pose(Vector3(float(p[0]), float(p[1]), float(p[2])), float(p[3]), float(p[4]) if p.size() > 4 else 0.0)
	if args.has("no-flashlight"):
		player.toggle_flashlight()
	if args.has("restore"):
		_restore_now()
	var frames := int(args.get("frames", "90"))
	for i in frames:
		await get_tree().process_frame
	if args.has("photo"):
		await _snap()
	# --before-after: photo, restore everything, photo again (for checking the gallery pairing)
	if args.has("before-after"):
		await _snap(12)
		_restore_now()
		for i in 12:
			await get_tree().process_frame
		await _snap(12)
	if args.has("gallery"):
		if phone.is_open:
			phone.toggle()
		gallery.open()
		if not phone.entries.is_empty():
			gallery._show_detail(phone.entries[-1])
		for i in 10:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path: String = args["shot"]
	img.save_png(path)
	print("Saved screenshot: ", ProjectSettings.globalize_path(path))
	get_tree().quit()


func _restore_now() -> void:
	restore.force_all()
	State.presence = State.presence_target
	for eid in echoes:
		echoes[eid].start()
		echoes[eid].t = 10.0


func _snap(wait := 240) -> void:
	# the phone ignores the shutter while it recovers from the last photo
	while phone._cool > 0.0:
		await get_tree().process_frame
	if not phone.is_open:
		phone.toggle()
	if phone.mode == "chat":
		phone.use()
	await get_tree().process_frame
	phone.use()
	for i in wait:
		await get_tree().process_frame
