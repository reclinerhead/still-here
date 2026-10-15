# Handoff: the basement stairs, service tunnel and day room hymnal

The browser prototype (`docs/prototype/ward3north.html`) had a stairwell down to a brick service tunnel under Ward 3 North. It didn't make it into the Godot slice. The tunnel is where the player finds the **day room hymnal**. Putting that hymnal back on the piano is the restoration that brings back the day room echo (the choir around the piano). So this one job covers three things: the basement, the hymnal restoration and the day room echo.

Read `CLAUDE.md` first. The rules there apply, especially: content goes in `data/`, state changes go through `State`, and residents never react to the player.

Note: in the prototype the phone assistant was called **Wren**. In Godot she is **Bertha**.

## What the Godot slice already has
- The piano and bench in the day room, at `[15.2, 0, -5.18]`.
- The Bertha subjects `piano` and `piano_plate`. One piano fragment already hints at the hymnal: "There's a clean rectangle in the dust on top, as if a book sat there for a long time."
- The ward day book (`doc.day_book`) mentions "Played hymns on the day room piano after lunch. Eleven ladies sang."
- Facts `nma.fact.tunnels_ventilation` and `nma.fact.markham_brick` in `data/sites/nma/site.json`.
- Signal dead spaces: `zone.signal.dead_spaces` as `[x0, x1, z0, z1]` boxes, checked by `phone.has_signal_here()`. The list is currently empty.
- The place verb with a dust-shadow slot (used for the lamp, day book and bell), plus restoration groups that start an echo when complete.

## What to build

### 1. The stair room
- In `zone.json`, change the south room at **x 24 to 28** from `"door": "locked"` to open, and name it `stair`. It is the room after the nurses' station.
- Cut a stair opening in the floor at **x 25.1 to 26.9, z 2.6 onward**. The floor will need splitting around the hole.
- Add an iron railing on both sides of the opening (rusty, about 0.95 m high, three posts per side), plus a broken sink or tub against the west wall, since this was the old bath room.
- 16 steps go down from floor level (y 0) at z 2.6 to the tunnel floor (**y −3.4**) at **z 7.6**. They continue through the room's back wall into a brick-lined shaft (walls at x 25.2 and 26.8).
- The player controller needs to walk the stairs. Use a ramp collider or step-up handling, whichever is simpler.

### 2. The service tunnel
Sketched from explorers' photos of the real tunnels, not from plans. Mark it `"basis": "inferred"` in data.
- Shape: a **barrel vault**, radius **1.45 m**, centered on **x 26** with its axis at **y −2.35** (floor y −3.4). It runs from **z 7.6 to z 53.6** (46 m south, away from the building).
- **Brick:** yellow-tan running bond (the Markham brick). Darker toward the floor and sweating. Add a procedural brick generator in `proc_tex.gd` and bump `CACHE_VERSION`.
- **Floor:** wet brick pavers, shiny, with dark reflective puddles (about 9).
- **Pipes along the walls:** one at upper left, a large one at lower right, and a thin cable and conduit along the crown. Rusty brackets every 3 m.
- **Bulbs:** bare bulbs down the center line at **z 13, 19, 25, 31, 37, 43, 49**. Every other one casts light (warm, short range, about 7.5 m). The one at **z 25 flickers**. The far ones fade into the dark.
- **Stencil:** on the west wall at **x 24.6, z 16**, at about eye level: "← BLDG 50" and "LAUNDRY →".
- **Debris on the floor:** scattered paper and small rubble.
- **Collapse:** the far end (from **z 51 to 53.6**) is a pile of brick and plaster rubble against a bricked end wall. This is the dead end.
- **Air:** the tunnel has its own atmosphere and stays the same as the ward is restored. Blend fog and ambient by how far below ground the player is. Use darker, brownish fog (prototype color `#0b0905`) and very low ambient, regardless of presence.

### 3. Sound
- **Running water:** close by but impossible to place. In the prototype it was band-passed noise (about 850 Hz) whose stereo pan wandered slowly, a lighter trickle layer (about 2.5 kHz) and a low rumble (below about 260 Hz). It went mostly through a long reverb (about 2.6 s).
- It is **faintly audible upstairs near the stair room** (within about 14 m of `[26, 0, 4]`) and gets **much louder underground**.
- **Drips:** occasional short downward-pitched blips, randomly panned, underground only.
- Upstairs ambience (drone, air, restoration pad) should duck underground.
- Generate all of this procedurally in `ambience.gd`, like the rest of the audio. No audio files.

### 4. Toasts (one-time, from data)
- On reaching the top of the stairs: "Stairs going down. Somewhere below, water is running."
- On first entering the tunnel proper: "The old service tunnels. The sound of water is everywhere and nowhere."

### 5. No signal underground
- Add a dead space covering the shaft and tunnel, roughly `[24.4, 27.6, 5.8, 53.6]`. Upstairs in the stair room should still have signal.
- Photos taken down there are queued and answered when the player comes back up. That system already exists.

### 6. The hymnal and its restoration
- **Object:** `dayroom.hymnal`, a small dark red hymnal, swollen from damp. It lies on the tunnel floor at **`[26.4, -3.4, 48.6]`**, rotated about 0.7 rad, just before the collapse. Add a `hymnal` model to `props.gd`.
- **Found note:** shown on pickup, as a new document in `story/documents.json`, `"basis": "invented"`:
  - Kicker: "Found in the tunnel, near the collapse"
  - Title: "Day room hymnal"
  - Body: "Swollen from the damp, the pages stuck together. Inside the cover, in pencil: "PROPERTY OF WARD 3 NORTH DAY ROOM. Please return to the piano. — M.H." Someone carried it a long way from home."
