import Foundation
import Testing
@testable import ios_word_game

struct ios_word_gameTests {
    // MARK: - Existing engine tests

    @Test func gravityCompactionDropsTilesToBottom() {
        let rows = 4
        let cols = 1

        let a = Tile(id: UUID(), letter: "A")
        let b = Tile(id: UUID(), letter: "B")

        let tiles: [Tile?] = [a, nil, b, nil]
        let template = BoardTemplate.full(gridSize: max(rows, cols), id: "test_gravity", name: "Test Gravity")
        let result = Gravity.apply(tiles: tiles, rows: rows, cols: cols, template: template)

        #expect(result.tiles[0] == nil)
        #expect(result.tiles[1] == nil)
        #expect(result.tiles[2]?.id == a.id)
        #expect(result.tiles[3]?.id == b.id)
        #expect(result.drops.count == 2)
    }

    @Test func resolverRejectsShortPath() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            rows: 1,
            cols: 4,
            tiles: [TestBuilders.makeTile("G"), TestBuilders.makeTile("A"), TestBuilders.makeTile("M"), TestBuilders.makeTile("E")]
        )

        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(!result.accepted)
        #expect(result.rejectionReason == .invalidLength)
        #expect(result.movesDelta == 0)
        #expect(result.events.isEmpty)
    }

    @Test func resolverAcceptsNonAdjacentFreePickPath() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["game"])
        let tiles: [Tile?] = [
            TestBuilders.makeTile("G"), TestBuilders.makeTile("M"), nil, nil,
            nil, nil, TestBuilders.makeTile("E"), TestBuilders.makeTile("A")
        ]
        let state = TestBuilders.makeState(rows: 2, cols: 4, tiles: tiles)
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 7, 1, 6]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(result.accepted)
        #expect(result.acceptedWord == "game")
    }

    @Test func freshLockedTilesBreakButDoNotClear() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["game"])
        let tileIDs = [UUID(), UUID(), UUID(), UUID()]

        let tiles: [Tile?] = [
            TestBuilders.makeTile("G", freshness: .freshLocked, id: tileIDs[0]),
            TestBuilders.makeTile("A", freshness: .freshLocked, id: tileIDs[1]),
            TestBuilders.makeTile("M", freshness: .freshLocked, id: tileIDs[2]),
            TestBuilders.makeTile("E", freshness: .freshLocked, id: tileIDs[3])
        ]

        let state = TestBuilders.makeState(rows: 1, cols: 4, tiles: tiles)
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 2, 3]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(result.accepted)
        #expect(result.clearedCount == 0)
        #expect(result.locksBrokenThisMove == 4)
        #expect(result.movesDelta == 0)
        #expect(result.newState.totalLocksBroken == 4)

        for index in 0..<4 {
            #expect(result.newState.tiles[index]?.id == tileIDs[index])
            #expect(result.newState.tiles[index]?.freshness == .freshUnlocked)
        }

        guard case .lockBreak(let indices) = result.events.first else {
            Issue.record("Expected lockBreak event")
            return
        }
        #expect(indices == [0, 1, 2, 3])
    }

    @Test func mixedFreshnessClearsOnlyUnlockedAndNormal() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["game"])
        let lockedID = UUID()

        let tiles: [Tile?] = [
            TestBuilders.makeTile("G", freshness: .normal),
            TestBuilders.makeTile("A", freshness: .freshUnlocked),
            TestBuilders.makeTile("M", freshness: .normal),
            TestBuilders.makeTile("E", freshness: .freshLocked, id: lockedID)
        ]

        let state = TestBuilders.makeState(rows: 1, cols: 4, tiles: tiles)
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 2, 3]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(result.accepted)
        #expect(result.clearedCount == 3)
        #expect(result.locksBrokenThisMove == 1)
        #expect(result.newState.tiles[3]?.id == lockedID)
        #expect(result.newState.tiles[3]?.freshness == .freshUnlocked)

        let clearEvents = result.events.compactMap { event -> ClearEvent? in
            guard case .clear(let clear) = event else { return nil }
            return clear
        }
        #expect(clearEvents.first?.indices == [0, 1, 2])
    }

    @Test func initialStateHasTargetLockFloor() {
        var bag = LetterBag()
        let dictionary = WordDictionary(words: ["cat", "game", "word"])
        let state = Resolver.initialState(rows: 7, cols: 7, dictionary: dictionary, bag: &bag)

        let lockedCount = state.tiles.compactMap { $0 }.filter { $0.freshness == .freshLocked }.count
        #expect(lockedCount >= GameState.defaultTargetLocks)
    }

    @MainActor
    @Test func submitCostUnlockedSelection_equals1() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            rows: 1,
            cols: 4,
            tiles: [TestBuilders.makeTile("G"), TestBuilders.makeTile("A"), TestBuilders.makeTile("M"), TestBuilders.makeTile("E")]
        )
        controller.configureForTesting(state: state, dictionary: dictionary)
        #expect(controller.computeSubmitCost(selectionIndices: [0, 1, 2, 3]) == 1)
    }

    @MainActor
    @Test func submitCostIncludesLocked_equals2() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            rows: 1,
            cols: 4,
            tiles: [
                TestBuilders.makeTile("G", freshness: .freshLocked),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("M"),
                TestBuilders.makeTile("E")
            ]
        )
        controller.configureForTesting(state: state, dictionary: dictionary)
        #expect(controller.computeSubmitCost(selectionIndices: [0, 1, 2, 3]) == 2)
    }

    @MainActor
    @Test func invalidSubmitRefundsCost() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            rows: 1,
            cols: 4,
            tiles: [TestBuilders.makeTile("G"), TestBuilders.makeTile("A"), TestBuilders.makeTile("M"), TestBuilders.makeTile("X")],
            moves: 5
        )
        controller.configureForTesting(state: state, dictionary: dictionary)
        controller.submitPath(indices: [0, 1, 2, 3])

        #expect(controller.moves == 5)
        #expect(controller.lastSubmitOutcome == .invalid)
    }

    @MainActor
    @Test func validSubmitSpendsCost() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            rows: 1,
            cols: 4,
            tiles: [TestBuilders.makeTile("G"), TestBuilders.makeTile("A"), TestBuilders.makeTile("M"), TestBuilders.makeTile("E")],
            moves: 5
        )
        controller.configureForTesting(state: state, dictionary: dictionary)
        controller.submitPath(indices: [0, 1, 2, 3])

        #expect(controller.moves == 4)
        #expect(controller.lastSubmitOutcome == .valid)
    }

    @MainActor
    @Test func cannotSubmitIfMovesInsufficient_noSpend() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            rows: 1,
            cols: 4,
            tiles: [
                TestBuilders.makeTile("G", freshness: .freshLocked),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("M"),
                TestBuilders.makeTile("E")
            ],
            moves: 1
        )
        controller.configureForTesting(state: state, dictionary: dictionary)
        controller.submitPath(indices: [0, 1, 2, 3])

        #expect(controller.moves == 1)
        #expect(controller.lastSubmitOutcome == .invalid)
        #expect(controller.status == "rejected:notEnoughMoves")
    }

    // MARK: - Run formula tests

    /// Verify moves formula for 15-board roguelike.
    /// Formula: max(14, 22 - (board-1)/3) + (boss ? 3 : 0).
    /// Boss boards: 5, 10, 15.
    @Test func runMovesFormulaIsCorrect() {
        // Spot-check key boards
        let cases: [(board: Int, expected: Int)] = [
            (1, 22), (2, 22), (3, 22),
            (4, 21), (5, 24),   // board 5 is boss: 21+3
            (6, 21), (7, 20),
            (10, 22),           // board 10 is boss: 19+3
            (15, 21)            // board 15 is boss: 18+3
        ]
        for (board, exp) in cases {
            #expect(RunState.moves(for: board) == exp,
                    "Board \(board): expected \(exp) got \(RunState.moves(for: board))")
        }
    }

    /// Verify locksGoal progression with template scaling and boss multipliers.
    @Test func runLocksGoalFormulaIsCorrect() {
        let board1 = RunState.locksGoal(for: 1)
        let board4 = RunState.locksGoal(for: 4)
        let board5Boss = RunState.locksGoal(for: 5)
        let board6 = RunState.locksGoal(for: 6)

        #expect(board1 < board4)
        #expect(board4 < board5Boss)
        #expect(board5Boss > board4)
        #expect(board5Boss > board6)

        let sixBySix = BoardTemplate.full(gridSize: 6, id: "test_6x6", name: "Test 6x6")
        let sevenBySeven = BoardTemplate.full(gridSize: 7, id: "test_7x7", name: "Test 7x7")
        let board4Six = RunState.locksGoal(for: 4, template: sixBySix)
        let board4Seven = RunState.locksGoal(for: 4, template: sevenBySeven)
        #expect(board4Six <= board4Seven)

        // Spot-checks on stable baseline cases.
        #expect(board1 == 5)
        #expect(board5Boss == 11)
    }

    /// Run has 15 boards total.
    @Test func runHas15Boards() {
        #expect(RunState.Tunables.totalBoards == 15)
    }

    /// resetBoardCounters clears all per-board fields.
    @Test func runStateResetBoardCountersClearsFields() {
        var run = RunState()
        run.locksBrokenThisBoard = 7
        run.scoreThisBoard = 250
        run.shufflesRemaining = 2
        run.pendingMoveFraction = 0.5
        run.modifierPendingMoveFraction = 1.5
        run.freshSparkCount = 3
        run.freeHintChargesRemaining = 1
        run.freeUndoChargesRemaining = 1

        run.resetBoardCounters()

        #expect(run.locksBrokenThisBoard == 0)
        #expect(run.scoreThisBoard == 0)
        #expect(run.shufflesRemaining == RunState.Tunables.shufflesPerBoard)
        #expect(run.pendingMoveFraction == 0.0)
        #expect(run.modifierPendingMoveFraction == 0.0)
        #expect(run.freshSparkCount == 0)
        #expect(run.freeHintChargesRemaining == 0)
        #expect(run.freeUndoChargesRemaining == 0)
    }

    /// Repeat penalty multipliers match the new 5-entry curve [1.0, 0.7, 0.5, 0.35, 0.25].
    @Test func repeatPenaltyMultipliersAreCorrect() {
        #expect(Scoring.repeatMultiplier(useCount: 0) == 1.0)
        #expect(Scoring.repeatMultiplier(useCount: 1) == 0.7)
        #expect(Scoring.repeatMultiplier(useCount: 2) == 0.5)
        #expect(Scoring.repeatMultiplier(useCount: 3) == 0.35)
        #expect(Scoring.repeatMultiplier(useCount: 4) == 0.25)
        #expect(Scoring.repeatMultiplier(useCount: 99) == 0.25)  // capped at last entry
    }

    /// A 3-letter word repeated any number of times still scores >= minPoints.
    @Test func repeatedWordNeverScoresZero() {
        // "ant": A=1, N=1, T=1 → letterSum=3 (low-value word, worst case for rounding)
        let letterSum = LetterValues.sum(for: "ant")
        let length = 3
        let floor = Scoring.minPoints(length: length)

        for useCount in [0, 1, 2, 3, 4, 10, 99] {
            let pts = Scoring.wordScore(letterSum: letterSum, length: length, useCount: useCount)
            #expect(pts >= floor, "Expected >= \(floor) at useCount=\(useCount), got \(pts)")
            #expect(pts > 0, "Word score must never be 0 (useCount=\(useCount))")
        }
    }

    /// scoreThisBoard increases on every accepted word, even when the same word
    /// is repeated many times (simulates the GameSessionController logic).
    @Test func scoreThisBoardIncreasesOnEveryAcceptedWord() {
        var run = RunState()
        let wordKey = "CAT"
        let letterSum = LetterValues.sum(for: wordKey)
        let length = wordKey.count

        for _ in 0..<6 {
            let before = run.scoreThisBoard
            let useCount = run.wordUseCounts[wordKey, default: 0]
            let pts = Scoring.wordScore(letterSum: letterSum, length: length, useCount: useCount)
            run.wordUseCounts[wordKey] = useCount + 1
            run.scoreThisBoard += pts
            #expect(run.scoreThisBoard > before,
                    "scoreThisBoard must increase even on repeat submission (useCount=\(useCount))")
        }
    }

    // MARK: - Milestone tracker tests

    /// Fresh tracker starts with defaultUnlockedPerks and zero counters.
    @Test func milestoneTrackerInitialisesWithDefaults() {
        // Use an isolated key so this test doesn't touch real UserDefaults
        let tracker = MilestoneTrackerTestHelper.makeIsolated()
        #expect(tracker.counters.totalLocksBroken == 0)
        #expect(tracker.unlockedPerks == defaultUnlockedPerks)
    }

    /// recordLocksBroken accumulates and unlocks lockSplash at threshold 50.
    @Test func milestoneTrackerUnlocksLockSplashAt50Locks() {
        let tracker = MilestoneTrackerTestHelper.makeIsolated()
        #expect(!tracker.unlockedPerks.contains(.lockSplash))

        tracker.recordLocksBroken(49)
        #expect(!tracker.unlockedPerks.contains(.lockSplash))

        tracker.recordLocksBroken(1)
        #expect(tracker.unlockedPerks.contains(.lockSplash))
        #expect(tracker.justUnlocked.contains(.lockSplash))
    }

    /// recordWord unlocks bigGame after 50 six-letter words.
    @Test func milestoneTrackerUnlocksBigGameAt50SixLetterWords() {
        let tracker = MilestoneTrackerTestHelper.makeIsolated()
        #expect(!tracker.unlockedPerks.contains(.bigGame))

        for _ in 0..<49 {
            tracker.recordWord("CASTLE")  // 6 letters
        }
        #expect(!tracker.unlockedPerks.contains(.bigGame))

        tracker.recordWord("CASTLE")
        #expect(tracker.unlockedPerks.contains(.bigGame))
    }

    /// recordWord unlocks echoChamber after 100 words containing A.
    @Test func milestoneTrackerUnlocksEchoChamberAt100AWords() {
        let tracker = MilestoneTrackerTestHelper.makeIsolated()
        #expect(!tracker.unlockedPerks.contains(.echoChamber))

        for _ in 0..<99 {
            tracker.recordWord("CAT")
        }
        #expect(!tracker.unlockedPerks.contains(.echoChamber))

        tracker.recordWord("CAT")
        #expect(tracker.unlockedPerks.contains(.echoChamber))
    }

    /// milestoneProgress returns correct tuple before and after threshold.
    @Test func milestoneProgressReturnsCorrectTuple() {
        let tracker = MilestoneTrackerTestHelper.makeIsolated()
        tracker.recordLocksBroken(25)

        let (current, threshold) = tracker.milestoneProgress(for: .break50Locks)
        #expect(current == 25)
        #expect(threshold == 50)
    }
}

