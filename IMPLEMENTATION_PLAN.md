# WordFall — Implementation Plan for Claude Code

> **Remaining work only · Updated 2026-03-06**
>
> Work through steps sequentially within each phase. Each step is a self-contained task with acceptance criteria. Do not move to the next step until all acceptance criteria pass.

---

## How to Use This Document

Each step below is designed as a prompt for Claude Code. For each step:

1. Read the step description and implementation notes
2. Implement the changes
3. Validate against the acceptance criteria
4. Move to the next step

> ⚠️ **Critical:** This plan front-loads endgame tuning (Phase A2) before finalizing the difficulty curve. If R40–50 don't work, the entire target formula needs adjustment. Don't skip ahead.

---

## Prerequisites

Before starting, ensure these are in place:

- [ ] Existing WordFall codebase with working board, tile selection, and word validation
- [ ] `LetterValues.swift` (or equivalent) with per-letter point values defined
- [ ] A word dictionary for validation (the game already uses one)
- [ ] Basic board generation + gravity system functional

---

## Completed Through 2026-03-06

- Step 1: Word scoring formula
- Step 2: Run-wide word use tracking
- Step 3: 50-round run with acts
- Step 4: Move budget formula
- Step 5: Score target formula + score-only round clear/fail gate
- Step 6: Long-word move refunds + refund toast
- Step 7: Debug round metrics logging
  - Added a DEBUG settings toggle for round metrics logging
  - Added structured per-round JSON telemetry covering round info, economy, locks, words, and powerups
  - Telemetry emits on round clear or fail and is stored on the session for inspection/testing
- Step 8: Prototype rounds 40–50 debug entry
  - Added a DEBUG start-round setting for new runs/restarts
  - Added seeded late-run bootstrap state for round jumps above round 1
  - Added tests covering telemetry aggregation and round-40 debug bootstrapping
- Step 9: Late-run sanity validation support
  - Added a rounds 40–50 sanity report that aggregates telemetry into the plan's target ranges
  - The report dedupes retries by round, tracks missing/failed late rounds, and snapshots active tuning dials
  - Added session-stored JSON output for the late-run sanity report to support debug inspection and testing
- Step 10: Final score target curve logging
  - Documented the finalized score-target formula in code comments, including the explicit Act 3 multiplier dial
  - Added generation and session-stored JSON logging for the full 50-round score target curve
  - Added tests covering late-run sanity evaluation and score-curve generation/logging
- Step 11: Challenge round infrastructure
  - Added a `ChallengeRound` model plus resolver mapping rounds 10/20/30/40/50 to named challenge types
  - Moved challenge modifiers to resolver-backed infrastructure: scoreTarget × 1.15, moves + 2, lockCount + 2
  - Added challenge metadata to the session/HUD/banner so challenge rounds are visibly distinct in-game
- Step 12: Round 10 quad board
  - Added the separated 2×2 quad-board template for round 10 with quadrant metadata on playable cells
  - Enforced the round rule that submitted words must stay within a single quadrant
  - Added generation safeguards to guarantee at least 2 vowels per quadrant and tests for segmented gravity behavior
- Step 13: Round 20 pyramid board
  - Added a pyramid-shaped challenge template with a narrow top, wide base, and irregular gravity/refill support via the existing masked-board pipeline
  - Added board-generation safeguards to preserve a minimum vowel floor on the reduced tile count
  - Added tests covering the mask shape, gravity behavior, and vowel distribution guarantees
- Step 14: Round 30 tax round
  - Added the tax-round challenge template and rule metadata so round 30 shows the correct HUD messaging
  - Updated submit-cost calculation so base cost is 2 on round 30, with locked submissions costing 3 total
  - Verified invalid submits still refund fully and long-word refunds still apply on accepted tax-round words
- Step 15: Round 40 alternating pools
  - Added the split left/right pool template with a hard center gutter so the board renders as two distinct regions
  - Enforced pool-only submissions plus alternation state, so the same pool cannot be used twice in a row
  - Added region-aware generation safeguards for vowels, consonants, duplicate consonant caps, and 4-word multiset solvability per pool, plus tests covering 100 generations
