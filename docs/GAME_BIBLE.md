# CATCH PETS, CLIMB THE TOWER
# Master build prompt + game bible, v1 (14 Nov 2026). Working title.
# With Amendment 1 folded in (15 Nov 2026): wild showdowns and Secret
# pets. Amended passages are marked [A1]. The v1 text is in git history.

This one document is both your instructions and the game bible. It
replaces any earlier prompt for this game.

====================================================================
PART A. HOW YOU WORK
====================================================================
You are the lead game designer and Roblox engineer. Build this game
from an empty place to a soft-launch build, one milestone at a time.
Do not ask design questions this document already answers. If
something here is impossible or contradicts itself, stop and ask.

First three actions
1. Save this whole message, unchanged, as docs/GAME_BIBLE.md in the
   project folder. Re-read the parts you need at the start of every
   session and before every milestone.
2. Create docs/STATUS.md (milestone, done, next, blockers) and
   docs/DECISIONS.md (date, what differs from the bible, why, my
   approval). Keep both current. Never drift from the bible silently.
3. Ask me which Roblox account owns the game, and tell me anything on
   this machine that blocks M0.

Hard rules
1. New project only: folder "/Volumes/SANDISK SSD/Projects/PetTower"
   and a new place file. If that drive is not mounted, stop and ask.
   Never open, edit, save or publish any other place or project on
   this machine (Aeonrise / StrikeWarfare2100, Seventh Horizon, Sword
   Oath, Hacker Universe, Bounce For Sky Pets).
2. Use a separate Studio window for this game.
3. "/Volumes/SANDISK SSD/Game Asset Library" is COPY ONLY.
4. Stop and ask before: publishing, spending Robux or money, paid
   Meshy or Higgsfield generations, creating a repo, posting anything
   online, or setting or changing any price.
5. I review every batch of models, sounds and screens before it goes
   into the game.
6. Everything original: names, pets, sounds, UI, story. Pokemon,
   Sword Art Online, Destiny and Knights of the Old Republic are feel
   references only. Copy nothing from them or from any Roblox game.
   Check every name against existing games and replace clashes.
7. Roblox rules and APIs change. Before relying on any rule, number
   or API named here, check the current Roblox Creator docs. If they
   differ, tell me and follow the docs.
8. The server decides everything that matters.
9. Reports: 6 lines per milestone (built, real test numbers, open
   problems, next step, what needs my approval). Never promise the
   game will go viral.

====================================================================
PART B. GAME BIBLE
====================================================================

## B1. Vision
Pitch: Pick a starter pet, befriend wild pets by tapping three beats
in time, and climb a giant tower floor by floor with other players.
Pets at your camp earn coins, coins grow your team, your team cheers
up each floor's grumpy Guardian, and higher floors hold rarer pets.

The promise: in 30 seconds you make a friend, in 3 minutes it
evolves, in 5 you cheer up a giant alongside strangers, and tomorrow
something is waiting for you.

Pillars (original takes on beloved feelings)
1. MY FIRST PET. Choose 1 of 3 starters in the first 5 seconds. Catch
   suspense, evolution, an index of silhouettes.
2. THE CLIMB. A 100-floor tower, one Guardian per floor, easier with
   a party. The floor number is the number that climbs.
3. THE LIGHT SHOW. Rarity colours, a pillar of light for rare pets, a
   Saturday reset, a Weekly Guardian, a weekend merchant.
4. DAWN OR DUSK. A choice that marks you: share or keep.

Tone: warm, funny, kind. Never scary, never mean.

When in doubt, ask four questions. Can a 7-year-old do it without
reading? Would a 17-year-old show it to a friend? Does it make a
10-second clip? Is it kind?

## B2. Players and platform rules
- Main players: ages 7-12, on phones, chat off, 15-20 minute sessions.
- First players, by Roblox rule: age-checked 16+. A new game reaches
  under-16s only after 250 unique plays by highly engaged 16+ players
  within 60 days. The first hour must delight them too: nostalgia, a
  timing skill with a high ceiling, a monument of first clears.
