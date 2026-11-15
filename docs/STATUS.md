# Status

**Milestone:** M0-M3 source written, headless-tested only. Amendment 1 in progress on branches.
**Owner account:** FantasyGaming (@Talleyrandw).
**Where this lives:** a cloud container, local git only (`main` = M0, `dev` = current). Not yet on the SanDisk.

## Done
- M0 (source half): bible saved, config modules, headless harness, tools/econ_sim.
- M1-M3 (source only): core rules with tests (profile, Trust Tap, spawns, stack, camp, levels, team,
  natures, showdown, saving with session lock, rate limit); Roblox services and a greybox client.

## Real numbers
- `python3 tools/lua.py tests/run.lua`: see the last line of the latest run in the branch notes.
- `python3 tools/check_lua.py`: 0 syntax errors.
- econ_sim (300 runs, mean active minutes, Guardians 1-5), bible target 4 / 15 / 58 / 141 / 260:
  - bot as written in B9 (never buys pads): 5.6 / 17.2 / 65.1 / 197.1 / 394.1
  - bot that buys pads when full: 5.6 / 18.2 / 61.1 / 151.2 / 301.8
  - Evolutions (pads bot): Lv 5 at 5.0 min, Lv 25 at 18.3 min (right after the first break), Lv 42 at 130.6 min (day 4).
  - The table does NOT match B9 exactly: Guardians 4 and 5 are 7% and 16% late even with pads. No values were retuned.

## Not done / cannot be done here
- Nothing has run in Roblox Studio. Every file under src/server/Services and src/client is unverified
  against the engine: expect fixes on first install.
- M0 test "a script edit shows in Studio", M1 "first catch within 30 s", M2 "rejoin keeps everything"
  in a real DataStore, M3 "3 clients on a local server": all wait for the Mac.
- No art, no sound, no place file. The world is built by code as grey boxes.
- Asset library not read (it is on the SanDisk).
- Neighbour games (Battle Pets, Catch and Tame, Climb HILL for Animals) not yet read.
- Name clash check (hard rule 6) not done for any pet name.
- Roblox docs check (hard rule 7) not done: IsFriendsWithAsync, PromptGameInvite, Captures and the
  DataStore calls are written from memory.

## Next
1. Copy this folder to "/Volumes/SANDISK SSD/Projects/PetTower" (keep the .git folder).
2. On the Mac: create the new place, install with Rojo (`default.project.json`) or the usual method,
   press Play, fix what the engine rejects.
3. Run the M1-M3 Studio tests, then the Amendment 1 three-client test.

## Blockers
- No access to the Mac, the SanDisk or Studio from this session.

## Install map
- src/shared -> ReplicatedStorage.Shared
- src/server -> ServerScriptService.Server (Main.server.lua is the only Script)
- src/client -> StarterPlayer.StarterPlayerScripts.Client (Main.client.lua is the only LocalScript)
- Place settings to set by hand: 7 players, StreamingEnabled, R15, Studio API access for DataStores.
