extends RefCounted
## Bertha, the phone's AI assistant. Entirely scripted: she assembles an answer from data
## fragments whose conditions hold right now (see docs/data-model.md, "How Bertha answers").

const Conditions = preload("res://scripts/core/conditions.gd")

## A connection ties the photo to something the player already found (read(doc), told(fragment)).
const SLOTS := ["ident", "observation", "connection", "history", "hint", "special"]
const PER_SLOT := {"ident": 1, "observation": 2, "connection": 1, "history": 1, "hint": 1, "special": 1}
const FALLBACK := "core.fallback"


## Returns {"text": String, "effects": Array, "subject": String, "state": String, "ids": Array}.
## Evaluated at the moment of the photo, so a delayed answer still describes what was photographed.
## "ids" lists the fragments used, for State.mark_told once the answer is delivered.
func answer(subject_id: String) -> Dictionary:
	var sid := subject_id if subject_id != "" else FALLBACK
	var by_slot := {}
	for f in Data.fragments:
		if f.get("subject", "") != sid:
			continue
		if not Conditions.check(f.get("when", "")):
			continue
		var slot: String = f.get("slot", "ident")
		if not by_slot.has(slot):
			by_slot[slot] = []
		by_slot[slot].append(f)
	if by_slot.is_empty() and sid != FALLBACK:
		return answer("")
	var chosen := {}
	for slot in SLOTS:
		if not by_slot.has(slot):
			continue
		var list: Array = by_slot[slot]
		list.sort_custom(func(a, b): return float(a.get("priority", 0)) > float(b.get("priority", 0)))
		chosen[slot] = list.slice(0, mini(PER_SLOT[slot], list.size()))
	# Length budget: at most MAX_PARTS paragraphs before any special line.
	# Drop history first (the journal keeps it), then extra observations, and the connection last:
	# it is what the player came back for.
	while _count(chosen) > MAX_PARTS:
		if chosen.has("history"):
			chosen.erase("history")
		elif chosen.has("observation") and chosen["observation"].size() > 1:
			chosen["observation"].pop_back()
		elif chosen.has("connection"):
			chosen.erase("connection")
		else:
			break
	var parts: Array[String] = []
	var effects: Array = []
	var ids: Array = []
	for slot in SLOTS:
		for f in chosen.get(slot, []):
			parts.append(f["text"])
			effects.append_array(f.get("effects", []))
			ids.append(f["id"])
	# the ident fragment names the state the subject was in (used to pair before/after photos)
	var state_key: String = chosen["ident"][0]["id"] if chosen.has("ident") else ""
	return {"text": "\n\n".join(parts), "effects": effects, "subject": sid, "state": state_key, "ids": ids}


const MAX_PARTS := 4


func _count(chosen: Dictionary) -> int:
	var n := 0
	for slot in chosen:
		if slot != "special":
			n += chosen[slot].size()
	return n


## After answering, unsolved restorations linked to this subject get a slightly stronger hint next time.
func escalate(subject_id: String) -> void:
	var s: Dictionary = Data.subjects.get(subject_id, {})
	for rid in s.get("hints_for", []):
		if not State.done.has(rid):
			State.bump_hint(rid)
	State.photo_counts[subject_id] = int(State.photo_counts.get(subject_id, 0)) + 1