- Step 16: Round 50 final exam
  - Added the diamond-board final exam template with stone obstacles and a 6-letter minimum-word rule
  - Updated submit validation, hints, and submit UI messaging so the 6+ letter rule is surfaced consistently
  - Tuned generation toward longer words with a higher vowel floor and added tests for template shape, rejection behavior, and vowel distribution
  - Final playfeel confirmation for the climax round is still pending real gameplay
- Step 17: Lock count formula + placement
  - Replaced the old scaling logic with the plan formula: `2 + floor((round - 1) / 6)`, with challenge rounds adding +2 locks
  - Locks are now placed once at round start on valid letter tiles only, with no mid-round reseeding
  - Existing tile visuals continue to distinguish locked tiles clearly on the board and in the word pill
- Step 18: Lock break mechanics + rewards
  - Locked tiles now break and clear as part of a valid word, so locks behave as optional acceleration instead of persistent blockers
  - Locked submits still cost +1 move total, and each broken lock now refunds +1 move immediately and adds +20 crack-bonus score
  - Added lock-break sound/haptic feedback and aligned round telemetry with actual locks broken this round
- Step 19: Lock HUD display
  - Added a subtle lock progress readout in the in-round HUD showing locks broken vs total locks for the board
  - Kept locks framed as optional via secondary styling/captioning rather than as a primary round objective
  - Broken locks now visibly clear their badge/icon state on-board as soon as the lock is cracked
- Step 20: XP calculation at run end
  - Added the run-end XP formula for wins and losses: base, rounds cleared, score conversion, challenge clears, and rare-letter bonus
  - Added run tracking for challenge clears and rare-letter usage so XP inputs are available at summary time
  - Surfaced XP earned on the run summary screen and added tests covering the formula and end-run summary payload
- Step 21: Persistent XP storage + lifetime tracking
  - Added a persistent `PlayerProfile` storing total XP plus lifetime words built, locks broken, rare-letter words, highest round reached, and completed runs
  - Wired run-end summary data into profile updates so wins and losses both commit lifetime progression
  - Added debug reset support for the saved profile in settings and tests covering persistence/reset behavior
- Step 22: XP unlock thresholds
  - Added the full XP threshold unlock table with derived slot/perk-tier/meta unlock helpers backed by persistent profile state
  - Run-end summaries now detect and surface newly earned unlocks immediately after each run
  - Added start-screen profile UI showing current XP, next unlock target, and unlocked progression state
- Step 23: Equip slots + starter perks
  - Added a pre-run starter-perk equip screen on the start flow, with slot-gated selection persisted on the player profile
  - Implemented the three starter perks in gameplay: Pencil Grip invalid-submit tempo refund, Clean Ink 6+ letter score bonus, and Spare Seal locked-submit discount
  - Added tests covering starter-perk persistence, locked-submit cost reduction, invalid-submit refund behavior, and Clean Ink score feedback
- Step 24: Milestone passives
  - Added lifetime milestone passives derived from persistent profile stats for starting shuffle, locked-submit discount, rare-letter spawn boost, and challenge-round opening move
  - Reworked the milestones screen to show lifetime milestone progress and unlocked passive effects instead of the older perk-unlock presentation
  - Added tests covering lifetime milestone unlock state plus board-start application of the passive bonuses
- Step 25: Run lifetime stat tracking
  - Confirmed run-wide tracking for total score, rounds cleared, words built, locks broken, best word by highest single-word score, challenge clears, and rare-letter usage
  - Added test coverage validating that loss summaries include the full tracked stat set and round reached metadata
  - Added scoring-order test coverage confirming best-word tracking is score-based rather than length-based
- Step 26: Run summary screen
  - Updated the summary subtitle copy to match plan language ("Run Complete" on wins, "Run Ended" on losses)
  - Expanded summary stats presentation to include challenge clears, rare-letter usage, and round reached on losses
  - Kept all required actions wired from summary overlay: Back to Menu, Play Again, and Share Run
- Step 27: Share card generation
  - Updated share-card rendering to a social-preview landscape format (`1200×630`) with stronger branding and run progress visualization
  - Kept run-summary integration wired to iOS share sheet via `UIActivityViewController`
  - Added test coverage for share-card export sizing
