# Still Here

*A first-person exploration game about abandoned places, the phone in your pocket, and the people who never left.*

> The building was looted, vandalized and left to rot. You came to explore it, document it, and put things back.
> As you do, the darkness lifts, and the people it remembers come back into view. They were always here.

---

## The idea

Urban explorers walk through abandoned hospitals, schools and factories, photograph everything, take nothing, and try to leave without disturbing anything. Every locked door makes you wonder what's behind it. Every building has a story.

**Still Here is a reverse looter.** The sites have already been stripped by scrappers and vandals. The player explores, photographs what they find, and asks their phone's AI assistant, **Bertha**, what they're looking at. Bertha's answers reveal the building's history, and quietly point toward what's missing and what could be set right.

Restoring things doesn't just tidy a room. It changes the soul of the place. As grime is cleared and objects return, the people who lived and worked there become visible again, carrying on their ordinary days: a nurse writing the night report, women singing around the day room piano, supper at five. They never left. Neglect only made them impossible to see.

This is a personal project, built for the joy of building it and playing it.

## Design pillars

1. **Respect over spectacle.** The residents are never monsters. Asylum imagery sets a mood; it is never used to mock or frighten at the residents' expense.
2. **Real places, human stories.** Buildings are modeled on real historic sites from public records, plans and photos. The history is real; the individual people are composites.
3. **The player is a witness, not a visitor.** The residents are memories, not spirits. They never interact with the player, never notice them, never acknowledge them. They live on in what the player uncovers.
4. **Darkness first, warmth earned.** Every space starts cold, dark and unsettling. The fear at the start is what makes the warmth at the end land.
5. **The world tells you, not the HUD.** Progress, hints and goals come through the world and through Bertha, not through markers, checklists or progress bars.
6. **Reusable systems, not one-off scripts.** Buildings, photo subjects, restorations, cleanup and echoes are data-driven. New content is mostly new data.

## Core mechanic 1: Exploration through the phone

Exploration is the main mechanic, and the phone is how the player explores.

### Photograph and ask Bertha
- Raise the phone to get a viewfinder. Take a photo (with flash) of anything that catches your eye.
- The photo goes to Bertha with "What am I looking at?" After a short pause, her answer streams in like a real AI response: what the object is, what it was for, and the history around it.
- Bertha is entirely scripted data, not a live AI call. Every answer is written per subject and per state.
- Framing matters: the subject has to be reasonably centered, close enough and not blocked. A vague photo gets a vague answer and a suggestion to get closer.

### Why it works
Lots of people point their phones at things and ask an AI what they are, every day, for everything. The habit feels natural immediately, and the player comes to rely on Bertha. That reliance is what makes losing her tense.

### Layered discovery
- **Wide shots** give the general picture: a piano, a ward station, a dining room.
- **Close-ups** of details unlock more: a maker's plate, a stencil, a label.
- **State changes the answer.** Bertha describes what's actually in front of her. Before restoration she sees the empty counter; after, she sees the lamp turned toward the hall.
- **Cleaning changes the answer.** "There's writing here, but the paint's too thick to read." Scrub it, photograph again, and Bertha reads it to you.

### Bertha as the hint system
Bertha's answers carry the hints, written as history rather than instructions:

- *"Night staff often kept a lamp burning at the station, so patients who woke up frightened could see someone was there."* The counter is empty. The player works out what's missing.
- **Answers are assembled from the current state.** Each restoration carries its own hint lines; Bertha includes only the ones still relevant ("a small round spot on the counter, cleaner than the wood around it").
- **Escalating hints.** The first photo is subtle. Photograph the same spot again later while still stuck, and Bertha gets a little more specific. Players who want to puzzle it out never need to ask twice.
- **Pointing toward next goals.** Bertha's history can mention where things went, what lies deeper in the building, or what a room used to connect to.
- **Optional follow-up questions** (idea): two or three scripted questions after an answer, for players who want more.
- **Not a quest log.** Hints stay inside the story. Some objects get only their history and no hint at all, so players keep reading for the history, not skimming for tasks.

### Dust shadows
When something sits in one place for decades and is then taken, it leaves a clean silhouette in the dust. Urbex photographers capture these all the time. They replace any glowing outlines or markers: subtle on screen, real-world, and something Bertha can describe ("a cleaner rectangle, as if a book sat here for a long time").

