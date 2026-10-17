"""Shared helpers for the scripted Blender models in tools/blender/ (piano.py shows the pattern).

A build script runs in Blender with no window open:

    blender --background --python tools/blender/<model>.py -- --out assets/models/<model>.glb

It builds geometry from bevelled pieces (Mesh), gives it procedural materials (Graph, with the
aged wood, brass and dust layers below), bakes those into textures (bake: colour; occlusion,
roughness and metal packed as glTF ORM; tangent-space normal) and writes a .glb (export).

Geometry is written in Godot's axes (x right, y up, z toward the viewer) and converted by G():
Blender is z-up with the front facing -y, and the glTF exporter turns that back into Godot's frame.
"""

import argparse
import math
import os
import random
import sys
import tempfile

import bmesh
import bpy
from mathutils import Vector


def G(x, y, z):
	"""A point in Godot's axes, in Blender's."""
	return Vector((x, -z, y))


def srgb(h):
	"""A '#rrggbb' colour as the linear RGBA that node sockets take."""
	c = [int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
	return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c) + (1.0,)


def parse_args():
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	p = argparse.ArgumentParser()
	p.add_argument("--out", required=True, help="the .glb to write")
	p.add_argument("--maps", help="keep the baked texture maps in this folder (default: a temp folder)")
	p.add_argument("--blend", help="also save the .blend here, to look at in Blender")
	p.add_argument("--quick", action="store_true", help="half-size textures and few samples, for iterating")
	return p.parse_args(argv)


def reset(quick=False):
	"""An empty scene set up for baking with Cycles, on the GPU if there is one."""
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.world = bpy.data.worlds.new("world")
	scene.cycles.samples = 8 if quick else 64
	print("kit: baking on", _use_gpu())


def _use_gpu():
	prefs = bpy.context.preferences.addons["cycles"].preferences
	for kind in ("OPTIX", "CUDA", "HIP", "ONEAPI", "METAL"):
		try:
			prefs.compute_device_type = kind
		except TypeError:
			continue
		prefs.refresh_devices()
		found = [d for d in prefs.devices if d.type == kind]
		if found:
			for d in prefs.devices:
				d.use = d.type == kind
			bpy.context.scene.cycles.device = "GPU"
			return f"{kind} ({found[0].name})"
	bpy.context.scene.cycles.device = "CPU"
	return "CPU"


# --- geometry ------------------------------------------------------------------

_DIRS = {"+x": (1, 0, 0), "-x": (-1, 0, 0), "+y": (0, 1, 0), "-y": (0, -1, 0), "+z": (0, 0, 1), "-z": (0, 0, -1)}


