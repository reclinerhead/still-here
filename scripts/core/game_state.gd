extends Node
## Autoload "State". The single source of truth at runtime.
## Visual systems and Bertha both read from here; a save file would be this, serialized.

signal object_state_changed(id: String, state: String)
signal restoration_done(id: String)
signal group_done(id: String)

var object_states: Dictionary = {}
var done: Dictionary = {}
var flags: Dictionary = {}
var hint_levels: Dictionary = {}
var photo_counts: Dictionary = {}
var revealed: Dictionary = {}
var read: Dictionary = {}       # document ids (found notes and echo captions) the player has seen
var told: Dictionary = {}       # fragment ids Bertha has delivered (with signal, not merely queued)
var carried: Array[String] = []
var presence_target := 0.0
var presence := 0.0


func _ready() -> void:
	for oid in Data.objects:
		object_states[oid] = Data.objects[oid].get("start_state", "missing")


func get_object_state(oid: String) -> String:
	return object_states.get(oid, "")


func set_object_state(oid: String, s: String) -> void:
	object_states[oid] = s
	if s == "carried":
		if not carried.has(oid):
			carried.append(oid)
	else:
		carried.erase(oid)
	object_state_changed.emit(oid, s)


func complete_restoration(rid: String) -> void:
	if done.has(rid):
		return
	done[rid] = true
	restoration_done.emit(rid)
	for gid in Data.groups:
		if done.has(gid):
			continue
		var all_done := true
		for m in Data.groups[gid]["members"]:
			if not done.has(m):
				all_done = false
		if all_done:
			done[gid] = true
			group_done.emit(gid)
	var n := 0
	for r in Data.restorations:
		if done.has(r):
			n += 1
	presence_target = float(n) / maxf(1.0, float(Data.restorations.size()))


func hint_level(rid: String) -> int:
	return int(hint_levels.get(rid, 1))


func bump_hint(rid: String) -> void:
	hint_levels[rid] = mini(2, hint_level(rid) + 1)


func set_flag(name: String) -> void:
	flags[name] = true


func has_flag(name: String) -> bool:
	return flags.has(name)


## The player has read a document: a found note, or an echo's caption as it played.
func mark_read(doc_id: String) -> void:
	if doc_id != "":
		read[doc_id] = true


## Bertha has delivered these fragments. Called when the text appears, so a no-signal
## answer counts only once signal returns.
func mark_told(fragment_ids: Array) -> void:
	for fid in fragment_ids:
		told[fid] = true