### Signal as tension
- **Dead zones with a reason:** tunnels, basements, and interior rooms deep inside thick masonry walls.
- **No signal means no Bertha.** Photos are saved and queued as "waiting for signal."
- **Answers arrive later.** Coming back into range delivers a burst of answers about what you found below. Resurfacing becomes its own small reward.
- **Finding signal** can be a small goal: holding the phone up by a window for one bar.

### The camera sees more than you do
Rarely, maybe once per area, a flash photo captures something the player didn't see: faint figures around the piano before it's restored. Bertha notices them too: *"There appear to be several people standing around the piano in your photo. Is this a recent picture? As far as I know, this building has been closed since 1989."* The residents aren't reacting to anyone; the camera simply catches what's always there.

### The phone as the toolkit
- **Gallery:** every photo is saved; the phone becomes the scrapbook of the building.
- **Before and after:** photographing the same subject before and after restoring it pairs the two shots automatically.
- **Journal:** the building's history and the notes, letters and writing the player finds live on the phone too.

## Core mechanic 2: Restoration

Restoration is the second mechanic, quieter and more subtle. It's about the effect the player has on the soul of the building and the people in it.

### Restoration verbs
Every fix uses a small set of reusable verbs, defined in data:

| Verb | Example |
|---|---|
| **place** | Return the desk lamp to the nurses' station |
| **upright** | Set a knocked-over chair back on its feet |
| **sweep** (hold) | Clear a rubble pile to uncover what's buried |
| **scrub** (hold) | Wipe away grime and graffiti to reveal what's underneath |
| **read** | A letter, a stencil, a page in the day book |
| **use** | Ring the restored call bell |

Later restorations get more involved: multi-step repairs (restore power to run the dumbwaiter, find replacement hammers to fix the piano) and history puzzles (match day book entries to the right beds, piece together a torn photograph).

### Cleanup
Two separate systems:

- **Piles:** physical junk covering things. Hold to clear; pieces tumble away with dust and sound until what's underneath is free.
- **Grime layer:** a dirty overlay on surfaces with a paintable mask. Scrubbing reveals the clean surface, and sometimes something hidden, like pencil writing protected for decades under spray paint.

### Presence
Each zone has a presence value from 0 to 1 that rises as it's restored. It drives fog density and color, ambient light, wall tint, which lights flicker on, how far decay recedes, and the sound mix. Progress is shown through the world itself, not through on-screen counters.

### Echoes
Groups of residents tied to specific restorations:

- **Nurses' station:** the night nurse writing her report.
- **Day room:** a pianist, women gathered around singing and swaying, a woman at the bay window.
- **Dining room:** women at supper, an attendant pouring tea.

Echoes fade in by degrees through a dissolve shader (blocky noise, soft rim glow, gentle shimmer). Before they're earned, the player catches brief glimpses at the edge of vision. Each figure is a body, a pose and a looping routine from a small library: sit, stand, sway, play, write, sip, pour.

**Echoes never interact with the player.** No eye contact, no reaction, no acknowledgment. They live their ordinary day; the player is there to witness it.

### Proximity cues
Unrestored places of significance call softly when the player is near: the hymn faint and muffled near the piano, a clock ticking near the station, a murmur near the dining room. Warm motes drift in the air and the screen edges glow faintly. The cues fade once the place is restored and the echoes take over.

## Sound
Sound does much of the emotional work, and the soundtrack assembles itself as the player restores:

- The cold drone of the abandoned ward.
- Running water in the tunnels from no clear direction, under a long tunnel reverb, with occasional drips.
- The day room hymn (New Britain, 1835, public domain: the Amazing Grace melody) with piano and soft voices.
- Supper-time murmur and teacups.

## First location: Northern Michigan Asylum, Building 50

Traverse City, Michigan. Chosen because it's well documented, still standing, and sat empty for years before being restored in real life.

- Opened November 30, 1885, Michigan's third state asylum.
- Building 50 was designed by Gordon W. Lloyd on the Kirkbride plan, Victorian Italianate, built of yellow-white brick from the Markham brickworks in Greilickville.
- A shallow V: wings step back from the center so every ward could see Grand Traverse Bay. Women in the north wings, men in the south.
- Kirkbride's model ward: a parlor, a dining room served by a dumbwaiter from the central kitchen, single rooms off a wide corridor, a small dormitory watched from an attendant's room, a bath room.
- Brick tunnels beneath the grounds were part of the ventilation system; fans pushed air through them into the basements and up flues in the walls.
- Walls more than two feet thick in places.
- The original center section was demolished in 1963. The hospital closed in 1989 after serving more than 50,000 patients and stood vacant for about a decade. Restoration began in 2002.