class Mesh:
	"""One mesh built from bevelled pieces. Every vertex carries the per-piece attributes that
	the materials read: 'grain' (position along the wood grain, then across it, in metres, offset
	so each board shows a different part of the log), 'rand' (one random number per piece) and
	any extra floats named here and set per piece (metal=1.0 and so on).

	Each piece takes: bevel (edge radius in metres), segs (bevel segments), grain ('x', 'y' or
	'z': the axis the grain runs along) and drop (sides never seen, such as '-y' for a bottom on
	the floor, left out to save texture space)."""

	def __init__(self, name, floats=(), seed=0):
		self.name = name
		self.floats = tuple(floats)
		self.rng = random.Random(seed)
		self.co = []
		self.faces = []
		self.attrs = {k: [] for k in ("grain", "rand") + self.floats}

	def block(self, corner, **kw):
		"""Six sides; corner(sx, sy, sz) gives the corner on each side (signs +-1) in Godot axes."""
		def make(bm):
			v = {}
			for sx in (-1, 1):
				for sy in (-1, 1):
					for sz in (-1, 1):
						v[sx, sy, sz] = bm.verts.new(G(*corner(sx, sy, sz)))
			for axis in range(3):
				a, b = [i for i in range(3) if i != axis]
				for s in (-1, 1):
					quad = []
					for p, q in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
						k = [0, 0, 0]
						k[axis], k[a], k[b] = s, p, q
						quad.append(v[tuple(k)])
					bm.faces.new(quad)
		self._piece(make, **kw)

	def box(self, c, size, **kw):
		h = [s / 2.0 for s in size]
		self.block(lambda sx, sy, sz: (c[0] + sx * h[0], c[1] + sy * h[1], c[2] + sz * h[2]), **kw)

	def prism(self, outline, axis, a0, a1, **kw):
		"""An outline extruded along axis from a0 to a1. Outline points are (z, y) for 'x', (x, z)
		for 'y' and (x, y) for 'z': a side view, a top view and a front view."""
		def pt(u, v, a):
			return {"x": (a, v, u), "y": (u, a, v), "z": (u, v, a)}[axis]

		def make(bm):
			lo = [bm.verts.new(G(*pt(u, v, a0))) for u, v in outline]
			hi = [bm.verts.new(G(*pt(u, v, a1))) for u, v in outline]
			bm.faces.new(lo)
			bm.faces.new(hi)
			for i in range(len(outline)):
				j = (i + 1) % len(outline)
				bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
		self._piece(make, **kw)

	def lathe(self, profile, x, z, segs=16, **kw):
		"""A turned piece: profile is (radius, y) pairs from bottom to top, around a vertical axis at x, z."""
		def make(bm):
			rings = []
			for r, y in profile:
				rings.append([bm.verts.new(G(x + r * math.cos(t), y, z + r * math.sin(t)))
					for t in (2.0 * math.pi * i / segs for i in range(segs))])
			for a, b in zip(rings, rings[1:]):
				for i in range(segs):
					j = (i + 1) % segs
					bm.faces.new((a[i], a[j], b[j], b[i]))
			bm.faces.new(rings[0])
			bm.faces.new(rings[-1])
		self._piece(make, **kw)

	def _piece(self, make, bevel=0.0, segs=2, grain="x", drop=(), **attrs):
		bm = bmesh.new()
		make(bm)
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
		if bevel:
			edges = [e for e in bm.edges if e.calc_face_angle(0.0) > 0.5]
			bmesh.ops.bevel(bm, geom=edges, offset=bevel, offset_type="OFFSET", segments=segs, profile=0.5,
				affect="EDGES", clamp_overlap=True)
		if drop:
			bm.normal_update()
			dirs = [G(*_DIRS[d]) for d in drop]
			gone = [f for f in bm.faces if any(f.normal.dot(d) > 0.99 for d in dirs)]
			bmesh.ops.delete(bm, geom=gone, context="FACES")
		# tangents (for the baked normals) need triangles and quads
		bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4], ngon_method="BEAUTY")
		r = self.rng
		off = Vector((r.uniform(0.0, 20.0), r.uniform(-0.3, 0.3), r.choice((-1, 1)) * r.uniform(0.1, 0.5)))
		rand = r.random()
		base = len(self.co)
		bm.verts.index_update()
		for v in bm.verts:
			x, y, z = v.co.x, v.co.z, -v.co.y
			along = {"x": (x, y, z), "y": (y, x, z), "z": (z, x, y)}[grain]
			self.co.append(v.co.copy())
			self.attrs["grain"].append(Vector(along) + off)
			self.attrs["rand"].append(rand)
			for k in self.floats:
				self.attrs[k].append(float(attrs.get(k, 0.0)))
		self.faces += [[base + v.index for v in f.verts] for f in bm.faces]
		bm.free()

	def finish(self, origin=(0.0, 0.0, 0.0), parent=None):
		"""The finished object, its origin (pivot) at origin. Shading is smooth with weighted
		normals, so bevels read as rounded edges while flat faces stay flat."""
		o = G(*origin)
		me = bpy.data.meshes.new(self.name)
		me.from_pydata([c - o for c in self.co], [], self.faces)
		me.update()
		me.attributes.new("grain", "FLOAT_VECTOR", "POINT").data.foreach_set(
			"vector", [c for v in self.attrs["grain"] for c in v])
		for k in ("rand",) + self.floats:
			me.attributes.new(k, "FLOAT", "POINT").data.foreach_set("value", self.attrs[k])
		me.shade_smooth()
		me.set_sharp_from_angle(angle=math.radians(50))
		obj = bpy.data.objects.new(self.name, me)
		obj.location = o
		bpy.context.scene.collection.objects.link(obj)
		obj.parent = parent
		mod = obj.modifiers.new("normals", "WEIGHTED_NORMAL")
		mod.keep_sharp = True
		with bpy.context.temp_override(object=obj, active_object=obj):
			bpy.ops.object.modifier_apply(modifier=mod.name)
		return obj


