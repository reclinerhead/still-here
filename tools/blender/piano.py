"""The day room's old upright piano, exported to assets/models/piano.glb.

    blender --background --python tools/blender/piano.py -- --out assets/models/piano.glb

An upright from the early 1900s, of the plain kind a state hospital would buy, left for decades:
dark stained case, water-stained and worn at the edges, yellowed keys with a few chipped or
missing their ivory, and dust on every top surface except a clean rectangle on the lid where the
hymnal lay. The hymnal's slot and the maker's plate are read from the zone's objects.json, so the
clean rectangle and the open fallboard line up with them.

Coordinates are the piano's local frame in Godot's axes: origin on the floor at the centre,
keyboard facing +z, case 1.55 m wide and 0.55 m deep, keys at 0.85 m, matching the primitive
placeholder in scripts/world/props.gd so its collider and the data positions still fit.

In Godot each key is keys/key_<midi> (key_21 to key_108). A key's origin is its back edge, so
rotation.x = deg_to_rad(3.5) presses it. The lid hinges at its back edge (a negative rotation.x
opens it) and the fallboard at its bottom front edge (rotation.x = PI / 2 closes it over the keys).
"""

import json
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
from kit import srgb  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OBJECTS = os.path.join(ROOT, "data", "sites", "nma", "b50", "w3n", "objects.json")
HYMNAL = (0.16, 0.23)       # the hymnal's footprint (x, z), as props.gd builds it

W = 0.775                   # half the case's width
IN = 0.74                   # inside faces of the side panels
LID = 1.305                 # underside of the lid
KEYS_W = 1.222              # 52 white keys at 23.5 mm
KB = KEYS_W / 2.0
KEY_BACK = 0.29             # under the fallboard: every key's pivot
KEY_FRONT = 0.465
WHITE_Y = (0.823, 0.845)    # bottom and top of a white key
BLACK_Y = (0.826, 0.857)
BLACK_LEN = 0.11
SPLIT = BLACK_LEN + 0.0015  # where a white key widens, measured from its back edge
WHITE_PCS = (0, 2, 4, 5, 7, 9, 11)
# white keys that lost their ivory tops, and ones chipped at the right (1) or left (-1) front corner
BARE = (33, 64, 89)
CHIPPED = {41: 1, 57: -1, 71: 1, 79: 1, 96: -1}

# the key cheeks either side of the keyboard, in side view (z, y): rounded over at the front
CHEEK = [(0.255, 0.745), (0.49, 0.745), (0.49, 0.835), (0.484, 0.858), (0.468, 0.877), (0.444, 0.892),
	(0.414, 0.90), (0.255, 0.90)]
# a turned front leg, (radius, y): foot, vase, ring, neck and capital under the keybed
LEG = [(0.036, 0.06), (0.038, 0.075), (0.031, 0.085), (0.028, 0.10), (0.024, 0.13), (0.03, 0.17), (0.04, 0.22),
	(0.044, 0.27), (0.042, 0.32), (0.034, 0.37), (0.025, 0.42), (0.021, 0.46), (0.026, 0.475), (0.027, 0.49),
	(0.021, 0.505), (0.022, 0.55), (0.027, 0.60), (0.034, 0.635), (0.04, 0.655), (0.042, 0.67), (0.042, 0.70)]


def placement():
	"""The hymnal's slot (position and yaw) and the maker's plate, in the piano's frame."""
	with open(OBJECTS, encoding="utf-8") as f:
		d = json.load(f)
	piano = next(p for p in d["props"] if p["model"] == "piano")
	plate = next(p for p in d["props"] if p["model"] == "makers_plate")
	home = next(o for o in d["objects"] if o["id"] == "dayroom.hymnal")["home"]
	assert piano.get("rot_deg", [0, 0, 0]) == [0, 0, 0], "piano.py assumes the piano isn't rotated"

	def local(p):
		return [p[i] - piano["pos"][i] for i in range(3)]

	return local(home["pos"]), home.get("rot_deg", [0, 0, 0])[1], local(plate["pos"])


