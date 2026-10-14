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
scripts/world/           ward builder, props, materials, procedural textures, debris,
                         restorations, echoes, presence
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

## Running and checking
Godot binary on Windows: wherever `Godot_v4.7.2-stable_win64.exe` was unzipped. Examples below use `godot`.

- Play: open the project in the editor and press F5, or `godot --path .`
- **Headless smoke test** (catches script errors): `godot --headless --path . --quit-after 200`
- **Preview Bertha** for any subject and state:
  `godot --headless --path . -- --bertha=station [--restore] [--photos=2]`
- **Screenshot** from a pose, optionally restored or with a phone photo:
  `godot --path . -- --shot=user://shot.png --pose=x,y,z,yaw,pitch [--restore] [--photo] [--before-after] [--gallery] [--no-flashlight] [--frames=40]`
  (`--before-after` photographs, restores everything, photographs again; `--gallery` opens the gallery on the last photo.)
  Useful poses: corridor `1.2,0,0,-90,-3`; station `17.6,0,-0.9,180,-12`; day room `18,0,0.6,0,4`.
- Procedural textures are cached in `user://tex_cache`. Bump `CACHE_VERSION` in `proc_tex.gd` after changing a generator.

After any change: run the smoke test; for visual changes, take a screenshot and look at it.

## Coordinates (Ward 3 North)
- The corridor runs along +X from 0 to 36 m; north is −Z, south is +Z.
- Corridor half-width 1.8 m, rooms 3.7 m deep, walls 0.2 m, ceilings 4 m.
- Nurses' station: south alcove, x 15 to 21. Day room: north alcove, x 14 to 22.
- Facing: yaw −90° looks down the corridor (+X); 180° looks south; 0° looks north.
