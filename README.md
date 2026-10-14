# Still Here

*A first-person exploration game about putting abandoned places back together, and finding that the people who lived there never left.*

> The building was looted, vandalized and left to rot. You came to put things back.
> As you do, the darkness lifts, and the people it remembers come back into view.

---

## The idea

Urban explorers walk through abandoned malls, factories, schools and hospitals, take nothing, and try to leave without disturbing anything. Every locked door makes you wonder what's on the other side. Every building has a story.

**Still Here is a reverse looter.** The sites have already been stripped by scrappers and vandals. Instead of scavenging, the player finds what was taken or wrecked, returns it to where it belongs, and restores the place to a snapshot of how it was when people lived and worked there.

The supernatural side: the people who spent their lives in these places never left. Neglect and abuse of the building made them invisible. Restoring the place lets them be seen again, carrying on their ordinary days: a nurse writing the night report, women singing around the day room piano, supper at five. Restoring their world is a way of paying respect to them.

This is a personal project, built for the joy of building and playing it.

## Design pillars

1. **Respect over spectacle.** The people of these places are never monsters. Asylum imagery is used to set a mood, never to mock or frighten at the residents' expense.
2. **Real places, human stories.** Locations are modeled on real historic buildings using public records, plans and photos. The history is real; the individual people are composites.
3. **Restoration is the reward.** No loot, no score for its own sake. The payoff is light returning, sound returning, and people returning.
4. **Darkness first, warmth earned.** Every space starts cold, dark and unsettling. The fear at the start is what makes the warmth at the end land.
5. **Reusable systems, not one-off scripts.** Buildings, restorations, cleanup and echoes are all data-driven, so new content is mostly new data.

## Core loop

1. **Explore** a dark, damaged space with a flashlight.
2. **Notice** what's missing or wrecked. Ghost outlines show where things belonged.
3. **Clean** to uncover things: sweep rubble piles, scrub away grime and graffiti.
4. **Find** the missing items, sometimes far away (the day room hymnal ends up in the service tunnels).
5. **Restore** by putting things back, setting them right, or repairing them.
6. **Witness** the space respond: lights flicker on, fog thins, the drone warms into music, and echoes of the residents fade into view.
7. **Learn** the human history as the journal fills in.

## Core systems

### Data-driven buildings
Each wing or ward is generated from a spec: segments of rooms, alcoves and solid walls; doors (open or locked); windows (glass, boarded, bay). The spec is traced from original floor plans. A modular kit (walls, corridors, doors, fixtures) turns the spec into geometry.

### Restoration verbs
Every fix is one of a small set of reusable verbs, defined in data:

| Verb | Example |
|---|---|
| **place** | Return the desk lamp to the nurses' station |
| **upright** | Set a knocked-over chair back on its feet |
| **read** | A letter, a stencil, a note in the day book |
| **ring / use** | Ring the restored call bell |
| **sweep** (hold) | Clear a rubble pile to uncover what's buried |
| **scrub** (hold) | Wipe away grime and graffiti to reveal what's underneath |

Later restorations get more involved: multi-step repairs (restore power to run the dumbwaiter, find replacement hammers to fix the piano) and history puzzles (match day book entries to the right beds, reassemble a torn photo).

### Presence
One value per zone, from 0 to 1, rising as restorations are completed. It drives fog density and color, ambient light, wall tint, which ceiling lights flicker on, how far decay recedes from the restored spot, and the sound mix (cold drone fading, warm chord rising).

### Echoes
Groups of ghostly residents tied to specific restorations:

- **Nurses' station:** the night nurse, writing her report.
- **Day room:** a pianist, women gathered around singing and swaying, a woman at the bay window.
- **Dining room:** women at supper, an attendant pouring tea.

Echoes fade in by degrees through a dissolve shader (blocky noise, soft rim glow, gentle shimmer). Before they're earned, the player catches brief glimpses at the edge of vision. Each figure is a body, a pose and a looping routine from a small library: sit, stand, sway, play, write, sip, pour. Echoes mostly don't notice the player, which makes the rare moment when one does matter.

### Cleanup
Two separate systems:

- **Piles:** physical junk covering things. Hold to clear; pieces tumble away with dust and sound.
- **Grime layer:** a dirty overlay on surfaces with a paintable mask. Scrubbing reveals the clean surface, and sometimes something hidden: pencil writing protected for decades under spray paint.

Cleaning raises presence, can be tracked per room for completionists, and doubles as discovery.