- Content rating: aim for Minimal, accept Mild. Nothing may push it
  to Moderate: no fear, no blood, nothing realistic. Showdowns are
  play, not fighting: pets dance, bounce and sparkle to cheer a
  Guardian up. Nothing gets hit or hurt. Answer the maturity
  questionnaire truthfully.
- No free-form drawing, building or writing shared between players,
  and not a social hangout: those categories are 16+ only.
- Everything works with chat off and without reading: icons, numbers,
  colour, sound and Wick the guide.
- Money rules: nothing bought with Robux, or with coins, may be random
  or change any odds. No paid eggs, spins, crates or luck boosts. No
  ads or video feeds in the game. No off-platform links. Never reward
  likes, favourites or ratings.
- Kindness rules: players return because it is a delight, never from
  pressure. No countdown popups, no penalty for a missed day, no
  nagging to buy, no shaming. Messages say "welcome back", never
  "hurry".

## B3. What the research says (why the design is what it is)
- Roblox Home ranking, strongest signals: play-through rate;
  first-play bounce (leaving in under 60 s, or in 61-180 s); play days
  on day 1, days 2-7 and days 8-28; playtime (capped at 60 min a day).
  Next: co-play days with friends, qualified sessions, spend days,
  Robux spent. Players bought with ads do not count toward ranking.
- So: a peak before 60 s, another at 180 s, reasons to return across
  28 days, real benefits for playing with friends.
- The biggest earners, from Adopt Me and Brookhaven to Grow a Garden
  and Steal An Egg, share: a title that explains the game, one number
  that climbs, collecting with rarity tiers, a personal space others
  can see, progress while away, small servers, an update every
  Saturday, spending on looks and time-savers.
- Clips spread on striking, funny moments, not on polish, and a spike
  without retention hurts ranking. Retention first, then clips.
- Close look-alikes rank lower. Neighbours: Battle Pets, Catch and
  Tame, Climb HILL for Animals. Read their pages and list 3 ways this
  game plays differently. Our twists: a catch decided by timing, pets
  everyone can catch together, the pet stack, Share-or-Keep, and a
  tower whose new floors are the weekly update.

## B4. World and story
- The Lantern Tower stands in the middle of a quiet valley. It has
  100 floors. Each floor is a small world with one great lantern.
- A long storm blew every lantern out. On each floor the oldest,
  biggest pet stayed to guard its dark lantern and grew lonely and
  grumpy. These are the Guardians.
- Climbers and their pets cheer a Guardian up. It relights its
  lantern, the floor wakes into full colour, and the lift can go one
  floor higher.
- Wick, your guide, is a tiny floating lantern flame. Wick points
  with light, reacts with faces and never uses text.
- Dawn and Dusk are the tower's two lights: gold morning and violet
  evening. Neither is bad. Dawn shares. Dusk is cheeky and
  independent.
- Story is told without words. Each relit floor reveals one mural
  panel. The newest floor's panel always ends on a question. Season 1
  (Floors 1-10) builds to one reveal: the first lantern was lit by a
  child and a starter pet like yours.
- Places: the hub plaza at the tower's foot (lift, monument of first
  clears, Dawn-vs-Dusk scale, weekend merchant's balloon, Weekly
  Guardian ring), ringed by 7 player camps.

## B5. Loops
- 30 s: spot a pet -> walk up -> Trust Tap -> it hops onto your stack.
- 5 min: ride the lift home -> pets take pads and earn -> feed the
  team -> Team Power climbs -> cheer up the Guardian -> next floor.
- Session (15-20 min): a floor or a big step toward one, an evolution
  or a new index entry, one showdown with others.
- Day: welcome-back chest, Mystery Egg, ladder gift, rested bonus.
- Week: Saturday floors, Weekly Guardian, Dawn-vs-Dusk result,
  merchant.

## B6. First 5 minutes (no menus, no popups, no text walls)
- 0-5 s: spawn in camp facing three starters on pedestals. Walk into
  one.
- 5-25 s: Wick lights a path to a wild pet 20 studs away. The first
  Trust Tap cannot fail.