# --- geometry ------------------------------------------------------------------

def build_case(top, face):
	"""The case (one mesh), the lid and fallboard (separate, to hinge), and the back. Faces
	hidden inside the case or against another piece are dropped to save texture space."""
	m = kit.Mesh("case", floats=("metal", "dark"), seed=5)
	ends = ("-x", "+x")
	for s in (-1, 1):
		outer = "+x" if s > 0 else "-x"
		m.box((s * (W - 0.0175), LID / 2, 0.0), (0.035, LID, 0.55), bevel=0.004, grain="y", drop=("-y", "+y", "-z"))
		x0, x1 = sorted((s * (KB + 0.001), s * W))
		m.prism(CHEEK, "x", x0, x1, bevel=0.004, grain="z", drop=("-y", "-z"))
		# beside the open fallboard, and a bracket under each end of the music shelf
		m.box((s * (IN + KB + 0.001) / 2, 0.96, 0.2775), (IN - KB - 0.001, 0.12, 0.045), bevel=0.003,
			drop=("-y", "-z", outer))
		m.box((s * 0.675, 1.005, 0.30), (0.03, 0.03, 0.08), bevel=0.003, grain="z", drop=("+y", "-z"))
		# turned legs standing on toe blocks
		m.box((s * 0.69, 0.03, 0.37), (0.085, 0.06, 0.26), bevel=0.008, segs=3, grain="z", drop=("-y", "-z"))
		m.lathe(LEG, s * 0.69, 0.445, grain="y", drop=("-y", "+y"))
	# upper front: a board behind the fallboard and shelf, three raised panels, a moulded cornice
	m.box((0.0, 1.0675, 0.255), (2 * IN, 0.415, 0.02), drop=("-y", "+y", "-z") + ends)
	for x in (-0.46, 0.0, 0.46):
		m.box((x, 1.17, 0.271), (0.40, 0.17, 0.012), bevel=0.006, drop=("-z",))
	m.box((0.0, 1.29, 0.2675), (2 * W, 0.03, 0.045), bevel=0.006, segs=3, drop=("+y", "-z"))
	# the music shelf, with a lip to stop music sliding off
	m.box((0.0, 1.0325, 0.305), (1.40, 0.025, 0.10), bevel=0.004, drop=("-z",))
	m.box((0.0, 1.0525, 0.349), (1.40, 0.015, 0.012), bevel=0.003, drop=("-y",))
	# keybed with a moulded front edge, the dark key frame seen between the keys, the key slip
	m.box((0.0, 0.7225, 0.3575), (2 * W, 0.045, 0.265), bevel=0.005, drop=("+y", "-z"))
	m.box((0.0, 0.6925, 0.4825), (2 * W, 0.015, 0.025), bevel=0.005, segs=3, drop=("+y",))
	m.box((0.0, 0.7725, 0.3675), (KEYS_W, 0.055, 0.195), dark=1.0, drop=("-y", "-z") + ends)
	m.box((0.0, 0.7865, 0.479), (KEYS_W + 0.002, 0.083, 0.022), bevel=0.003, drop=("-y",) + ends)
	# lower front with a raised panel, the plinth, and three brass pedals coming out of it
	m.box((0.0, 0.3875, 0.235), (2 * IN, 0.625, 0.02), drop=("-y", "+y", "-z") + ends)
	m.box((0.0, 0.385, 0.251), (1.12, 0.43, 0.012), bevel=0.006, drop=("-z",))
	m.box((0.0, 0.0375, 0.2425), (2 * IN, 0.075, 0.035), bevel=0.004, drop=("-y", "-z") + ends)
	for x in (-0.09, 0.0, 0.09):
		m.prism(_pedal(x), "y", 0.055, 0.07, bevel=0.003, grain="z", drop=("-z",), metal=1.0)
	case = m.finish()

	lid = kit.Mesh("lid", seed=6)
	lid.box((0.0, (LID + top) / 2, 0.0125), (1.60, top - LID, 0.585), bevel=0.008, segs=3)
	fall = kit.Mesh("fallboard", seed=7)
	fall.box((0.0, 0.94, face - 0.011), (KEYS_W, 0.16, 0.022), bevel=0.004, drop=("+y", "-z"))
	back = kit.Mesh("back")
	back.box((0.0, LID / 2, -0.265), (2 * IN, LID, 0.02))
	return case, lid.finish(origin=(0.0, top, -0.28)), fall.finish(origin=(0.0, 0.86, face)), back.finish()

