extends Node
## Autoload "Data". Loads the JSON content under res://data into lookup tables.
## Nothing here knows about specific objects; it only indexes what the data files say.

const CORE := "res://data/core/"
const ARCHETYPE := "res://data/archetypes/kirkbride/"
const SITE := "res://data/sites/nma/"
const ZONE := "res://data/sites/nma/b50/w3n/"

var types: Dictionary = {}
var facts: Dictionary = {}
var sources: Dictionary = {}
var zone: Dictionary = {}
var objects: Dictionary = {}
var props: Array = []
var restorations: Dictionary = {}
var groups: Dictionary = {}
var subjects: Dictionary = {}
var fragments: Array = []
var documents: Dictionary = {}
var characters: Dictionary = {}
var echoes: Dictionary = {}
## Everything the player can encounter that is "about" a character: documents (whole or by excerpt),
## echo captions, Bertha fragments and echo figures. Built by _index_traces; read by the journal.
## Each is {"id", "kind": doc|frag|echo, "ref": what State records, "about": [character ids],
## "label": where it came from, "text": the excerpt ("" for a figure)}.
var traces: Array = []
## The view from the windows (the site's "outside" block).
var outside: Dictionary = {}


func _ready() -> void:
	types = _load(CORE + "object_types.json").get("types", {})
	var site := _load(SITE + "site.json")
	outside = site.get("outside", {})
	for d in [_load(ARCHETYPE + "facts.json"), site]:
		for s in d.get("sources", []):
			sources[s["id"]] = s
		for f in d.get("facts", []):
			facts[f["id"]] = f
	zone = _load(ZONE + "zone.json")
	var o := _load(ZONE + "objects.json")
	for item in o.get("objects", []):
		objects[item["id"]] = item
	props = o.get("props", [])
	var r := _load(ZONE + "restorations.json")
	for item in r.get("restorations", []):
		restorations[item["id"]] = item
	for g in r.get("groups", []):
		groups[g["id"]] = g
	var fr := _load(ZONE + "fragments.json")
	for s in fr.get("subjects", []):
		subjects[s["id"]] = s
	fragments = fr.get("fragments", [])
	fragments.append_array(_load(CORE + "fragments.json").get("fragments", []))
	var story := _load(SITE + "story/documents.json")
	for d in story.get("documents", []):
		documents[d["id"]] = d
	for c in story.get("characters", []):
		# composites only: a character presented as anything but invented is refused outright
		if c.get("basis", "") != "invented":
			push_error("Character %s is not marked invented; refusing it" % c.get("id", "?"))
			continue
		characters[c["id"]] = c
	for e in _load(ZONE + "echoes.json").get("echoes", []):
		echoes[e["id"]] = e
	_index_traces()


func _index_traces() -> void:
	for did in documents:
		var d: Dictionary = documents[did]
		var fallback: String = d.get("label", d.get("title", ""))
		if d.has("excerpts"):
			var i := 0
			for x in d["excerpts"]:
				_trace("doc:%s#%d" % [did, i], "doc", did, x.get("about", []), x.get("label", fallback), x.get("text", ""))
				i += 1
		elif d.has("about"):
			_trace("doc:" + did, "doc", did, d["about"], fallback, d.get("text", ""))
	for f in fragments:
		if f.has("about"):
			var title: String = subjects.get(f.get("subject", ""), {}).get("title", "")
			_trace("frag:" + f["id"], "frag", f["id"], f["about"], f.get("label", "Bertha, " + title.to_lower()), f.get("text", ""))
	for eid in echoes:
		var i := 0
		for fig in echoes[eid].get("figures", []):
			if fig.has("character"):
				_trace("echo:%s#%d" % [eid, i], "echo", eid, [fig["character"]], fig.get("label", ""), "")
			i += 1


func _trace(id: String, kind: String, ref: String, about: Array, label: String, text: String) -> void:
	for cid in about:
		if not characters.has(cid):
			push_warning("%s is about unknown character %s" % [id, cid])
	traces.append({"id": id, "kind": kind, "ref": ref, "about": about, "label": label, "text": text})


func traces_about(cid: String) -> Array:
	return traces.filter(func(t): return t["about"].has(cid))


func object_name(oid: String) -> String:
	var o: Dictionary = objects.get(oid, {})
	if o.has("name"):
		return o["name"]
	return types.get(o.get("type", ""), {}).get("name", oid)


func restoration_for_object(oid: String) -> Dictionary:
	for rid in restorations:
		if restorations[rid]["object"] == oid:
			return restorations[rid]
	return {}


static func vec3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func rot_deg(a: Array) -> Vector3:
	return Vector3(deg_to_rad(float(a[0])), deg_to_rad(float(a[1])), deg_to_rad(float(a[2])))


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Data file missing: " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Data file is not a JSON object: " + path)
		return {}
	return parsed