- Step 28: Extend word length to 20 (all rounds)
  - Increased selection/submit support from 8 to 20 letters across resolver, board input, and submit UI
  - Extended scoring length multipliers through 20 letters with a soft ceiling and kept Round 50's 6-letter minimum intact
  - Replaced long-word refunds with the capped schedule (`6:+1`, `7–8:+1+0.25`, `9–10:+1+0.50`, `11–12:+1+0.75`, `13+:+1`)
  - Kept hint defaults focused on 6-letter suggestions and made word-pill selection rendering resilient for long selections
  - Added/updated tests for 9+ validation, multiplier mapping (9/12/16/20), refund behavior, and regression stability

---

## Phase A2 — Endgame Tuning

Before building anything else, validate that the math actually works for the hardest rounds. If R40–50 are impossible or trivial, every other number in the plan is wrong.

> ⚠️ This phase requires playtesting. Run rounds 40–50 with debug metrics enabled and compare against the sanity targets below.

---

### Step 9: Validate Against Sanity Targets

Compare your R40–50 telemetry against these benchmarks for a "good round" in Act 3:

Status:
- Validation/reporting support is implemented in code.
- Real gameplay confirmation for rounds 40–50 is still pending playtesting.

| Metric | Target Range |
|--------|-------------|
| Submits per round | 10–12 |
| Locks broken | 2–4 |
| 7–8 letter words | 1–2 per round |
| Avg points per word | 250–500 |
| Total round score | 3500–6500 |

**If targets are not met, adjust ONE dial at a time in this priority order:**

1. Length multipliers (increase 7 and 8-letter values)
2. Repeat penalty floor (raise from 0.40 to 0.50)
3. Lock bonus value (increase from 20 per lock)
4. Move refund thresholds (make 6-letter words give 0.25 fraction)
5. Act 3 scoreTarget multiplier (scale down 5–15%)

**Acceptance criteria:**

- [ ] R40–50 are completable by a skilled player (not trivially easy)
- [ ] Average points per word falls within 250–500 range
- [ ] Total round scores for R40–50 fall within 3500–6500
- [ ] If adjustments were made, they are documented with before/after values

---

## Remaining Work

- Step 9 follow-up: Playtest rounds 40–50 with debug metrics enabled and confirm the new sanity report passes against real gameplay telemetry; tune one dial at a time only if the report or feel is off
- Step 10 follow-up: Playtest the full score-target curve across early, mid, and final checkpoints and confirm R1/R10/R25/R50 feel right in real gameplay
- Step 16 follow-up: Playtest the final exam round and confirm it feels like a climax rather than a brick wall
- Post-Step 28 polish: Validate 9–20 letter availability against production dictionary content and perform gameplay balance checks across Acts 2–3 for long-word economy

---

### Step 10: Finalize Score Target Curve

After tuning, lock in the final scoreTarget formula. If you adjusted any dial in Step 9, recompute all 50 round targets and verify the full curve feels smooth.

**Acceptance criteria:**

- [x] Final formula is documented in code comments
- [x] All 50 round targets are generated and logged
- [ ] R1 is easily clearable in 5–6 submits
- [ ] R10 requires focused play but is reliably achievable
- [ ] R25 is a clear checkpoint requiring build optimization
- [ ] R50 is the climax: tense, demanding, but fair

---

## Phase B — Challenge Templates + Generation Safeguards

Build the five challenge rounds that punctuate the run every 10 rounds. Each introduces a constraint that changes how the player interacts with the board.

---

### Step 11: Challenge Round Infrastructure

Create the framework for challenge rounds before implementing individual templates.

**Implementation:**

- Create a `ChallengeRound` protocol/interface with properties: `boardTemplate`, `specialRule`, `modifiedScoreTarget`, `modifiedMoves`, `modifiedLockCount`
- Apply the universal challenge modifiers: scoreTarget × 1.15, moves + 2, lockCount + 2
- Add a challenge round resolver that maps round numbers to specific challenge types
- Ensure the HUD indicates when a challenge round is active

**Acceptance criteria:**