def _pedal(x):
	"""A pedal in top view (x, z): narrow where it leaves the plinth, a rounded spoon at the front."""
	side = [(0.013, 0.20), (0.016, 0.30), (0.021, 0.34), (0.019, 0.36), (0.010, 0.372)]
	return [(x + dx, z) for dx, z in side] + [(x - dx, z) for dx, z in reversed(side)]


def _white_index(n):
	"""How many white keys lie left of note n (negative below A0, for the groups A0 starts in)."""
	if n >= 21:
		return sum(1 for k in range(21, n) if k % 12 in WHITE_PCS)
	return -sum(1 for k in range(n, 21) if k % 12 in WHITE_PCS)


def build_keys():
	"""88 keys, each its own object under 'keys', named key_<midi> with its origin at its back edge."""
	root = kit.empty("keys")
	p = KEYS_W / 52.0
	gap, clear, bw, tw = 0.0012, 0.0009, 0.0135, 0.010

	def left(n):
		return -KB + _white_index(n) * p

	def black_centre(n):
		# black keys sit so the tails between them are even: 3 per C-E group, 4 per F-B group
		back, k = {1: (1, 0.9), 3: (3, 2.1), 6: (1, 6.0 / 7.0), 8: (3, 2.0), 10: (5, 22.0 / 7.0)}[n % 12]
		return left(n - back) + k * p

	def is_black(n):
		return 21 <= n <= 108 and n % 12 not in WHITE_PCS

	keys = []
	for n in range(21, 109):
		m = kit.Mesh(f"key_{n}", floats=("black", "bare", "chip"), seed=n)
		if is_black(n):
			c = black_centre(n)

			def corner(sx, sy, sz, c=c):
				up = sy > 0
				z = KEY_BACK if sz < 0 else KEY_BACK + BLACK_LEN - (0.012 if up else 0.0)
				return (c + sx * (tw if up else bw) / 2, BLACK_Y[1] if up else BLACK_Y[0], z)
			m.block(corner, bevel=0.0008, segs=1, grain="z", drop=("-y", "-z"), black=1.0)
			pivot = (c, BLACK_Y[0], KEY_BACK)
		else:
			xl = left(n)
			hl, hr = xl + gap / 2, xl + p - gap / 2
			tl = max(hl, black_centre(n - 1) + bw / 2 + clear) if is_black(n - 1) else hl
			tr = min(hr, black_centre(n + 1) - bw / 2 - clear) if is_black(n + 1) else hr
			zs = KEY_BACK + SPLIT
			outline = [(tl, KEY_BACK), (tr, KEY_BACK), (tr, zs), (hr, zs), (hr, KEY_FRONT), (hl, KEY_FRONT), (hl, zs), (tl, zs)]
			outline = [q for i, q in enumerate(outline) if q != outline[i - 1]]
			top = WHITE_Y[1] - (0.002 if n in BARE else 0.0)
			m.prism(outline, "y", WHITE_Y[0], top, bevel=0.0008, segs=1, grain="z", drop=("-y", "-z"),
				bare=1.0 if n in BARE else 0.0, chip=CHIPPED.get(n, 0))
			pivot = ((hl + hr) / 2, WHITE_Y[0], KEY_BACK)
		keys.append(m.finish(origin=pivot, parent=root))
	assert sum(1 for k in range(21, 109) if not is_black(k)) == 52
	return keys