def empty(name, parent=None):
	obj = bpy.data.objects.new(name, None)
	bpy.context.scene.collection.objects.link(obj)
	obj.parent = parent
	return obj


# --- materials -----------------------------------------------------------------

class Graph:
	"""A procedural material's node tree, built a few terse calls at a time. Inputs take a
	socket, a number or a colour; most helpers return the output socket."""

	def __init__(self, name):
		self.mat = bpy.data.materials.new(name)
		self.nt = self.mat.node_tree
		self.nt.nodes.remove(self.nt.nodes["Principled BSDF"])
		self._cache = {}

	def node(self, kind, inputs=(), **props):
		n = self.nt.nodes.new(kind)
		for k, v in props.items():
			setattr(n, k, v)
		for i, v in inputs:
			self.put(n.inputs[i], v)
		return n

	def put(self, sock, v):
		if isinstance(v, bpy.types.NodeSocket):
			self.nt.links.new(v, sock)
		elif isinstance(v, (int, float)) and hasattr(sock.default_value, "__len__"):
			sock.default_value = (float(v),) * len(sock.default_value)
		else:
			sock.default_value = v

	def _shared(self, kind, out):
		if kind not in self._cache:
			self._cache[kind] = self.node(kind)
		return self._cache[kind].outputs[out]

	def geo(self, out):
		"""World-space 'Position' or 'Normal' (Blender axes: z is up)."""
		return self._shared("ShaderNodeNewGeometry", out)

	def obj(self):
		"""Object-space position: relative to the object's origin, in Blender axes."""
		return self._shared("ShaderNodeTexCoord", "Object")

	def attr(self, name, out="Factor"):
		return self.node("ShaderNodeAttribute", attribute_type="GEOMETRY", attribute_name=name).outputs[out]

	def xyz(self, v):
		return self.node("ShaderNodeSeparateXYZ", [(0, v)]).outputs

	def math(self, op, a, b=0.0):
		return self.node("ShaderNodeMath", [(0, a), (1, b)], operation=op).outputs[0]

	def add(self, a, b):
		return self.math("ADD", a, b)

	def mul(self, a, b):
		return self.math("MULTIPLY", a, b)

	def inv(self, a):
		return self.math("SUBTRACT", 1.0, a)

	def vec(self, op, a, b):
		return self.node("ShaderNodeVectorMath", [(0, a), (1, b)], operation=op).outputs[0]

	def stretch(self, v, sx, sy, sz):
		return self.vec("MULTIPLY", v, (sx, sy, sz))

	def ramp(self, x, lo, hi, a=0.0, b=1.0):
		"""Smoothstep from lo to hi, mapped to a..b."""
		return self.node("ShaderNodeMapRange", [(0, x), (1, lo), (2, hi), (3, a), (4, b)],
			interpolation_type="SMOOTHSTEP").outputs[0]

	def mix(self, fac, a, b, blend="MIX"):
		"""Colours."""
		return self.node("ShaderNodeMix", [(0, fac), (6, a), (7, b)], data_type="RGBA", blend_type=blend).outputs[2]

	def lerp(self, fac, a, b):
		"""Numbers."""
		return self.node("ShaderNodeMix", [(0, fac), (2, a), (3, b)], data_type="FLOAT").outputs[0]

	def noise(self, v, scale=1.0, detail=3.0, rough=0.5, out="Factor"):
		return self.node("ShaderNodeTexNoise", [("Vector", v), ("Scale", scale), ("Detail", detail),
			("Roughness", rough)]).outputs[out]

	def finish(self, color, rough, metal=0.0, height=None, bump=0.3, distance=0.0006):
		"""Wires the channels to a Principled BSDF; bake() reads them back from here."""
		p = self.node("ShaderNodeBsdfPrincipled", [("Base Color", color), ("Roughness", rough), ("Metallic", metal)])
		if height is not None:
			b = self.node("ShaderNodeBump", [("Height", height), ("Strength", bump), ("Distance", distance)])
			self.put(p.inputs["Normal"], b.outputs[0])
		self.put(self.nt.nodes["Material Output"].inputs["Surface"], p.outputs[0])
		self.bsdf = p
		self.channels = {"color": color, "rough": rough, "metal": metal}
		return self.mat


