# PetTower ("Catch Pets, Climb The Tower") - read this first

A new, original Roblox game for players aged 7-12 on phones. Owner account: FantasyGaming
(@Talleyrandw). This repo is separate from every other project on the owner's machine.

- Design and rules: `docs/GAME_BIBLE.md` (with Amendment 1 folded in, marked [A1]).
- Where things stand: `docs/STATUS.md`. What differs from the bible and what awaits the owner's
  ruling: `docs/DECISIONS.md`.
- On the Mac, start with `docs/HANDOFF_MAC.md`.
- Taking over from another session or account: `docs/CONTINUE_PROMPT.md`.
- Branches: `main` = last build that passed Studio tests; `dev` = current work.

Skills in `.claude/skills/` (use them):
- `pettower-rules`: approvals, money and kindness rules, one-project-only. Before any work.
- `pettower-test`: headless tests, syntax check, economy simulation. Before every commit.
- `pettower-studio`: installing into Studio and running the checklist on the Mac.
- `pettower-branches`: splitting work across branches and worktrees, merge order.
- `pettower-assets`: models, sounds and store art; nothing in without the owner's review.
- `pettower-saturday-update`: adding floors, pets and weekly content.

Before every commit: `python3 tools/check_lua.py && python3 tools/lua.py tests/run.lua`.
Never publish, set a price, spend, or post without the owner's explicit approval.