# --- materials -----------------------------------------------------------------

def case_material(slot, yaw):
	"""Aged dark wood, tarnished brass pedals and dark felt, under dust that stops at the hymnal's outline."""
	g = kit.Graph("piano_case_src")
	col, rough, height, edge = kit.aged_wood(g, dark="#2a160a", light="#45260f", worn="#5a3a20", bloom="#6e6458")
	brass = g.attr("metal")
	bc, br, bm, bh = kit.brass(g)
	col = g.mix(brass, col, bc)
	rough = g.lerp(brass, rough, br)
	height = g.lerp(brass, height, bh)
	felt = g.attr("dark")
	col = g.mix(felt, col, srgb("#0b0908"))
	rough = g.lerp(felt, rough, 1.0)
	# feet kept the pedals' tops fairly clean, and wear the edges
	keep = g.math("MAXIMUM", g.mul(_hymnal_outline(g, slot, yaw), 0.92), g.math("MAXIMUM", g.mul(edge, 0.6), g.mul(brass, 0.85)))
	col, rough, height, dusty = kit.dust(g, col, rough, height, amount=0.8, keep=keep)
	g.finish(col, rough, g.mul(g.mul(brass, bm), g.inv(dusty)), height, bump=0.35, distance=0.0005)
	return g


def _hymnal_outline(g, slot, yaw):
	"""1 inside the hymnal's footprint on the lid, with a slightly ragged edge."""
	pos = g.geo("Position")
	c = kit.G(*slot)
	local = g.node("ShaderNodeVectorRotate", [("Vector", pos), ("Center", c), ("Angle", -math.radians(yaw))],
		rotation_type="Z_AXIS").outputs[0]
	d = g.xyz(g.vec("ABSOLUTE", g.vec("SUBTRACT", local, c), (0.0, 0.0, 0.0)))
	ragged = g.mul(g.math("SUBTRACT", g.noise(pos, 90.0, 2.0), 0.5), 0.004)
	inside = 1.0
	for axis, size in (("X", HYMNAL[0]), ("Y", HYMNAL[1])):
		inside = g.mul(inside, g.ramp(g.add(d[axis], ragged), size / 2 - 0.002, size / 2 + 0.004, 1.0, 0.0))
	return g.mul(inside, g.ramp(g.xyz(pos)["Z"], slot[1] - 0.01, slot[1] - 0.003))