- [x] Challenge rounds automatically apply +15% target, +2 moves, +2 locks
- [x] A visual indicator distinguishes challenge rounds in the HUD
- [x] The resolver correctly maps rounds 10/20/30/40/50 to their challenge types

---

### Step 12: Round 10 — Quad Board

**Template:** 4 mini 4×4 boards arranged in a 2×2 grid.
**Rule:** Each submitted word must use letters from only one quadrant.

**Implementation:**

- Create the quad board template with 4 isolated 4×4 regions
- Tag each tile with its quadrant index (0–3)
- On submit, validate that all selected tiles share the same quadrant index; reject with message if mixed
- Ensure gravity operates independently within each quadrant

**Acceptance criteria:**

- [x] Board renders as 4 visually distinct quadrants
- [x] Selecting tiles from multiple quadrants and submitting shows an error
- [x] Gravity refills within each quadrant independently
- [x] Each quadrant has viable letter distributions (at least 2 vowels per quadrant)

---

### Step 13: Round 20 — Pyramid Board

**Template:** Pyramid-shaped mask (wide base, narrow top).
**Rule:** None additional — the shape itself is the constraint, limiting available tiles as you clear upward.

**Acceptance criteria:**

- [x] Board renders with a clear pyramid shape
- [x] Gravity works correctly within the irregular shape
- [x] Letter distribution accounts for reduced tile count

---

### Step 14: Round 30 — Tax Round

**Template:** Standard board.
**Rule:** Base submit cost becomes 2 (locked tiles add +1 for total 3). Invalid submits still refund fully.

**Acceptance criteria:**

- [x] Base submit cost is 2 for this round only
- [x] Locked submits cost 3 total
- [x] Invalid submits refund the full cost (net 0)
- [x] Move refunds from long words still apply normally

---

### Step 15: Round 40 — Alternating Pools

**Template:** Split board (left/right regions).
**Rule:** Word submissions must alternate between pools (left, right, left, right…).

**Generation safety rules (critical):**

This challenge can become unsolvable with bad letter distribution. Enforce these constraints during board generation:

- Each pool must have at least 2 vowels
- Each pool must have at least 6 consonants
- Cap identical consonants at 2 or fewer per pool
- **Solvability scan:** after generation, verify each pool can form at least 4 valid words of length 4–6 using a multiset-based dictionary check. If not, reroll the pool.

**Acceptance criteria:**

- [x] Board renders as two visually distinct left/right pools
- [x] Alternation is enforced: submitting from the same pool twice in a row is rejected
- [x] First submit can use either pool
- [x] Generation constraints produce solvable boards (test 100 generations, 0 failures)
- [x] Reroll triggers if solvability check fails

---

### Step 16: Round 50 — Final Exam

**Template:** Diamond board with stone obstacles.
**Rule:** Minimum word length is 6 letters.

**Acceptance criteria:**

- [x] Board renders as a diamond shape with stones
- [x] Words shorter than 6 letters are rejected with a clear message
- [x] Letter distribution is tuned to make 6+ letter words viable (higher vowel ratio)
- [ ] This round feels like a climax, not a brick wall

---

## Phase C — Locks Subsystem

Implement locks as a strategic acceleration mechanic, not a punishment.

---

### Step 17: Lock Count Formula + Placement

Determine how many locks appear each round and place them on the board.

**Formula:**

```
lockCount = 2 + floor((round - 1) / 6)
if challengeRound: lockCount += 2
```

**Implementation:**

- Calculate `lockCount` per round using the formula
- Randomly place locks on non-stone tiles
- Visually distinguish locked tiles (overlay icon or color change)
- Locks are optional — the round can be cleared without breaking them

**Acceptance criteria:**

- [x] R1 has 2 locks, R25 has ~6 locks, R50 has ~12 locks (including challenge bonus)
- [x] Locked tiles are visually distinct
- [x] Locks are placed on valid (non-stone) tiles only

---

### Step 18: Lock Break Mechanics + Rewards

Implement the lock break behavior and its rewards — the core reason locks feel good rather than punishing.

**Implementation:**