- 25-45 s: it rides your head to a camp pad. Coins start popping.
- 45-75 s: lift to Floor 1. A pillar of light marks a guaranteed Rare
  (the 60 s mark passes mid-chase).
- 75-150 s: catch 2 more, go home, feed the starter to Lv 5.
- 150-180 s: the starter evolves, and the Guardian gate swings open
  as the 180 s mark passes.
- By 5 min: Old Bramblehorn is smiling, Floor 1 is in full colour,
  the first Share-or-Keep choice is made, Floor 2 is open, the index
  reads 5/28.
- Before the first session ends, Wick shows tomorrow: the Mystery Egg
  in its nest and the next ladder gift.

## B7. Systems
Catching: the Trust Tap
- Wild pets are shared sights. Everyone on a floor sees the same pet,
  each player gets one try at it, and a success gives you your own
  copy. Nobody can take a pet from anybody. 10-12 pets roam a floor;
  each stays 90 s.
- A try is three shrinking rings around the pet's heart. Tap anywhere
  as each ring meets the heart: Perfect (within 80 ms), Good (within
  200 ms) or Miss.
- Needed to succeed: Common 1 Good; Uncommon 2 Goods; Rare 2 Goods
  including 1 Perfect; Epic 3 hits including 2 Perfects; Legendary 3
  Perfects. Ring time: 1.2 / 1.0 / 0.8 / 0.65 / 0.5 s.
- Skill decides, never dice. A Charm tier below the floor's tier
  makes rings 15% faster per tier. After 3 misses in a row, rings run
  20% slower until 2 catches (assist; also a setting).
- A miss on the last beat: the pet bolts in slow motion with a comic
  sting. No penalty.
- Spawn odds per floor, shown in the index: Common 60, Uncommon 25,
  Rare 10, Epic 4, Legendary 1. One spawn in 500 is Radiant (rainbow
  sheen, x3 income). A Legendary or Radiant raises a pillar of light
  and a server banner and stays 90 s so everyone can ride up and try.

Wild showdowns: play first, then catch [A1]
- Common, Uncommon and Rare pets: Trust Tap only, as above.
- Epic, Legendary and Secret pets want to play before they trust
  you. Walk up and a small ring opens. Your team plays with the pet
  by itself; you tap rings to cheer, exactly as in a Guardian
  showdown. Natures count (x1.5).
- The pet has a Play meter: the floor's Guardian power x 4 (Epic),
  x 10 (Legendary) or x 150 (Secret). Teams drain it at Team Power
  per second. Anyone on the floor can step in and add their team.
- The meter never refills while the pet is there. If it is not
  empty when the pet leaves, the pet just leaves. Nothing is lost.
- Meter empty: everyone who took part gets one Trust Tap try, with
  rings 20% slower because the pet now likes you.
- Rough feel: a player ready for that floor's Guardian plays an Epic
  out in about 5 s and a Legendary in about 12 s. A Secret takes
  three ready players about a minute.
- No Keepers, no chase, nothing dropped.

Secret pets (the long hunt) [A1]
- One Secret pet per floor, above Legendary (untested: x20 income,
  x10 power). It appears when the floor's lantern chimes, about 3
  times a day at times that are the same on every server, with a
  glow that builds and a server banner. It stays 3 minutes.

The stack and the camp
- Caught pets ride in a wobbling stack on your head until you take
  them home. Stack size 3, up to 10 with coins. Full stack: Wick
  points home.
- Camp stations are things you walk to, not menus: 8 pet pads (24
  with coins), Snack Table (feeding), Charm Bench, Index Board, Egg
  Nest, Mailbox (journey ladder, codes), Tower Trophy (your floors,
  lit gold or violet), Closet (looks).
- Every placed pet earns coins. A pad holds 10 minutes of coins; walk
  over pads to collect. Spare pets can be released for 60 s of their
  income.

Growing your team
- Team = your starter, always in front, plus 2 wild pets you pick.
- Starter levels: fed with coins, no cap. It evolves at Lv 5, Lv 25
  and Lv 42. At Lv 42 you choose its Dawn or Dusk form. Evolution is
  a 2.5 s full-screen moment: flash, fanfare, camera orbit.
