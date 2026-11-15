---
name: pettower-test
description: How to check PetTower code without Roblox Studio - the headless Lua test suite, the syntax check, the economy simulation and the tuning tool. Use this whenever you change any Lua file, config value, pet, floor or price in this project, before every commit and merge, when a test fails, when adding a new rule or service, or when the owner asks for the pacing table or whether a tuning change "still holds".
---

# PetTower: testing without Studio

The game's rules are written so they run both in Roblox and in a plain Lua 5.1 runtime. That is what
makes real test numbers possible away from Studio. Protect that property.

## Commands (run from the project root)
    pip install lupa                                  # once
    python3 tools/check_lua.py                        # every Lua file parses
    python3 tools/lua.py tests/run.lua                # the whole suite; last line is the total
    python3 tools/lua.py tools/econ_sim.lua 300 buyPads   # pacing table (add noWild to drop Amendment 1 play time)
    python3 tools/lua.py tools/sim_wild.lua           # wild-showdown meter timings and Secret values
    python3 tools/lua.py tools/tune.lua 300 try GuardianPower.4=62000   # try values without editing config

Run the check and the suite before every commit and after every merge. Report the totals line
verbatim.

## How the code must be written so this keeps working
- Lua 5.1 subset of Luau: no type annotations, no `continue`, no `+=`, no `//`, no backtick strings.
- Pure rules live in `src/server/Core` and `src/shared/Logic` and use NO Roblox APIs. Time, randomness
  and storage are passed in (`now`, `rand`, a `store`), which is what lets tests control them.
- Roblox-facing code (`src/server/Services`, `src/client`) stays thin: validate, call a Core function,
  replicate. If a service grows logic, move the logic into Core and test it there.
- Modules require each other Roblox-style: `require(script.Parent.X)`. `tools/harness.lua` fakes the
  instance tree with the same mapping as `default.project.json`.

## Adding a test
Create `tests/test_<name>.lua` returning a table of functions; it is picked up automatically.
Helpers: `T.eq(a, b)`, `T.near(a, b, tol)`, `T.ok(v)`, `T.no(v)`. Globals `Shared` and `Server` are
the roots (`require(Server.Core.Profile)`). Tests must be deterministic: seed any random source.
Prefer a test that states a bible rule in numbers ("Floor 1 Rare hearts cost 250, 500, 1,000, 2,000,
4,000") over one that mirrors the code.

## The economy simulation
`tools/econ_sim.lua` is the greedy bot from bible B9 and reads the same `Config` as the game. After
any tuning change, re-run it and show the owner the table next to the targets (4 / 15 / 58 / 141 /
260 active minutes). Things to know when reading it:
- The bot only spends at the end of each 150 s trip, so Guardians 1-2 look late; that is the bot,
  not the values. See `docs/TUNING_PROPOSAL.md`.
- `buyPads` matters a lot from Guardian 4 on. Say which mode a table used.
- Tuning values are prices: propose with a before/after table, do not apply without approval.

## What headless tests cannot tell you
Anything the engine decides: physics, touches, streaming, GUI layout, real DataStores, timing on a
phone. Those need the Studio checklist (see the pettower-studio skill). Never report a headless pass
as "works in Roblox".