- A lock breaks when its tile is used in a valid submitted word
- Submit cost: if any selected tile is locked, total cost = 2 moves (base 1 + 1 for locks, regardless of how many locks)
- **On each lock break:** +1 move refunded immediately, +20 score added as "crack bonus"
- Show satisfying visual/audio feedback on lock break (crack animation, sound)
- Track `locksBrokenThisRound` and `locksBrokenTotal` for debug metrics

**Net economy of lock breaking:**

- Word with 1 lock: costs 2 moves, refunds 1 → net 1 move + 20 bonus points
- Word with 2 locks: costs 2 moves, refunds 2 → net 0 extra moves + 40 bonus points
- **Key insight:** multi-lock words are extremely efficient

**Acceptance criteria:**

- [x] Submitting a word with 1 locked tile costs 2 moves and refunds 1
- [x] Submitting a word with 2 locked tiles costs 2 moves and refunds 2
- [x] Lock bonus of 20 per lock is added to the word score
- [x] Lock-breaking metrics appear in debug output
- [x] Visual/audio feedback plays on lock break

---

### Step 19: Lock HUD Display

Show lock status in the HUD so players can make informed decisions about which tiles to target.

**Acceptance criteria:**

- [x] HUD shows locks broken this round vs lockCount (e.g. 3/6)
- [x] The display is subtle — locks are optional, not a primary objective indicator
- [x] Broken locks are visually updated on the board (icon removed or changed)

---

## Phase D — XP + Meta Progression

Build the between-run progression system that gives players a reason to keep running.

---

### Step 20: XP Calculation at Run End

Calculate XP earned when a run ends (win or lose).

**Formula:**

```
xp = 40                              // base
   + 12 * roundsCleared
   + floor(totalScore / 250)
   + 25 * challengeRoundsCleared
   + 10 if rareLetterWordUsed        // J, Q, X, Z, or K
```

**Reference — mid-skill run clearing Round 25:**
Base 40 + 300 (rounds) + ~200 (score) + 25 (1 challenge) + 10 (rare letter) = ~575 XP

**Acceptance criteria:**

- [x] XP formula produces expected values for sample runs
- [x] XP displays on the run summary screen
- [x] Rare-letter bonus triggers correctly (any word containing J, Q, X, Z, or K)
- [x] XP is calculated for both wins and losses

---

### Step 21: Persistent XP Storage + Lifetime Tracking

Store cumulative XP and lifetime stats across runs.

**Implementation:**

- Create a persistent `PlayerProfile` with: `totalXP`, `totalWordsBuilt`, `totalLocksBroken`, `totalRareLetterWords`, `highestRoundReached`, `runsCompleted`
- Update profile at end of each run
- Use appropriate platform persistence (UserDefaults, Core Data, or similar)

**Acceptance criteria:**

- [x] XP persists across app launches
- [x] Lifetime stats accumulate correctly over multiple runs
- [x] Profile can be reset (for testing and debug)

---

### Step 22: XP Unlock Thresholds

Implement the unlock gates that convert XP into tangible progression.

| XP | Phase | Unlock |
|-----|---------|--------|
| 150 | Phase 1 | Equip Slot 1 |
| 300 | Phase 1 | Equip Slot 2 |
| 500 | Phase 2 | Perk Library Tier 2 |
| 700 | Phase 2 | 1 Reroll per run |
| 900 | Phase 2 | +1 starting powerup |
| 1200 | Phase 3 | Equip Slot 3 |
| 1500 | Phase 3 | Challenge Insight |
| 1800 | Phase 3 | Perk Library Tier 3 |
| 2200 | Phase 4 | Equip Slot 4 |
| 2600 | Phase 4 | Ascension 1 |

**Acceptance criteria:**

- [x] Unlocks trigger at correct XP thresholds
- [x] Previously unlocked items remain unlocked
- [x] A notification or visual indicator appears when a new unlock is earned
- [x] Unlock state persists across app launches

---

### Step 23: Equip Slots + Starter Perks

Implement the equip system with the 3 starter perks. Players select perks before a run begins.

**Starter perks:**

| Perk | Effect |
|------|--------|
| Pencil Grip | First invalid submit each round refunds +1 extra move (net +1 moves) |
| Clean Ink | +10% score on 6+ letter words |
| Spare Seal | First locked submit each round costs 1 instead of 2 |