- Wild pets earn hearts (0-5): each adds 25% power and 10% income. At
  3 and 5 hearts they grow a size and gain a sparkle. Wild-pet
  evolutions arrive in updates.
- Natures: Ember beats Leaf, Leaf beats Tide, Tide beats Ember. A pet
  whose nature beats the Guardian's counts x1.5. There is no penalty.
  Shown by colour and icon only.
- Team Power is the three pets' power added up, shown over your head.

Guardian showdowns
- Walk into the ring to start or join. 40 seconds, no aiming. Teams
  play by themselves; you tap the same rings to cheer (Perfect = +50%
  for 2 s, Good = +20%). A Roblox friend in the ring doubles the
  cheer bonus.
- Everyone in the ring adds their Team Power and everyone gets the
  full reward. Lose: nothing is lost; a "Call for help" button pings
  the server and offers SocialService:PromptGameInvite.
- Win: the lantern relights, the floor blooms into colour, a mural
  panel appears, the Guardian becomes a friendly landmark that waves,
  and you choose Share or Keep.
- Helping on a floor you have cleared earns a Helper star and a small
  daily reward.
- Weekly Guardian (hub): its meter scales to the players in the ring,
  so a full ring wins comfortably and a solo player needs
  near-perfect cheers. One cosmetic reward a week.

Share or Keep, Dawn or Dusk
- After a first win on a floor and after each Weekly Guardian: two
  big icon buttons. SHARE: every player on the server gets 5 minutes
  of their own income, and you gain a Dawn point. KEEP: you get 10
  minutes of yours and a Dusk point.
- Only sharing gets a banner ("<name> shared!"). Keeping is never
  announced.
- Your aura takes the colour of your majority. Each floor on your
  Tower Trophy glows with the choice you made there. A hub scale
  shows the week's Dawn-vs-Dusk tally; the leading side wears a
  special aura trim the next week.

Friends (all of it works with chat off)
- Roblox friend in the server: +20% coins for both.
- Shared lift: a party rides together, floor counter ticking.
- Six sticker emotes. Free private servers. No trading at launch.

Reasons to come back (warm, never urgent)
- Welcome-back chest: pets earn at 25% speed for up to 4 hours while
  you are away (8 hours with the Night Lantern upgrade).
- Rested bonus: x2 coins for the first 10 minutes after 8 hours away.
- Journey ladder that never resets ("Day 4 of your climb") and shows
  tomorrow's gift.
- One free Mystery Egg a day: hatches after 8 real hours into a pet
  from your highest floor, same odds, odds shown, never buyable or
  skippable.
- Saturday: 2 new floors, 8 new pets, a new Weekly Guardian, a code.
- Weekend merchant: 3 clearly shown items for coins (a look, a named
  Rare pet, a camp decoration).
- Index sets: catch all 5 pets of a floor for +5% coins forever and a
  camp decoration.
- Design the first welcome-back chest to carry the starter to Lv 25,
  so the first return visit opens with an evolution.
- Codes: the Mailbox takes codes (launch code, creator codes). A code
  gives a look or at most 10 minutes of income.

## B8. Pets (working names; check each for clashes)
Starters (3 stages each, then a Dawn or Dusk form)
- Ember: Pandle -> Pandlewick -> Pandelabra. A red panda whose tail
  is a candle flame.
- Tide: Narbub -> Narbeam -> Narbeacon. A narwhal calf floating in a
  bubble; its horn becomes a lighthouse beam.
- Leaf: Capling -> Capybloom -> Capyglow. A capybara with a sprout
  that grows into lantern flowers.

Wild pets, listed Common, Uncommon, Rare, Epic, Legendary
- F1 Sunny Meadow: Buttercub (Leaf, bear cub with a buttercup hat);
  Hopscotch (Leaf, hare with checkered ears); Zipwing (Tide,
  dragonfly with stained-glass wings); Marigoat (Ember, goat kid with
  a marigold mane); Sunflion (Leaf, lion cub with a sunflower mane).
