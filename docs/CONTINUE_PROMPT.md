# Prompt for a new AI session: continue building PetTower

Copy everything in the box below into the new session as its first message.

```
You are taking over construction of an original Roblox game, working title "Catch Pets, Climb The
Tower" (project name PetTower). A previous AI session built the code without Roblox Studio and left
everything in git. Pick up from there. Do not start over and do not redesign.

1. GET THE PROJECT
   Repo: https://github.com/t9731594-create/Pet-towers-   Branch to work on: dev
   - On the owner's Mac, the project folder must be "/Volumes/SANDISK SSD/Projects/PetTower".
     If the SanDisk is not mounted, stop and ask. If the folder does not exist:
       cd "/Volumes/SANDISK SSD/Projects" && git clone https://github.com/t9731594-create/Pet-towers- PetTower
     then: cd PetTower && git checkout dev && git pull
   - In a cloud session without the Mac: clone the same repo, check out dev, and do only work that
     needs no Studio.
   - If you cannot read or push to the repo, stop and tell the owner; do not create another repo.

2. READ BEFORE DOING ANYTHING (in this order)
   CLAUDE.md                      - what this project is and where things are
   .claude/skills/*/SKILL.md      - six project skills: rules, testing, Studio, branches, assets,
                                    Saturday updates. Follow them.
   docs/STATUS.md                 - what is built, real test numbers, what is not done
   docs/DECISIONS.md              - every place the build differs from the design, and every row
                                    marked "Pending" that needs the owner's ruling
   docs/GAME_BIBLE.md             - the full design and the owner's working rules (Part A)
   docs/HANDOFF_MAC.md            - place setup, install, and the Studio test checklist
   docs/BUGS_FOUND_HEADLESS.md    - bugs already fixed, and the "Needs Studio" list to check first
   docs/TUNING_PROPOSAL.md, docs/LAUNCH_RESEARCH.md, docs/API_CHECK.md, docs/ART_PROMPTS.md,
   docs/launch/                   - proposals, research and drafts (nothing applied, sent or posted)

3. CONFIRM THE BUILD IS HEALTHY
   pip install lupa
   python3 tools/check_lua.py && python3 tools/lua.py tests/run.lua
   Expected at hand-over: 0 syntax errors in 96 files; 238 tests passed, 0 failed. If your numbers
   differ, find out why before changing anything.

4. WHERE THINGS STAND
   Written and tested without Studio: all game rules for milestones M0-M6, Amendment 1 (wild
   showdowns and Secret pets), the weekly systems, a grey-box world built by code, grey-box client
   screens, saving, shop rules (shop switched off), analytics hooks. The server and client have been
   run against a fake Roblox engine (tools/roblox_mock.lua), never in real Roblox Studio.
   Not done: any run in real Studio; all art and sound (pets are coloured balls, icons are
   placeholder letters); murals; device and soak tests (M8); anything to do with publishing.

5. WHAT TO DO NEXT
   If you have the Mac and Roblox Studio:
     follow docs/HANDOFF_MAC.md - new place in its own Studio window, install the source, fix what
     the engine rejects, check the "Needs Studio" list first, then run the checklist and write the
     real numbers into docs/STATUS.md. Then read the Game Asset Library index and show the owner
     what fits before proposing any generated art.
   If you do not have the Mac:
     ask the owner which Pending decision to settle first, and do only Studio-free work.

6. RULES THAT NEVER BEND (full list in the pettower-rules skill and bible Part A)
   - Stop and ask the owner before: publishing, spending Robux or money, paid Meshy or Higgsfield
     generations, creating a repo, posting anything online, or setting or changing any price.
   - The owner reviews every batch of models, sounds and screens before it goes into the game.
   - Work only on this project. Never open, edit, save or publish any other project or place on the
     machine (Aeonrise / StrikeWarfare2100, Seventh Horizon, Sword Oath, Hacker Universe, Bounce For
     Sky Pets). "/Volumes/SANDISK SSD/Game Asset Library" is copy-only.
   - Players are 7-12, on phones, chat off: no reading needed, nothing scary, nothing hit or hurt.
   - Nothing bought with Robux or coins may be random or change odds. No pressure: no countdowns,
     no "hurry", no "last chance", no penalty for a missed day.
   - Everything original. The server decides everything that matters.
   - Work on dev or a branch from it. main is the last build that passed Studio tests: merge dev
     into main only with the owner's OK. Never force-push or rewrite history.
   - Run the check and the test suite before every commit; commit and push often.
   - Log anything that differs from the bible in docs/DECISIONS.md and keep docs/STATUS.md current.
   - Report in 6 lines per milestone with real numbers only. Never promise the game will go viral.

7. FIRST MESSAGE BACK TO THE OWNER
   Say whether you could pull the repo and what the two test totals were, whether the SanDisk and
   Studio are available to you, what you will do first, and the Pending decisions you need answered
   to keep moving (start with: the economy tuning proposal, the Secret pet names and chime times,
   the flagged pet names, the title, and whether the repo should be private).
```

Notes for the owner
- The other account needs access to the repo. It is public right now, so any account can read it; to
  push, that account must be given write access (or use your GitHub login). If you make the repo
  private, add the other account as a collaborator first.
- Owner account for the game: FantasyGaming (@Talleyrandw).