**Implementation:**

- Create a pre-run equip screen showing available slots and perks
- Number of available slots depends on XP unlocks (0–4)
- Each perk can only be equipped once
- Perk effects integrate into existing scoring/move logic with clear hooks

**Acceptance criteria:**

- [x] Equip screen appears before run start
- [x] Only unlocked slots are available
- [x] Each perk's effect works correctly in gameplay
- [x] Pencil Grip: first invalid submit per round is free (refunds +1)
- [x] Clean Ink: 6+ letter words show +10% bonus in score breakdown
- [x] Spare Seal: first locked submit per round costs 1 instead of 2

---

### Step 24: Milestone Passives

Implement always-on bonuses that unlock from lifetime stat thresholds.

| Milestone | Reward |
|-----------|--------|
| Build 100 words total | +1 starting shuffle |
| Break 150 locks total | Once per round, locked submit cost reduced by 1 |
| Use 25 rare-letter words | +5% rare-letter spawn rate |
| Reach Round 20 | +1 move at start of challenge rounds |

**Acceptance criteria:**

- [x] Milestones unlock when lifetime stats cross thresholds
- [x] Passive effects are always active once unlocked (no equip required)
- [x] Milestone progress is visible somewhere in the UI (profile or stats screen)
- [x] Effects stack correctly with equipped perks

---

## Phase E — Run Summary + Share Card

Build the end-of-run experience that makes players want to share and immediately re-run.

---

### Step 25: Run Lifetime Stat Tracking

Track per-run stats that feed the summary screen.

**Stats to track:**

- `totalScore` (sum of all round scores)
- `roundsCleared`
- `wordsBuilt` (total valid submissions)
- `locksBrokenTotal`
- `bestWord` + its point value
- `challengeRoundsCleared`
- `rareLetterWordUsed` (boolean)

**Acceptance criteria:**

- [x] All stats accumulate correctly across a full 50-round run
- [x] Best word is tracked by highest single-word score, not length
- [x] Stats are available at run end for both wins and losses

---

### Step 26: Run Summary Screen

Display the run results in a clean, premium-feeling overlay.

**Layout:**

- **Win state:** Title "RUN SUMMARY", subtitle "Run Complete", hero total score, then stats grid (rounds cleared, locks broken, words built, best word + points)
- **Loss state:** Same layout, subtitle "Run Ended", show round reached
- **Buttons:** Back to Menu, Play Again, Share Run

**Acceptance criteria:**

- [x] Summary screen appears on run end (win or loss)
- [x] Total score is prominently displayed
- [x] All tracked stats are shown
- [x] Buttons navigate correctly
- [x] Visual style matches the game's premium aesthetic

---

### Step 27: Share Card Generation

Generate a shareable image summarizing the run for social media / messaging.

**Implementation:**

- Render a card image (~1200×630px for social preview) with: game logo, total score, rounds cleared, best word, and a visual indicator of how far the player got
- Integrate with iOS share sheet (`UIActivityViewController` or `ShareLink`)
- Card should look good on dark and light backgrounds

**Acceptance criteria:**

- [x] Share card generates correctly for wins and losses
- [x] Card renders at appropriate resolution for social sharing
- [x] Share sheet opens with the card image
- [x] Card includes all key stats and the WordFall branding

### Step 28: Extend Word Length to 20 (All Rounds)

Goal: Allow 4–20 letter words in every round, with scoring + move economy scaling that doesn’t break Act 3.

Scope
	•	Selection: up to 20 tiles
	•	Validation: 4–20 (except Round 50 still enforces min 6)
	•	Scoring: add length multipliers for 9–20 with a soft ceiling
	•	Refunds: keep long-word refunds rewarding but capped (avoid infinite loops)
	•	UI: selection pill supports up to 20 letters (scroll or wrap)
	•	Tests: cover scoring and refund ceiling

Implementation Notes

