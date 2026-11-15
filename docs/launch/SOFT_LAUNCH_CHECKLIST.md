# Soft launch checklist (DRAFT for the owner)

Status: draft, in order, from "Studio tests pass" to "stage 1 ads on". Built from bible C3, C4, C5 and
docs/LAUNCH_RESEARCH.md. **OWNER** marks a step that needs the owner's approval or action.
"Unconfirmed" means the research could not check it. Recheck every number in Creator Hub (hard rule 7).

## 1. The build is ready

- [ ] Studio tests pass for M1-M8 with real numbers written into docs/STATUS.md (today nothing has run
      in Studio).
- [ ] All of B6 happens on time for a new player with no instructions.
- [ ] No data loss in the rejoin, shutdown and 30-minute, 7-player soak tests.
- [ ] 30+ FPS on an emulated low-end phone; client memory under 600 MB.
- [ ] Pending rows in docs/DECISIONS.md are ruled on. **OWNER**
- [ ] Art, sound and screens approved batch by batch. **OWNER**
- [ ] Shop: stays off, or every price is approved and product ids are set (decision 24). **OWNER**
- [ ] Pet names flagged in decision 28 kept or replaced. **OWNER**
- [ ] STOP here. Nothing is published without the owner's go (hard rule 4, M8). **OWNER**

## 2. The account (FantasyGaming, decision 2)

- [ ] ID-verified. **OWNER**
- [ ] 2-step verification on. **OWNER**
- [ ] Either Plus or Premium held 2 months in a row, or the one-time refundable fee. The fee is reported
      as 1,000 Robux per game, refunded 90 days after the game becomes eligible (unconfirmed, search
      snippet only). Spending Robux needs approval. **OWNER**
- [ ] Do not use the optional expedited review, reported as 50,000 Robux refundable (from the docs
      mirror, not Creator Hub), unless the owner asks for it. **OWNER**

## 3. Audience Reach (Creator Hub)

- [ ] Read the evaluation bar on the Audience Reach dashboard. The bible says 250 unique plays by highly
      engaged 16+ players within 60 days. It may now be 100 (unconfirmed).
- [ ] Read how "highly engaged" is defined. Research: account tenure, playtime in the game, and a
      minimum purchase anywhere on Roblox in the same 60 days (unconfirmed).
- [ ] Find out whether ad-driven plays count toward the bar (unconfirmed). This decides how useful
      stage 1 ads are for the evaluation.
- [ ] Write the confirmed numbers into docs/DECISIONS.md.

## 4. Questionnaire and page

- [ ] Fill in the maturity questionnaire truthfully from docs/launch/MATURITY_QUESTIONNAIRE.md. Target
      Minimal, accept Mild. Check the four flagged answers first. **OWNER**
- [ ] Title chosen from docs/launch/STORE_PAGE.md and searched on Roblox itself. **OWNER**
- [ ] Description approved. **OWNER**
- [ ] Custom thumbnails uploaded (required for Home), from real captures. **OWNER**
- [ ] Three icon variants ready to test: pet stack; starter trio; tiny avatar under the tower. **OWNER**
- [ ] Short real-gameplay video for the Home tile. **OWNER**
- [ ] Place settings: 7 players, private servers free, no off-platform links anywhere in the game.

## 5. Publish

- [ ] Owner gives the go to publish. **OWNER**
- [ ] Publish. Join on a real phone. Play the first 5 minutes. Leave and rejoin: everything is kept.
- [ ] Launch code works in the Mailbox and gives a look or at most 10 minutes of income.

## 6. Funnel dashboards (events only log in a published game, docs/API_CHECK.md)

- [ ] Funnel steps arrive in order: Joined, StarterChosen, FirstCatch, FirstPetPlaced, Floor1,
      FirstEvolution, FirstGuardianWin, FirstChoice, Floor2, FirstCoopShowdown, Session10Min,
      Day2Return, Lv25Evolution.
- [ ] Coin sources and sinks are logged.
- [ ] Wild showdowns started, joined by 2+ players, and finished are logged.
- [ ] A view for each target (C3): starter within 15 s 85%+; first catch within 45 s 70%+; leaving in
      under 60 s 25% or less; leaving in 61-180 s 15% or less; day 1 return 15%+; day 7 4%+; day 30
      1.5%+; session 12 min+; 20%+ of sessions with a co-op showdown; 40%+ of choices Share; half of
      Legendary showdowns with 2+ players.
- [ ] Note beside the targets: the comparison medians are GameAnalytics figures, not Roblox's, and the
      16.6 min "top 5%" session figure was not checked (unconfirmed).

## 7. Stage 1 ads on (16+ only)

- [ ] Total budget is $500 for all stages, spent only by the owner. **OWNER**
- [ ] Owner sets the small daily amount and turns stage 1 ads on, aimed at 16+. **OWNER**
- [ ] Remember: players bought with ads do not count toward Home ranking (confirmed in the docs mirror).
- [ ] Every 2 days: fix the worst funnel step.
- [ ] Creator outreach drafts are ready; the owner sends them. **OWNER**

## Decision rules once ads are on (C4, C5; judge on 1,000+ players)

- Stop ads if day-1 return is under 8%. **OWNER**
- Scale up: day-1 15%+ AND session 12 min+ AND under-60 s leavers at 25% or less.
- Iterate, two 4-day fix cycles at most: day-1 10-15%.
- Stop and tell the owner: day-1 under 10% after both cycles, or under 70% get a first catch, or 60 days
  pass without the evaluation plays.
- Stage 2 (day-1 12%+): raise ads, nominate for Standout Games. **OWNER**
- Stage 3 (once under-16s can play): weekend ads to all ages. **OWNER**
- Tower Pass from week 3 only if day-1 return is 12% or more (B13). **OWNER**
- The bible leaves one gap: day-1 at 15%+ with a short session or high early leavers is not named in C5.
  Treat it as "iterate" unless the owner says otherwise. **OWNER**