def keys_material():
	"""Yellowed ivory over bare wood, and worn ebony, with dust on top."""
	g = kit.Graph("piano_keys_src")
	black, bare, chip, rand = g.attr("black"), g.attr("bare"), g.attr("chip"), g.attr("rand")
	o = g.obj()
	ox, oy, oz = (g.xyz(o)[k] for k in "XYZ")      # across, back to front (negative) and up, from the pivot
	n = g.xyz(g.geo("Normal"))
	top = g.ramp(n["Z"], 0.7, 0.9)
	front = g.ramp(n["Y"], -0.9, -0.7, 1.0, 0.0)
	# ivory, yellowed unevenly key to key, with a faint lengthwise grain and a hairline where the
	# head and tail pieces were glued on
	streaks = g.noise(g.stretch(o, 500.0, 6.0, 500.0), 1.0, 2.0)
	ivory = g.mix(rand, srgb("#d4c7a4"), srgb("#b9a379"))
	ivory = g.mix(g.mul(streaks, 0.3), ivory, srgb("#b49f75"))
	seam = g.mul(g.ramp(g.math("ABSOLUTE", g.add(oy, SPLIT)), 0.0002, 0.0006, 1.0, 0.0), top)
	ivory = g.mix(g.mul(seam, 0.6), ivory, srgb("#7d6c50"))
	# fingers polished the fronts; grime gathered toward the back and in the gaps
	played = g.ramp(oy, -0.15, -0.12, 1.0, 0.0)
	ao = g.node("ShaderNodeAmbientOcclusion", [("Distance", 0.02)], samples=8).outputs["AO"]
	grime = g.add(g.mul(g.inv(ao), 0.8), g.ramp(oy, -0.04, 0.0, 0.0, 0.4))
	ivory = g.mix(g.mul(grime, 0.5), ivory, srgb("#6e5d40"))
	# the wood under the ivory: key sides, lost tops and chips
	wood = g.mix(g.noise(g.stretch(o, 300.0, 4.0, 300.0), 1.0, 3.0), srgb("#b39a74"), srgb("#8a7050"))
	wood = g.mix(g.mul(g.ramp(g.noise(o, 400.0, 2.0), 0.55, 0.7), 0.5), wood, srgb("#6b5536"))
	corner = g.node("ShaderNodeCombineXYZ", [("X", g.math("SUBTRACT", ox, g.mul(chip, 0.0105))),
		("Y", g.add(oy, KEY_FRONT - KEY_BACK))]).outputs[0]
	near = g.add(g.node("ShaderNodeVectorMath", [(0, corner)], operation="LENGTH").outputs["Value"],
		g.mul(g.noise(o, 900.0, 2.0), 0.0015))
	chipped = g.mul(g.mul(g.ramp(near, 0.0045, 0.006, 1.0, 0.0), g.ramp(g.math("ABSOLUTE", chip), 0.4, 0.6)),
		g.ramp(oz, 0.016, 0.018))
	on_top = g.math("MAXIMUM", top, g.ramp(oz, 0.0195, 0.0202))
	ivory_on = g.mul(g.math("MAXIMUM", g.mul(on_top, g.inv(bare)), front), g.inv(chipped))
	white = g.mix(ivory_on, wood, ivory)
	white_rough = g.lerp(ivory_on, 0.85, g.lerp(played, 0.55, 0.42))
	# ebony, worn brown at the edges
	bevel = g.node("ShaderNodeBevel", [("Radius", 0.0015)], samples=8).outputs[0]
	worn = g.ramp(g.inv(g.node("ShaderNodeVectorMath", [(0, bevel), (1, g.geo("Normal"))],
		operation="DOT_PRODUCT").outputs["Value"]), 0.02, 0.08)
	ebony = g.mix(g.noise(g.stretch(o, 200.0, 3.0, 200.0), 1.0, 3.0), srgb("#120f0d"), srgb("#1f1915"))
	ebony = g.mix(g.mul(worn, 0.7), ebony, srgb("#3e2d20"))
	col = g.mix(black, white, ebony)
	rough = g.lerp(black, white_rough, g.lerp(worn, 0.55, 0.75))
	height = g.add(g.mul(streaks, 0.1), g.add(g.mul(seam, -1.0), g.mul(chipped, -1.5)))
	col, rough, height, _ = kit.dust(g, col, rough, height, amount=g.ramp(oy, -0.05, -0.01, 0.35, 0.0))
	g.finish(col, rough, 0.0, height, bump=0.2, distance=0.0003)
	return g


def main():
	args = kit.parse_args()
	kit.reset(args.quick)
	slot, yaw, plate = placement()
	assert 1.3 < slot[1] < 1.4, "the hymnal's slot should be on top of the piano"
	case, lid, fallboard, back = build_case(top=slot[1], face=plate[2] - 0.003)
	keys = build_keys()
	cm = case_material(slot, yaw)
	for o in (case, lid, fallboard):
		o.data.materials.append(cm.mat)
	km = keys_material()
	for k in keys:
		k.data.materials.append(km.mat)
	back.data.materials.append(kit.flat("piano_back", "#1c130c", 0.9))
	s = 1 if args.quick else 2
	maps = kit.maps_dir(args, "piano")
	kit.bake("case", [case, lid, fallboard], [cm], 1024 * s, 0.2, maps)
	kit.bake("keys", keys, [km], 512 * s, 0.03, maps)
	kit.report([case, lid, fallboard, back] + keys)
	kit.export(args.out)
	if args.blend:
		bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.blend))


main()
