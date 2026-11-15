# Contracts for Amendment 1 (owned by the coordinator; workers do not edit)

Decision (final): "wild showdowns: play first, then catch", plus Secret pets. No Keepers, no chase,
nothing dropped. No new combat system, no moves, no health bars on pets.

Contract files (read-only for workers): everything under `src/shared/Config`, `src/shared/Net/Remotes.lua`,
`src/server/Core/Profile.lua`, `src/server/Core/TapCore.lua`, `src/server/Core/ShowdownCore.lua`,
`src/server/Core/SpawnCore.lua`, `src/server/Services/PetService.lua`, `src/server/Main.server.lua`,
`src/client/Main.client.lua`, `tools/harness.lua`, `tools/lua.py`, `tests/run.lua`, this file,
`docs/GAME_BIBLE.md`, `docs/DECISIONS.md`, `docs/STATUS.md`.
A worker who needs a change in any of them writes `REQUEST: ...` in its note file and stops on that item.

## Rules of the code base
- Lua 5.1 subset of Luau only: no type annotations, no `continue`, no `+=`, no `//`, no backtick strings.
- Pure rules go in `src/server/Core` or `src/shared/Logic` with NO Roblox APIs, and get tests.
- Tests: `tests/test_<name>.lua` returns a table of functions; helpers `T.eq`, `T.near`, `T.ok`, `T.no`.
  Run all: `python3 tools/lua.py tests/run.lua`. Syntax: `python3 tools/check_lua.py`.
- Modules require each other Roblox-style (`require(script.Parent.X)`); see existing files.
- Only the coordinator touches Roblox Studio. Service and controller code cannot be run here: keep it small.

## Config (already committed)
- `Economy.Wild = { MeterMult = { Epic = 4, Legendary = 10, Secret = 150 }, FriendlySlow = 0.20, JoinDistance = 20, TryGraceSeconds = 12 }`
- `Economy.Secret = { Rarity = "Secret", StaySeconds = 180, ChimesPerDay = 3, GlowSeconds = 60 }`
- `Economy.RarityIncomeMult.Secret = 20`, `Economy.RarityPowerMult.Secret = 10` (untested)
- `Economy.Tap.RingTime.Secret = 0.5`, `Economy.Tap.Need.Secret = { hits = 3, perfects = 3 }`
- `Economy.Sim.ExtraTrySeconds = { Epic = 5, Legendary = 12 }`
- `Pets.Secret[floor] = { species, nature }`; `Pets.ByFloor[floor].Secret = species`; `Pets.Wild[species].rarity == "Secret"`
- `Economy.Rarities` stays the five spawnable rarities. Secret never comes from the spawn roll.

## Remotes (already committed)
- C2S `WildJoin(petId)`.
- S2C `ShowdownState` / `ShowdownEnd` / `CheerGrade` and C2S `Cheer` are reused with `kind = "wild"`.
  `ShowdownState` for wild: `{ kind = "wild", petId, rarity, floor, start, ends = nil, meter, left, count }`.
  `ShowdownEnd` for wild: `{ kind = "wild", petId, floor, won }` (won = meter empty, you may now try; false = the pet left).
- S2C `SecretChime({ floor, phase = "glow" | "here" | "gone", at, leaves })` (UTC seconds).
- S2C `ClipMoment({ kind, floor })`.

## Saved data (already committed)
- `profile.stats.wild = { started, coop, finished }` (bible C3 counters). Secret pets are ordinary pet
  records with `rarity = "Secret"`. No other new fields.

## PetService hooks (already committed): `Pets.hook(name, fn)`
`beforeTry(player, profile, pet) -> false` blocks; `tryOptions(player, profile, pet, opts)` (set `opts.friendly = true`);
`afterTry(player, profile, pet, result)`; `petSpawned(pet, ball)`; `keepPet(pet, now) -> true`; `petLeft(pet)`.
Also `Pets.partOf(pet)`, `Pets.floorOf(player)`, `Pets.root(player)`, `Pets.spawnOn(floor, forced, position)`
with `forced = { rarity, radiant, stay, pillar }`. A wild `pet` is `{ id, floor, rarity, radiant, species, leaves, tried, pillar }`.
The client skips auto-tries on a pet part whose attribute `NeedsPlay` is true.
`ShowdownService.byPlayer[player] = <ShowdownCore session>` routes that player's `Cheer` taps.

## Function signatures to implement

### feat/wild-showdown-server
Owns: `src/server/Core/WildCore.lua`, `src/server/Services/WildShowdownService.lua`, `tests/test_wild.lua`.
- `WildCore.needsPlay(rarity) -> boolean` (true for Epic, Legendary, Secret)
- `WildCore.meter(floor, rarity) -> number` (Guardian power of the floor x MeterMult)
- `WildCore.new(pet, nature, now) -> session` (wraps `ShowdownCore.new` with kind "wild", no time limit; the meter never refills)
- `WildCore.join(session, userId, power, now) -> ok, reason` (anyone on the floor; power already includes natures x1.5)
- `WildCore.tick(session, now) -> "active" | "won" | "left"`
- `WildCore.leave(session, now)` (the pet left: state "left", nothing is lost)
- `WildCore.canTry(session, userId) -> boolean` (meter empty AND this player took part)
- `WildShowdownService.init()`; registers hooks; handles `WildJoin`; ticks sessions; sets the `NeedsPlay` attribute;
  counts `stats.wild`; fires `ClipMoment` for a Legendary or Secret played out by 2+ players.

### feat/wild-showdown-client
Owns: `src/client/Controllers/WildShowdown.lua`, `src/client/Controllers/Showdown.lua`, `src/shared/Logic/WildView.lua`, `tests/test_wildview.lua`.
- `WildView.shouldJoin(distance, needsPlay, alreadyIn, inTry) -> boolean`
- `WildView.ringScale(kind) -> number` (wild = a small ring; guardian = 1)
- `WildView.captureAllowed(policy) -> boolean` (policy = what the platform reports for this player)
- `WildShowdown.init()`: auto-join when near a `NeedsPlay` pet, small ring and meter through the Showdown
  controller, join prompt for others on the floor, and the capture hook on `ClipMoment`.

### feat/secret-pets
Owns: `src/server/Core/SecretCore.lua`, `src/server/Services/SecretService.lua`, `src/client/Controllers/Secret.lua`, `tests/test_secret.lua`.
- `SecretCore.chimes(dayNumber, floor) -> { seconds-of-day, ... }` sorted, `ChimesPerDay` long, same on every server
- `SecretCore.phase(floor, utcSeconds) -> { phase = "idle" | "glow" | "here", at, leaves, key }`
- `SecretService.init()`: spawns the floor's Secret once per chime via `Pets.spawnOn`, fires `SecretChime` and a banner.
- `Secret.init()` (client): the glow that builds, and the banner. No countdown, no "hurry" (bible B2).

### tools/sim-wild-showdown
Owns: `tools/econ_sim.lua`, `tools/sim_wild.lua`, `tests/test_sim.lua`, `tests/test_sim_wild.lua`.
- `Sim.run(seed, opts)` reads `Economy.Sim.ExtraTrySeconds` by default (opts can switch it off for a before/after table).
- `tools/sim_wild.lua` prints: seconds to play out each meter for 1 / 2 / 3 "ready" players per floor, what a
  Secret adds to income and Team Power, and the new pacing table next to the old one.

## Notes
Each branch ends with commits and a 5-line note in `docs/branches/<branch name with / replaced by ->.md`:
what was built, files, tests run with real results, open problems.