- F2 Sunset Shore: Shellby (Tide, hermit crab in a teacup); Pufferpop
  (Tide, balloon pufferfish); Coralope (Leaf, fawn with sea-fern
  antlers); Flaremingo (Ember, flamingo with sunset feathers);
  Sunsetter (Ember, setter pup with a sunset coat).
- F3 Glowcap Grove: Capkin (Leaf, mouse under a mushroom cap); Glowl
  (Leaf, owlet with glowing ring eyes); Lumoth (Ember, moth with
  lantern wings); Fungiraffe (Leaf, giraffe calf with mushroom
  horns); Wispwolf (Tide, wolf pup of soft blue mist).
- F4 Frostbell Peaks: Flurrypup (Tide, snowball puppy); Chillama
  (Tide, llama with icicle wool); Belluga (Tide, beluga calf with a
  bell tail, swimming through air); Auroram (Ember, ram with aurora
  horns); Mammint (Leaf, mint-green baby mammoth with candy-cane
  tusks).
- F5 Starlight Deck: Cometkit (Ember, kitten with a comet tail);
  Saturtle (Leaf, turtle with a ringed-planet shell); Nebulray (Tide,
  ray with star freckles); Meteorhino (Ember, rhino calf with a
  glowing horn); Haloheron (Tide, heron with a gold-and-violet halo).

Guardians (grumpy, sleepy or lonely; never scary; friendly once
cheered up)
- F1 Old Bramblehorn (Leaf): a sleepy ox overgrown with hedges.
- F2 Clatterclaw (Tide): a hermit crab wearing a lighthouse.
- F3 Grumblecap (Ember): a toad under a glowing lantern mushroom.
- F4 Brrnard (Tide): a mountain dog the size of a cabin who lost his
  bell.
- F5 Starsnore (Ember): a sky whale snoring constellations.
- Weekly, in the hub: Honk the Clockwork Goose; Dozy the Pillow
  Dragon.

Model count: 40 for soft launch (9 starter, 25 wild, 5 Guardians, 1
weekly). 27 for the smallest playable version (Floors 1-3).

## B9. Economy (starting values, checked by simulation)
One currency: coins. No premium currency. Start with 50 coins.

By floor, F1 / F2 / F3 / F4 / F5
- Common income per second: 1 / 3 / 9 / 27 / 81
- Common power: 2 / 8 / 250 / 2,200 / 7,500
- Guardian power: 20 / 180 / 7,500 / 65,000 / 225,000
- Charm price: free / 300 / 4,000 / 50,000 / 600,000

By rarity, Common / Uncommon / Rare / Epic / Legendary
- Income: x1 / x2 / x3.5 / x6 / x10
- Power: x1 / x1.5 / x2.5 / x4 / x7

- Starter power = 3 x 1.2^(level-1) x stage (1, then 1.5 at Lv 5,
  2.5 at Lv 25, 4 at Lv 42). Level cost = 10 x 1.4^(level-1) coins.
- Heart n costs 100 x the floor's Common income x the rarity power
  multiplier x 2^(n-1). Floor 1 Rare: 250, 500, 1,000, 2,000, 4,000.
- Pads: +4 for 500 / 6,000 / 70,000 / 800,000.
- Untested guesses: stack +1 for 200 / 1,000 / 5,000 / 25,000 /
  120,000 / 600,000 / 3,000,000; Night Lantern 250,000.
- Showdown: the meter is Guardian power x 40; teams drain it at Team
  Power per second; good cheering adds about 20%.
- Pacing targets for a typical player (2 sessions of 18 min a day):
  Guardian 1 by 5 min, Guardian 2 by 15-20 min, Guardian 3 on day 2,
  Guardian 4 on day 4, Guardian 5 around day 8. Evolutions at about
  3 minutes, on the first return visit, and on day 4.
- [A1] Secret pets: income x20, power x10 (untested). Play meters:
  Guardian power x 4 / 10 / 150 for Epic / Legendary / Secret.
  tools/econ_sim adds 5 s per Epic try and 12 s per Legendary try.