A- Length multiplier table (recommended)
	•	4: 1.00
	•	5: 1.20
	•	6: 1.45
	•	7: 1.75
	•	8: 2.10
	•	9: 2.40
	•	10: 2.70
	•	11: 2.95
	•	12: 3.20
	•	13: 3.40
	•	14: 3.58
	•	15: 3.74
	•	16: 3.88
	•	17: 4.00
	•	18: 4.10
	•	19: 4.18
	•	20: 4.25

B- Move refund schedule (safe default)
	•	6: +1 move
	•	7–8: +1 move +0.25 pending
	•	9–10: +1 move +0.50 pending
	•	11–12: +1 move +0.75 pending
	•	13–20: +1 move max (no extra pending)

(You still get lock refunds as before.)

C- Hint powerup behavior
	•	No passive hints
	•	“Suggest a 6-letter word” remains the default hint powerup
	•	Later upgrades can unlock “Suggest 8/10” (not in this step)

Acceptance criteria:
- [x] Selection supports 4–20 tiles; UI remains readable
- [x] Words 9–20 validate and score correctly
- [x] Refunds do not exceed the cap for 13+ length
- [x] Round 50 still rejects < 6 letters
- [x] Unit tests pass
- [x] Length multiplier mapping covered for 9, 12, 16, 20
- [x] Refund cap at 13+ covered by tests
- [x] Round 50 minimum-length enforcement unchanged
---

## Appendix A: Scoring Reference Tables

Use these to validate your scoring output. If your `LetterValues` produce scores outside these ranges, adjust letter values before tuning anything else.

### Target Scoring Ranges by Word Profile

| Word Profile | First Use | 4th Use |
|-------------|-----------|---------|
| 4-letter common (THAT) | 20–40 pts | 8–16 pts |
| 5-letter common (HOUSE) | 30–60 pts | 12–24 pts |
| 6-letter solid (GARDEN) | 80–160 pts | 32–64 pts |
| 7-letter strong (QUICKLY) | 250–500 pts | 100–200 pts |
| 8-letter with rares (QUIXOTIC) | 500–700+ pts | 200–280 pts |

### Target Average Word Score by Act

| Act | Avg Word | Good Word | Great Word |
|-----|----------|-----------|------------|
| Act 1 (R1–17) | 40–100 | 100–200 | 200–350 |
| Act 2 (R18–34) | 80–180 | 180–350 | 350–500 |
| Act 3 (R35–50) | 150–300 | 300–500 | 500–700+ |

These ranges reflect the combined effects of repeat penalties (vocabulary breadth), length multipliers (rewarding long words), and lock bonuses (rewarding lock engagement).

---

## Appendix B: Repeat Penalty Monitoring

The repeat penalty is tracked run-wide. By late game, common short words will be heavily penalized. This is intentional — it forces vocabulary breadth. But monitor the 0.40 floor closely.

**What to watch in debug logs:**

- If more than 60% of Act 3 submits are at the 0.40 floor → penalty may be too aggressive. Consider raising the floor to 0.50.
- If fewer than 20% of Act 3 submits hit any penalty → system isn't creating enough pressure. Consider tracking word roots or reducing the penalty tiers.
- **Ideal state:** Act 3 players are actively seeking new words and using rare letters, not grudgingly replaying THAT for 8 points.

---

## Appendix C: Claude Code Prompt Templates

Copy these directly into Claude Code for each step. Modify file paths as needed.

### Example — Step 1:

```
Implement the word scoring formula in WordScorer.swift.

Formula: letterSum * lengthMultiplier * repeatPenalty + lockBonus.

Length multipliers: 4=1.00, 5=1.20, 6=1.45, 7=1.75, 8=2.10
Repeat penalty (run-wide): 1st=1.00, 2nd=0.75, 3rd=0.55, 4th+=0.40, min 1
Lock bonus: 20 * locksInWord

Target output: avg word 180-350 pts, great 7-8 letter word 350-700 pts.
Add unit tests. See LetterValues.swift for per-letter values.
```

### Example — Step 8:

```
Add a debug mode that lets me start a run at any round number.
Pre-seed wordUseCounts with 15-20 common words at 2-3 uses each.
I need to playtest rounds 40-50 and verify scoring output.
Log all debug metrics from the DebugMetrics system after each round.
```
