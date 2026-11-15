---
name: pettower-saturday-update
description: How to add a weekly content update to PetTower - new floors, their five pets and Secret pet, a Guardian, a Weekly Guardian, looks, a code and patch notes. Use this whenever the owner asks for new floors, new pets, "the Saturday update", week N content, a new Guardian, a new code, or patch notes for this game.
---

# PetTower: a Saturday update

Every Saturday the tower grows: 2 new floors, 8 or more pets, a Weekly Guardian, a set of looks, a
code, a patch-note image and three 15 s clips. New floors ARE the update, so this path should stay
cheap: almost everything is config.

## What to change, in order
1. `src/shared/Config/Floors.lua`: raise `Count`, add each floor's name and colour mood.
2. `src/shared/Config/Economy.lua`: extend every by-floor list by the same number of entries
   (`CommonIncome`, `CommonPower`, `GuardianPower`, `CharmPrice`). Keep each list rising. These are
   prices: propose values, show the simulation, get approval.
3. `src/shared/Config/Pets.lua`: one `wild(floor, {...})` line per floor with five pets in rarity
   order (Common to Legendary), a `Pets.Secret` entry, and a `Pets.Guardians` entry with its nature.
   New Weekly Guardians go in `Pets.WeeklyGuardians`.
4. `src/server/Services/WorldService.lua`: `BuiltFloors`, and a colour in `FLOOR_COLOR`.
5. `Economy.IndexTotal`: 3 starters + all non-Secret wild pets.
6. Looks: add ids to the merchant or ladder lists only if the art is approved. A look id's prefix
   picks its Closet slot (`aura_`, `trail_`, `camp_`, `decor_`, `lift_`, `trim_`).
7. Code: add to `src/shared/Config/Codes.lua` (a look, or at most 600 seconds of income).

## Design rules for new content
- Natures: spread Ember, Tide and Leaf across a floor's pets; give the Guardian a nature so that
  some earlier pets have the x1.5 edge.
- Names and creatures are original and need a clash check (see pettower-rules). Describe each pet in
  one line, in the bible's style, for `docs/ART_PROMPTS.md`.
- Guardians are grumpy, sleepy or lonely, never scary.
- Nothing is "last chance": events, looks and merchants come back.
- A weekly reward is one look, never power.

## Check it
    python3 tools/check_lua.py && python3 tools/lua.py tests/run.lua
    python3 tools/lua.py tools/econ_sim.lua 300 buyPads
    python3 tools/lua.py tools/sim_wild.lua
Some tests pin the soft-launch counts (25 wild pets, 5 floors, index total 28): update those numbers
deliberately, in the same commit, rather than loosening the test. Show the owner the pacing table
with the new floors before anything is applied.

## Ship it
Fill `docs/launch/PATCH_NOTES_TEMPLATE.md`, list the clips from `docs/launch/CLIP_SHOTLIST.md`, add a
row to `docs/DECISIONS.md` for every invented value, update `docs/STATUS.md`. Art and sounds follow
the pettower-assets skill. The owner approves and publishes; do not publish.