- A simulation with a greedy bot hits those targets with these values
  (wins at about 4, 15, 58, 141 and 260 active minutes). The bot
  ignores natures, friend and rested bonuses, treasure and index
  sets, and real players are slower. Rebuild it as tools/econ_sim,
  reading the same config module as the game: the bot catches 3 pets
  per 150 s trip (success 95/85/70/50/25% by rarity), keeps the best
  earners, buys the floor's Charm, then whatever adds most Team Power
  per coin, and gets 3,600 s of income per session break. Re-run it
  after every tuning change and show me the table.

## B10. Art bible
Style: bright, chunky, toy-like 3D. Stylized and low-poly, like vinyl
figures. Never realistic.
- Pets: big heads, large simple eyes, one bold silhouette, 2-3 flat
  colours, matte, no fine texture. Each must read at icon size and
  from 50 studs away. Symmetrical. Common about 2 studs tall,
  Legendary about 4, Guardians 25-40.
- Rarity reads three ways: frame colour (grey, green, blue, purple,
  gold), frame shape, and glow strength.
- Dawn forms: gold and cream palette, sun crest, soft rays. Dusk
  forms: violet and indigo palette, crescent crest, star sparkles.
  Same mesh as the base form.
- Floors: one colour mood each, simple shapes, soft gradient sky. A
  floor starts dim and washed out and blooms to full colour when its
  lantern is relit.
    F1 Sunny Meadow: grass green, butter yellow, sky blue, morning.
    F2 Sunset Shore: coral, pink, teal water, golden hour.
    F3 Glowcap Grove: teal and violet with lime and pink glow, a
      friendly night.
    F4 Frostbell Peaks: white, ice blue, warm lantern orange.
    F5 Starlight Deck: navy, gold stars, lavender clouds.
- Effects get the polish, because they are what gets clipped: ring
  hits, catch sparkle, the slow-motion bolt, evolution flash, pillar
  of light, lantern bloom, coin pops, stack wobble.
- UI: thick rounded buttons, big numbers, icons over words, one
  rounded bold font.
- Nostalgia as an accent: pixel-style index icons and retro-flavoured
  jingles, not a full retro look.
- Pipeline: first a style sheet (3 starters, Floor 1, HUD) for my
  approval. Then batches. Reuse first: read ASSET_INDEX.csv in the
  Game Asset Library and show me what fits. For new models prompt
  for "stylized cartoon toy, chunky low-poly, big head, large simple
  eyes, 2-3 flat colours, matte, symmetrical, neutral pose", then
  decimate to 5,000 triangles or fewer with 512 px textures.
- Store art: icon and thumbnails from real in-game captures, built
  around the pet stack and the tower.

## B11. Audio bible
- One 5-note "lantern" motif runs through everything.
- A calm loop per floor in that floor's mood; a hub theme; a faster
  showdown version.
- Jingles: three rising notes on the three rings, resolving on a
  catch; a slide-whistle for the bolt; level-up; evolution fanfare;
  lantern relight swell; welcome-back chime.
- Soft wood-and-glass UI sounds. Music sits under effects. Separate
  music and effects sliders.
- All original. Ask before any paid generation.

## B12. Screens and controls
- Landscape. Thumbstick left, jump right. Tap anywhere for rings.
- HUD: coins top left; floor number and Team Power top centre; at
  most 3 buttons on the right (Team, Index, Shop); one context
  button; Wick as the hint giver.
- Numbers shortened (1.2K, 3.4M). Touch targets 48 px or more. Safe
  areas respected. Tested at 667x375.
- Settings: music, effects, low graphics, tap assist, reduced flash.
- No popups in the first 5 minutes. The Shop button appears after
  that, and nothing ever interrupts play to sell.

## B13. Money (all prices are proposals for my approval)
- Sell looks and time-savers, never chance.
- Passes (Robux): 2x Coins 399; Bigger Stack 249; +8 Camp Pads 199;
  Auto-Collect 199.
