---
name: pettower-branches
description: The branch, worktree and merge workflow for PetTower when work is split across several workers or subagents. Use this whenever a task for this project says to "split the work", use branches or worktrees, coordinate subagents, implement an amendment or feature set across branches, merge into dev, or when deciding whether dev may go into main.
---

# PetTower: splitting work across branches

The owner wants parallel work that cannot trample itself. The pattern below has been used on this
project and works; follow it rather than inventing a new one.

## Branch meanings
- `main`: the last build that passed its Studio tests. Merge `dev` into it only with the owner's OK.
- `dev`: the coordinator's branch. Everything lands here first.
- `feat/...`, `fix/...`, `tools/...`, `docs/...`, `test/...`: one worker each.
Remote: `origin` is the PetTower repo. Never push to any other repository. Never force-push, rewrite
history or delete a branch.

## The coordinator's order of work
1. Contracts first, on `dev`, before any branch exists: new config values, remote names and payloads,
   saved-data fields, service function signatures, and which files each branch owns. Write them down
   (see `docs/CONTRACTS_AMENDMENT_1.md` for the shape) and commit.
2. Branch every worker from that commit, each in its own worktree:
   `git worktree add -b <branch> ../PetTower-wt/<branch-with-dashes> dev`
3. One worker per branch. Each branch owns its files. Nobody edits another branch's files or the
   contract files (Config, Remotes, Profile, Main scripts, harness, bible, decisions, status). A
   worker who needs a contract change writes `REQUEST: ...` in its note and stops on that item.
4. Workers write Luau and tests that run without Studio. Only the coordinator touches Studio, and
   never two sessions in the place file.
5. Each branch ends with commits and a short note in `docs/branches/<branch-with-dashes>.md`: what
   was built, files, tests run with real results, open problems, requests.
6. Merge into `dev` one branch at a time, in the order the owner gave, with `--no-ff`. After EACH
   merge run `python3 tools/check_lua.py` and `python3 tools/lua.py tests/run.lua`. Stop at the first
   failure.
7. After the last merge, read every worker's "open problems" against the others: branches built
   apart usually disagree somewhere (who receives a remote, an attribute that is nil vs false, which
   clock a time is measured on). Fix those on `dev`, log each in `docs/DECISIONS.md`.
8. Report per branch, then wait for the owner before `dev` goes into `main`.

## Briefing a worker
A worker knows only what the brief says. Give it: the worktree path and branch; the contract file to
read first; the exact files it owns; the final design in the owner's words ("do not redesign"); the
Lua 5.1 rule; how to verify; the note file to write; and what to send back (commit hash, test totals
line, what it is unsure will work in Roblox). Tell it not to push.

## Small jobs
A change that touches contract files, or a fix of a few lines, is the coordinator's own work on
`dev`: do not spin up a branch for it.