### Prototype story: Ward 3 North (invented)
A women's ward in the north wing. The night nurse, **Margaret Hale**, kept the lamp on all night so anyone who woke up frightened would see someone was there. Her day book records small victories: a patient finishing her supper, eleven women singing hymns on a snowy afternoon. Under a layer of spray paint in the corridor is her pencil roster of the day room choir. A letter from a daughter, Ruth, promises a Sunday visit to her mother, who sits at the bay window watching the water. All composites.

## What the browser prototype proved

A lo-fi browser prototype (Three.js, one HTML file, built in a single session) tested the core ideas. What worked:

- **The darkness lifting.** Watching the ward come back to life as things were restored was satisfying and clearly tied to the player's actions.
- **The echoes.** The nurse appearing at her station was a strong moment. The day room was the emotional high point: the women fading in around the piano and swaying while the hymn played.
- **The tunnels.** A barrel-vaulted brick tunnel modeled on explorers' photos captured the feeling of those photos. Running water from nowhere, layered against the hum from upstairs, was effective with just two sounds.
- **The phone and Bertha** (named Wren in the prototype). Photographing, getting a streamed answer, and learning the history felt natural immediately. The ghost photo at the piano landed. No signal in the tunnels created real tension: it felt like a bug until the answers arrived after coming back upstairs, which turned out to be exactly right.
- **Cleanup.** Sweeping a pile off the lamp and scrubbing paint off a wall to find the choir roster underneath were satisfying, and the reveal gave the cleanup a purpose.
- **The journal.** Filling in the human side of a place the player may already know the facts about worked well.
- **Proximity cues.** Hearing the hymn faintly near the unrestored piano drew the player toward it.

What needs work:

- **Too pixelated.** The final game wants more visual fidelity: clean low-poly geometry, crisp textures, little or no pixelation.
- **Ghosts up close** looked like glass jars; softening them near the camera fixed it.
- **Gamey signals** like glowing outlines and progress diamonds should give way to dust shadows and the world itself.
- **Puzzles** were deliberately trivial. Real puzzle design is the biggest remaining design job.
- **Collision gaps** let the player walk out of the building.

## Art direction

- Low-poly geometry with crisp, characterful textures.
- Lighting carries the mood, in the spirit of Valheim: simple shapes, beautiful light and fog.
- Dim interiors that suit the subject and hide rough edges.
- Asset sources: purchased modular kits (FBX/GLB), photos used as reference only, and eventually the project's own photos and photogrammetry from site visits.

## Tech

- **Engine:** Godot 4, GDScript.
- **Why Godot:** scenes and resources are plain text, so Claude Code can build and edit scenes directly, run the project headless, read errors and fix them. Lightweight, open source, and well suited to indoor first-person games.
- **Lighting:** baked lightmaps for static spaces, real-time global illumination where useful, volumetric fog, dynamic lights driven by presence.
- **Approach:** everything data-driven. Wards, photo subjects and Bertha's answers, hints, restorations, echoes, notes and cues all live in data files; code provides the reusable systems.
- **Phone photos:** capture the viewport to an image for the gallery; subject detection by view direction, screen position, distance and an occlusion check.
- **Dev setup:** Windows machine with WSL2 and Claude Code; Godot editor on Windows. A `CLAUDE.md` will pin conventions (Godot 4 API only, folder layout, naming, data-driven rules).

## Roadmap

1. **`CLAUDE.md` and project setup:** repo structure, conventions, data formats for wards, photo subjects, restorations and echoes.
2. **Vertical slice:** one ward of Building 50 built from the real plans, with lighting, the phone and Bertha, dust shadows, cleanup, three restorations and one echo group.
3. **Puzzle design pass:** deeper, multi-step and history-based restorations, with Bertha's hints written alongside them.
4. **The tunnels:** their own darkness, their own dead zone, their own chapter.
5. **More of Building 50**, then other places.

## Open questions

- What is the explorer's own story, if any? Why are they here?
- Is there any tool progression (bare hands, broom, scrub brush, restoration kit), or is the building's response the only reward?
- How large is a chapter: a ward, a wing, a building?
- Should Bertha offer follow-up questions, or only answer photos?
- Which real sites come after Building 50?

## Principles for real places

- Use real, public, sourced history for buildings and institutions.
- Keep residents and staff as composites; never invent stories about real, named people.
- Treat the people of these places with dignity.
- Credit sources in the journal.