def flat(name, color, rough):
	"""A plain material with no textures, for faces nobody sees."""
	m = bpy.data.materials.new(name)
	m.use_backface_culling = True
	p = m.node_tree.nodes["Principled BSDF"]
	p.inputs["Base Color"].default_value = srgb(color)
	p.inputs["Roughness"].default_value = rough
	return m


def aged_wood(g, dark, light, worn="#5c3f27", bloom="#7d766c"):
	"""Old varnished wood left for decades: ring figure and pores along each board's grain,
	the varnish crazed in patches, tide-marked and bleached by water running down from above,
	faded in broad patches, worn through to paler wood on the edges and grimy in the corners;
	dull all over. dark and light are the grain's two colours. Returns colour, roughness,
	height and the edge-wear mask."""
	grain = g.attr("grain", "Vector")
	pos = g.geo("Position")
	n = g.xyz(g.geo("Normal"))
	wobble = g.vec("SUBTRACT", g.noise(g.stretch(grain, 1.2, 5.0, 5.0), out="Color"), (0.5, 0.5, 0.5))
	gw = g.vec("ADD", grain, g.vec("MULTIPLY", wobble, (0.0, 0.035, 0.035)))
	rings = g.node("ShaderNodeTexWave", [("Vector", gw), ("Scale", 70.0), ("Distortion", 2.0), ("Detail", 2.0),
		("Detail Scale", 0.5)], wave_type="RINGS", rings_direction="X", wave_profile="SAW").outputs["Factor"]
	late = g.ramp(rings, 0.55, 0.95)
	pores = g.ramp(g.noise(g.stretch(grain, 4.0, 900.0, 900.0), detail=1.0), 0.56, 0.7)
	col = g.mix(late, srgb(light), srgb(dark))
	col = g.mix(g.mul(pores, 0.5), col, srgb(dark), "MULTIPLY")
	board = g.attr("rand")
	col = g.mix(1.0, col, g.lerp(board, 0.82, 1.15), "MULTIPLY")
	col = g.mix(1.0, col, g.ramp(g.noise(pos, 30.0, 3.0), 0.3, 0.7, 0.9, 1.08), "MULTIPLY")
	# crazed varnish in patches
	cells = g.node("ShaderNodeTexVoronoi", [("Vector", grain), ("Scale", 110.0)],
		feature="DISTANCE_TO_EDGE").outputs["Distance"]
	craze = g.mul(g.ramp(cells, 0.0, 0.035, 1.0, 0.0), g.ramp(g.noise(g.vec("ADD", pos, (3.1, 0.0, 0.0)), 1.3), 0.4, 0.58))
	col = g.mix(g.mul(craze, 0.8), col, srgb("#0d0806"))
	# water: tide marks where puddles dried, and streaks down the vertical faces, worst near the top
	region = g.ramp(g.noise(g.vec("ADD", pos, (7.7, 1.3, 0.0)), 0.8, 2.0), 0.5, 0.66)
	t = g.noise(pos, 2.2, 1.5)
	tide = g.mul(g.ramp(g.math("ABSOLUTE", g.math("SUBTRACT", t, 0.57)), 0.0, 0.025, 1.0, 0.0), region)
	soaked = g.mul(g.ramp(t, 0.57, 0.62), region)
	upright = g.ramp(g.math("ABSOLUTE", n["Z"]), 0.2, 0.5, 1.0, 0.0)
	streak = g.ramp(g.noise(g.stretch(pos, 45.0, 45.0, 1.5), 1.0, 3.0), 0.58, 0.72)
	drip = g.mul(g.mul(streak, upright), g.ramp(g.xyz(pos)["Z"], 0.3, 1.25))
	drip = g.mul(drip, g.ramp(g.noise(g.vec("ADD", pos, (2.3, 5.1, 0.0)), 1.5, 2.0), 0.5, 0.65))
	col = g.mix(g.mul(soaked, 0.35), col, g.mix(0.6, col, srgb("#3b3530")))
	col = g.mix(g.add(g.mul(tide, 0.3), g.mul(drip, 0.25)), col, srgb(bloom))
	# the finish faded and greyed in broad patches
	faded = g.ramp(g.noise(g.vec("ADD", pos, (4.4, 0.7, 2.9)), 1.1, 3.0), 0.45, 0.7)
	col = g.mix(g.mul(faded, 0.3), col, g.mix(0.5, col, srgb("#3a3229")))
	# worn edges
	bevel = g.node("ShaderNodeBevel", [("Radius", 0.012)], samples=8).outputs[0]
	e = g.inv(g.node("ShaderNodeVectorMath", [(0, bevel), (1, g.geo("Normal"))], operation="DOT_PRODUCT").outputs["Value"])
	edge = g.ramp(g.mul(e, g.ramp(g.noise(pos, 30.0, 3.0), 0.4, 0.7, 0.0, 2.0)), 0.015, 0.06)
	col = g.mix(g.mul(edge, 0.7), col, srgb(worn))
	# grime in the corners and low down
	ao = g.node("ShaderNodeAmbientOcclusion", [("Distance", 0.06)], samples=8).outputs["AO"]
	grime = g.add(g.mul(g.inv(ao), 0.8), g.ramp(g.xyz(pos)["Z"], 0.0, 0.25, 0.3, 0.0))
	col = g.mix(g.mul(grime, 0.6), col, srgb("#120d09"))
	# dried-out varnish: dull, so the room barely shows in it
	rough = g.ramp(g.noise(pos, 12.0), 0.3, 0.7, 0.86, 0.94)
	rough = g.lerp(craze, rough, 0.95)
	rough = g.lerp(g.mul(soaked, 0.6), rough, 0.92)
	rough = g.lerp(g.add(tide, drip), rough, 0.95)
	rough = g.lerp(faded, rough, 0.95)
	rough = g.lerp(edge, rough, 0.93)
	rough = g.lerp(grime, rough, 0.97)
	height = g.add(g.add(g.mul(late, 0.15), g.mul(pores, -0.25)), g.add(g.mul(craze, -1.0), g.mul(edge, -0.2)))
	return col, rough, height, edge


