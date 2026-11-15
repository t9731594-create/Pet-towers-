# Status

**Milestone:** M0-M6 rules and greybox services written on `dev` (with Amendment 1), headless-tested only: check_lua 69 files, 0 syntax errors; tests 129 passed, 0 failed. Waiting for the owner's OK before `dev` goes into `main`, and for the Mac for every Studio test.
**Owner account:** FantasyGaming (@Talleyrandw).
**Where this lives:** github.com/t9731594-create/Pet-towers- (`main` = M0, `dev` = current, plus the five Amendment 1 branches). Not yet on the SanDisk.

## Done (source only, headless-tested; nothing has run in Studio)
- M0: bible, config modules, headless harness, tools/econ_sim.
- M1-M3: profile, Trust Tap, shared spawns, stack, camp, levels, team, natures, Guardian showdowns,
  session-locked saving, rate limits; Roblox services and a greybox client.
- Amendment 1: wild showdowns and Secret pets, merged into dev from five branches.
- M4 (part): Wick guide logic and beam, funnel and coin analytics. No sound, no real HUD art.
- M5 (rules + greybox): welcome-back chest, rested bonus, journey ladder, Mystery Egg, Share-or-Keep,
  Dawn/Dusk form, index count and sets, helper stars, emotes, Floors 4-5 in greybox.
- M6 (rules): receipts granted once per PurchaseId, passes, codes, a "nothing random for sale" audit.
  The shop is switched off until prices are approved.
- Research: docs/LAUNCH_RESEARCH.md, docs/API_CHECK.md. Hand-off: docs/HANDOFF_MAC.md. Model prompts: docs/ART_PROMPTS.md.

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
- Neighbour games, titles and names: checked by web search only (docs/LAUNCH_RESEARCH.md). No trademark search.
- Roblox docs check: done against the docs source, not Creator Hub itself (docs/API_CHECK.md).
- Not built: Weekly Guardian, weekend merchant, monument, Dawn-vs-Dusk weekly scale, Tower Trophy, Closet,
  Index Board screen, settings screen, sound, murals, debug panel, M7 art, M8 hardening.

## Next
1. Follow docs/HANDOFF_MAC.md on the Mac: clone to the SanDisk, new place, install, fix engine errors.
2. Run the Studio checklist there and write the real numbers here.
3. Owner rulings waiting: see "Pending" rows in docs/DECISIONS.md.

## Blockers
- No access to the Mac, the SanDisk or Studio from this session.

## Install map
- src/shared -> ReplicatedStorage.Shared
- src/server -> ServerScriptService.Server (Main.server.lua is the only Script)
- src/client -> StarterPlayer.StarterPlayerScripts.Client (Main.client.lua is the only LocalScript)
- Place settings to set by hand: 7 players, StreamingEnabled, R15, Studio API access for DataStores.