- Looks, bought directly: pet auras and trails, camp themes, lift
  skins, 49-299.
- Coin packs worth 30 min / 2 h / 8 h of current income: 49 / 149 /
  399.
- From week 3, only if day-1 return is 12% or more: a 28-day Tower
  Pass, free lane for everyone, paid lane looks only.
- Every item shows exactly what you get. Purchases go through
  ProcessReceipt, grant once, and survive a rejoin.

## B14. Live plan (every Saturday)
- Soft launch: Floors 1-5, 25 wild pets, 3 starters, 5 Guardians.
- Wk 1: Floors 6-7 (Candy Canyon, Clockwork Attic) and the monument
  of first clears. Wk 2: weather days and a Radiant weekend. Wk 3:
  evolutions for 10 wild pets, Tower Pass. Wk 4: pet fusion (3 of a
  kind grow one size), leaderboards. Wk 5: Floors 8-9. Wk 6: Floor
  10 and the Season 1 mural reveal.
- Each update ships: 8 or more pets, a Guardian, a set of looks, a
  code, a patch-note image, three 15 s clips.
- Events come back. Nothing is "last chance".

## B15. Moments built to be clipped
1. "SO CLOSE": a Legendary bolts on beat three. Its mirror: "PERFECT
   x3" under the pillar of light.
2. The Dawn-or-Dusk evolution reveal.
3. The pet stack: ten pets wobbling on a tiny avatar.
4. [A1] A whole server playing with one Legendary, then seven catch
   tries at once.
5. Seven players' pets around one building-sized Guardian.
Offer a capture at these moments through the Captures API where
Roblox allows it for that player (Moments is 13+). Otherwise nothing.

====================================================================
PART C. BUILD PLAN
====================================================================

## C1. Tech rules
- Luau source lives in the project folder and installs into Studio by
  this machine's existing method, or Rojo if installed. Use a Studio
  MCP connection if configured, otherwise computer use.
- Place: 7 players, StreamingEnabled, R15.
- Config modules (Pets, Floors, Economy, Shop) hold every value in
  Part B and feed both the game and tools/econ_sim.
- Server services: Data, Pets (spawns, tap checks), Camp (pads,
  income, away income), Levels, Team, Showdown, Choice (Share or
  Keep, sides), Floors (unlocks, lift, lanterns), Friends (bonus,
  invites, help), Return (chest, ladder, egg, rested), Events
  (pillar, Weekly Guardian, merchant), Shop, Codes, Analytics,
  AntiExploit.
- Client controllers: TrustTap, Stack, Camp, Showdown, HUD, Wick
  (tutorial), FX, Audio, Settings.
- Saved data (versioned): coins; starter {species, level, form}; pets
  [{id, species, rarity, hearts, radiant}]; pads; team; stack; floors
  cleared and the choice on each; Dawn and Dusk points; Charm tier;
  upgrades; index; journey day; last seen; egg; weekly; purchases;
  codes; settings; tutorial step; first join; stats.
- Saving: session-locked DataStore, autosave every 120 s, save on
  leave and BindToClose, retries. ProcessReceipt idempotent by
  PurchaseId.
- Trust: the server issues each ring timeline; the client sends tap
  offsets; the server scores them, checks distance (15 studs),
  ownership and cooldowns, and rate-limits every remote. Flag inhuman
  streaks; never auto-ban.
- Performance: 30+ FPS on an emulated low-end phone with 7 players,
  12 wild pets and 7 stacks on screen; client memory under 600 MB;
  low-graphics mode turns off shadows and trims effects.
- A debug panel for testing exists in Studio only.
- [A1] Wild showdowns reuse the Showdown service and UI. No new
  combat system, no moves, no health bars on pets.

## C2. Milestones (build, test, report, continue)
M0 Setup. Bible saved, status files, source install, tools/econ_sim
   matching B9. Test: a script edit shows in Studio; the sim table
   matches B9.
M1 Catch. Starter choice, Trust Tap, shared spawns, stack, camp pads
   and income, Floor 1 in greybox. Art: style sheet for approval.
   Test: first catch within 30 s of spawn; server scores every tap.
