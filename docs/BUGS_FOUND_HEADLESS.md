# Bugs found by running the game headless (branch test/roblox-mock)

The services, the server entry script and the whole client were run for the first time, against
`tools/roblox_mock.lua` (a stand-in for the Roblox engine). Nothing here has run in Studio. Every fix
below has a test that failed before the fix and passes after it.

Numbers: `python3 tools/lua.py tests/run.lua` -> "tests: 237 passed, 0 failed" (167 before; 50 new in
test_boot_server, 19 in test_boot_client, 1 soak test). `python3 tools/lua.py tools/cover_boot.lua` ->
"cover_boot: 2245 of 2280 lines ran" of src/server/Services, both Main scripts and src/client.

## Fixed: 7

### 1. Emotes never arrived (server)
- File: `src/server/Services/Net.lua`
- Wrong: "Emote" is in both remote lists (client-to-server and server-to-client), and `Net.init` made
  one RemoteEvent per list entry: two RemoteEvents named "Emote" in the same folder. The server kept the
  second one (it listened and fired on it); every client's `WaitForChild("Emote")` finds the first one.
- In Studio: tapping a sticker does nothing, for everyone, with no error in the Output window.
- Fix: a name that is in both lists gets one RemoteEvent (a RemoteEvent works in both directions). No
  remote name or payload changed.
- Tests: `test_boot_server.a01` (exactly one RemoteEvent per name, 48 in all), `c04`, `test_boot_client.d01`.

### 2. The first pet was never put on a pad (server)
- File: `src/server/Services/CampService.lua`
- Wrong: pets leave the head stack only in `comeHome`, which ran from the camp zone's `Touched` (and from
  the lift home). The first pet is caught 20 studs from the spawn, inside the 90 x 90 zone, so the player
  never crosses the zone's edge. Wick then points at Pad 1, but touching a pad only collected coins.
- In Studio: checklist line "Pet rides the head, lands on a pad at camp, coins pop" fails: the pet stays
  on the head until the player walks out of the camp and back, or rides the lift once.
- Fix: touching one of your pads with pets on your head (at camp) puts them down, then collects.
- Honest note: in Studio the new head-stack ball appearing inside the zone may fire the zone's `Touched`
  by itself and hide this. The mock cannot tell (see "needs Studio"); with the fix both cases work.
- Tests: `test_boot_server.b05` (pad), `b06` (zone edge still works).

### 3. The Tower Trophy block did not light on a clear, or change colour on Share / Keep (server)
- File: `src/server/Services/ChoiceService.lua`
- Wrong: the trophy blocks are painted in `Camp.refresh`, which nothing called after a first clear or
  after the Share / Keep choice. The block changed only at the next unrelated refresh (a deposit, a buy).
- In Studio: clear Floor 1, choose Share: the trophy block stays grey until something else redraws the camp.
- Fix: `Camp.refresh` after a first clear (through `Showdown.onClear`) and after `Choose`.
- Test: `test_boot_server.d04`.

### 4. A showdown with nobody in it (server)
- File: `src/server/Services/ShowdownService.lua`
- Wrong: `join` created the floor's Guardian showdown first and only then refused a player who is
  already cheering somewhere else (a wild showdown next to the ring, the weekly one). The empty showdown
  ran its 40 seconds; a player who walked in later joined the tail of it and lost.
- In Studio: play with an Epic near the Guardian ring and step on the ring; a friend who then walks into
  the ring gets a showdown that is already running out.
- Fix: the "already in a showdown" check comes before the showdown is created.
- Test: `test_boot_server.m01`.

### 5. After a respawn the client still thought it was on the floor (server)
- File: `src/server/Services/CampService.lua`
- Wrong: a new character is moved to the camp and `Floor` is set to 0, but the `floor` value sent with
  State stayed at the old floor, and no State was sent.
- In Studio: fall off a floor's edge: you respawn at camp, the music (once there is any) stays the floor's.
- Fix: set the extra to 0 and push State when the character is placed.
- Test: `test_boot_server.m08`.

### 6. The Studio "Away16h" debug command did nothing (server, Studio only)
- Files: `src/server/Services/DebugService.lua`, `src/server/Services/DataService.lua`
- Wrong: the command moved `lastSeen` back, but every save stamps `lastSeen` with the time now, so leaving
  wrote the real time over it. It also left `lastPlayDay` at today, so the journey day could not move.
