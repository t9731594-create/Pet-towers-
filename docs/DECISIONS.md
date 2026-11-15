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