def brass(g):
	"""Tarnished brass, dark and dull in patches. Returns colour, roughness, metal and height."""
	pos = g.geo("Position")
	tarnish = g.ramp(g.noise(pos, 14.0, 4.0), 0.25, 0.55)
	col = g.mix(tarnish, srgb("#9a7638"), srgb("#2e2214"))
	return col, g.lerp(tarnish, 0.42, 0.8), g.lerp(tarnish, 1.0, 0.35), g.mul(tarnish, 0.3)


def dust(g, color, rough, height, amount=0.8, side=0.015, keep=None, tint="#8c8576"):
	"""Decades of dust: thick on surfaces facing up, a film on the rest. keep (0 to 1) thins it
	where something kept it off. Returns colour, roughness, height and the dust mask."""
	pos = g.geo("Position")
	up = g.ramp(g.xyz(g.geo("Normal"))["Z"], 0.55, 0.95)
	vary = g.add(0.65, g.mul(g.math("SUBTRACT", g.noise(pos, 7.0, 4.0), 0.5), 0.6))
	m = g.add(g.mul(g.mul(up, amount), vary), g.mul(g.inv(up), side))
	if keep is not None:
		m = g.mul(m, g.inv(keep))
	m = g.math("MINIMUM", m, 1.0)
	fine = g.noise(pos, 140.0, 2.0)
	col = g.mix(m, color, g.mix(fine, srgb(tint), g.mix(0.25, srgb(tint), (1, 1, 1, 1))))
	return col, g.lerp(m, rough, 0.97), g.lerp(m, height, g.mul(fine, 0.3)), m


# --- baking and export --------------------------------------------------------

def _select(objs):
	if bpy.context.object and bpy.context.object.mode != "OBJECT":
		bpy.ops.object.mode_set(mode="OBJECT")
	for o in bpy.context.view_layer.objects:
		o.select_set(o in objs)
	bpy.context.view_layer.objects.active = objs[0]


def unwrap(objs, margin=0.003):
	"""One UV atlas shared by all of objs, islands scaled alike so texel density is even."""
	_select(objs)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.context.scene.tool_settings.use_uv_select_sync = True
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin)
	bpy.ops.uv.pack_islands(rotate=True, margin=margin)
	bpy.ops.object.mode_set(mode="OBJECT")


