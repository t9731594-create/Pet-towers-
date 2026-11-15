# Tuning proposal (nothing is applied)

For the owner to approve. No file under `src/` was changed. Numbers are from `python3 tools/lua.py tools/tune.lua`
(300 runs, mean active minutes, 36 a day); full output: `docs/branches/tools-tuning-proposal-output.txt`.

## Recommendation: option B (lower two Guardian powers; no coin price or pet changes)

| Value in `Config/Economy.lua` | Old | New |
|---|---|---|
| `GuardianPower[4]` | 65,000 | 62,000 |
| `GuardianPower[5]` | 225,000 | 210,000 |

| Guardian | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Bible target (min) | 4 | 15 | 58 | 141 | 260 |
| Before, pads bot | 5.65 (+41%) | 18.25 (+22%) | 60.90 (+5%) | 150.68 (+7%) | 302.49 (+16%) |
| After, pads bot | 5.65 (+41%) | 18.25 (+22%) | 60.90 (+5%) | 143.04 (+1%) | 272.40 (+5%) |
| Day before -> after, pads bot | 1 -> 1 | 1 -> 1 | 2 -> 2 | 5 -> 4 | 9 -> 8 |
| Before, no-pads bot | 5.65 (+41%) | 17.30 (+15%) | 65.00 (+12%) | 196.01 (+39%) | 393.60 (+51%) |
| After, no-pads bot | 5.65 (+41%) | 17.30 (+15%) | 65.00 (+12%) | 182.21 (+29%) | 363.12 (+40%) |

Evolutions (Lv 5 / 25 / 42) do not move: minute 5.0 / 18.4 / 131.0 (pads), 5.0 / 18.7 / 171.7 (no pads).
Why B: it alone puts every Guardian on the day the bible names (1, 1, 2, 4, 8) for the pads bot, with two
small changes and no price change. A player feels Guardians 4 and 5 fall about 8 and 30 active minutes sooner.

## Guardians 1 and 2 are late because of the bot, not the values

The bot only spends and challenges at the end of a 150 s trip, so it can beat Guardian 1 at about
190 s or 340 s and never between: 98% of runs win after minute 5, mean 5.65. With the same catch rate
but coming home after each catch (50 s trips), 94% win by minute 4, mean 3.20. That "attentive" bot on
the current values gives 3.20 / 13.93 / 55.11 / 142.94 / 302.52 with pads. The bible's 4 and 15 sit between
the two bots, and 18.25 is inside the bible's "15-20 min". So: no value change on floors 1 and 2.

## The other options

**A, smallest change:** `GuardianPower[5]` 225,000 -> 200,000 only.
Pads bot: 5.65 / 18.25 / 60.90 / 150.68 / 261.56 (+41% / +22% / +5% / +7% / +1%), days 1 / 1 / 2 / 5 / 8.
No-pads bot: 5.65 / 17.30 / 65.00 / 196.01 / 353.31. Guardian 4 stays on day 5, not day 4.

**C, change nothing:** pads bot 5.65 / 18.25 / 60.90 / 150.68 / 302.49, days 1 / 1 / 2 / 5 / 9. Guardians 4 and 5
are each a day late (+7%, +16%). Acceptable if "day 4" may mean day 5 and "around day 8" may mean day 9.

**B plus Guardian 2** (`GuardianPower[2]` 180 -> 150 as well) puts Guardians 2-5 within 10% in the bot as
written: 5.65 / 16.11 / 59.73 / 141.28 / 271.46 (worst +7%). Not recommended: the attentive bot then wins
Guardian 2 at 12.16 min (-19%), so it fixes a bot artefact by making floor 2 easier.

## Which bot did the bible use? Please say

The bible's bot text does not mention pads. If the original bot never bought pads, no option here fits:
no-pads Guardians 4 and 5 stay 29% and 40% late under B. About 380 combinations were tried; none put both
bots within 10%. Closest: level cost growth 1.4 -> 1.39, `CommonPower[4]` 2,200 -> 2,500, `GuardianPower[2]`
180 -> 150, `GuardianPower[5]` 225,000 -> 200,000: pads 5.65 / 15.80 / 56.12 / 124.24 / 225.13 (worst -13%), no pads
5.65 / 15.27 / 58.80 / 153.12 / 296.90 (worst +14%). Not offered: it reprices every starter level. Buying pads
is worth about 30% from Guardian 4 on; that gap is the real open question.

## Levers that were tried

- Level cost growth 1.4 -> 1.39 alone: pads bot Guardians 2-5 at +19% / -1% / -4% / +4%, Lv 42 at minute 116.
  With Guardian 2 at 150 it fits as well as B (worst 6%), but it is a coin price change on every level.
- Common power, floor 4: helps the no-pads bot more than the pads bot; also raises that floor's Secret.
- Weak (100 runs): floor 5 income 81 -> 100 moves Guardian 5 by 4%; pad prices 3-4 under 3%; Charm prices nothing.

## Checks, for A, B and C alike

- First five minutes (`tests/test_first_minutes.lua`: evolve at 150-180 s, Guardian 1 by 5 min with Good
  cheers) and the day-2 return opening with the Lv 25 evolution (`tests/test_return.lua`): both pass.
- Wild showdowns, a ready player alone: Epic 4 s, Legendary 10 s, Secret 150 s on every floor, unchanged,
  because the meters are multiples of Guardian power.
- Secret pets under B: floor 4 meter 9,750,000 -> 9,300,000, floor 5 meter 33,750,000 -> 31,500,000. One
  Secret is 34% -> 35% (floor 4) and 33% -> 36% (floor 5) of the Guardian's power; just-arrived players
  needed for a floor 4 Secret 8 -> 7 (floor 5: 3 -> 3). So Secrets get slightly easier on floors 4-5.
- Under A: floor 5 meter 33,750,000 -> 30,000,000; one Secret is 33% -> 38% of the Guardian.
- Every per-floor list still rises. Spawn odds, rarity multipliers, the Trust Tap and the shop are untouched.

## Risks

- The bot ignores natures, friends, rested bonus, treasure, index sets and Secrets; real players are slower.
- A sits at +1% (262 min) but day 8 starts at minute 252; B's 272 min has more room on both sides.
- Bible B9's Guardian power line would need the new numbers if A or B is approved.
- Try other values: `python3 tools/lua.py tools/tune.lua 300 try GuardianPower.4=62000 GuardianPower.5=210000`
