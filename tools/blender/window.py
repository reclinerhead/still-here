"""The ward's windows: tall double-hung wooden sashes from the 1880s, exported to
assets/models/<model>.glb for each model the zone's window types name.

    blender --background --python tools/blender/window.py -- --out-dir assets/models

Four-over-four sashes painted white and flaking to grey wood, a narrow casing, a projecting
interior sill over an apron, and a plastered reveal that runs out past our thin walls to the
depth of real masonry ones. Outside the glass is a diamond wire-mesh guard, as on the hospital's
wards, and a sheet of weathered plywood that boarded windows show.

Coordinates are the window's frame in Godot's axes: origin on the floor under the middle of the
opening, on the wall's inner face; +z faces into the room and the wall runs back to z = -0.2.
The opening's size (width, sill, top) comes from window_types in the zone data.

In Godot, every pane of glass is glass/<sash>_<row>_<col> (sash upper or lower, row 0 at the
bottom, col 0 on the left as seen from the room), so the game can hide, swap or break one.
`plywood` is shown only on boarded windows; `guard` is the wire mesh and its frame.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
from kit import srgb  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
ZONE = os.path.join(ROOT, "data", "sites", "nma", "b50", "w3n", "zone.json")

LINING = 0.012      # plaster lining the reveal
FRAME_W = 0.048     # the frame's jambs and head, inside the lining
FRAME = (-0.44, -0.30)  # the frame's depth: outer and inner faces
STILE = 0.05        # sash stiles and top rail
MUNTIN = 0.02
LOWER_Z = (-0.345, -0.305)  # the lower sash runs in the inner track
UPPER_Z = (-0.395, -0.355)
GUARD_Z = -0.425
MESH = 0.05         # the guard's diamonds, wire to wire
PLY_Z = (-0.47, -0.452)


def models():
	"""Each model the zone's window types name, with its opening's width, sill and top."""
	with open(ZONE, encoding="utf-8") as f:
		types = json.load(f)["window_types"]
	out = {}
	for t in types.values():
		size = (float(t["width"]), float(t["sill"]), float(t["top"]))
		assert out.setdefault(t["model"], size) == size, f"window types sharing {t['model']} must be one size"
	return out


# --- geometry ------------------------------------------------------------------

def build(width, sill, top):
	"""The frame and trim (one mesh), the panes, the guard and the plywood."""
	hw = width / 2.0
	m = kit.Mesh("frame", floats=("plaster", "brass", "ply"), seed=12)
	# the reveal, lined with plaster from the wall's face back to the frame. The lining runs on
	# into the wall and keeps its back faces: past our thin wall it alone stops the moonlight.
	into = 0.02
	for s in (-1, 1):
		m.box((s * (hw + (into - LINING) / 2), (sill + top) / 2, FRAME[1] / 2), (LINING + into, top - sill, -FRAME[1]),
			grain="y", plaster=1.0)
	m.box((0.0, top + (into - LINING) / 2, FRAME[1] / 2), (width + 2 * into, LINING + into, -FRAME[1]), plaster=1.0)
	# the frame: jambs, head, and a sill running out past the wall to shed water
	inner = hw - LINING - FRAME_W
	fz = (FRAME[0] + FRAME[1]) / 2
	fd = FRAME[1] - FRAME[0]
	for s in (-1, 1):
		m.box((s * (inner + FRAME_W / 2), (sill + top) / 2, fz), (FRAME_W, top - sill, fd), bevel=0.003, grain="y")
		# stop beads holding the lower sash, on the room side
		m.box((s * (inner - 0.007), (sill + top) / 2, FRAME[1] + 0.004), (0.014, top - sill - 0.1, 0.018), bevel=0.003, grain="y")
	m.box((0.0, top - LINING - FRAME_W / 2, fz), (2 * inner, FRAME_W, fd), bevel=0.003)
	m.box((0.0, sill + 0.02, (FRAME[1] - 0.52) / 2), (width, 0.04, 0.52 + FRAME[1]), bevel=0.004)
	# sashes; the meeting rails overlap where they cross
	clear_lo, clear_hi = sill + 0.04, top - LINING - FRAME_W
	meet = (clear_lo + clear_hi) / 2
	sx = inner - 0.005
	panes = []
	for sash, (z0, z1), y0, y1, bottom in (("lower", LOWER_Z, clear_lo, meet + 0.018, 0.075),
			("upper", UPPER_Z, meet - 0.018, clear_hi, 0.035)):
		zc, zd = (z0 + z1) / 2, z1 - z0
		rail_top = 0.035 if sash == "lower" else STILE
		for s in (-1, 1):
			m.box((s * (sx - STILE / 2), (y0 + y1) / 2, zc), (STILE, y1 - y0, zd), bevel=0.003, grain="y")
		m.box((0.0, y0 + bottom / 2, zc), (2 * sx, bottom, zd), bevel=0.003)
		m.box((0.0, y1 - rail_top / 2, zc), (2 * sx, rail_top, zd), bevel=0.003)
		gx, gy0, gy1 = sx - STILE, y0 + bottom, y1 - rail_top
		gm = (gy0 + gy1) / 2
		m.box((0.0, gm, zc), (2 * gx, MUNTIN, zd * 0.7), bevel=0.002)
		m.box((0.0, (gy0 + gy1) / 2, zc), (MUNTIN, gy1 - gy0, zd * 0.7), bevel=0.002, grain="y")
		for row, (py0, py1) in enumerate(((gy0, gm), (gm, gy1))):
			for col, (px0, px1) in enumerate(((-gx, 0.0), (0.0, gx))):
				panes.append((f"{sash}_{row}_{col}", (px0, px1, py0, py1, zc)))
	# brass: the sash lock on the meeting rails, and two lifts on the lower sash
	m.box((0.0, meet + 0.024, LOWER_Z[1] - 0.012), (0.06, 0.012, 0.035), bevel=0.002, brass=1.0)
	m.box((0.012, meet + 0.034, LOWER_Z[1] - 0.008), (0.035, 0.008, 0.012), bevel=0.002, brass=1.0)
	for x in (-0.22, 0.22):
		m.box((x, clear_lo + 0.03, LOWER_Z[1] + 0.008), (0.03, 0.022, 0.016), bevel=0.003, brass=1.0)
	# trim on the room side: casing, a cap over the head, the projecting sill and its apron
	cw, ct = 0.1, 0.03
	for s in (-1, 1):
		m.box((s * (hw + cw / 2), (sill + 0.03 + top) / 2, ct / 2), (cw, top - sill - 0.03, ct), bevel=0.004, grain="y", drop=("-z",))
	m.box((0.0, top + 0.06, ct / 2), (width + 2 * cw, 0.12, ct), bevel=0.004, drop=("-z",))
	m.box((0.0, top + 0.1325, 0.022), (width + 2 * cw + 0.04, 0.025, 0.044), bevel=0.006, segs=3, drop=("-z",))
	horn = hw + cw + 0.03
	stool = [(-hw, LOWER_Z[1]), (hw, LOWER_Z[1]), (hw, 0.0), (horn, 0.0), (horn, 0.035), (-horn, 0.035), (-horn, 0.0), (-hw, 0.0)]
	m.prism(stool, "y", sill - 0.005, sill + 0.03, bevel=0.005, segs=2)
	m.box((0.0, sill - 0.07, 0.009), (width + 2 * cw - 0.04, 0.13, 0.018), bevel=0.003, drop=("-z",))
	frame = m.finish()

	root = kit.empty("glass")
	glass = []
	for name, (x0, x1, y0, y1, zc) in panes:
		p = kit.Mesh(name)
		cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
		p.box((cx, cy, zc), (x1 - x0 + 0.01, y1 - y0 + 0.01, 0.003), drop=("+x", "-x", "+y", "-y", "-z"))
		glass.append(p.finish(origin=(cx, cy, zc), parent=root))

	ply = kit.Mesh("plywood", floats=("ply",), seed=13)
	ply.box((0.0, (sill + 0.04 + top) / 2, (PLY_Z[0] + PLY_Z[1]) / 2), (width + 0.04, top - sill - 0.04, PLY_Z[1] - PLY_Z[0]),
		bevel=0.003, grain="y", ply=1.0)
	return frame, glass, ply.finish(), _guard(inner, clear_lo, clear_hi)


def _guard(inner, y0, y1):
	"""Diamond wire mesh in a flat iron frame, just outside the upper sash."""
	g = kit.Mesh("guard")
	x0, x1 = -inner + 0.004, inner - 0.004
	bar = 0.025
	for s in (-1, 1):
		g.box((s * (inner - 0.004 - bar / 2), (y0 + y1) / 2, GUARD_Z), (bar, y1 - y0, 0.006))
	for y in (y0 + bar / 2, y1 - bar / 2):
		g.box((0.0, y, GUARD_Z), (x1 - x0, bar, 0.006))
	# wires along both diagonals, clipped to the frame
	step = MESH * math.sqrt(2.0)
	for slope in (1.0, -1.0):
		lo = y0 - slope * (x1 if slope > 0 else x0)
		hi = y1 - slope * (x0 if slope > 0 else x1)
		c = lo + step / 2
		while c < hi:
			ends = _clip(slope, c, x0, x1, y0, y1)
			if ends:
				_wire(g, *ends, GUARD_Z + 0.004 * slope)
			c += step
	return g.finish()


def _clip(slope, c, x0, x1, y0, y1):
	"""The part of the line y = slope * x + c inside the rectangle, as two (x, y) points."""
	pts = []
	for x in (x0, x1):
		y = slope * x + c
		if y0 <= y <= y1:
			pts.append((x, y))
	for y in (y0, y1):
		x = (y - c) / slope
		if x0 < x < x1:
			pts.append((x, y))
	pts = sorted(set(pts))
	return (pts[0], pts[-1]) if len(pts) >= 2 and pts[0] != pts[-1] else None


def _wire(g, a, b, z, t=0.004):
	dx, dy = b[0] - a[0], b[1] - a[1]
	n = math.hypot(dx, dy)
	px, py = -dy / n * t / 2, dx / n * t / 2

	def corner(sx, sy, sz):
		x, y = a if sx < 0 else b
		return (x + sy * px, y + sy * py, z + sz * t / 2)
	g.block(corner)


# --- materials -----------------------------------------------------------------

def frame_material():
	"""White paint flaking off grey wood, cream paint off plaster in the reveal, brass fittings,
	weathered plywood; dust on everything that faces up."""
	g = kit.Graph("window_frame_src")
	wood = kit.bare_wood(g, dark="#5a534a", light="#8a8274")
	col, rough, height, _ = kit.painted(g, wood, paint="#c4bca6", peel=0.4)
	pl = g.attr("plaster")
	pcol, prough, pheight, _ = kit.painted(g, kit.plaster(g), paint="#b9ad8e", peel=0.28, scale=4.0)
	col, rough, height = g.mix(pl, col, pcol), g.lerp(pl, rough, prough), g.lerp(pl, height, pheight)
	ply = g.attr("ply")
	ycol, yrough, yheight = kit.bare_wood(g, dark="#6b6152", light="#9d927d")
	col, rough, height = g.mix(ply, col, ycol), g.lerp(ply, rough, yrough), g.lerp(ply, height, yheight)
	brass = g.attr("brass")
	bc, br, bm, bh = kit.brass(g)
	col, rough, height = g.mix(brass, col, bc), g.lerp(brass, rough, br), g.lerp(brass, height, bh)
	col, rough, height, dusty = kit.dust(g, col, rough, height, amount=0.6, keep=g.mul(brass, 0.7))
	g.finish(col, rough, g.mul(g.mul(brass, bm), g.inv(dusty)), height, bump=0.4, distance=0.0006)
	return g


def glass_material():
	"""Old glass: a thin grey film all over, heavier in the corners against the frame, with
	streaks run down from rain and a few spots."""
	g = kit.Graph("window_glass_src")
	pos = g.geo("Position")
	ao = g.node("ShaderNodeAmbientOcclusion", [("Distance", 0.06)], samples=16).outputs["AO"]
	corners = g.ramp(g.inv(ao), 0.05, 0.6)
	streaks = g.mul(g.ramp(g.noise(g.stretch(pos, 40.0, 40.0, 2.0), 1.0, 3.0), 0.6, 0.8), 0.2)
	spots = g.mul(g.ramp(g.noise(pos, 45.0, 2.0), 0.7, 0.76), 0.5)
	film = g.ramp(g.noise(pos, 6.0, 4.0), 0.3, 0.7, 0.12, 0.26)
	dirt = g.math("MINIMUM", g.add(g.add(corners, streaks), spots), 1.0)
	col = g.mix(dirt, srgb("#6f7473"), srgb("#3d3830"))
	alpha = g.add(film, g.mul(dirt, 0.6))
	height = g.add(g.mul(g.noise(g.stretch(pos, 3.0, 3.0, 9.0), 1.0, 2.0), 0.4), g.mul(dirt, 0.2))
	g.finish(col, g.lerp(dirt, 0.3, 0.8), 0.0, height, bump=0.15, distance=0.002, alpha=alpha)
	return g


def main():
	args = kit.parse_args(out_dir=True)
	for model, (width, sill, top) in models().items():
		kit.reset(args.quick)
		frame, glass, ply, guard = build(width, sill, top)
		fm = frame_material()
		for o in (frame, ply):
			o.data.materials.append(fm.mat)
		gm = glass_material()
		for o in glass:
			o.data.materials.append(gm.mat)
		guard.data.materials.append(kit.flat("guard", "#3a3029", 0.85, 0.4))
		s = 1 if args.quick else 2
		maps = kit.maps_dir(args, model)
		kit.bake("frame", [frame, ply], [fm], 1024 * s, 0.25, maps)
		kit.bake("glass", glass, [gm], 512 * s, 0.1, maps)
		kit.report([frame, ply, guard] + glass)
		kit.export(os.path.join(args.out_dir, f"{model}.glb"))


main()