M2 Grow. Saving, feeding, levels, first evolution, lift, Floor 2,
   Guardian 1. Test: rejoin keeps everything; evolution near 3 min.
M3 Together. Co-op showdowns, call for help, friend bonus, pillar of
   light, Floor 3. Test: 3 clients on a local server; rewards correct.
M4 First 5 minutes. Wick, sound, HUD, analytics.
   >>> SMALLEST VERSION FOR REAL PLAYERS: Floors 1-3, 15 pets, no shop <<<
   Test: a new player with no instructions evolves a starter in 3 min.
M5 Come back. Chest, rested bonus, ladder, egg, Share or Keep, sides,
   trophy, natures, hearts, index, emotes, Floors 4-5.
   Test: a simulated day-2 return opens with the Lv 25 evolution.
M6 Shop and policy. Test: every purchase grants once, survives
   rejoin, and nothing for sale is random.
M7 Art and audio. Approved batches in, murals, icon, thumbnails,
   gameplay video.
M8 Hardening. Low-end phone, 30-minute soak with 7 players, data-loss
   tests, maturity questionnaire. Then STOP before publishing.
M9 Launch and Saturdays, only after my go.

Done for soft launch means: all of B6 happens on time for a new
player; no data loss in tests; every target in C3 is measured; every
rule in Part A and B2 holds; I have approved art, sound and prices.

## C3. Measure
Funnel: Joined, StarterChosen, FirstCatch, FirstPetPlaced, Floor1,
FirstEvolution, FirstGuardianWin, FirstChoice, Floor2,
FirstCoopShowdown, Session10Min, Day2Return, Lv25Evolution. Log every
coin source and sink.
Targets
- 85%+ choose a starter within 15 s; 70%+ catch a pet within 45 s.
- Leaving in under 60 s: 25% or less. Leaving in 61-180 s: 15% or
  less.
- Day 1 return 15%+ (large-game median 10.3%, top 1% 22.2%).
- Day 7 return 4%+ (median 1.6%, top 1% 9.1%).
- Day 30 return 1.5%+ (median 0.5%, top 1% 4.7%).
- Session 12 min+ (median 9.8, top 5% 16.6).
- 20%+ of sessions include a showdown with another player.
- 40%+ of choices are Share. If far lower, raise the share reward.
- [A1] Track wild showdowns started, joined by 2+ players, and
  finished. Target: half of Legendary showdowns have 2+ players.

## C4. Launch (prepare everything; I approve every spend and post)
- Account: ID-verified, 2-step verification on, and either Plus or
  Premium held 2 months in a row or the one-time refundable all-ages
  fee. Confirm the current fee and the 250-play number in Creator Hub
  under Audience Reach, and whether ad-driven plays count toward it.
- Title: propose 5 that explain the game in 6 words or fewer. Confirm
  no live Roblox game uses them. Never lead a title with rewards.
- Custom thumbnails (required for Home), 3 icon variants to test (pet
  stack; starter trio; tiny avatar under the tower), and a short
  real-gameplay video for the Home tile.
- Stage 1, 16+ only: small daily ads to gather funnel data and the
  evaluation plays. Fix the worst funnel step every 2 days.
- Stage 2, once day-1 return is 12%+: raise ads and nominate the game
  for Standout Games.
- Stage 3, once under-16s can play: weekend ads to all ages.
- Total budget $500, spent only by me. Stop ads if day-1 return is
  under 8%.
- For video creators: codes, a first look at every Saturday update,
  and three 15 s vertical clips a week from B15. Draft the outreach;
  I send and post.

## C5. Decision rules (judge on 1,000+ players)
- Scale up: day-1 15%+ AND session 12 min+ AND under-60 s leavers at
  25% or less.
- Iterate, two 4-day fix cycles at most: day-1 10-15%.
- Stop and tell me: day-1 under 10% after both cycles, or under 70%
  get a first catch, or 60 days pass without the evaluation plays.

Start now with the three first actions in Part A, then M0.
