# Still Here: notes for Claude Code

Still Here is a personal first-person exploration game built in Godot. Read `README.md` for the design and `docs/data-model.md` for how content is structured. This file covers how to work in the code.

## Engine and language
- **Godot 4.7.x, standard build (not .NET).** GDScript only. Use the Godot 4 API; never Godot 3 names (`KinematicBody`, `Spatial`, `yield`, `export var`, etc.).
- Renderer: Forward+. Lighting uses SDFGI, volumetric fog, SSAO and glow.
- Indent with tabs.

## Layout
```text
project.godot            autoloads: Data (content), State (runtime state)
scenes/main.tscn         one node; scripts/main.gd builds everything from data
scripts/core/            data loading, state store, condition language, input map
scripts/world/           ward builder (with fallen ceilings and windows), tunnel builder (stairs and
                         service tunnel), the view outside, props (imported models or primitives),
                         materials, procedural textures, debris and paint-flake drifts, dust,
                         restorations, echoes, presence
scripts/player/          first-person controller, flashlight, interaction ray
scripts/phone/           phone camera UI, photo gallery, and Bertha's answer assembly
scripts/ui/              HUD: prompt, toasts, captions, found notes, title
scripts/audio/           procedurally generated ambience and one-shots
shaders/ghost.gdshader   the echo dissolve shader
shaders/decay.gdshader   layered decay for walls, floors, ceilings and wood (see Materials)
shaders/night_sky.gdshader  the night sky and the bay seen from the windows (see The view outside)
data/                    all content (see below)
assets/fonts/            open-licensed fonts with their licences
assets/textures/         CC0 PBR texture sets from Poly Haven, credited in CREDITS.md
assets/models/           .glb props built by tools/blender/, with the textures Godot extracts from them
tools/blender/           Blender build scripts for the models (see Models)
tools/shot.ps1           screenshots that don't take focus (see Running and checking)
docs/                    design and data model docs
```

## Rules
1. **Content lives in `data/`, never in scripts.** Scripts implement systems (verbs, echoes, Bertha, presence); data says which objects, where, what Bertha says, and under which conditions. If you find yourself writing an object ID or a sentence of game text in GDScript, it belongs in a data file.
2. **One source of truth.** Visuals and Bertha both read `State`. Change state through `State` methods, not by poking nodes.
3. **Honest history.** Historical claims in Bertha fragments cite fact IDs; facts cite sources. Mark anything invented `"basis": "invented"`. Never invent stories about real, named people.
4. **Residents never interact with the player.** No eye contact, reaction or acknowledgment in any echo routine.
5. **Placeholder art is fine.** A prop uses `assets/models/<model>.glb` when there is one and otherwise falls back to primitives in `scripts/world/props.gd`, so the game always runs. Models replace placeholders under the same model names; data never changes.
6. **Free assets only, and credited.** Downloaded assets must be CC0 or similarly open, get Todd's OK first, and go in `CREDITS.md`. Reference photos are reference only, never textures.

## Materials
- `scripts/world/mats.gd` builds every material once, by name. Architecture is projected in world space (triplanar), so boxes need no UVs and textures line up across pieces.
- Walls, floor, ceiling and wood use `shaders/decay.gdshader`: layer A (paint, tiles, wood) breaks away to layer B (bare plaster and brick, concrete) where a large-scale noise mask says so, worse near the floor, with grime along the broken edges and water streaks down the walls. It can repaint saturated red paint (`a_recolor`, used to turn `peeling_painted_wall` green), re-tint a whole layer (`a_colorize`, for wood) and lift dark tones (`a_gamma`). The presence tint is its `tint` parameter.
- Smaller things use `_pbr(set, metres, tint)`: a standard material from one set, with `metres` being the set's real-world size from Poly Haven. A few props stay flat colours.
- **Never put two faces in different materials on one plane.** The GPU can't tell which is in front, so they flicker as the camera moves or turns (z-fighting). Faces in the same world-projected material shade alike, so their overlaps don't show. Where trim meets a wall, end one at the other or stop it short: the door jambs fill the walls' ends, and `wall()` stops the chair rail at a window's casing and `RAIL_STOP` (5 mm) short of a bare wall end.
- **Adding a texture set:** put the three 2K JPGs (`diff`, `nor_gl`, `arm`) in `assets/textures/<set>/`, run `godot --headless --path . --import`, then edit each new `.import` to `compress/mode=2` (VRAM), `mipmaps/generate=true` and `detect_3d/compress_to=0`, plus `compress/normal_map=1` on the `nor_gl` map. Materials are built in code, so the editor can't detect these settings itself. Delete the files' entries in `.godot/imported` and import again, then credit the set.

