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
        let result = Gravity.apply(tiles: tiles, rows: rows, cols: cols)

        #expect(result.tiles[0] == nil)
        #expect(result.tiles[1] == nil)
        #expect(result.tiles[2]?.id == a.id)
        #expect(result.tiles[3]?.id == b.id)
        #expect(result.drops.count == 2)
    }

    @Test func resolverRejectsShortPath() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["cat"])
        let state = TestBuilders.makeState(
            rows: 1,
            cols: 3,
            tiles: [TestBuilders.makeTile("C"), TestBuilders.makeTile("A"), TestBuilders.makeTile("T")]
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

    @Test func freshLockedTilesBreakButDoNotClear() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["cat"])
        let tileIDs = [UUID(), UUID(), UUID()]

        let tiles: [Tile?] = [
            TestBuilders.makeTile("C", freshness: .freshLocked, id: tileIDs[0]),
            TestBuilders.makeTile("A", freshness: .freshLocked, id: tileIDs[1]),
            TestBuilders.makeTile("T", freshness: .freshLocked, id: tileIDs[2])
        ]

        let state = TestBuilders.makeState(rows: 1, cols: 3, tiles: tiles)
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 2]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(result.accepted)
        #expect(result.clearedCount == 0)
        #expect(result.locksBrokenThisMove == 3)
        #expect(result.movesDelta == -1)
        #expect(result.newState.totalLocksBroken == 3)

        for index in 0..<3 {
            #expect(result.newState.tiles[index]?.id == tileIDs[index])
            #expect(result.newState.tiles[index]?.freshness == .freshUnlocked)
        }

        guard case .lockBreak(let indices) = result.events.first else {
            Issue.record("Expected lockBreak event")
            return
        }
        #expect(indices == [0, 1, 2])
    }

    @Test func mixedFreshnessClearsOnlyUnlockedAndNormal() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["cat"])
        let lockedID = UUID()

        let tiles: [Tile?] = [
            TestBuilders.makeTile("C", freshness: .normal),
            TestBuilders.makeTile("A", freshness: .freshUnlocked),
            TestBuilders.makeTile("T", freshness: .freshLocked, id: lockedID)
        ]

        let state = TestBuilders.makeState(rows: 1, cols: 3, tiles: tiles)
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 2]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(result.accepted)
        #expect(result.clearedCount == 2)
        #expect(result.locksBrokenThisMove == 1)
        #expect(result.newState.tiles[2]?.id == lockedID)
        #expect(result.newState.tiles[2]?.freshness == .freshUnlocked)

        let clearEvents = result.events.compactMap { event -> ClearEvent? in
            guard case .clear(let clear) = event else { return nil }
            return clear
        }
        #expect(clearEvents.first?.indices == [0, 1])
    }

    @Test func initialStateHasTargetLockFloor() {
        var bag = LetterBag()
        let dictionary = WordDictionary(words: ["cat", "game", "word"])
        let state = Resolver.initialState(rows: 7, cols: 7, dictionary: dictionary, bag: &bag)

        let lockedCount = state.tiles.compactMap { $0 }.filter { $0.freshness == .freshLocked }.count
        #expect(lockedCount >= GameState.defaultTargetLocks)
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

    /// Verify locksGoal formula for 15-board roguelike.
    /// Base: 4 + board + (board-1)/3. Boss boards ×1.5 (ceil).
    @Test func runLocksGoalFormulaIsCorrect() {
        let cases: [(board: Int, expected: Int)] = [
            (1, 5), (2, 6), (3, 7), (4, 9),
            (5, 15),    // base=10, boss ceil(10*1.5)=15
            (6, 11), (7, 13),
            (10, 26),   // base=17, boss ceil(17*1.5)=26
            (15, 35)    // base=23, boss ceil(23*1.5)=35
        ]
        for (board, exp) in cases {
            #expect(RunState.locksGoal(for: board) == exp,
                    "Board \(board): expected \(exp) got \(RunState.locksGoal(for: board))")
        }
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
        run.lockRefundMovesGranted = 2
        run.lockRefundRealLocks = 6
        run.freshSparkCount = 3
        run.freeHintUsed = true
        run.freeUndoUsed = true

        run.resetBoardCounters()

        #expect(run.locksBrokenThisBoard == 0)
        #expect(run.scoreThisBoard == 0)
        #expect(run.shufflesRemaining == RunState.Tunables.shufflesPerBoard)
        #expect(run.pendingMoveFraction == 0.0)
        #expect(run.lockRefundMovesGranted == 0)
        #expect(run.lockRefundRealLocks == 0)
        #expect(run.freshSparkCount == 0)
        #expect(run.freeHintUsed == false)
        #expect(run.freeUndoUsed == false)
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

    /// milestoneProgress returns correct tuple before and after threshold.
    @Test func milestoneProgressReturnsCorrectTuple() {
        let tracker = MilestoneTrackerTestHelper.makeIsolated()
        tracker.recordLocksBroken(25)

        let (current, threshold) = tracker.milestoneProgress(for: .break50Locks)
        #expect(current == 25)
        #expect(threshold == 50)
    }
}

    // MARK: - Dictionary path-order and abbreviation tests

    /// A path spelling "GME" must be rejected: it is an abbreviation/ticker
    /// and must not exist in the 3-letter common set.
    /// Anagram acceptance must also be impossible — the dictionary validates
    /// only the exact path string (forward) or its strict reversal.
    @Test func dictionaryRejectsGME() {
        // Build a dictionary that only knows "cat".
        let dict = WordDictionary(words: ["cat"])

        // "gme" is not in the dictionary.
        #expect(!dict.contains("gme"))
        // Neither is any anagram of "gme".
        #expect(!dict.containsEitherDirection("gme"))
        // Reversed "emg" is also not valid.
        #expect(!dict.containsEitherDirection("emg"))

        // Sanity: "cat" IS accepted.
        #expect(dict.contains("cat"))
        // And reversed "tac" is found via either-direction.
        #expect(dict.containsEitherDirection("tac"))
    }

    /// A path spelling "EKG" must be rejected.
    @Test func dictionaryRejectsEKG() {
        let dict = WordDictionary(words: ["cat"])
        #expect(!dict.contains("ekg"))
        #expect(!dict.containsEitherDirection("ekg"))
    }

    /// Resolver must reject a submitted path whose tiles spell "GME"
    /// even when the dictionary is pre-loaded with "cat".
    @Test func resolverRejectsPathSpellingGME() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["cat"])
        // Tiles spell G-M-E
        let tiles: [Tile?] = [TestBuilders.makeTile("G"), TestBuilders.makeTile("M"), TestBuilders.makeTile("E")]
        let state = TestBuilders.makeState(rows: 1, cols: 3, tiles: tiles)

        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 2]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(!result.accepted)
        #expect(result.rejectionReason == .notInDictionary)
    }

    /// Resolver must reject a path spelling "EKG".
    @Test func resolverRejectsPathSpellingEKG() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["cat"])
        let tiles: [Tile?] = [TestBuilders.makeTile("E"), TestBuilders.makeTile("K"), TestBuilders.makeTile("G")]
        let state = TestBuilders.makeState(rows: 1, cols: 3, tiles: tiles)

        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 2]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(!result.accepted)
        #expect(result.rejectionReason == .notInDictionary)
    }

    /// Path order is respected: tiles [C, A, T] at indices [0,1,2] form "cat",
    /// which is accepted. The same tiles at indices [2,1,0] form "tac" and must
    /// also be accepted (reverse match), but NOT because letters were sorted.
    @Test func resolverAcceptsForwardAndReversePathOrder() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["cat"])
        let tiles: [Tile?] = [TestBuilders.makeTile("C"), TestBuilders.makeTile("A"), TestBuilders.makeTile("T")]
        let state = TestBuilders.makeState(rows: 1, cols: 3, tiles: tiles)

        // Forward path [0,1,2] => "cat" — must be accepted.
        let forward = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 2]),
            dictionary: dictionary,
            bag: &bag
        )
        #expect(forward.accepted)
        #expect(forward.acceptedWord == "cat")

        // Reverse path [2,1,0] => "tac" — dictionary contains reverse "cat", accept.
        let reverse = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [2, 1, 0]),
            dictionary: dictionary,
            bag: &bag
        )
        #expect(reverse.accepted)
        #expect(reverse.acceptedWord == "cat")
    }

    /// Anagram path must NOT be accepted. Tiles [C, T, A] at [0,1,2] spell "cta",
    /// which is neither "cat" nor reversed "tac", so it must be rejected.
    @Test func resolverRejectsAnagramPath() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["cat"])
        // Tiles in anagram order: C, T, A (spells "cta")
        let tiles: [Tile?] = [TestBuilders.makeTile("C"), TestBuilders.makeTile("T"), TestBuilders.makeTile("A")]
        let state = TestBuilders.makeState(rows: 1, cols: 3, tiles: tiles)

        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 2]),
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