- **Slot:** on top of the piano at **`[15.2, 1.30, -5.12]`**, with the same dust-shadow decal as the station slots, matching the "clean rectangle in the dust" Bertha already mentions.
- **Restoration:** `dayroom.restore.hymnal` (verb `place`), in a new group `dayroom.all` → `echo.dayroom`.
- Restoring it should raise presence like the station restorations do. `presence_target` is already done/total, so it scales automatically.

### 7. The day room echo (`echo.dayroom`)
New entry in `echoes.json`. Caption document (invented): "March 9, 1953. Snow to the windowsills and the radiator ticking. Eleven ladies crowd around the day room piano, and Mrs. D. sings louder than anyone. At the bay window, Ruth's mother keeps one eye on the water."

Figures, using the existing routines in `echo_group.gd`:
- A pianist seated at the piano, `[15.2, -4.3]`, routine `play`.
- Six standing singers facing the piano (`[15.3, -4.75]`), routine `sway`, at `[16.4, -4.45]`, `[16.9, -3.75]`, `[16.1, -3.3]`, `[15.25, -3.25]`, `[14.5, -3.6]`, `[17.6, -4.3]`.
- One seated figure at the bay window, `[18.4, -4.75]`, routine `still`.
- Like all echoes, none of them ever look at or react to the player.

**The hymn:** New Britain (1835, public domain; the tune of Amazing Grace), in 3/4 with a pickup, beat about 0.66 s. Melody as `[MIDI note, beats]`:
```
[62,1],[67,2],[71,.5],[67,.5],[71,2],[69,1],[67,2],[64,1],[62,2],[62,1],[67,2],[71,.5],[67,.5],[71,2],[69,1],[74,3],
[74,2],[71,1],[74,2],[71,.5],[74,.5],[71,2],[67,1],[62,2],[64,1],[67,2],[64,.5],[62,.5],[67,2],[71,.5],[67,.5],[71,2],[69,1],[67,3]
```
Bass roots, one per bar starting at beat 1, each played as root + fifth + tenth (+0, +7, +16 semitones):
`43,43,48,43,43,43,50,50,43,43,48,43,43,50,43,43`. One loop is 52 beats.

Synthesize it as a soft piano tone with a quiet "choir" double of the melody. Generate the whole loop as one AudioStreamWAV on a worker thread, as the restoration pad already does.
- **Before restoration:** inaudible, except very faintly and muffled (low-pass about 650 Hz) when the player stands close to the piano. This is the proximity cue from the prototype.
- **After restoration:** clear (filter open), loudest in the day room, falling off over about 16 m, and nearly silent underground.

Keep it gentle. Todd found the earlier restored-ward chord jarring over time, so this should be pleasant and subtle but noticeable.

### 8. Bertha
New subjects and fragments in `fragments.json`:
- **`tunnel_stencil`** at `[24.61, -2.3, 16]`. Ident: stenciled lettering on brick, arrows to "Bldg 50" and "Laundry". History citing `nma.fact.tunnels_ventilation`: "This looks like one of the service tunnels under the hospital grounds. They were part of the ventilation system: big fans pushed fresh air through them into the basements and up flues inside the walls."
- **`tunnel`** (the general view down the tunnel, so a photo there doesn't fall through to the generic fallback). Ident: "A long barrel-vaulted tunnel in yellow-tan brick, with old pipes along the walls and bare bulbs down the middle." History citing `nma.fact.markham_brick`: "The brick looks like the same yellow-white kind used for Building 50 above, which was fired at the Markham brickworks in Greilickville." This may need a small "area subject" mechanism, chosen by player position when nothing specific is in frame.
- **`piano`**, new states:
  - Before: add a hint fragment pointing toward the basement, escalating with `hint_level(dayroom.restore.hymnal)`. For example, level 1 notes the empty music shelf; level 2 wonders whether the book was carried off somewhere below the ward. Keep it subtle.
  - After (`done(dayroom.restore.hymnal)`): "Same upright piano, and now there's a hymnal on top, open to a tune called New Britain. Most people know it as the melody of Amazing Grace." and "The room around it looks warmer than in your earlier photo. Whoever put that book back, it seems to belong there."
  - Ghost special (before restoration, once, sets a flag like the station's): "One more thing. There appear to be several people standing around the piano in your photo, five or six at least. Is this a recent picture? As far as I know, this building has been closed since 1989."
- Add `dayroom.restore.hymnal` to the piano subject's `hints_for`.
- Photos of the piano before and after should pair up in the gallery automatically, because the ident fragment changes.

## Checking it
- Smoke test after each step.
- Bertha previews: `--bertha=piano`, `--bertha=piano --restore`, `--bertha=tunnel_stencil`.
- Screenshot poses to add to `CLAUDE.md` once they look right (yaw 180 looks south, down the tunnel):
  - Top of the stairs: about `26,0,2.2,180,-35`
  - Tunnel, looking south from the bottom of the stairs: about `26,-3.4,9,180,0`
  - The hymnal by the collapse: about `26,-3.4,45,180,-15`
  - Day room after restoration: `18,0,0.6,0,4 --restore`
- `--restore` and `force_all()` should include the hymnal. Make sure `force_all()` handles an item that starts far away in the tunnel.
- The tunnel should feel dark but navigable with the flashlight. The water should feel directionless.

## Open choices (ask Todd if unsure)
- Whether the stair room door should be locked until the station is restored, to pace the player. The prototype left it open.
- Whether to add a cleanup step in the day room (the prototype had a painted-over pencil note behind the piano, the 1953 choir list, exposed by scrubbing). That's a separate feature; leave it for later unless asked.
