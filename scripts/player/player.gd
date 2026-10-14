extends CharacterBody3D
## First-person explorer: walk, look, flashlight, and a ray that finds what's in front of you.

const SENSITIVITY := 0.0022
const WALK := 1.7
const HURRY := 3.0
const EYE := 1.62
const REACH := 2.6

var cam: Camera3D
var flashlight: SpotLight3D
var enabled := false
var yaw := 0.0
var pitch := 0.0
var focus: Object = null
var _bob := 0.0
var _flash_on := true


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.875
	add_child(col)
	cam = Camera3D.new()
	cam.position.y = EYE
	cam.fov = 72.0
	cam.near = 0.05
	cam.far = 80.0
	add_child(cam)
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.18, -0.16, 0.05)
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.light_energy = 7.0
	flashlight.spot_range = 22.0
	flashlight.spot_angle = 30.0
	flashlight.spot_angle_attenuation = 1.2
	flashlight.shadow_enabled = true
	flashlight.light_volumetric_fog_energy = 0.8
	cam.add_child(flashlight)


func set_pose(pos: Vector3, yaw_deg: float, pitch_deg := 0.0) -> void:
	global_position = pos
	yaw = deg_to_rad(yaw_deg)
	pitch = deg_to_rad(pitch_deg)
	rotation.y = yaw
	cam.rotation.x = pitch


func toggle_flashlight() -> void:
	_flash_on = not _flash_on
	flashlight.visible = _flash_on


## Mouse look reads input before the UI does, so no on-screen control can swallow it.
func _input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * SENSITIVITY
		pitch = clampf(pitch - e.relative.y * SENSITIVITY, -1.35, 1.35)
		rotation.y = yaw
		cam.rotation.x = pitch


func _physics_process(dt: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * dt
	var input := Vector2.ZERO
	if enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := HURRY if Input.is_action_pressed("sprint") else WALK
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length()
	_bob += moving * dt * 5.0
	cam.position.y = EYE + sin(_bob) * 0.025 * minf(1.0, moving)
	# flashlight lags slightly behind the view, like a hand-held light
	flashlight.rotation = flashlight.rotation.lerp(Vector3.ZERO, minf(1.0, dt * 8.0))
	_update_focus()


func _update_focus() -> void:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	focus = null
	if hit and hit["collider"].has_meta("interact"):
		focus = hit["collider"]
