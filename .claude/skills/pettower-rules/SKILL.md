---
name: pettower-rules
description: The owner's standing rules for the PetTower Roblox game ("Catch Pets, Climb The Tower"). Use this before ANY work on this project - writing or changing game code, config or tuning values, pets, prices, shop items, UI text, store or marketing copy, publishing, or spending - and whenever you are unsure whether something needs the owner's approval. Also use it when a request might touch another Roblox project on the same machine.
---

# PetTower: the rules that never bend

The full design is `docs/GAME_BIBLE.md`. Read the parts you need at the start of a session and before
each milestone. This skill is the short list of things that cause real harm if forgotten.

## Stop and ask the owner before
Publishing; spending Robux or money; paid Meshy or Higgsfield generations; creating a repo or remote;
posting anything online; setting or changing ANY price (Robux and coin prices both). The owner also
reviews every batch of models, sounds and screens before it goes into the game. A go-ahead for one
thing is not a go-ahead for the next.

## One project only
Work only in `/Volumes/SANDISK SSD/Projects/PetTower` (or this repo's checkout) and its own new place
file, in its own Studio window. Never open, edit, save or publish another project on the machine
(Aeonrise / StrikeWarfare2100, Seventh Horizon, Sword Oath, Hacker Universe, Bounce For Sky Pets).
`/Volumes/SANDISK SSD/Game Asset Library` is copy-only. If the SanDisk is not mounted, stop and ask.

## Who plays, and what that forbids
Players are 7-12, on phones, chat off, often not reading. So:
- Icons, numbers, colour, sound and Wick the guide instead of sentences. Touch targets 48 px or more.
- Content rating Minimal or Mild: nothing scary, nothing hit or hurt. Showdowns are play: pets cheer a
  Guardian up.
- No free-form drawing, building or writing shared between players, no social-hangout features, no
  media sharing: those make the game 16+.

## Money: never chance
Nothing bought with Robux OR coins may be random or change any odds. No paid eggs, spins, crates or
luck boosts. No ads or video feeds in the game, no off-platform links, no rewards for likes or
favourites. The shop sells looks and time-savers only and stays off (`Config.Shop.Approved = false`)
until the owner approves each price. `ShopCore.audit` fails the server if an item looks random.

## Kindness: never pressure
Players come back because it is a delight. No countdown popups, no penalty for a missed day, no
nagging to buy, no shaming, no "last chance", no "hurry". Timers that players would feel chased by
are not shown (the egg is "warming" or "ready"). Keeping in Share-or-Keep is never announced.

## Originality
Every name, pet, sound and screen is original. Other franchises are feel references only and are
never named in the game or its marketing. New names need a clash check; flag near-misses in
`docs/DECISIONS.md` instead of deciding alone.

## The server decides
Clients send intent (a tap time, a pet id). The server scores, checks distance, ownership and
cooldowns, and rate-limits every remote. Never trust a number from the client.

## Never drift silently
- `docs/DECISIONS.md`: add a row for anything that differs from the bible or fills a gap in it, with
  its approval state. Invented values are "Pending" until the owner rules.
- `docs/STATUS.md`: keep milestone, done, next and blockers current.
- Roblox rules and APIs change: check current Creator docs before relying on a rule, number or API,
  and tell the owner where the docs differ from the bible.

## Reporting
Six lines per milestone: built, real test numbers, open problems, next step, what needs approval.
Real numbers only. Say plainly what has not run in Studio. Never promise the game will go viral.