- In Studio: checklist line "Change lastSeen to 16 hours ago and rejoin: chest, x2 rested, journey day 2"
  shows nothing at all when done with the debug panel.
- Fix: the save takes the pretend time off its stamp (`Data.away`, only ever set by the debug command),
  and the command sets `lastPlayDay` to the UTC day of the pretend time. Journey day 2 then shows when
  16 hours ago was another UTC day (before 16:00 UTC it is; after 16:00 UTC use `away 24`).
- Test: `test_boot_server.m09`.

### 7. A full head stack used up your one try on a pet (client)
- File: `src/client/Controllers/TrustTap.lua`
- Wrong: the client marks a pet as "asked" before the server answers. With a full stack the server
  refuses, silently, and the client never asked for that pet again, even after the pets were put down.
- In Studio: walk past the Rare under the pillar with three pets on your head, ride home, come back
  within its 90 seconds: nothing happens when you walk up to it.
- Fix: the client does not ask while its stack is full.
- Test: `test_boot_client.f05`.

## Seen, not changed (design, or nothing is wrong yet)
- No control in the client sends `Place` (move a pet to a pad) or `Lift` with a floor number. The camp
  lift always rides to the highest unlocked floor, so Floor 1 cannot be visited again after Floor 2
  opens, and pad pets cannot be swapped for better spares.
- Every touch counts as a tap or a cheer, also a touch on the thumbstick or the jump button
  (`Rings.lua` ignores `processed` for touches on purpose).
- A wild showdown can be joined with a full stack; the catch try is then refused with no sign why.
- Wick points at a pet under a pillar even when this player has already had their try on it.
- `State` carries the whole profile on every change; one soak bot had about 140 pets after 20 minutes.
- Music (no sounds exist yet): a `State` push during a showdown switches back to the floor track and
  the next meter update restarts the showdown track; after a wild showdown ends the music stops until
  the next `State`.
- `FriendService` forgets pairs on leaving with a pattern that does not match the negative UserIds of
  Studio test players (harmless: test players are never friends).
- The ring and camp debounce tables are never emptied when a player leaves (a few bytes per player).
- A friend joining does not push `State` to the friend who was already here; their HUD multiplier is
  right again at their next change.

## Needs Studio (the mock cannot settle these)
1. Does moving the character one `task.wait()` after `CharacterAdded` hold, or does the engine's own
   spawn placement win? With no SpawnLocation the character first appears at the origin, inside the Tower.
2. `Touched`: does the camp zone fire when a head-stack ball is created inside it (see fix 2)? Does it
   fire on arrival by `PivotTo` (ride home with a stack, ring after a lift)? The mock fires `Touched`
   only when a test says so (and only when the character box really overlaps the part).
3. Streaming: are far parts there when the client reads them (pets on the floor just reached, the
   lantern)? `RequestStreamAroundAsync` only yields in the mock.
4. Clocks: client `GetServerTimeNow()` against the server's within the 0.1 s early / 0.6 s late grace;
   `os.time()` (Secret chimes, eggs) against `GetServerTimeNow()` (pets, tries).
5. Real DataStore behaviour: budgets and throttling (per server: 3 global writes a minute plus one
   autosave per player every 120 s), queueing of two calls on one key, the 4 MB limit.
6. The picture: UIStroke rings, text scaling, the 667 x 375 phone layout, safe areas, the grid canvas
   size read in the same frame the tiles are added (`Team.lua`), tweens (the mock sets the end value).
7. Head-stack and starter balls welded to the character: do they disturb walking, jumping or the camera?
8. ProximityPrompts 10 studs apart with a 10 stud range: which one shows.
9. `SetAttribute("Leaves", math.huge)` on the first pet: does infinity replicate as an attribute?
10. Analytics: funnel steps arrive out of numeric order (Day2Return, step 12, can come before step 5);
    events only log in a published game.
11. PolicyService, CaptureService and SocialService on a real account (age and region gates);
    server-side `IsFriendsWithAsync`.
12. A real purchase: ProcessReceipt called by Roblox, a retried receipt, and the pass prompt.
13. Sound: nothing can be heard here; the mock only counts Sound instances.
14. Falling off a floor (there are no walls) and the respawn that follows, in the real physics.