// MARK: - Dictionary path-order tests

@Test func dictionaryRejectsGMEZ() {
    let dict = WordDictionary(words: ["game"])
    #expect(!dict.contains("gmez"))
    #expect(!dict.containsEitherDirection("gmez"))
    #expect(dict.contains("game"))
}

@Test func dictionaryRejectsEKGX() {
    let dict = WordDictionary(words: ["game"])
    #expect(!dict.contains("ekgx"))
    #expect(!dict.containsEitherDirection("ekgx"))
}

@Test func resolverRejectsPathSpellingGMEZ() {
    var bag = LetterBag(weights: [("Z", 1)])
    let dictionary = WordDictionary(words: ["game"])
    let tiles: [Tile?] = [TestBuilders.makeTile("G"), TestBuilders.makeTile("M"), TestBuilders.makeTile("E"), TestBuilders.makeTile("Z")]
    let state = TestBuilders.makeState(rows: 1, cols: 4, tiles: tiles)

    let result = Resolver.reduce(
        state: state,
        action: .submitPath(indices: [0, 1, 2, 3]),
        dictionary: dictionary,
        bag: &bag
    )

    #expect(!result.accepted)
    #expect(result.rejectionReason == .notInDictionary)
}

@Test func resolverRejectsPathSpellingEKGX() {
    var bag = LetterBag(weights: [("Z", 1)])
    let dictionary = WordDictionary(words: ["game"])
    let tiles: [Tile?] = [TestBuilders.makeTile("E"), TestBuilders.makeTile("K"), TestBuilders.makeTile("G"), TestBuilders.makeTile("X")]
    let state = TestBuilders.makeState(rows: 1, cols: 4, tiles: tiles)

    let result = Resolver.reduce(
        state: state,
        action: .submitPath(indices: [0, 1, 2, 3]),
        dictionary: dictionary,
        bag: &bag
    )

    #expect(!result.accepted)
    #expect(result.rejectionReason == .notInDictionary)
}