## Models
- Props can be scripted Blender models: `tools/blender/<model>.py` builds the geometry, gives it procedural materials, bakes them to textures and exports `assets/models/<model>.glb`. Everything is generated, so a model rebuilds the same way every time. `kit.py` holds what the next props reuse: bevelled pieces with per-piece wood-grain attributes; the aged-wood, bare-wood, plaster, flaking-paint, brass and dust layers; baking and export. `piano.py` is the worked example; `window.py` writes several models in one run with `--out-dir assets/models`.
- **Blender 5.2.2 LTS**, installed on bluejay at `C:\Program Files\Blender Foundation\Blender 5.2\`. Build from the project root, then import:
  `"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools/blender/piano.py -- --out assets/models/piano.glb`
  then `godot --headless --path . --import`. Add `--quick` for half-size textures and fewer samples while iterating, `--maps <dir>` to keep the baked maps and `--blend <file>` to save the scene for a look in Blender.
- Scripts write coordinates in Godot's axes (`kit.G()` converts): origin on the floor at the prop's centre, front facing +Z, the same frame as the placeholder, so data positions still fit. Pieces carry only a position (their pivot), never a rotation or scale.
- Each atlas bakes to colour, ORM (occlusion, roughness, metal) and a tangent-space normal map; a see-through material (glass) puts alpha in its colour map and exports two-sided. Godot extracts them next to the .glb as `<model>_<atlas>_<map>`; give their `.import` the same settings as a texture set (see Materials) once, and they keep them through rebuilds.
- Models carry no collision. `props.gd` `COLLIDERS` holds every prop's box, for models and placeholders alike; `ward_builder.gd` keeps a solid box in each window opening.
- Keep wood matte (roughness around 0.9): the flashlight sits at the camera, so even 4% specular on dark varnish reads as a grey sheen, and SSR shows the room in anything glossier. Compare with the station counter under the flashlight.
- The windows: `window.py` builds one model per `model` named in the zone's `window_types`, sized to that type's opening, with the window's origin on the floor under the opening's middle, on the wall's inner face. It is four-over-four double-hung sashes painted white and flaking, casing, interior sill and apron, a plastered reveal that runs out past the thin wall (it alone stops the moonlight there, so keep it closed), a diamond wire guard (`guard`) and plywood (`plywood`, kept only on boarded windows). Each pane is `glass/<sash>_<row>_<col>` (`upper` or `lower`, row 0 at the bottom, col 0 on the left from the room), so code can hide, swap or break one; panes cast no shadow. The guard is its frame (`guard/bars`) and a panel of mesh over each pane, `guard/mesh_<sash>_<row>_<col>`, pivoted on its top edge so it can be torn back. Windows on the south side are turned to face their room. A frosted window's panes get `glass_frosted` (nearly opaque, glowing with the moon behind it); a broken one loses its eye-level panes (`lower_1_*`) to teeth of glass, its guard panels there torn back, with glass on the sill and floor (`ward_builder.gd` `_break`).
- The piano: each key is `keys/key_<midi>` (21 to 108) with its pivot on its back edge, so `rotation.x = deg_to_rad(3.5)` presses it; the lid (hinged at its back edge) and fallboard (hinged at its bottom front edge, `rotation.x = PI / 2` closes it) are separate nodes. `piano.py` reads the hymnal's slot and the maker's plate from `objects.json`: the clean rectangle in the lid's dust is baked from the hymnal's footprint and yaw, and the open fallboard's face sits behind the plate. Rebuild if either moves.

## The view outside
- `scripts/world/outside.gd` builds it from `Data.outside`. Far off, `shaders/night_sky.gdshader` is the environment's sky: it paints by compass bearing at infinity, so every window shows the same view in its own direction. A profile texture made from the data gives, per bearing, the top of the land against the sky (`far_land`), where the water starts below the horizon (`near_shore`), and town and shore light densities; the shader adds stars, the moon, its glow and the glitter path on the water from the moon light's direction, and goes black underground.
- Nearer, the hillside falls away from the north wall (`ground`: drop, slope, reach), with `trees` and `houses` (lit windows) placed by bearing and distance from `origin`, so each window sees them from where it is. They are unshaded, the slope shaded by hand from the moon's direction: nothing outside follows presence. The player camera's far plane (1500 m) is what lets them show.
- Bearings: 0 is north (-Z), east positive (+X). Heights in the profile are exaggerated about three times so the bay reads from a window; the shape follows a map of the hospital and the south end of the bay's West Arm.
- Fog volumes with negative density clear the air beyond the long walls (above ground only, so the tunnel keeps its fog): the view stays crisp behind the room's own haze. The sky neither lights the ward nor shows in its reflections (`reflected_light_source` off, `sdfgi_read_sky_light` false).

