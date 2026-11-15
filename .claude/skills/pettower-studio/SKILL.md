---
name: pettower-studio
description: Installing PetTower into Roblox Studio on the owner's Mac and running the Studio test checklist. Use this whenever the work involves Roblox Studio, the place file, playtesting, the "3 clients on a local server" tests, measuring first-catch or evolution times, phone emulation, DataStore checks in Studio, or fixing engine errors from the Output window - and at the start of any session on the Mac.
---

# PetTower: Studio on the Mac

Most of the Roblox-facing code was written without Studio. The first run will surface engine errors;
that is expected. Work through them calmly and keep the pure rules passing their tests.

## Before touching Studio
1. The SanDisk must be mounted and the project at `/Volumes/SANDISK SSD/Projects/PetTower`. If not,
   stop and ask.
2. `git pull` on `dev`, then `python3 tools/check_lua.py && python3 tools/lua.py tests/run.lua`.
3. Use a separate Studio window with this game's own place (`PetTower.rbxl`). Never open, save or
   publish any other project's place. Only one session works in the place file at a time.

## Place setup (first time)
Empty Baseplate place saved into the project folder; delete Baseplate and SpawnLocation. Game
Settings: max players 7, avatar R15. `Workspace.StreamingEnabled` on. Enable Studio access to API
services (DataStores). The world is built by code at server start; there is nothing to model by hand.

## Installing source
Use Rojo with `default.project.json` if it is installed, otherwise the machine's usual script-swap
method. Mapping:
- `src/shared` -> `ReplicatedStorage.Shared`
- `src/server` -> `ServerScriptService.Server` (`Main.server.lua` is the only Script)
- `src/client` -> `StarterPlayer.StarterPlayerScripts.Client` (`Main.client.lua` is the only LocalScript)
- A folder with `init.lua` is a ModuleScript with children.
Sync only what changed. M0 test: change a print in `Main.server.lua`, reinstall, see it in Output.

## Running the checklist
`docs/HANDOFF_MAC.md` is the ordered checklist (M1, M2, M3, Amendment 1, weekly and camp extras,
phone). For each item: do it, write the real number or pass/fail into `docs/STATUS.md`. Use the
Studio-only debug panel (bottom left) to jump ahead: coins, levels, spawn Epic / Legendary / Secret,
Away16h (then rejoin), Egg, Wipe. Multi-player tests: Test tab > Clients and Servers > 3 players.
Phone: device emulator at 667x375, landscape.

## When the engine rejects something
- Read the Output window top to bottom; fix the first error first.
- Decide where the bug lives. If a rule is wrong, fix it in `src/server/Core` WITH a headless test.
  If the engine call is wrong, fix the service or controller and note it in `docs/API_CHECK.md`.
- Check the current Roblox Creator docs before changing an API call; do not guess from memory.
- `docs/BUGS_FOUND_HEADLESS.md` (if present) lists behaviours that only Studio can settle: check
  those early.
- Commit small, on `dev` or a branch; push when a checklist section passes.

## Hard stops
Do not publish. Do not create passes, products or prices. Do not import models or sounds the owner
has not approved. Stop before publishing at the end of M8 and report.
