---
name: pettower-assets
description: The art and sound pipeline for PetTower - reusing the Game Asset Library, generating pet and Guardian models (Meshy), style sheets, triangle and texture budgets, importing into Studio, and sounds. Use this whenever the work involves models, pets' looks, icons, thumbnails, UI art, murals, music, jingles or any generated or imported asset for this project, or when the owner asks where or how the pets will be made.
---

# PetTower: art and sound pipeline

Nothing goes into the game until the owner has seen it. Paid generation needs a yes each time. The
game runs fine on coloured balls and placeholder letters, so art never blocks a code milestone.

## Order of work
1. Reuse first. Read `/Volumes/SANDISK SSD/Game Asset Library/ASSET_INDEX.csv` (copy-only: never edit
   or move anything there) and show the owner what fits before using it.
2. Style sheet first: the 3 starters, the Floor 1 pets and the HUD, for approval. Only then batches,
   one floor at a time.
3. Ask before any paid Meshy or Higgsfield generation, saying how many generations and for what.
4. Review: each batch of models, sounds or screens is shown to the owner before import.

## Models
Prompts for every pet and Guardian are in `docs/ART_PROMPTS.md`. The house prompt:
"stylized cartoon toy, chunky low-poly, big head, large simple eyes, 2-3 flat colours, matte,
symmetrical, neutral pose" + the pet's one-line description from bible B8.
- Budgets: 5,000 triangles or fewer, 512 px textures. Decimate after generation; check the count.
- Read at icon size and from 50 studs: one bold silhouette. Common about 2 studs tall, Legendary
  about 4, Guardians 25-40.
- Never scary, never realistic. Guardians are grumpy, sleepy or lonely, then friendly.
- Starters need three stages; Dawn and Dusk forms reuse the stage-3 mesh with a new palette (gold and
  cream with a sun crest; violet and indigo with a crescent crest).
- Rarity reads three ways: frame colour (grey, green, blue, purple, gold), frame shape, glow strength.
- Raw files (GLB etc.) stay on the SanDisk in the project folder, not in git.

## Getting a model into the game
Import into this game's own place only. Keep the part names and attributes the code relies on: a pet
is found by its `Species` / `Rarity` / `PetId` attributes, and `WorldService.petBall` is the single
place a pet's look is made, so swapping balls for models is a change there, not in every service.

## Sound
One 5-note "lantern" motif through everything; a calm loop per floor; three rising notes on the three
rings resolving on a catch; slide-whistle for the bolt; level-up, evolution, relight, welcome-back.
All original. Ids go in `src/shared/Config/Sounds.lua` (empty strings play nothing) after approval.
Music sits under effects; the two volumes are separate settings.

## Store art
Icon and thumbnails come from real in-game captures, built around the pet stack and the tower. See
`docs/launch/STORE_PAGE.md` and `docs/launch/CLIP_SHOTLIST.md`.

## Names
Pet names are working names. A new or changed name gets a clash check and a row in
`docs/DECISIONS.md`; names already flagged there are the owner's call.