### Proximity cues
Unrestored points of interest call to the player when they're close: the hymn heard faintly and muffled near the piano, a clock ticking near the nurses' station, a murmur near the dining room. Warm motes drift in the air around them, and the screen edges glow faintly amber. The cues fade once the spot is restored.

### Journal
Fills in as the player explores:

- **The building:** real, sourced history.
- **Found in the ward:** notes, letters and writing the player discovers.
- **About this place:** what is real and what is invented.

The player may arrive knowing the basic facts. The journal fills in the human side.

### Sound
Sound does a lot of the emotional work. Layers are added per space and per echo: the cold drone of the abandoned ward, running water in the tunnels from no clear direction, the day room hymn, supper conversation. The soundtrack assembles itself as the player restores.

## First location: Northern Michigan Asylum, Building 50

Traverse City, Michigan. Chosen because it's well documented, still standing, and sat empty for years before being restored in real life.

- Opened November 30, 1885, Michigan's third state asylum.
- Building 50 was designed by Gordon W. Lloyd on the Kirkbride plan, Victorian Italianate, built of yellow-white brick from the Markham brickworks in Greilickville.
- A shallow V: wings step back from the center so every ward could see Grand Traverse Bay. Women in the north wings, men in the south.
- Kirkbride's model ward: a parlor, a dining room served by a dumbwaiter, single rooms off a wide corridor, a small dormitory watched from an attendant's room, a bath room.
- Brick tunnels beneath the grounds were part of the ventilation system; fans pushed air through them into the basements and up flues in the walls.
- The original center section was demolished in 1963. The hospital closed in 1989 after serving more than 50,000 patients and stood vacant for about a decade. Restoration began in 2002.

### The prototype story: Ward 3 North (invented)
A women's ward in the north wing. The night nurse, **Margaret Hale**, kept the lamp on all night so anyone who woke up frightened would see someone was there. Her day book records small victories: a patient finishing her supper, eleven women singing hymns on a snowy afternoon. A letter from a daughter, Ruth, promises a Sunday visit to her mother, who sits at the bay window watching the water. All composites.

## Art direction

- Low-poly geometry with crisp, characterful textures. Less pixelated than the browser prototype.
- Lighting carries the mood, in the spirit of Valheim: simple shapes, beautiful light and fog.
- Moody, dim interiors, which hide rough edges and suit the subject.
- Asset sources: purchased modular kits (FBX/GLB), photos used as reference only, and eventually the project's own photos and photogrammetry from site visits.

## Tech

- **Engine:** Godot 4, GDScript.
- **Why Godot:** scenes and resources are plain text, so AI-assisted development (Claude Code) can build and edit scenes directly, run the project headless, read errors and fix them. Lightweight, open source, and well suited to indoor first-person games.
- **Lighting:** baked lightmaps for static spaces, real-time global illumination where useful, volumetric fog, dynamic lights driven by presence.
- **Approach:** everything data-driven. Buildings, restorations, echoes, notes and cues live in data files; code provides reusable systems.
- **Dev setup:** Windows machine with WSL2 and Claude Code; Godot editor on Windows. A `CLAUDE.md` will pin conventions (Godot 4 API only, folder layout, naming, data-driven rules).

## Prototype

A lo-fi browser prototype (Three.js, single HTML file) proved out the feel:

- A procedurally built Kirkbride ward with a flashlight, presence-driven fog, lights, decay and sound.
- Six restorations, three echo groups, a buried lamp to sweep out, a graffiti panel to scrub.
- A stairwell down into a barrel-vaulted brick service tunnel, modeled on explorers' photos, with running water you can't place.
- The day room hymn (New Britain, 1835, public domain) muffled and faint until the hymnal is returned.

## Roadmap

1. **Design doc:** expand this README into pillars, loop, scope and what's out of scope.
2. **Godot project setup:** repo structure, `CLAUDE.md`, data formats for wards, restorations and echoes.
3. **Vertical slice:** one ward of Building 50 from the real plans, with lighting, cleanup, three restorations and one echo group.
4. **Puzzle design pass:** deeper, multi-step and history-based restorations.
5. **The tunnels:** their own darkness and their own chapter.
6. **More of Building 50**, then other places.

## Open questions

- What is the explorer's own story, if any? Why are they here?
- Is there a currency or tool progression (broom → brush → restoration kit), or is presence the only reward?
- How much should echoes acknowledge the player?
- How large is a "chapter": a ward, a wing, a building?
- Which real sites come after Building 50?

## Principles for real places

- Use real, public, sourced history for buildings and institutions.
- Keep residents and staff as composites; never invent stories about real, named people.
- Treat the people of these places with dignity.
- Credit sources in the journal.