@Test func resolverRejectsReversePathOrder() {
    let dictionary = WordDictionary(words: ["game"])
    let tiles: [Tile?] = [TestBuilders.makeTile("G"), TestBuilders.makeTile("A"), TestBuilders.makeTile("M"), TestBuilders.makeTile("E")]
    let state = TestBuilders.makeState(rows: 1, cols: 4, tiles: tiles)

    var reverseBag = LetterBag(weights: [("Z", 1)])
    let reverse = Resolver.reduce(
        state: state,
        action: .submitPath(indices: [3, 2, 1, 0]),
        dictionary: dictionary,
        bag: &reverseBag
    )
    #expect(!reverse.accepted)
    #expect(reverse.rejectionReason == .notInDictionary)

    var forwardBag = LetterBag(weights: [("Z", 1)])
    let forward = Resolver.reduce(
        state: state,
        action: .submitPath(indices: [0, 1, 2, 3]),
        dictionary: dictionary,
        bag: &forwardBag
    )
    #expect(forward.accepted)
    #expect(forward.acceptedWord == "game")
}

@Test func resolverRejectsAnagramPath() {
    var bag = LetterBag(weights: [("Z", 1)])
    let dictionary = WordDictionary(words: ["game"])
    let tiles: [Tile?] = [TestBuilders.makeTile("G"), TestBuilders.makeTile("E"), TestBuilders.makeTile("A"), TestBuilders.makeTile("M")]
    let state = TestBuilders.makeState(rows: 1, cols: 4, tiles: tiles)

    let result = Resolver.reduce(
        state: state,
        action: .submitPath(indices: [0, 1, 2, 3]),
        dictionary: dictionary,
        bag: &bag
    )

    #expect(!result.accepted)
    #expect(result.rejectionReason == .notInDictionary)
}

// MARK: - Test helper (isolated UserDefaults key)

enum MilestoneTrackerTestHelper {
    static func makeIsolated() -> MilestoneTracker {
        // Wipe any residual data under the test key before creating a fresh tracker
        let testKey = "wordfall.milestoneTracker.test.\(UUID().uuidString)"
        UserDefaults.standard.removeObject(forKey: testKey)
        return MilestoneTracker(defaultsKey: testKey)
    }
}