def bake(name, objs, graphs, size, ao_distance, maps_dir):
	"""Bakes the procedural materials (Graphs) used by objs into one atlas of textures, saved in
	maps_dir: <name>_color (sRGB), <name>_orm (occlusion, roughness, metal) and <name>_normal
	(tangent space, OpenGL convention like glTF and Godot). Then gives objs a single plain
	material, also called name, that uses them."""
	unwrap(objs)
	maps = {
		"color": _image(f"{name}_color", size, "sRGB"),
		"orm": _image(f"{name}_orm", size, "Non-Color"),
		"normal": _image(f"{name}_normal", size, "Non-Color"),
	}
	for g in graphs:
		g.target = g.node("ShaderNodeTexImage")
		g.nt.nodes.active = g.target
		g.emit = g.node("ShaderNodeEmission")
		ao = g.node("ShaderNodeAmbientOcclusion", [("Distance", ao_distance)], samples=16).outputs["AO"]
		g.orm = g.node("ShaderNodeCombineColor", [("Red", ao), ("Green", g.channels["rough"]),
			("Blue", g.channels["metal"])]).outputs[0]
	for key in ("color", "orm", "normal"):
		for g in graphs:
			g.target.image = maps[key]
			surface = g.nt.nodes["Material Output"].inputs["Surface"]
			if key == "normal":
				g.put(surface, g.bsdf.outputs[0])
			else:
				g.put(g.emit.inputs["Color"], g.channels["color"] if key == "color" else g.orm)
				g.put(surface, g.emit.outputs[0])
		_select(objs)
		print(f"kit: baking {name}_{key} at {size}px")
		bpy.ops.object.bake(type="NORMAL" if key == "normal" else "EMIT", margin=max(4, size // 128), use_clear=True)
	os.makedirs(maps_dir, exist_ok=True)
	for key, img in maps.items():
		ext = "jpg" if key == "color" else "png"
		img.file_format = "JPEG" if key == "color" else "PNG"
		img.filepath_raw = os.path.join(maps_dir, f"{img.name}.{ext}")
		img.save(quality=92)
	mat = _textured(name, maps)
	for o in objs:
		o.data.materials.clear()
		o.data.materials.append(mat)
	return mat


def _image(name, size, space):
	img = bpy.data.images.new(name, size, size, alpha=False)
	img.colorspace_settings.name = space
	return img


def _textured(name, maps):
	"""The export material, in the node layout the glTF exporter understands."""
	mat = bpy.data.materials.new(name)
	mat.use_backface_culling = True
	nt = mat.node_tree
	p = nt.nodes["Principled BSDF"]

	def tex(key):
		n = nt.nodes.new("ShaderNodeTexImage")
		n.image = maps[key]
		return n.outputs["Color"]

	nt.links.new(tex("color"), p.inputs["Base Color"])
	orm = nt.nodes.new("ShaderNodeSeparateColor")
	nt.links.new(tex("orm"), orm.inputs[0])
	nt.links.new(orm.outputs["Green"], p.inputs["Roughness"])
	nt.links.new(orm.outputs["Blue"], p.inputs["Metallic"])
	occlusion = nt.nodes.new("ShaderNodeGroup")
	occlusion.node_tree = _gltf_output()
	nt.links.new(orm.outputs["Red"], occlusion.inputs["Occlusion"])
	nm = nt.nodes.new("ShaderNodeNormalMap")
	nt.links.new(tex("normal"), nm.inputs["Color"])
	nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
	return mat


def _gltf_output():
	"""The custom node group the glTF exporter reads an occlusion texture from."""
	ng = bpy.data.node_groups.get("glTF Material Output")
	if ng is None:
		ng = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
		ng.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
	return ng


def maps_dir(args, model):
	return os.path.abspath(args.maps) if args.maps else os.path.join(tempfile.gettempdir(), f"still_here_{model}_maps")


def report(objs):
	tris = 0
	for o in objs:
		o.data.calc_loop_triangles()
		tris += len(o.data.loop_triangles)
	print(f"kit: {len(objs)} meshes, {tris} triangles")


def export(path):
	"""A binary glTF in Godot's frame: y up, metres, transforms as built (pieces carry only
	a position, the pivot), tangents included so the baked normals shade the same as in Blender."""
	path = os.path.abspath(path)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True,
		export_tangents=True, export_image_format="AUTO", export_extras=False, export_cameras=False,
		export_lights=False, export_animations=False, use_selection=False)
	print("kit: wrote", path)
