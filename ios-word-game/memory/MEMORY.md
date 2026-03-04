# WordFall Project Memory

## Project
- iOS SwiftUI + SpriteKit word game
- Root: `/Users/juanvallejo/Documents/Projects/ios-word-game/ios-word-game/`
- Module name: `ios_word_game` (for `@testable import`)
- App entry: `WordFall/App/WordFallApp.swift`

## Architecture
- `GameState` (Types.swift) – immutable value type passed through Resolver
- `Resolver` (Engine/Resolver.swift) – pure reducer; `initialState`, `reduce`
- `GameSessionController` (Game/) – `@MainActor ObservableObject`; owns `scene`, `state`, `bag`
- `BoardScene` (SpriteKit/) – SpriteKit scene; callbacks: `onSubmitPath`, `onRequestBoard`, `onAnyTouch`, `onPathLengthChanged`
- `GameScreen` (App/) – main SwiftUI view

## Run System (added 2026-03-02)
New files:
- `WordFall/Meta/RunState.swift` – 9-round struct, scaling formulas, per-round counters
- `WordFall/Meta/Perks.swift` – PerkID enum, Perk struct, 10 default + 3 milestone perks
- `WordFall/Meta/Milestones.swift` – MilestoneID enum, Milestone struct (3 milestones)
- `WordFall/Meta/MilestoneTracker.swift` – ObservableObject; persists to UserDefaults key `wordfall.milestoneTracker.v1`
- `WordFall/UI/PerkDraftView.swift` – overlay shown after each round win
- `WordFall/UI/RunSummaryView.swift` – overlay on run end

Key scaling formulas (tweak in RunState.swift):
- moves(r)     = 22 − (r−1)/2  → 22,22,21,21,20,20,19,19,18
- locksGoal(r) = 4 + r + (r−1)/3 → 5,6,7,9,10,11,13,14,15

GameSessionController key additions:
- `@Published runState: RunState?`, `showPerkDraft`, `perkDraftOptions`, `showRunSummary`, `runSummaryRound`, `runSummaryWon`
- `let milestoneTracker: MilestoneTracker` (public, used by RunSummaryView)
- `startRun()`, `endRun(won:)`, `advanceRoundAfterPerkSelection(_:)`, `dismissRunSummary()`
- `processPerkEffects(word:path:preMoveState:result:)` – called in submitPath after accepted
- `checkRunConditions()` – called in animation completion block

LetterBag change:
- Added `var excludedLetters: Set<Character> = []`; respected in `nextLetter(respecting:existingCounts:)`
- Used by rareRelief perk to block Q/Z/X/J/K spawns

## Xcode project note
All new Swift files must be manually added to the Xcode target (drag into project navigator and tick the app target + test target where applicable).

## Testing
- Test framework: Swift Testing (`import Testing`)
- Tests in `ios-word-gameTests/ios_word_gameTests.swift`
- `MilestoneTracker(defaultsKey:)` init for isolated test instances

## Constraints
- No currency / shop mechanics
- Core board rules unchanged (HV adjacency, 3-6 length, FreshLocked break/clear cycle, gravity+spawn, no auto-cascades)
- Milestone-only unlock; perk draft only after round win
