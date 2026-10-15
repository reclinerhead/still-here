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
scripts/world/           ward builder, tunnel builder (stairs and service tunnel), props,
                         materials, procedural textures, debris, restorations, echoes, presence
scripts/player/          first-person controller, flashlight, interaction ray
scripts/phone/           phone camera UI, photo gallery, and Bertha's answer assembly
scripts/ui/              HUD: prompt, toasts, captions, found notes, title
scripts/audio/           procedurally generated ambience and one-shots
shaders/ghost.gdshader   the echo dissolve shader
data/                    all content (see below)
assets/fonts/            open-licensed fonts with their licences
docs/                    design and data model docs
```

## Rules
1. **Content lives in `data/`, never in scripts.** Scripts implement systems (verbs, echoes, Bertha, presence); data says which objects, where, what Bertha says, and under which conditions. If you find yourself writing an object ID or a sentence of game text in GDScript, it belongs in a data file.
2. **One source of truth.** Visuals and Bertha both read `State`. Change state through `State` methods, not by poking nodes.
3. **Honest history.** Historical claims in Bertha fragments cite fact IDs; facts cite sources. Mark anything invented `"basis": "invented"`. Never invent stories about real, named people.
4. **Residents never interact with the player.** No eye contact, reaction or acknowledgment in any echo routine.
5. **Placeholder art is fine.** Props are built from primitives in `scripts/world/props.gd`. Later they get replaced by Blender-scripted or CC0 models under the same model names.

## Data files
- Data is **JSON for now** (Godot parses it natively). The data model doc describes YAML; switching is an open question.
- IDs are currently relative to the single zone (`station.lamp`). Full namespacing (`nma.b50.w3n.station.lamp`) comes when there is more than one zone.
- Conditions use the tiny language in `scripts/core/conditions.gd`: `missing(id)`, `placed(id)`, `carried(id)`, `state(id) == "x"`, `done(id)`, `hint_level(id) >= n`, `photos(id) >= n`, `revealed(id)`, `flag(name)`, `presence() >= x`, combined with `and`, `or`, `not`.
- A Bertha subject with `"area": [x0, x1, z0, z1]` instead of `pos` answers for a whole place (the tunnel) when nothing specific is in frame.
- Echo figures take `"face": [x, z]` to turn toward a point instead of `rot_deg`. An echo's `"music"` block (melody and bass as MIDI notes) is synthesized by `ambience.gd`: a faint, muffled cue near its centre before the echo is revealed, clear after.
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
