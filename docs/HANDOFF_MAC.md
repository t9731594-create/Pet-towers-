# Hand-off: what to do on the Mac

Paste this to Claude Code on the Mac (SanDisk mounted), or follow it by hand.

## 1. Get the project onto the SanDisk
    cd "/Volumes/SANDISK SSD/Projects"
    git clone https://github.com/t9731594-create/Pet-towers- PetTower
    cd PetTower && git checkout dev
    pip install lupa            # for the headless tests
    python3 tools/check_lua.py && python3 tools/lua.py tests/run.lua

## 2. New place (separate Studio window; never open another project's place)
- New Baseplate place, saved as PetTower.rbxl in the project folder. Delete the Baseplate and SpawnLocation.
- Game Settings: max players 7, avatar R15. Workspace.StreamingEnabled on. Enable Studio access to API services.
- Install the source: Rojo with `default.project.json`, or the machine's usual script-swap method:
  src/shared -> ReplicatedStorage.Shared, src/server -> ServerScriptService.Server,
  src/client -> StarterPlayer.StarterPlayerScripts.Client. Folders with init.lua are ModuleScripts.
- M0 test: edit a print in src/server/Main.server.lua, reinstall, see it in the Output window.

## 3. First run: expect engine errors
None of src/server/Services or src/client has ever run in Roblox. Press Play, read the Output window top
to bottom, fix, repeat. Keep the pure rules (src/server/Core, src/shared/Logic) passing their tests.

## 4. Studio tests, in order (write real numbers into docs/STATUS.md)
M1
- [ ] Spawn faces three pedestals; walking into one picks the starter. Time from spawn to starter: ___ s
- [ ] Wick's beam leads to the first pet; the first Trust Tap cannot fail. Spawn to first catch: ___ s (target under 30)
- [ ] Send a Tap remote by hand with a perfect offset at the wrong time: graded Miss.
- [ ] Pet rides the head, lands on a pad at camp, coins pop.
M2
- [ ] Lift to Floor 1: a Rare under a pillar of light near the lift.
- [ ] Feed to Lv 5: evolution flash. Spawn to evolution: ___ s (target near 180)
- [ ] Stop and start Play: coins, pets, pads, level and floor are all kept.
- [ ] Guardian 1 falls by ___ min (target 5). Floor 2 unlocks.
M3 (Test > Clients and Servers > 3 players)
- [ ] Three players in one Guardian ring: all three get the clear.
- [ ] Lose a showdown on purpose: the help button shows, the banner reaches the others.
- [ ] Rare pillar banner reaches every client.
Amendment 1 (3 players)
- [ ] Epic alone: ring opens on walking up, meter empties in about 5 s, then one catch try with slower rings.
- [ ] Legendary with 2 players: both get a try. A third player who did not play cannot try.
- [ ] Secret with 3 players: spawn one from the command bar; about a minute to play out.
- [ ] Let a pet leave with the meter half full: nothing is lost, the ring closes.
- [ ] Every reward is granted once (check coins and pets against the Output log).
M5 / M6
- [ ] Change lastSeen in the save to 16 hours ago and rejoin: chest, x2 rested, journey day 2.
- [ ] Share after a first clear: every player gets coins and sees the banner. Keep: no banner.
- [ ] Shop stays hidden (Config.Shop.Approved is false).
Phone
- [ ] Device emulator at 667x375: every button reachable, nothing under the notch, 30+ FPS.

## 5. Known rough edges to look at first
- A player in a wild showdown cannot leave it by walking away (only by leaving the floor).
- A Secret shows two banners at once.
- Relit floor colour is server-wide, not per player.
- All visuals are grey boxes and coloured balls; all UI icons are placeholder letters.
