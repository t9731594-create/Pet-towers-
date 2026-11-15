# Decisions

Each entry: date, what differs from the bible (or fills a gap in it), why, owner's approval.

| # | Date | Decision | Why | Approval |
|---|------|----------|-----|----------|
| 1 | 2026-11-15 | Built source-only in a cloud container, not on the SanDisk. Nothing has run in Studio. | Owner was away from the Mac and chose "source-only for now". | Approved 2026-11-15 (chat) |
| 2 | 2026-11-15 | Owner account: FantasyGaming (@Talleyrandw), from the owner's screenshot. | Part A, first action 3. | Given by owner |
| 3 | 2026-11-15 | Local git repo with `main` (last tested build) and `dev`. No remote. | Branch plan for Amendment 1. Creating a remote needs approval (hard rule 4). | Asked for in the branch plan |
| 4 | 2026-11-15 | Code keeps to the Lua 5.1 subset of Luau (no type annotations, `continue` or `+=`). | Lets the same files run in Studio and in the headless tests (`tools/lua.py`). | Pending |
| 5 | 2026-11-15 | Pets at camp that are not on a pad are "spare": owned, earn nothing, can join the team, be placed or released. | The bible has pads and release but no place for pets beyond the pads. | Pending |
| 6 | 2026-11-15 | The starter earns no coins and does not take a pad. | B9 gives the starter power but no income. | Pending |
| 7 | 2026-11-15 | "3 misses in a row" (assist) is read as 3 failed tries in a row, not 3 missed rings. | A single Legendary try could otherwise switch the assist on. | Pending |
| 8 | 2026-11-15 | Charm deficit makes rings 15% faster as ring time x 0.85 per tier; assist makes ring time x 1.2. | The bible gives the percentages but not the formula. | Pending |
| 9 | 2026-11-15 | Taps are sent one at a time as they happen; the server compares each claimed offset with its arrival time (0.6 s late / 0.1 s early allowed) and grades a mismatch as a Miss. | "The server scores them": stops a client sending perfect numbers early or late. | Pending |
| 10 | 2026-11-15 | Cheer rings land once per second; a cheer boost lasts 2 s for Perfect and Good alike. | The bible gives +50% for 2 s (Perfect) and +20% (Good) but no ring period. | Pending |
| 11 | 2026-11-15 | tools/econ_sim buys pads when they are full (flag `buyPads`, on in the table we report). | Without pads the bot is much slower than B9 (see STATUS). B9's bot description does not mention pads. | Pending |
| 12 | 2026-11-15 | The relit floor colour is server-wide in the greybox, not per player. | Per-player bloom needs client-side art work (M4 / M7). | Pending |
| 13 | 2026-11-15 | A lost lock is treated as stale after 600 s; a player whose save is locked is kicked with a kind message after 5 tries. | Session-lock details the bible leaves open. | Pending |
| 14 | 2026-11-15 | AMENDMENT 1 (final): wild showdowns, "play first, then catch", plus Secret pets. Folded into the bible at B7, B9, B15, C1 and C3, marked [A1]. The earlier Keeper version (chase, flop, Boots) is dropped: no Keepers, no chase, nothing dropped. | Owner's amendment. | Approved by owner 2026-11-15 ("Decision (final)") |
| 15 | 2026-11-15 | Secret pet working names invented: Lanternlamb (F1, Leaf), Pearlotter (F2, Tide), Flickerfox (F3, Ember), Chimecub (F4, Tide), Novanewt (F5, Ember). | The amendment gives one Secret per floor but no names. Each needs a clash check. | Pending |
| 16 | 2026-11-15 | Secret Trust Tap: 3 Perfects on 0.5 s rings (same as Legendary), then 20% slower after play. | The final amendment does not give Secret ring values (the dropped version said "three Perfects on fast rings"). | Pending |
| 17 | 2026-11-15 | A played-out pet stays at least 12 s more so every participant gets the try. A player who did not take part cannot try an Epic, Legendary or Secret. | "Everyone who took part gets one Trust Tap try" needs time to happen; the amendment gives tries only to those who took part. | Pending |
| 18 | 2026-11-15 | Open question for the owner: Secret chimes at fixed times work as an appointment. Built with no countdown, no schedule shown and no "last chance" wording, to stay inside B2 and B14. | Kindness rules. | Pending |
| 19 | 2026-11-15 | Integration fix after the merges: the wild showdown state goes to every player on the pet's floor, not only to participants, so the client's join icon can show. | The client and server branches were built apart; the client's note asked for it. | Coordinator change on dev |
| 20 | 2026-11-15 | Repo: github.com/t9731594-create/Pet-towers- (separate from Aeonrise). It is public. | Owner asked for a separate repo. | Approved by owner 2026-11-15; visibility is the owner's call |
| 21 | 2026-11-15 | M4-M6 rules and services written ahead of the Studio tests for M1-M3 (return systems, Share-or-Keep, Dawn/Dusk form, index sets, analytics, shop receipts, codes, emotes, Wick, Floors 4-5 greybox). | Owner asked to push on with everything that can be done without the Mac. All of it is headless-tested only. | Owner request 2026-11-15 |
| 22 | 2026-11-15 | Journey ladder gifts invented: 5, 6, 7, 8, 9, 10, 15 minutes of own income for days 1-7, then 10 (15 every 7th day), never less than 100 coins x day; looks on days 3, 7, 14, 28. | The bible gives the ladder but no gift table. | Pending |
| 23 | 2026-11-15 | Pass sizes invented: Bigger Stack = +2 on top of coin upgrades; Auto-Collect empties pads every 5 s while online. | The bible gives pass names and prices only. | Pending |
| 24 | 2026-11-15 | The shop is off: Config.Shop.Approved = false, no product ids, no prices live. ProcessReceipt is still connected so no purchase can be lost. | Hard rule 4: the owner approves every price. | Needs owner approval before any sale |
| 25 | 2026-11-15 | Helper reward: a Helper star each time, plus 60 s of own income once a day. A player with no pets gets a small floor-based amount from Share, never zero. | The bible says "a small daily reward" without a size. | Pending |
| 26 | 2026-11-15 | Mystery Egg pets arrive at camp as spares; the first egg starts when the starter is chosen; a new egg starts on a new UTC day. | Details the bible leaves open. | Pending |
| 27 | 2026-11-15 | Research findings that differ from the bible are listed in docs/LAUNCH_RESEARCH.md: the evaluation bar may now be 100 plays, not 250; the publishing fee is reported as 1,000 Robux; the retention benchmarks are GameAnalytics figures. | Hard rule 7. Could not open Creator Hub from the build session. | Owner to confirm in Creator Hub |
| 28 | 2026-11-15 | Pet names flagged for a second look: Flaremingo, Buttercub, Auroram (closest to existing characters), Belluga, Hopscotch, Shellby, and the guide name Wick. Not changed. | Hard rule 6. | Pending |
| 29 | 2026-11-15 | No tuning value was changed although tools/econ_sim runs behind B9 (Guardian 5 at about 302 active minutes against 260). | Tuning changes coin prices, which need approval. | Pending |