## Data files
- Data is **JSON for now** (Godot parses it natively). The data model doc describes YAML; switching is an open question.
- IDs are currently relative to the single zone (`station.lamp`). Full namespacing (`nma.b50.w3n.station.lamp`) comes when there is more than one zone.
- Conditions use the tiny language in `scripts/core/conditions.gd`: `missing(id)`, `placed(id)`, `carried(id)`, `state(id) == "x"`, `done(id)`, `hint_level(id) >= n`, `photos(id) >= n`, `revealed(id)`, `flag(name)`, `presence() >= x`, combined with `and`, `or`, `not`.
- A Bertha subject with `"area": [x0, x1, z0, z1]` instead of `pos` answers for a whole place (the tunnel) when nothing specific is in frame.
- Echo figures take `"face": [x, z]` to turn toward a point instead of `rot_deg`. An echo's `"music"` block (melody and bass as MIDI notes) is synthesized by `ambience.gd`: a faint, muffled cue near its centre before the echo is revealed, clear after.
- The zone's decay is data too: `debris` zones are `[x0, x1, z0, z1, count, walls]`, where `walls` names the sides that are walls (`n` = z0, `s` = z1, `w` = x0, `e` = x1) for paint flakes to drift against; `ceiling_holes` are where the plaster has come down; `dust` boxes fill the air with motes.
- An object's `dust_shadow` (`rect`, `round`, `round_small`) is the decal left in the dust at its home; `none` when the model it sits on has the shadow baked in (the hymnal on the piano).
- Window openings are data: a back-wall segment's `win` names one of the zone's `window_layouts` (`glass`, `boarded`, `pair`, `bay`), which places windows at offsets from the segment's centre, each with a kind (`glass`, `frosted` or `boarded`) and a type from `window_types` (width, sill, top, the casing's width and the model built for it; `window.py` builds the casing to that width, and the chair rail stops at it). All are 1.0 m wide, sill 0.9 m, top 3.1 m. Windows in one layout share a sill and top. A segment's `broken` lists windows (counted from the west) that are smashed at eye level.
- The view outside is the site's `outside` block in `site.json` (see The view outside).
- Restoration groups put their completion toast in `on_complete.toast`. One-time toasts for places live in the zone's `triggers` (a box plus a y range); the tunnel's layout, bulbs, stencil text and water are in the zone's `stair` and `tunnel` blocks.

## Running and checking
Godot on Todd's PC (bluejay) lives in `D:\Tools\GODOT4`. When running commands, use the **console** build so errors and `print` output reach the terminal:
- From Windows (PowerShell/cmd): `D:\Tools\GODOT4\Godot_v4.7.2-stable_win64_console.exe`
- From WSL: `/mnt/d/Tools/GODOT4/Godot_v4.7.2-stable_win64_console.exe` (pass Windows-style paths to `--path` and `--shot`, e.g. via `wslpath -w`)

The plain `Godot_v4.7.2-stable_win64.exe` is for the editor and prints nothing to the terminal. Examples below use `godot` for whichever console exe applies.

Save screenshots to `shots/` in the project (ignored by git) with an absolute path, e.g. `--shot=D:/path/to/still-here/shots/station.png`, then open the PNG to look at it. `user://` also works but lands in `%APPDATA%\Godot\app_userdata\Still Here\`.

- Play: open the project in the editor and press F5, or `godot --path .`
- **Headless smoke test** (catches script errors): `godot --headless --path . --quit-after 200`
- **Preview Bertha** for any subject and state:
  `godot --headless --path . -- --bertha=station [--restore] [--photos=2]`
- **Screenshot** from a pose, optionally restored or with a phone photo:
  `godot --path . -- --shot=user://shot.png --pose=x,y,z,yaw,pitch [--restore] [--photo] [--before-after] [--gallery] [--no-flashlight] [--frames=40]`
  (`--before-after` photographs, restores everything, photographs again; `--gallery` opens the gallery on the last photo.)
- **On bluejay, take screenshots with `tools/shot.ps1`**, not Godot directly: a plain run's window jumps in front of whatever Todd is doing. `tools/shot.ps1 <name> <pose> [flags]`, e.g. `tools/shot.ps1 dayroom 18,0,0.6,0,4 restore`, saves `shots/<name>.png` from a window placed off-screen that never takes focus (a temporary `override.cfg` sets `display/window/size/no_focus`). Headless runs can't take screenshots: the dummy renderer never draws a frame.
  Useful poses: corridor `1.2,0,0,-90,-3`; station `17.6,0,-0.9,180,-12`; day room `18,0,0.6,0,4` (add `--restore` for the choir); top of the stairs `26,0,2.2,180,-35`; tunnel from the bottom of the stairs `26,-3.4,9,180,0`; the hymnal by the collapse `26,-3.4,45,180,-15`.
- Procedural textures are cached in `user://tex_cache`. Bump `CACHE_VERSION` in `proc_tex.gd` after changing a generator.

After any change: run the smoke test; for visual changes, take a screenshot and look at it.

## Coordinates (Ward 3 North)
- The corridor runs along +X from 0 to 36 m; north is −Z, south is +Z.
- Corridor half-width 1.8 m, rooms 3.7 m deep, walls 0.2 m, ceilings 4 m.
- Nurses' station: south alcove, x 15 to 21. Day room: north alcove, x 14 to 22.
- Stair room (the old bath room): south room, x 24 to 28. The stair opening is x 25.1 to 26.9 from z 2.6; 16 steps run down to y −3.4 at z 7.6. The walking surface is one smooth ramp collider under the visible steps.
- Service tunnel: a barrel vault of radius 1.45 m on x 26, axis at y −2.35, floor at y −3.4, running z 7.6 to 53.6, with the collapse from z 51. No phone signal from z 5.8 on. Underground (by eye height) the tunnel's own fog and ambient take over and ignore presence.
- Facing: yaw −90° looks down the corridor (+X); 180° looks south; 0° looks north.
