extends Node3D
## Spawns props and restorable objects from data and carries out the restoration verbs.
## Verbs implemented: place, upright, use (the restored bell). No object is hard-coded here.

const Props = preload("res://scripts/world/props.gd")
const ProcTex = preload("res://scripts/world/proc_tex.gd")

signal toast(msg: String)
signal note(doc_id: String)

var audio
var items: Dictionary = {}     # object id -> StaticBody3D holding the model
var slots: Dictionary = {}     # object id -> StaticBody3D at the home position


func build() -> void:
	for p in Data.props:
		var node := Props.build(p["model"])
		node.position = Data.vec3(p["pos"])
		node.rotation = Data.rot_deg(p.get("rot_deg", [0, 0, 0]))
		add_child(node)
	for oid in Data.objects:
		var o: Dictionary = Data.objects[oid]
		var r := Data.restoration_for_object(oid)
		if r.is_empty():
			continue
		var t: Dictionary = Data.types.get(o["type"], {})
		var body := _pick_body(Props.build(t.get("model", o["type"])), t.get("pick_size", [0.3, 0.3, 0.3]))
		body.position = Data.vec3(o["start"]["pos"])
		body.rotation = Data.rot_deg(o["start"].get("rot_deg", [0, 0, 0]))
		add_child(body)
		items[oid] = body
		match r["verb"]:
			"place":
				body.set_meta("interact", {"kind": "item", "object": oid})
				_make_slot(oid, o, r)
			"upright":
				body.set_meta("interact", {"kind": "upright", "object": oid, "restoration": r["id"]})


## Wraps a model in an interactable body (layer 2: seen by the player's ray, never blocks walking).
func _pick_body(model: Node3D, size: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(float(size[0]), float(size[1]), float(size[2]))
	cs.shape = sh
	cs.position.y = float(size[1]) / 2.0
	body.add_child(cs)
	body.add_child(model)
	return body


func _make_slot(oid: String, o: Dictionary, r: Dictionary) -> void:
	var home: Vector3 = Data.vec3(o["home"]["pos"])
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.34, 0.2, 0.3)
	cs.shape = sh
	cs.position.y = 0.1
	body.add_child(cs)
	body.position = home
	body.set_meta("interact", {"kind": "slot", "object": oid, "restoration": r["id"]})
	add_child(body)
	slots[oid] = body
	# the dust shadow: a clean silhouette where the object sat for decades
	var shape: String = o.get("dust_shadow", "rect")
	var decal := Decal.new()
	decal.texture_albedo = ProcTex.cached("dust_" + shape, func(): return ProcTex.dust_shadow(shape))
	decal.size = Vector3(0.62, 0.12, 0.5)
	decal.position = home + Vector3(0, 0.02, 0)
	decal.rotation.y = Data.rot_deg(o["home"].get("rot_deg", [0, 0, 0])).y
	add_child(decal)


func prompt_for(body) -> String:
	if not is_instance_valid(body) or not body.has_meta("interact"):
		return ""
	var m: Dictionary = body.get_meta("interact")
	var oid: String = m.get("object", "")
	var name := Data.object_name(oid)
	match m["kind"]:
		"item": return "[E]  Pick up the " + name
		"slot":
			if State.get_object_state(oid) == "carried":
				return "[E]  Put the " + name + " back"
			return ""
		"upright": return "[E]  Set the " + name + " upright"
		"ring": return "[E]  Ring the bell"
		"locked": return "[E]  Try the door"
	return ""


func interact(body) -> void:
	if not is_instance_valid(body) or not body.has_meta("interact"):
		return
	var m: Dictionary = body.get_meta("interact")
	var oid: String = m.get("object", "")
	match m["kind"]:
		"item":
			State.set_object_state(oid, "carried")
			var item: StaticBody3D = items[oid]
			item.visible = false
			item.collision_layer = 0
			audio.thunk()
			var doc: String = Data.objects[oid].get("document", "")
			if doc != "":
				note.emit(doc)
		"slot":
			if State.get_object_state(oid) != "carried":
				toast.emit("A %s belonged here. It must be somewhere in the ward." % Data.object_name(oid))
				return
			_place(oid, m["restoration"])
		"upright":
			_upright(oid, m["restoration"])
		"ring":
			audio.ding()
		"locked":
			toast.emit(m["msg"])
			audio.thunk()


func _place(oid: String, rid: String) -> void:
	var o: Dictionary = Data.objects[oid]
	var item: StaticBody3D = items[oid]
	item.position = Data.vec3(o["home"]["pos"])
	item.rotation = Data.rot_deg(o["home"].get("rot_deg", [0, 0, 0]))
	item.visible = true
	# switch the slot off rather than freeing it: the player's focus may still point at it this frame
	var slot: StaticBody3D = slots[oid]
	slot.remove_meta("interact")
	slot.collision_layer = 0
	State.set_object_state(oid, "placed")
	var model := item.get_child(1)
	if model.has_node("Light"):
		model.get_node("Light").light_energy = 1.4
		model.get_node("Bulb").material_override.emission_energy_multiplier = 6.0
	if Data.types.get(o["type"], {}).get("model", "") == "call_bell":
		item.collision_layer = 2
		item.set_meta("interact", {"kind": "ring"})
		audio.ding()
	else:
		audio.thunk()
	_complete(rid)


func _upright(oid: String, rid: String) -> void:
	var o: Dictionary = Data.objects[oid]
	var item: StaticBody3D = items[oid]
	item.remove_meta("interact")
	item.collision_layer = 0
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "position", Data.vec3(o["upright"]["pos"]), 0.8)
	tw.parallel().tween_property(item, "rotation", Data.rot_deg(o["upright"].get("rot_deg", [0, 0, 0])), 0.8)
	State.set_object_state(oid, "upright")
	audio.thunk()
	_complete(rid)


func _complete(rid: String) -> void:
	State.complete_restoration(rid)
	var left := 0
	for r in Data.restorations:
		if not State.done.has(r):
			left += 1
	toast.emit("The ward feels a little lighter." if left > 0 else "Everything at the station is back where it belongs.")


## For screenshots and tests: complete every restoration instantly.
func force_all() -> void:
	for oid in items.keys():
		var r := Data.restoration_for_object(oid)
		if r.is_empty() or State.done.has(r["id"]):
			continue
		if r["verb"] == "place":
			State.set_object_state(oid, "carried")
			_place(oid, r["id"])
		elif r["verb"] == "upright":
			_upright(oid, r["id"])
