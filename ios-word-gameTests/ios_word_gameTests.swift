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

    @Test func freshLockedTilesBreakAndClear() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["game"])
        let tiles: [Tile?] = [
            TestBuilders.makeTile("G", freshness: .freshLocked),
            TestBuilders.makeTile("A", freshness: .freshLocked),
            TestBuilders.makeTile("M", freshness: .freshLocked),
            TestBuilders.makeTile("E", freshness: .freshLocked)
        ]

        let state = TestBuilders.makeState(rows: 1, cols: 4, tiles: tiles)
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 2, 3]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(result.accepted)
        #expect(result.clearedCount == 4)
        #expect(result.locksBrokenThisMove == 4)
        #expect(result.movesDelta == 0)
        #expect(result.newState.totalLocksBroken == 4)

        guard case .lockBreak(let indices) = result.events.first else {
            Issue.record("Expected lockBreak event")
            return
        }
        #expect(indices == [0, 1, 2, 3])
    }

    @Test func mixedFreshnessClearsLockedUnlockedAndNormalTiles() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["game"])

        let tiles: [Tile?] = [
            TestBuilders.makeTile("G", freshness: .normal),
            TestBuilders.makeTile("A", freshness: .freshUnlocked),
            TestBuilders.makeTile("M", freshness: .normal),
            TestBuilders.makeTile("E", freshness: .freshLocked)
        ]

        let state = TestBuilders.makeState(rows: 1, cols: 4, tiles: tiles)
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 2, 3]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(result.accepted)
        #expect(result.clearedCount == 4)
        #expect(result.locksBrokenThisMove == 1)

        let clearEvents = result.events.compactMap { event -> ClearEvent? in
            guard case .clear(let clear) = event else { return nil }
            return clear
        }
        #expect(clearEvents.first?.indices == [0, 1, 2, 3])
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
    @Test func starterPerkSpareSealMakesFirstLockedSubmitCheaper() {
        let controller = GameSessionController(
            milestoneTracker: MilestoneTrackerTestHelper.makeIsolated(),
            playerProfile: PlayerProfileTestHelper.makeIsolated()
        )
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            tiles: [
                TestBuilders.makeTile("G", freshness: .freshLocked),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("M"),
                TestBuilders.makeTile("E")
            ],
            moves: 5,
            rows: 1,
            cols: 4
        )
        var run = RunState()
        run.equippedStarterPerks = [.spareSeal]
        controller.configureForTesting(state: state, dictionary: dictionary, runState: run)

        #expect(controller.computeSubmitCost(selectionIndices: [0, 1, 2, 3]) == 1)

        controller.submitPath(indices: [0, 1, 2, 3])

        #expect(controller.moves == 5)
    }

    @MainActor
    @Test func milestoneLockedSubmitDiscountStacksWithSpareSealOnTaxRound() {
        let profile = PlayerProfileTestHelper.makeIsolated()
        _ = profile.recordRunEnd(
            xpEarned: 0,
            wordsBuilt: 0,
            locksBroken: 150,
            rareLetterWords: 0,
            roundReached: 1,
            wonRun: false
        )
        let controller = GameSessionController(
            milestoneTracker: MilestoneTrackerTestHelper.makeIsolated(),
            playerProfile: profile
        )
        let dictionary = WordDictionary(words: ["game"])
        let template = BoardTemplate.template(for: 30)
        let size = template.gridSize * template.gridSize
        var tiles = [Tile?](repeating: nil, count: size)
        tiles[0] = TestBuilders.makeTile("G", freshness: .freshLocked)
        tiles[1] = TestBuilders.makeTile("A")
        tiles[2] = TestBuilders.makeTile("M")
        tiles[3] = TestBuilders.makeTile("E")
        let state = GameState(
            rows: template.rows,
            cols: template.cols,
            boardTemplate: template,
            tiles: tiles,
            score: 0,
            moves: 5,
            inkPoints: 0,
            usedTileIds: [],
            totalLocksBroken: 0,
            lockObjectiveTarget: 4
        )
        var run = RunState()
        run.roundIndex = 30
        run.equippedStarterPerks = [.spareSeal]
        controller.configureForTesting(state: state, dictionary: dictionary, runState: run)

        #expect(controller.computeSubmitCost(selectionIndices: [0, 1, 2, 3]) == 1)
    }

    @MainActor
    @Test func taxRoundSubmitCostStartsAtTwoAndLockedWordCostsThree() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["game"])
        let template = BoardTemplate.template(for: 30)
        let size = template.gridSize * template.gridSize
        var tiles = [Tile?](repeating: nil, count: size)
        tiles[0] = TestBuilders.makeTile("G", freshness: .freshLocked)
        tiles[1] = TestBuilders.makeTile("A")
        tiles[2] = TestBuilders.makeTile("M")
        tiles[3] = TestBuilders.makeTile("E")
        let state = GameState(
            rows: template.rows,
            cols: template.cols,
            boardTemplate: template,
            tiles: tiles,
            score: 0,
            moves: 5,
            inkPoints: 0,
            usedTileIds: [],
            totalLocksBroken: 0,
            lockObjectiveTarget: 4
        )

        controller.configureForTesting(state: state, dictionary: dictionary)

        #expect(controller.computeSubmitCost(selectionIndices: [1, 2, 3]) == 2)
        #expect(controller.computeSubmitCost(selectionIndices: [0, 1, 2, 3]) == 3)
    }

    @MainActor
    @Test func invalidSubmitRefundsCost() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            tiles: [TestBuilders.makeTile("G"), TestBuilders.makeTile("A"), TestBuilders.makeTile("M"), TestBuilders.makeTile("X")],
            moves: 5,
            rows: 1,
            cols: 4
        )
        controller.configureForTesting(state: state, dictionary: dictionary)
        controller.submitPath(indices: [0, 1, 2, 3])

        #expect(controller.moves == 5)
        #expect(controller.lastSubmitOutcome == .invalid)
    }

    @MainActor
    @Test func starterPerkPencilGripMakesFirstInvalidSubmitNetPositive() {
        let controller = GameSessionController(
            milestoneTracker: MilestoneTrackerTestHelper.makeIsolated(),
            playerProfile: PlayerProfileTestHelper.makeIsolated()
        )
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            tiles: [TestBuilders.makeTile("G"), TestBuilders.makeTile("A"), TestBuilders.makeTile("M"), TestBuilders.makeTile("X")],
            moves: 5,
            rows: 1,
            cols: 4
        )
        var run = RunState()
        run.equippedStarterPerks = [.pencilGrip]
        controller.configureForTesting(state: state, dictionary: dictionary, runState: run)

        controller.submitPath(indices: [0, 1, 2, 3])
        #expect(controller.moves == 6)
        #expect(controller.powerupToast == "Pencil Grip +1 Move")

        controller.submitPath(indices: [0, 1, 2, 3])
        #expect(controller.moves == 6)
    }

    @MainActor
    @Test func taxRoundInvalidSubmitRefundsFullCost() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["game"])
        let template = BoardTemplate.template(for: 30)
        let size = template.gridSize * template.gridSize
        var tiles = [Tile?](repeating: nil, count: size)
        tiles[0] = TestBuilders.makeTile("G")
        tiles[1] = TestBuilders.makeTile("A")
        tiles[2] = TestBuilders.makeTile("M")
        tiles[3] = TestBuilders.makeTile("X")
        let state = GameState(
            rows: template.rows,
            cols: template.cols,
            boardTemplate: template,
            tiles: tiles,
            score: 0,
            moves: 5,
            inkPoints: 0,
            usedTileIds: [],
            totalLocksBroken: 0,
            lockObjectiveTarget: 4
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
            tiles: [TestBuilders.makeTile("G"), TestBuilders.makeTile("A"), TestBuilders.makeTile("M"), TestBuilders.makeTile("E")],
            moves: 5,
            rows: 1,
            cols: 4
        )
        controller.configureForTesting(state: state, dictionary: dictionary)
        controller.submitPath(indices: [0, 1, 2, 3])

        #expect(controller.moves == 4)
        #expect(controller.lastSubmitOutcome == .valid)
    }

    @MainActor
    @Test func starterPerkCleanInkAddsBonusToLongWords() {
        let controller = GameSessionController(
            milestoneTracker: MilestoneTrackerTestHelper.makeIsolated(),
            playerProfile: PlayerProfileTestHelper.makeIsolated()
        )
        let dictionary = WordDictionary(words: ["planet"])
        let state = TestBuilders.makeState(
            tiles: [
                TestBuilders.makeTile("P"),
                TestBuilders.makeTile("L"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("N"),
                TestBuilders.makeTile("E"),
                TestBuilders.makeTile("T")
            ],
            moves: 5,
            rows: 1,
            cols: 6
        )
        var run = RunState()
        run.equippedStarterPerks = [.cleanInk]
        run.scoreTargetThisBoard = 999
        controller.configureForTesting(state: state, dictionary: dictionary, runState: run)

        let baseScore = WordScorer().scoreWord(letters: "PLANET", lockCount: 0, wordUseCounts: [:])
        let expectedBonus = Int((Double(baseScore) * 0.10).rounded())

        controller.submitPath(indices: [0, 1, 2, 3, 4, 5])

        #expect(controller.lastSubmitOutcome == .valid)
        #expect(controller.lastSubmitPoints == baseScore + expectedBonus)
        #expect(controller.lastSubmitFeedbackDetail == "Clean Ink +10%")
    }

    @MainActor
    @Test func validSubmitTracksRunWideWordUseCount() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            tiles: [TestBuilders.makeTile("G"), TestBuilders.makeTile("A"), TestBuilders.makeTile("M"), TestBuilders.makeTile("E")],
            moves: 5,
            rows: 1,
            cols: 4
        )
        controller.configureForTesting(state: state, dictionary: dictionary, runState: RunState())

        controller.submitPath(indices: [0, 1, 2, 3])

        #expect(controller.runState?.wordUseCounts["GAME"] == 1)
    }

    @MainActor
    @Test func roundDebugMetricsTrackAcceptedAndInvalidSubmits() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            tiles: [TestBuilders.makeTile("G"), TestBuilders.makeTile("A"), TestBuilders.makeTile("M"), TestBuilders.makeTile("E")],
            moves: 5,
            rows: 1,
            cols: 4
        )
        let run = RunState()

        controller.configureForTesting(
            state: state,
            dictionary: dictionary,
            runState: run,
            debugOptions: .init(roundMetricsLoggingEnabled: true, startRound: 1)
        )

        controller.submitPath(indices: [0, 1])
        controller.submitPath(indices: [0, 1, 2, 3])
        controller.finalizeCurrentRoundDebugMetricsForTesting(outcome: .failed)

        let metrics = controller.lastRoundDebugMetrics
        #expect(metrics?.roundIndex == 1)
        #expect(metrics?.numberOfSubmits == 1)
        #expect(metrics?.invalidSubmitCount == 1)
        #expect(metrics?.avgWordLength == 4.0)
        #expect(metrics?.bestWord == "GAME")
        #expect(metrics?.bestWordPoints == controller.runState?.scoreThisBoard)
        #expect(metrics?.netMoveRefunds == 0)
        #expect(controller.lastRoundDebugMetricsLog?.contains("\"roundIndex\":1") == true)
        #expect(controller.lastRoundDebugMetricsLog?.contains("\"invalidSubmitCount\":1") == true)
    }

    @MainActor
    @Test func cannotSubmitIfMovesInsufficient_noSpend() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            tiles: [
                TestBuilders.makeTile("G", freshness: .freshLocked),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("M"),
                TestBuilders.makeTile("E")
            ],
            moves: 1,
            rows: 1,
            cols: 4
        )
        controller.configureForTesting(state: state, dictionary: dictionary)
        controller.submitPath(indices: [0, 1, 2, 3])

        #expect(controller.moves == 1)
        #expect(controller.lastSubmitOutcome == .invalid)
        #expect(controller.status == "rejected:notEnoughMoves")
    }

    // MARK: - Run formula tests

    @Test func runMovesFollowBucketBaselines() {
        let cases: [(round: Int, expected: Int)] = [
            (1, 19),
            (10, 19),
            (11, 18),
            (21, 17),
            (31, 16),
            (50, 15)
        ]
        for (round, exp) in cases {
            #expect(RunState.moves(for: round) == exp,
                    "Round \(round): expected \(exp) got \(RunState.moves(for: round))")
        }
    }

    @Test func runMovesTightenAcrossBuckets() {
        #expect(RunState.moves(for: 9) == 19)
        #expect(RunState.moves(for: 19) == 18)
        #expect(RunState.moves(for: 29) == 17)
        #expect(RunState.moves(for: 39) == 16)
        #expect(RunState.moves(for: 49) == 15)
    }

    @Test func runScoreTargetsUseBucketMultipliersAndMilestoneBoosts() {
        #expect(RunState.baseScoreTarget(for: 1) == 120)
        #expect(RunState.baseScoreTarget(for: 10) == 679)
        #expect(RunState.baseScoreTarget(for: 25) == 1896)
        #expect(RunState.baseScoreTarget(for: 40) == 3481)
        #expect(RunState.baseScoreTarget(for: 50) == 4735)

        let round1Plan = RunState.progression(for: 1)
        let round10Plan = RunState.progression(for: 10)
        let round25Plan = RunState.progression(for: 25)
        let round50Plan = RunState.progression(for: 50)

        let round1Expected = Int((Double(RunState.baseScoreTarget(for: 1)) * round1Plan.bucketConfig.scoreMultiplier).rounded(.toNearestOrAwayFromZero))
        let round25Expected = Int((Double(RunState.baseScoreTarget(for: 25)) * round25Plan.bucketConfig.scoreMultiplier).rounded(.toNearestOrAwayFromZero))
        let round10Base = Int((Double(RunState.baseScoreTarget(for: 10)) * round10Plan.bucketConfig.scoreMultiplier).rounded(.toNearestOrAwayFromZero))
        let round50Base = Int((Double(RunState.baseScoreTarget(for: 50)) * round50Plan.bucketConfig.scoreMultiplier).rounded(.toNearestOrAwayFromZero))
        let round10Expected = Int((Double(round10Base) * round10Plan.bucketConfig.milestoneScoreMultiplier / 5.0).rounded(.toNearestOrAwayFromZero)) * 5
        let round50Expected = Int((Double(round50Base) * round50Plan.bucketConfig.milestoneScoreMultiplier / 5.0).rounded(.toNearestOrAwayFromZero)) * 5

        #expect(RunState.scoreGoal(for: 1) == round1Expected)
        #expect(RunState.scoreGoal(for: 10) == round10Expected)
        #expect(RunState.scoreGoal(for: 25) == Int((Double(round25Expected) / 5.0).rounded(.toNearestOrAwayFromZero)) * 5)
        #expect(RunState.scoreGoal(for: 50) == round50Expected)
    }

    @Test func milestoneScoreTargetsRoundToNearestFive() {
        let round10Plan = RunState.progression(for: 10)
        let round50Plan = RunState.progression(for: 50)
        let round10Base = Int((Double(RunState.baseScoreTarget(for: 10)) * round10Plan.bucketConfig.scoreMultiplier).rounded(.toNearestOrAwayFromZero))
        let round50Base = Int((Double(RunState.baseScoreTarget(for: 50)) * round50Plan.bucketConfig.scoreMultiplier).rounded(.toNearestOrAwayFromZero))
        let round10Expected = Int((Double(round10Base) * round10Plan.bucketConfig.milestoneScoreMultiplier / 5.0).rounded(.toNearestOrAwayFromZero)) * 5
        let round50Expected = Int((Double(round50Base) * round50Plan.bucketConfig.milestoneScoreMultiplier / 5.0).rounded(.toNearestOrAwayFromZero)) * 5

        #expect(RunState.scoreGoal(for: 10) == round10Expected)
        #expect(RunState.scoreGoal(for: 50) == round50Expected)
        #expect(RunState.scoreGoal(for: 10) % 5 == 0)
        #expect(RunState.scoreGoal(for: 50) % 5 == 0)
    }

    @Test func scoreTargetCurveCoversAllFiftyRoundsWithFinalTargets() {
        let curve = RunState.scoreTargetCurve()

        #expect(curve.count == 50)
        #expect(curve.first?.roundIndex == 1)
        #expect(curve.first?.finalScoreTarget == RunState.scoreGoal(for: 1))
        #expect(curve.first?.moves == 19)
        #expect(curve.first?.lockTarget == RunState.locksGoal(for: 1))
        #expect(curve[9].roundIndex == 10)
        #expect(curve[9].bucketLocalRound == 10)
        #expect(curve[9].isChallengeRound)
        #expect(curve[9].finalScoreTarget == RunState.scoreGoal(for: 10))
        #expect(curve[24].roundIndex == 25)
        #expect(curve[24].act == 3)
        #expect(curve[24].bucketLocalRound == 5)
        #expect(curve[24].finalScoreTarget == RunState.scoreGoal(for: 25))
        #expect(curve[49].roundIndex == 50)
        #expect(curve[49].act == 5)
        #expect(curve[49].isChallengeRound)
        #expect(curve[49].finalScoreTarget == RunState.scoreGoal(for: 50))
    }

    @MainActor
    @Test func startingRunPublishesScoreCurveLog() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())

        controller.startRun(debugOptions: .init(roundMetricsLoggingEnabled: false, startRound: 1))

        #expect(controller.scoreTargetCurve.count == 50)
        #expect(controller.scoreTargetCurve.first?.finalScoreTarget == RunState.scoreGoal(for: 1))
        #expect(controller.scoreTargetCurve.last?.finalScoreTarget == RunState.scoreGoal(for: 50))
        #expect(controller.scoreTargetCurveLog?.contains("\"roundIndex\":1") == true)
        #expect(controller.scoreTargetCurveLog?.contains("\"roundIndex\":50") == true)
    }

    @MainActor
    @Test func lateRunSanityReportUsesLatestTelemetryPerRoundAndChecksRanges() {
        let staleFailure = makeRoundDebugMetrics(
            outcome: .failed,
            round: 40,
            submits: 8,
            locksBroken: 1,
            avgPointsPerWord: 220,
            score: 3000,
            longWords: 0
        )
        let recoveredRound40 = makeRoundDebugMetrics(
            outcome: .cleared,
            round: 40,
            submits: 11,
            locksBroken: 3,
            avgPointsPerWord: 360,
            score: 4200,
            longWords: 1
        )
        let remainingRounds = (41...50).map { round in
            makeRoundDebugMetrics(
                outcome: .cleared,
                round: round,
                submits: 11,
                locksBroken: 3,
                avgPointsPerWord: 360,
                score: 4200,
                longWords: 1
            )
        }

        let report = GameSessionController.buildLateRunSanityReport(
            from: [staleFailure, recoveredRound40] + remainingRounds
        )

        #expect(report?.trackedRounds.count == 11)
        #expect(report?.missingRounds.isEmpty == true)
        #expect(report?.failedRounds.isEmpty == true)
        #expect(report?.capturedAllLateRounds == true)
        #expect(report?.allRoundsCleared == true)
        #expect(report?.avgSubmitsPerRound == 11.0)
        #expect(report?.avgLocksBrokenPerRound == 3.0)
        #expect(report?.avgLongWordsPerRound == 1.0)
        #expect(report?.avgPointsPerWord == 360.0)
        #expect(report?.avgRoundScore == 4200.0)
        #expect(report?.meetsTargets == true)
        #expect(report?.tuningSnapshot.bucketScoreMultipliers[1] == RunState.progression(for: 1).bucketConfig.scoreMultiplier)
        #expect(report?.tuningSnapshot.milestoneScoreMultipliers[5] == RunState.progression(for: 50).bucketConfig.milestoneScoreMultiplier)
    }

    @MainActor
    @Test func lateRunSanityReportFlagsMissingRoundsAndOutOfRangeAverages() {
        let report = GameSessionController.buildLateRunSanityReport(
            from: [
                makeRoundDebugMetrics(
                    outcome: .failed,
                    round: 40,
                    submits: 7,
                    locksBroken: 1,
                    avgPointsPerWord: 180,
                    score: 2800,
                    longWords: 0
                )
            ]
        )

        #expect(report?.capturedAllLateRounds == false)
        #expect(report?.meetsTargets == false)
        #expect(report?.missingRounds.count == 10)
        #expect(report?.failingChecks.contains(where: { $0.contains("Missing telemetry") }) == true)
        #expect(report?.failingChecks.contains(where: { $0.contains("Failed rounds present") }) == true)
        #expect(report?.failingChecks.contains(where: { $0.contains("Avg submits") }) == true)
        #expect(report?.failingChecks.contains(where: { $0.contains("Avg round score") }) == true)
    }

    @Test func runBucketsAndChallengeRoundsMatchPlanBoundaries() {
        #expect(RunState.act(for: 1) == 1)
        #expect(RunState.act(for: 10) == 1)
        #expect(RunState.act(for: 11) == 2)
        #expect(RunState.act(for: 20) == 2)
        #expect(RunState.act(for: 21) == 3)
        #expect(RunState.act(for: 40) == 4)
        #expect(RunState.act(for: 50) == 5)
        #expect(RunState.bucketLocalRound(for: 1) == 1)
        #expect(RunState.bucketLocalRound(for: 10) == 10)
        #expect(RunState.bucketLocalRound(for: 18) == 8)
        #expect(RunState.bucketLocalRound(for: 50) == 10)

        #expect(!RunState.isChallengeRound(for: 9))
        #expect(RunState.isChallengeRound(for: 10))
        #expect(!RunState.isChallengeRound(for: 19))
        #expect(RunState.isChallengeRound(for: 20))
        #expect(RunState.isChallengeRound(for: 30))
        #expect(RunState.isChallengeRound(for: 40))
        #expect(RunState.isChallengeRound(for: 50))
    }

    @Test func challengeRoundResolverMapsAllMilestoneRounds() {
        #expect(ChallengeRoundResolver.resolve(roundIndex: 9) == nil)
        #expect(ChallengeRoundResolver.resolve(roundIndex: 10)?.kind == .triplePoolBoard)
        #expect(ChallengeRoundResolver.resolve(roundIndex: 20)?.kind == .pyramidBoard)
        #expect(ChallengeRoundResolver.resolve(roundIndex: 30)?.kind == .taxRound)
        #expect(ChallengeRoundResolver.resolve(roundIndex: 40)?.kind == .alternatingPools)
        #expect(ChallengeRoundResolver.resolve(roundIndex: 50)?.kind == .finalExam)
    }

    @Test func challengeTemplatesAndGoalsApplyOnMilestoneRounds() {
        let round9Template = BoardTemplate.template(for: 9)
        let round10Template = BoardTemplate.template(for: 10)
        let round20Template = BoardTemplate.template(for: 20)
        let round30Template = BoardTemplate.template(for: 30)
        let round40Template = BoardTemplate.template(for: 40)
        let round50Template = BoardTemplate.template(for: 50)

        #expect(round9Template.id != round10Template.id)
        #expect(round10Template.id == "challenge10_triple_pools")
        #expect(round10Template.specialRule == .singlePoolPerWord)
        #expect(round20Template.id == "challenge20_pyramid_board")
        #expect(round20Template.playableCount < 49)
        #expect(round30Template.id == "challenge30_tax_round")
        #expect(round30Template.specialRule == .taxSubmitCost)
        #expect(round40Template.id == "challenge40_alternating_pools")
        #expect(round40Template.specialRule == .alternatingPools)
        #expect(round50Template.id == "challenge50_final_exam")
        #expect(round50Template.specialRule == .minimumWordLength(6))
        #expect(RunState.moves(for: 10) == 19)
        #expect(ChallengeRoundResolver.resolve(roundIndex: 10)?.modifiedLockCount == 1)
        #expect(RunState.scoreGoal(for: 10) > RunState.adjustedBaseScoreTarget(for: 10))
    }

    /// Run has 50 rounds total.
    @Test func runHas50Rounds() {
        #expect(RunState.Tunables.totalRounds == 50)
    }

    @Test func bucketObjectivesAppearOnConfiguredRounds() {
        #expect(RunState.objective(for: 1) == nil)
        #expect(RunState.objective(for: 4)?.shortDescription == "Make 4 words")
        #expect(RunState.objective(for: 10)?.shortDescription == "Make 1 5+ letter word")
        #expect(RunState.objective(for: 13)?.shortDescription == "Make 2 6+ letter words")
        #expect(RunState.objective(for: 50) == nil)
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
        run.roundObjectiveThisBoard = RunState.objective(for: 14)
        run.roundObjectiveProgressThisBoard.totalWordsMade = 3

        run.resetBoardCounters()

        #expect(run.locksBrokenThisBoard == 0)
        #expect(run.scoreThisBoard == 0)
        #expect(run.shufflesRemaining == RunState.Tunables.shufflesPerBoard)
        #expect(run.pendingMoveFraction == 0.0)
        #expect(run.modifierPendingMoveFraction == 0.0)
        #expect(run.freshSparkCount == 0)
        #expect(run.freeHintChargesRemaining == 0)
        #expect(run.freeUndoChargesRemaining == 0)
        #expect(run.roundObjectiveThisBoard == nil)
        #expect(run.roundObjectiveProgressThisBoard.totalWordsMade == 0)
    }

    @MainActor
    @Test func objectiveProgressTracksQualifyingWordsInRunStateAndHud() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["planet"])
        let state = TestBuilders.makeState(
            tiles: [
                TestBuilders.makeTile("P"),
                TestBuilders.makeTile("L"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("N"),
                TestBuilders.makeTile("E"),
                TestBuilders.makeTile("T")
            ],
            moves: 5,
            rows: 1,
            cols: 6
        )
        var run = RunState()
        run.roundIndex = 13
        run.scoreTargetThisBoard = 999
        run.roundObjectiveThisBoard = RunState.objective(for: 13)
        controller.configureForTesting(state: state, dictionary: dictionary, runState: run)

        controller.submitPath(indices: [0, 1, 2, 3, 4, 5])

        #expect(controller.runState?.roundObjectiveProgressThisBoard.qualifyingWordCount == 1)
        #expect(controller.runState?.roundObjectiveProgressThisBoard.submissionsUsed == 1)
        #expect(controller.objectivesText.contains("6+ letters: 1/2"))
    }

    @MainActor
    @Test func sevenLetterWordRefundsOneMoveAndAddsQuarterPending() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["planets"])
        let state = TestBuilders.makeState(
            tiles: [
                TestBuilders.makeTile("P"),
                TestBuilders.makeTile("L"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("N"),
                TestBuilders.makeTile("E"),
                TestBuilders.makeTile("T"),
                TestBuilders.makeTile("S")
            ],
            moves: 5,
            rows: 1,
            cols: 7
        )
        var run = RunState()
        run.scoreTargetThisBoard = 999
        controller.configureForTesting(state: state, dictionary: dictionary, runState: run)

        controller.submitPath(indices: [0, 1, 2, 3, 4, 5, 6])

        #expect(controller.moves == 5)
        #expect(controller.runState?.pendingMoveFraction == 0.25)
        #expect(controller.powerupToast == "+1 Move")
    }

    @MainActor
    @Test func twoSevenLetterWordsAccumulateHalfPendingRefund() async {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["planets"])
        let firstState = TestBuilders.makeState(
            tiles: [
                TestBuilders.makeTile("P"),
                TestBuilders.makeTile("L"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("N"),
                TestBuilders.makeTile("E"),
                TestBuilders.makeTile("T"),
                TestBuilders.makeTile("S")
            ],
            moves: 5,
            rows: 1,
            cols: 7
        )
        var run = RunState()
        run.scoreTargetThisBoard = 999
        controller.configureForTesting(state: firstState, dictionary: dictionary, runState: run)

        controller.submitPath(indices: [0, 1, 2, 3, 4, 5, 6])
        for _ in 0..<40 {
            if !controller.isAnimating { break }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        let secondState = TestBuilders.makeState(
            tiles: [
                TestBuilders.makeTile("P"),
                TestBuilders.makeTile("L"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("N"),
                TestBuilders.makeTile("E"),
                TestBuilders.makeTile("T"),
                TestBuilders.makeTile("S")
            ],
            moves: controller.moves,
            score: controller.score,
            rows: 1,
            cols: 7
        )
        controller.configureForTesting(
            state: secondState,
            dictionary: dictionary,
            runState: controller.runState
        )

        controller.submitPath(indices: [0, 1, 2, 3, 4, 5, 6])

        #expect(controller.moves == 5)
        #expect(controller.runState?.pendingMoveFraction == 0.5)
        #expect(controller.powerupToast == "+1 Move")
    }

    @MainActor
    @Test func eightLetterWordRefundsOneMoveAndAddsQuarterPending() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["notebook"])
        let state = TestBuilders.makeState(
            tiles: [
                TestBuilders.makeTile("N"),
                TestBuilders.makeTile("O"),
                TestBuilders.makeTile("T"),
                TestBuilders.makeTile("E"),
                TestBuilders.makeTile("B"),
                TestBuilders.makeTile("O"),
                TestBuilders.makeTile("O"),
                TestBuilders.makeTile("K")
            ],
            moves: 5,
            rows: 1,
            cols: 8
        )
        var run = RunState()
        run.scoreTargetThisBoard = 999
        controller.configureForTesting(state: state, dictionary: dictionary, runState: run)

        controller.submitPath(indices: [0, 1, 2, 3, 4, 5, 6, 7])

        #expect(controller.moves == 5)
        #expect(controller.runState?.pendingMoveFraction == 0.25)
        #expect(controller.powerupToast == "+1 Move")
    }

    @MainActor
    @Test func thirteenLetterWordRefundIsCappedAtOneMove() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["counterweight"])
        let state = TestBuilders.makeState(
            tiles: [
                TestBuilders.makeTile("C"),
                TestBuilders.makeTile("O"),
                TestBuilders.makeTile("U"),
                TestBuilders.makeTile("N"),
                TestBuilders.makeTile("T"),
                TestBuilders.makeTile("E"),
                TestBuilders.makeTile("R"),
                TestBuilders.makeTile("W"),
                TestBuilders.makeTile("E"),
                TestBuilders.makeTile("I"),
                TestBuilders.makeTile("G"),
                TestBuilders.makeTile("H"),
                TestBuilders.makeTile("T")
            ],
            moves: 5,
            rows: 1,
            cols: 13
        )
        var run = RunState()
        run.scoreTargetThisBoard = 999
        controller.configureForTesting(state: state, dictionary: dictionary, runState: run)

        controller.submitPath(indices: Array(0..<13))

        #expect(controller.moves == 5)
        #expect(controller.runState?.pendingMoveFraction == 0.0)
        #expect(controller.powerupToast == "+1 Move")
    }

    @Test func longWordMoveFractionResetsBetweenRounds() {
        var run = RunState()
        run.pendingMoveFraction = 0.75

        run.resetBoardCounters()

        #expect(run.pendingMoveFraction == 0.0)
    }

    /// Step 28 length multipliers extend cleanly from 4 through 20.
    @Test func wordScorerLengthMultipliersAreCorrect() {
        #expect(WordScorer.lengthMultiplier(for: 4) == 1.00)
        #expect(WordScorer.lengthMultiplier(for: 5) == 1.20)
        #expect(WordScorer.lengthMultiplier(for: 6) == 1.45)
        #expect(WordScorer.lengthMultiplier(for: 7) == 1.75)
        #expect(WordScorer.lengthMultiplier(for: 8) == 2.10)
        #expect(WordScorer.lengthMultiplier(for: 9) == 2.40)
        #expect(WordScorer.lengthMultiplier(for: 12) == 3.20)
        #expect(WordScorer.lengthMultiplier(for: 16) == 3.88)
        #expect(WordScorer.lengthMultiplier(for: 20) == 4.25)
        #expect(WordScorer.lengthMultiplier(for: 99) == 4.25)
    }

    /// Step 1 repeat penalties: 1st=1.00, 2nd=0.75, 3rd=0.55, 4th+=0.40.
    @Test func wordScorerRepeatPenaltyTiersAreCorrect() {
        #expect(WordScorer.repeatMultiplier(forSubmissionCount: 1) == 1.00)
        #expect(WordScorer.repeatMultiplier(forSubmissionCount: 2) == 0.75)
        #expect(WordScorer.repeatMultiplier(forSubmissionCount: 3) == 0.55)
        #expect(WordScorer.repeatMultiplier(forSubmissionCount: 4) == 0.40)
        #expect(WordScorer.repeatMultiplier(forSubmissionCount: 99) == 0.40)
    }

    @Test func wordScorerCommonFiveLetterWordFallsInTargetRange() {
        let points = WordScorer().scoreWord(letters: "HOUSE", lockCount: 0, wordUseCounts: [:])
        #expect(points >= 30)
        #expect(points <= 60)
    }

    @Test func wordScorerFourthUseIsAboutFortyPercentOfFirstUse() {
        let scorer = WordScorer()
        let firstUse = scorer.scoreWord(letters: "HOUSE", lockCount: 0, wordUseCounts: [:])
        let fourthUse = scorer.scoreWord(letters: "HOUSE", lockCount: 0, wordUseCounts: ["HOUSE": 3])
        let ratio = Double(fourthUse) / Double(firstUse)
        #expect(ratio >= 0.35)
        #expect(ratio <= 0.45)
    }

    @Test func wordScorerSevenLettersWithTwoRareLettersCanScoreOverThreeHundred() {
        let points = WordScorer().scoreWord(letters: "QZYWVHF", lockCount: 0, wordUseCounts: [:])
        #expect(points >= 300)
    }

    @Test func wordScorerLockBonusIsExactlyTwentyPerLock() {
        let scorer = WordScorer()
        let noLocks = scorer.scoreWord(letters: "HOUSE", lockCount: 0, wordUseCounts: [:])
        let threeLocks = scorer.scoreWord(letters: "HOUSE", lockCount: 3, wordUseCounts: [:])
        #expect(threeLocks - noLocks == 60)
    }

    @Test func firstRunWideSubmissionUsesFullMultiplierAndStoresCountOne() {
        var run = RunState()
        let word = "HOUSE"

        let points = WordScorer().scoreWord(letters: word, lockCount: 0, wordUseCounts: run.wordUseCounts)
        run.wordUseCounts[word] = run.wordUseCounts[word, default: 0] + 1

        #expect(points == WordScorer.scoreWord(
            letterSum: LetterValues.sum(for: word),
            length: word.count,
            priorUseCount: 0,
            lockCount: 0
        ))
        #expect(run.wordUseCounts[word] == 1)
        #expect(WordScorer.repeatMultiplier(forPriorUseCount: 0) == 1.0)
    }

    @Test func repeatedWordScoresDeclineAcrossFourSubmissions() {
        var run = RunState()
        let scorer = WordScorer()
        let word = "HOUSE"
        var scores: [Int] = []

        for _ in 0..<4 {
            scores.append(scorer.scoreWord(letters: word, lockCount: 0, wordUseCounts: run.wordUseCounts))
            run.wordUseCounts[word] = run.wordUseCounts[word, default: 0] + 1
        }

        #expect(scores[0] > scores[1])
        #expect(scores[1] > scores[2])
        #expect(scores[2] > scores[3])
    }

    @Test func wordUseCountsPersistAcrossRoundsWithinRun() {
        var run = RunState()
        run.wordUseCounts["HOUSE"] = 1
        run.roundIndex = 18

        let firstRoundScore = WordScorer().scoreWord(letters: "HOUSE", lockCount: 0, wordUseCounts: [:])
        run.resetBoardCounters()
        let laterRoundScore = WordScorer().scoreWord(letters: "HOUSE", lockCount: 0, wordUseCounts: run.wordUseCounts)

        #expect(run.wordUseCounts["HOUSE"] == 1)
        #expect(run.act == 2)
        #expect(laterRoundScore < firstRoundScore)
    }

    @Test func wordUseCountsResetBetweenRuns() {
        var priorRun = RunState()
        priorRun.wordUseCounts["HOUSE"] = 4

        let freshRun = RunState()

        #expect(priorRun.wordUseCounts["HOUSE"] == 4)
        #expect(freshRun.wordUseCounts.isEmpty)
    }

    /// scoreThisBoard increases on every accepted word, even with repeat penalties.
    @Test func scoreThisBoardIncreasesOnEveryAcceptedWord() {
        var run = RunState()
        let scorer = WordScorer()
        let wordKey = "HOUSE"

        for _ in 0..<6 {
            let before = run.scoreThisBoard
            let points = scorer.scoreWord(letters: wordKey, lockCount: 0, wordUseCounts: run.wordUseCounts)
            run.wordUseCounts[wordKey] = run.wordUseCounts[wordKey, default: 0] + 1
            run.scoreThisBoard += points
            #expect(run.scoreThisBoard > before)
        }
    }

    @MainActor
    @Test func reachingScoreTargetClearsRoundEvenWhenLocksRemain() async {
        let controller = GameSessionController(
            milestoneTracker: MilestoneTrackerTestHelper.makeIsolated(),
            playerProfile: PlayerProfileTestHelper.makeIsolated()
        )
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            tiles: [TestBuilders.makeTile("G"), TestBuilders.makeTile("A"), TestBuilders.makeTile("M"), TestBuilders.makeTile("E")],
            moves: 5,
            rows: 1,
            cols: 4
        )
        var run = RunState()
        run.scoreTargetThisBoard = 1
        run.lockTargetThisBoard = 99
        controller.configureForTesting(state: state, dictionary: dictionary, runState: run)

        controller.submitPath(indices: [0, 1, 2, 3])
        for _ in 0..<160 {
            if (controller.runState?.roundIndex ?? 1) >= 2 || controller.showRoundClearStamp || controller.showPerkDraft {
                break
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        #expect(controller.runState?.locksBrokenThisBoard == 0)
        #expect(controller.runRoundsCleared >= 1)
        #expect((controller.runState?.roundIndex ?? 1) >= 2 || controller.showRoundClearStamp || controller.showPerkDraft)
        #expect(!controller.showRunSummary)
    }

    @MainActor
    @Test func runningOutOfMovesBelowScoreTargetEndsRun() async {
        let controller = GameSessionController(
            milestoneTracker: MilestoneTrackerTestHelper.makeIsolated(),
            playerProfile: PlayerProfileTestHelper.makeIsolated()
        )
        let dictionary = WordDictionary(words: ["game"])
        let state = TestBuilders.makeState(
            tiles: [TestBuilders.makeTile("G"), TestBuilders.makeTile("A"), TestBuilders.makeTile("M"), TestBuilders.makeTile("E")],
            moves: 1,
            rows: 1,
            cols: 4
        )
        var run = RunState()
        run.scoreTargetThisBoard = 999
        run.lockTargetThisBoard = 0
        controller.configureForTesting(state: state, dictionary: dictionary, runState: run)

        controller.submitPath(indices: [0, 1, 2, 3])
        for _ in 0..<320 {
            if controller.runSummarySnapshot != nil { break }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        #expect(controller.moves == 0)
        #expect(controller.runState?.scoreThisBoard ?? 0 < 999)
        #expect(controller.runSummarySnapshot?.wonRun == false)
        #expect(controller.runState == nil)
    }

    @Test func xpFormulaMatchesPlanReferenceRun() {
        let xp = GameSessionController.calculateXP(
            roundsCleared: 25,
            totalScore: 50_000,
            challengeRoundsCleared: 1,
            rareLetterWordUsed: true
        )

        #expect(xp == 575)
    }

    @Test func rareLetterBonusDetectsPlanLettersOnly() {
        #expect(GameSessionController.wordContainsRareLetter("jolly"))
        #expect(GameSessionController.wordContainsRareLetter("equal"))
        #expect(GameSessionController.wordContainsRareLetter("xylol"))
        #expect(GameSessionController.wordContainsRareLetter("zebra"))
        #expect(GameSessionController.wordContainsRareLetter("knack"))
        #expect(!GameSessionController.wordContainsRareLetter("house"))
    }

    @MainActor
    @Test func endRunSummaryIncludesXPEarnedForLossesAndWins() {
        let controller = GameSessionController(
            milestoneTracker: MilestoneTrackerTestHelper.makeIsolated(),
            playerProfile: PlayerProfileTestHelper.makeIsolated()
        )

        controller.startRun(debugOptions: .init(roundMetricsLoggingEnabled: false, startRound: 1))
        controller.endRun(won: false)

        #expect(controller.runSummarySnapshot?.xpEarned == 40)
        #expect(controller.runSummarySnapshot?.wonRun == false)
        #expect(controller.runSummarySnapshot?.totalXPAfterRun == 40)

        controller.startRun(debugOptions: .init(roundMetricsLoggingEnabled: false, startRound: 1))
        controller.endRun(won: true)

        #expect(controller.runSummarySnapshot?.xpEarned == GameSessionController.calculateXP(
            roundsCleared: 50,
            totalScore: 0,
            challengeRoundsCleared: 0,
            rareLetterWordUsed: false
        ))
        #expect(controller.runSummarySnapshot?.wonRun == true)
    }

    @MainActor
    @Test func endRunSummaryCarriesTrackedRunStatsForLosses() {
        let controller = GameSessionController(
            milestoneTracker: MilestoneTrackerTestHelper.makeIsolated(),
            playerProfile: PlayerProfileTestHelper.makeIsolated()
        )

        controller.startRun(debugOptions: .init(roundMetricsLoggingEnabled: false, startRound: 18))
        controller.configureRunSummaryTrackingForTesting(
            totalScore: 43_210,
            roundsCleared: 17,
            locksBroken: 21,
            wordsBuilt: 88,
            bestWord: "JQXZ",
            bestWordScore: 360,
            challengeRoundsCleared: 2,
            rareLetterWordUsed: true,
            rareLetterWordsTotal: 5
        )
        controller.endRun(won: false)

        let summary = controller.runSummarySnapshot
        #expect(summary?.wonRun == false)
        #expect(summary?.totalScore == 43_210)
        #expect(summary?.roundsCleared == 17)
        #expect(summary?.roundReached == 18)
        #expect(summary?.locksBroken == 21)
        #expect(summary?.wordsBuilt == 88)
        #expect(summary?.bestWord == "JQXZ")
        #expect(summary?.bestWordScore == 360)
        #expect(summary?.challengeRoundsCleared == 2)
        #expect(summary?.rareLetterWordUsed == true)
    }

    @Test func shareCardExportSizeMatchesSocialPreviewTarget() {
        #expect(Int(ShareCardView.exportSize.width) == 1200)
        #expect(Int(ShareCardView.exportSize.height) == 630)
    }

    @MainActor
    @Test func bestWordTrackingUsesHighestSingleWordScoreNotLength() async {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["aaaaaa", "jqxz"])
        let state = TestBuilders.makeState(
            tiles: [
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("J"),
                TestBuilders.makeTile("Q"),
                TestBuilders.makeTile("X"),
                TestBuilders.makeTile("Z")
            ],
            moves: 8,
            rows: 1,
            cols: 10
        )
        var run = RunState()
        run.scoreTargetThisBoard = 9999
        controller.configureForTesting(state: state, dictionary: dictionary, runState: run)

        controller.submitPath(indices: [0, 1, 2, 3, 4, 5])
        for _ in 0..<40 {
            if !controller.isAnimating { break }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        let secondState = TestBuilders.makeState(
            tiles: [
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("A"),
                TestBuilders.makeTile("J"),
                TestBuilders.makeTile("Q"),
                TestBuilders.makeTile("X"),
                TestBuilders.makeTile("Z")
            ],
            moves: controller.moves,
            score: controller.score,
            rows: 1,
            cols: 10
        )
        controller.configureForTesting(state: secondState, dictionary: dictionary, runState: controller.runState)
        controller.submitPath(indices: [6, 7, 8, 9])
        for _ in 0..<40 {
            if !controller.isAnimating { break }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        #expect(controller.runWordsBuiltTotal == 2)
        #expect(controller.runBestWord == "JQXZ")
        #expect(controller.runBestWordScore >= 36)
    }

    @MainActor
    @Test func playerProfilePersistsLifetimeStatsAndUnlocks() {
        let key = "wordfall.playerProfile.test.\(UUID().uuidString)"
        UserDefaults.standard.removeObject(forKey: key)

        let profile = PlayerProfile(defaultsKey: key)
        let unlocks = profile.recordRunEnd(
            xpEarned: 930,
            wordsBuilt: 24,
            locksBroken: 9,
            rareLetterWords: 3,
            roundReached: 18,
            wonRun: false
        )
        profile.setEquippedStarterPerks([.cleanInk, .spareSeal, .cleanInk])

        #expect(profile.stats.totalXP == 930)
        #expect(profile.stats.totalWordsBuilt == 24)
        #expect(profile.stats.totalLocksBroken == 9)
        #expect(profile.stats.totalRareLetterWords == 3)
        #expect(profile.stats.highestRoundReached == 18)
        #expect(profile.stats.runsCompleted == 0)
        #expect(profile.equippedStarterPerks == [.cleanInk, .spareSeal])
        #expect(unlocks == [.equipSlot1, .equipSlot2, .perkLibraryTier2, .rerollPerRun, .startingPowerup])

        let reloaded = PlayerProfile(defaultsKey: key)
        #expect(reloaded.stats == profile.stats)
        #expect(reloaded.unlockedThresholds == profile.unlockedThresholds)
        #expect(reloaded.equippedStarterPerks == [.cleanInk, .spareSeal])
    }

    @MainActor
    @Test func playerProfileResetClearsPersistedProgress() {
        let key = "wordfall.playerProfile.test.\(UUID().uuidString)"
        UserDefaults.standard.removeObject(forKey: key)

        let profile = PlayerProfile(defaultsKey: key)
        _ = profile.recordRunEnd(
            xpEarned: 300,
            wordsBuilt: 8,
            locksBroken: 4,
            rareLetterWords: 1,
            roundReached: 7,
            wonRun: false
        )

        profile.reset()

        #expect(profile.stats == PlayerProfile.Stats())
        #expect(profile.unlockedThresholds.isEmpty)
        #expect(profile.equippedStarterPerks.isEmpty)

        let reloaded = PlayerProfile(defaultsKey: key)
        #expect(reloaded.stats == PlayerProfile.Stats())
        #expect(reloaded.unlockedThresholds.isEmpty)
        #expect(reloaded.equippedStarterPerks.isEmpty)
    }

    @MainActor
    @Test func endRunUpdatesPlayerProfileAndSummaryUnlocks() {
        let tracker = MilestoneTrackerTestHelper.makeIsolated()
        let profile = PlayerProfileTestHelper.makeIsolated()
        let controller = GameSessionController(milestoneTracker: tracker, playerProfile: profile)

        controller.startRun(debugOptions: .init(roundMetricsLoggingEnabled: false, startRound: 1))
        controller.configureRunSummaryTrackingForTesting(
            totalScore: 50_000,
            roundsCleared: 25,
            locksBroken: 12,
            wordsBuilt: 40,
            bestWord: "QUARTZ",
            bestWordScore: 440,
            challengeRoundsCleared: 1,
            rareLetterWordUsed: true,
            rareLetterWordsTotal: 4
        )
        controller.endRun(won: false)

        #expect(profile.totalXP == 575)
        #expect(profile.stats.totalWordsBuilt == 40)
        #expect(profile.stats.totalLocksBroken == 12)
        #expect(profile.stats.totalRareLetterWords == 4)
        #expect(profile.unlockedThresholds.contains(.perkLibraryTier2))
        #expect(controller.runSummarySnapshot?.totalXPAfterRun == 575)
        #expect(controller.runSummarySnapshot?.newUnlocks == [.equipSlot1, .equipSlot2, .perkLibraryTier2])
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

    @MainActor
    @Test func lifetimeMilestonesApplyBoardStartPassives() {
        let profile = PlayerProfileTestHelper.makeIsolated()
        _ = profile.recordRunEnd(
            xpEarned: 0,
            wordsBuilt: 100,
            locksBroken: 150,
            rareLetterWords: 25,
            roundReached: 20,
            wonRun: false
        )

        let controller = GameSessionController(
            milestoneTracker: MilestoneTrackerTestHelper.makeIsolated(),
            playerProfile: profile
        )
        controller.startRun(debugOptions: .init(roundMetricsLoggingEnabled: false, startRound: 10))

        #expect(profile.unlockedLifetimeMilestones == Set(LifetimeMilestoneID.allCases))
        #expect(controller.shufflesRemaining == RunState.Tunables.shufflesPerBoard + 1)
        #expect(controller.moves == RunState.moves(for: 10) + 2)
        #expect(controller.rareSpawnRateMultiplierForTesting == 1.05)
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

    @MainActor
    @Test func debugBootstrapStartsRunAtConfiguredRound() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())

        controller.startRun(debugOptions: .init(roundMetricsLoggingEnabled: false, startRound: 40))

        guard let run = controller.runState else {
            Issue.record("Expected seeded run state")
            return
        }

        #expect(run.roundIndex == 40)
        #expect(controller.currentRound == 40)
        #expect(controller.currentAct == 4)
        #expect(controller.runRoundsCleared == 39)
        #expect(run.activePerks == [.tightGloves, .freeHint, .vowelBloom])
        #expect(run.inventory.hints == 2)
        #expect(run.inventory.wildcards == 1)
        #expect(run.inventory.undos == 1)
        #expect(run.wordUseCounts.count == 18)
        #expect(run.wordUseCounts.values.allSatisfy { (2...3).contains($0) })
    }

    @MainActor
    @Test func roundTenPublishesChallengeHudMetadata() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())

        controller.startRun(debugOptions: .init(roundMetricsLoggingEnabled: false, startRound: 10))

        #expect(controller.currentRound == 10)
        #expect(controller.isChallengeRound)
        #expect(controller.currentChallengeDisplayName == "TRIPLE POOLS")
        #expect(controller.currentChallengePrimaryText == "One pool per word")
        #expect(controller.currentChallengeSecondaryLabel == "BONUS")
        #expect(controller.currentChallengeSecondaryText == "Make 1 5+ letter word")
        #expect(controller.currentChallengeRuleText == "One pool per word")
        #expect(controller.templateDisplayName == "TRIPLE POOLS")
    }

    @MainActor
    @Test func roundFortyPublishesChallengeHudMetadata() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())

        controller.startRun(debugOptions: .init(roundMetricsLoggingEnabled: false, startRound: 40))

        #expect(controller.currentRound == 40)
        #expect(controller.isChallengeRound)
        #expect(controller.currentChallengeDisplayName == "ALTERNATING POOLS")
        #expect(controller.currentChallengePrimaryText == "Alternate left and right pools")
        #expect(controller.currentChallengeSecondaryLabel == "BONUS")
        #expect(controller.currentChallengeSecondaryText == "Make 2 6+ letter words")
        #expect(controller.currentChallengeRuleText == "Alternate left and right pools")
        #expect(controller.templateDisplayName == "ALTERNATING POOLS")
    }

    @MainActor
    @Test func roundTwentyPublishesRequiredObjectiveMetadata() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())

        controller.startRun(debugOptions: .init(roundMetricsLoggingEnabled: false, startRound: 20))

        #expect(controller.currentRound == 20)
        #expect(controller.isChallengeRound)
        #expect(controller.currentChallengeDisplayName == "PYRAMID BOARD")
        #expect(controller.currentChallengePrimaryText == "Shape board only")
        #expect(controller.currentChallengeSecondaryLabel == "OBJECTIVE")
        #expect(controller.currentChallengeSecondaryText == "Hit target in 7 submissions")
        #expect(controller.currentChallengeRuleText == "Shape board only")
        #expect(controller.templateDisplayName == "PYRAMID BOARD")
    }

    @MainActor
    @Test func roundFiftyPublishesChallengeHudMetadata() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())

        controller.startRun(debugOptions: .init(roundMetricsLoggingEnabled: false, startRound: 50))

        #expect(controller.currentRound == 50)
        #expect(controller.isChallengeRound)
        #expect(controller.currentChallengeDisplayName == "FINAL EXAM")
        #expect(controller.currentChallengeRuleText == "Words must be 6+ letters")
        #expect(controller.currentChallengePrimaryText == "Words must be 6+ letters")
        #expect(controller.currentChallengeSecondaryLabel == nil)
        #expect(controller.currentChallengeSecondaryText == nil)
        #expect(controller.templateDisplayName == "FINAL EXAM")
    }

    @Test func triplePoolsTemplateHasExpectedRegionsAndGutters() {
        let template = BoardTemplate.template(for: 10)
        let middleRowIndices = (0..<template.cols).map { (3 * template.cols) + $0 }
        let topGutterIndices = [3, 10, 17]

        #expect(template.regionIDs == [0, 1, 2])
        #expect(template.playableCount == 36)
        #expect(template.visualStyle == .triplePoolsBalanced)
        #expect(middleRowIndices.allSatisfy { !template.isPlayable($0) })
        #expect(topGutterIndices.allSatisfy { !template.isPlayable($0) })
    }

    @Test func triplePoolsGenerationGuaranteesTwoVowelsPerPool() {
        let template = BoardTemplate.template(for: 10)
        let dictionary = WordDictionary(words: ["game"])

        var bag = LetterBag()
        let state = Resolver.initialState(
            template: template,
            moves: RunState.moves(for: 10),
            dictionary: dictionary,
            bag: &bag,
            lockObjectiveTarget: RunState.locksGoal(for: 10, template: template)
        )

        let regionCounts = vowelCountsByRegion(in: state.tiles, template: template)
        for region in template.regionIDs {
            #expect(regionCounts[region, default: 0] >= 2)
        }
    }

    @Test func resolverRejectsTriplePoolsWordThatMixesPools() {
        let template = BoardTemplate.template(for: 10)
        let dictionary = WordDictionary(words: ["game"])
        let size = template.gridSize * template.gridSize
        var tiles = [Tile?](repeating: nil, count: size)
        tiles[0] = TestBuilders.makeTile("G")
        tiles[1] = TestBuilders.makeTile("A")
        tiles[5] = TestBuilders.makeTile("M")
        tiles[6] = TestBuilders.makeTile("E")

        let state = GameState(
            rows: template.rows,
            cols: template.cols,
            boardTemplate: template,
            tiles: tiles,
            score: 0,
            moves: 8,
            inkPoints: 0,
            usedTileIds: [],
            totalLocksBroken: 0,
            lockObjectiveTarget: 4
        )

        var bag = LetterBag(weights: [("E", 1)])
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 5, 6]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(!result.accepted)
        #expect(result.rejectionReason == .mixedPools)
    }

    @Test func triplePoolsGravityKeepsColumnsInsideTheirPoolSegment() {
        let template = BoardTemplate.template(for: 10)
        let size = template.gridSize * template.gridSize
        var tiles = [Tile?](repeating: nil, count: size)
        let topTile = TestBuilders.makeTile("A")
        tiles[0] = topTile

        let gravity = Gravity.apply(
            tiles: tiles,
            rows: template.rows,
            cols: template.cols,
            template: template
        )

        #expect(gravity.tiles[14]?.id == topTile.id)
        #expect(gravity.tiles[42] == nil)
    }

    @Test func alternatingPoolsTemplateHasDistinctLeftRightRegions() {
        let template = BoardTemplate.template(for: 40)
        let centerColumnIndices = (0..<template.rows).map { ($0 * template.cols) + 3 }

        #expect(template.regionIDs == [0, 1])
        #expect(centerColumnIndices.allSatisfy { !template.isPlayable($0) })
        #expect(template.playableCount == 42)
    }

    @Test func alternatingPoolsGenerationMeetsConstraintsAcrossHundredBoards() {
        let template = BoardTemplate.template(for: 40)
        let dictionary = WordDictionary(words: makeAlternatingPoolsDictionary())

        for _ in 0..<100 {
            var bag = LetterBag()
            let state = Resolver.initialState(
                template: template,
                moves: RunState.moves(for: 40),
                dictionary: dictionary,
                bag: &bag,
                lockObjectiveTarget: RunState.locksGoal(for: 40, template: template)
            )

            #expect(Resolver.satisfiesGenerationConstraints(tiles: state.tiles, template: template, dictionary: dictionary))
        }
    }

    @Test func alternatingPoolsConstraintValidatorRejectsUnsolvablePoolBoards() {
        let template = BoardTemplate.template(for: 40)
        let dictionary = WordDictionary(words: makeAlternatingPoolsDictionary())
        let size = template.gridSize * template.gridSize
        var tiles = [Tile?](repeating: nil, count: size)

        for (index, regionID) in template.regions {
            let letter: Character = regionID == 0 ? "T" : "S"
            tiles[index] = TestBuilders.makeTile(letter)
        }

        #expect(!Resolver.satisfiesGenerationConstraints(tiles: tiles, template: template, dictionary: dictionary))
    }

    @Test func resolverRejectsAlternatingPoolsWordThatMixesRegions() {
        let template = BoardTemplate.template(for: 40)
        let dictionary = WordDictionary(words: ["game"])
        let size = template.gridSize * template.gridSize
        var tiles = [Tile?](repeating: nil, count: size)
        tiles[0] = TestBuilders.makeTile("G")
        tiles[1] = TestBuilders.makeTile("A")
        tiles[4] = TestBuilders.makeTile("M")
        tiles[5] = TestBuilders.makeTile("E")

        let state = GameState(
            rows: template.rows,
            cols: template.cols,
            boardTemplate: template,
            tiles: tiles,
            score: 0,
            moves: 8,
            inkPoints: 0,
            usedTileIds: [],
            totalLocksBroken: 0,
            lockObjectiveTarget: 4
        )

        var bag = LetterBag(weights: [("E", 1)])
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 4, 5]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(!result.accepted)
        #expect(result.rejectionReason == .mixedPools)
    }

    @MainActor
    @Test func controllerRejectsAlternatingPoolsRepeatFromSamePool() async {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["game", "word"])
        let template = BoardTemplate.template(for: 40)
        let firstState = alternatingPoolsState(
            template: template,
            leftWord: "GAME",
            rightWord: "WORD",
            moves: 8
        )
        var run = RunState()
        run.roundIndex = 40
        run.scoreTargetThisBoard = 999
        controller.configureForTesting(state: firstState, dictionary: dictionary, runState: run)

        controller.submitPath(indices: [0, 1, 2, 8])
        for _ in 0..<40 {
            if !controller.isAnimating { break }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        let secondState = alternatingPoolsState(
            template: template,
            leftWord: "GAME",
            rightWord: "WORD",
            moves: controller.moves,
            score: controller.score
        )
        controller.configureForTesting(state: secondState, dictionary: dictionary, runState: controller.runState)
        controller.submitPath(indices: [0, 1, 2, 8])

        #expect(controller.lastSubmitOutcome == .invalid)
        #expect(controller.powerupToast == "Switch pools")
        #expect(controller.moves == secondState.moves)
    }

    @MainActor
    @Test func controllerAllowsAlternatingPoolsSubmitAfterSwitchingPools() async {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["game", "word"])
        let template = BoardTemplate.template(for: 40)
        let firstState = alternatingPoolsState(
            template: template,
            leftWord: "GAME",
            rightWord: "WORD",
            moves: 8
        )
        var run = RunState()
        run.roundIndex = 40
        run.scoreTargetThisBoard = 999
        controller.configureForTesting(state: firstState, dictionary: dictionary, runState: run)

        controller.submitPath(indices: [0, 1, 2, 8])
        for _ in 0..<40 {
            if !controller.isAnimating { break }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        let secondState = alternatingPoolsState(
            template: template,
            leftWord: "GAME",
            rightWord: "WORD",
            moves: controller.moves,
            score: controller.score
        )
        controller.configureForTesting(state: secondState, dictionary: dictionary, runState: controller.runState)
        controller.submitPath(indices: [4, 5, 6, 11])
        for _ in 0..<40 {
            if !controller.isAnimating { break }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        #expect(controller.runWordsBuiltTotal == 2)
        #expect(controller.runState?.lastChallengeRegionIDThisBoard == 1)
    }

    @Test func pyramidBoardMaskHasNarrowTopAndWideBase() {
        let template = BoardTemplate.template(for: 20)
        let topRowPlayable = (0..<template.cols).filter { template.isPlayable($0) }.count
        let bottomRowStart = (template.rows - 1) * template.cols
        let bottomRowPlayable = (0..<template.cols).filter { template.isPlayable(bottomRowStart + $0) }.count

        #expect(topRowPlayable == 1)
        #expect(bottomRowPlayable == 7)
        #expect(template.playableCount == 35)
    }

    @Test func pyramidBoardGravityDropsWithinIrregularShape() {
        let template = BoardTemplate.template(for: 20)
        let size = template.gridSize * template.gridSize
        var tiles = [Tile?](repeating: nil, count: size)
        let tile = TestBuilders.makeTile("A")
        tiles[9] = tile

        let gravity = Gravity.apply(
            tiles: tiles,
            rows: template.rows,
            cols: template.cols,
            template: template
        )

        #expect(gravity.tiles[44]?.id == tile.id)
        #expect(gravity.tiles[9] == nil)
    }

    @Test func pyramidBoardGenerationGuaranteesMinimumVowels() {
        let template = BoardTemplate.template(for: 20)
        let dictionary = WordDictionary(words: ["game"])

        var bag = LetterBag()
        let state = Resolver.initialState(
            template: template,
            moves: RunState.moves(for: 20),
            dictionary: dictionary,
            bag: &bag,
            lockObjectiveTarget: RunState.locksGoal(for: 20, template: template)
        )

        let regionCounts = vowelCountsByRegion(in: state.tiles, template: template)
        #expect(regionCounts[0, default: 0] >= 7)
    }

    @MainActor
    @Test func taxRoundEightLetterWordStillGetsNormalRefund() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["notebook"])
        let template = BoardTemplate.template(for: 30)
        let size = template.gridSize * template.gridSize
        var tiles = [Tile?](repeating: nil, count: size)
        for (offset, letter) in Array("NOTEBOOK").enumerated() {
            tiles[offset] = TestBuilders.makeTile(letter)
        }

        let state = GameState(
            rows: template.rows,
            cols: template.cols,
            boardTemplate: template,
            tiles: tiles,
            score: 0,
            moves: 5,
            inkPoints: 0,
            usedTileIds: [],
            totalLocksBroken: 0,
            lockObjectiveTarget: 4
        )
        var run = RunState()
        run.roundIndex = 30
        run.scoreTargetThisBoard = 999

        controller.configureForTesting(state: state, dictionary: dictionary, runState: run)
        controller.submitPath(indices: Array(0..<8))

        #expect(controller.moves == 4)
        #expect(controller.runState?.pendingMoveFraction == 0.25)
        #expect(controller.powerupToast == "+1 Move")
    }

    @Test func resolverAcceptsNineLetterWordsWithinExtendedLengthRange() {
        let dictionary = WordDictionary(words: ["notebooks"])
        let state = TestBuilders.makeState(
            tiles: [
                TestBuilders.makeTile("N"),
                TestBuilders.makeTile("O"),
                TestBuilders.makeTile("T"),
                TestBuilders.makeTile("E"),
                TestBuilders.makeTile("B"),
                TestBuilders.makeTile("O"),
                TestBuilders.makeTile("O"),
                TestBuilders.makeTile("K"),
                TestBuilders.makeTile("S")
            ],
            moves: 8,
            rows: 1,
            cols: 9
        )

        var bag = LetterBag()
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: Array(0..<9)),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(result.accepted)
        #expect(result.rejectionReason == nil)
        #expect(result.scoreDelta > 0)
    }

    @Test func finalExamTemplateIsDiamondWithStoneObstacles() {
        let template = BoardTemplate.template(for: 50)
        let center = 3 * template.cols + 3

        #expect(template.id == "challenge50_final_exam")
        #expect(template.isPlayable(center))
        #expect(!template.stones.isEmpty)
        #expect(template.playableCount < 49)
        #expect(template.specialRule == .minimumWordLength(6))
    }

    @Test func finalExamGenerationGuaranteesHigherVowelRatio() {
        let template = BoardTemplate.template(for: 50)
        let dictionary = WordDictionary(words: makeAlternatingPoolsDictionary())

        var bag = LetterBag()
        let state = Resolver.initialState(
            template: template,
            moves: RunState.moves(for: 50),
            dictionary: dictionary,
            bag: &bag,
            lockObjectiveTarget: RunState.locksGoal(for: 50, template: template)
        )

        let regionCounts = vowelCountsByRegion(in: state.tiles, template: template)
        #expect(regionCounts[0, default: 0] >= 12)
    }

    @Test func resolverRejectsFinalExamWordsShorterThanSixLetters() {
        let template = BoardTemplate.template(for: 50)
        let dictionary = WordDictionary(words: ["game", "planet"])
        let size = template.gridSize * template.gridSize
        var tiles = [Tile?](repeating: nil, count: size)
        tiles[9] = TestBuilders.makeTile("G")
        tiles[10] = TestBuilders.makeTile("A")
        tiles[11] = TestBuilders.makeTile("M")
        tiles[12] = TestBuilders.makeTile("E")

        let state = GameState(
            rows: template.rows,
            cols: template.cols,
            boardTemplate: template,
            tiles: tiles,
            score: 0,
            moves: 8,
            inkPoints: 0,
            usedTileIds: [],
            totalLocksBroken: 0,
            lockObjectiveTarget: 4
        )

        var bag = LetterBag()
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [9, 10, 11, 12]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(!result.accepted)
        #expect(result.rejectionReason == .minimumWordLength)
    }

    @MainActor
    @Test func finalExamControllerShowsClearMessageForShortWords() {
        let controller = GameSessionController(milestoneTracker: MilestoneTrackerTestHelper.makeIsolated())
        let dictionary = WordDictionary(words: ["planet"])
        let template = BoardTemplate.template(for: 50)
        let size = template.gridSize * template.gridSize
        var tiles = [Tile?](repeating: nil, count: size)
        tiles[9] = TestBuilders.makeTile("G")
        tiles[10] = TestBuilders.makeTile("A")
        tiles[11] = TestBuilders.makeTile("M")
        tiles[12] = TestBuilders.makeTile("E")

        let state = GameState(
            rows: template.rows,
            cols: template.cols,
            boardTemplate: template,
            tiles: tiles,
            score: 0,
            moves: 8,
            inkPoints: 0,
            usedTileIds: [],
            totalLocksBroken: 0,
            lockObjectiveTarget: 4
        )
        var run = RunState()
        run.roundIndex = 50
        run.scoreTargetThisBoard = 999
        controller.configureForTesting(state: state, dictionary: dictionary, runState: run)

        controller.submitPath(indices: [9, 10, 11, 12])

        #expect(controller.lastSubmitOutcome == .invalid)
        #expect(controller.powerupToast == "Use 6+ letters")
        #expect(controller.moves == 8)
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

enum PlayerProfileTestHelper {
    @MainActor
    static func makeIsolated() -> PlayerProfile {
        let testKey = "wordfall.playerProfile.test.\(UUID().uuidString)"
        UserDefaults.standard.removeObject(forKey: testKey)
        return PlayerProfile(defaultsKey: testKey)
    }
}

private func makeRoundDebugMetrics(
    outcome: GameSessionController.RoundDebugOutcome,
    round: Int,
    submits: Int,
    locksBroken: Int,
    avgPointsPerWord: Double,
    score: Int,
    longWords: Int
) -> GameSessionController.RoundDebugMetrics {
    GameSessionController.RoundDebugMetrics(
        outcome: outcome,
        roundIndex: round,
        act: RunState.act(for: round),
        isChallengeRound: RunState.isChallengeRound(for: round),
        movesStart: RunState.moves(for: round),
        movesEnd: max(0, RunState.moves(for: round) - submits),
        scoreTarget: RunState.scoreGoal(for: round),
        scoreThisRound: score,
        locksAvailable: RunState.locksGoal(for: round),
        locksBrokenThisRound: locksBroken,
        numberOfSubmits: submits,
        avgWordLength: longWords > 0 ? 7.0 : 5.0,
        avgPointsPerWord: avgPointsPerWord,
        bestWord: longWords > 0 ? "LANTERN" : "STONE",
        bestWordPoints: Int(avgPointsPerWord.rounded()),
        longWordCount: longWords,
        lockedSubmitCount: min(submits, locksBroken),
        netMoveRefunds: longWords,
        shufflesUsed: 0,
        hintsUsed: 0,
        invalidSubmitCount: 0
    )
}

private func vowelCountsByRegion(in tiles: [Tile?], template: BoardTemplate) -> [Int: Int] {
    var counts: [Int: Int] = [:]
    for (index, regionID) in template.regions {
        guard let tile = tiles[index], tile.isLetterTile else { continue }
        if LetterBag.vowelSet.contains(tile.letter) {
            counts[regionID, default: 0] += 1
        }
    }
    return counts
}

private func makeAlternatingPoolsDictionary() -> Set<String> {
    [
        "alert", "alter", "later", "ratel", "artel",
        "stare", "tears", "rates", "aster", "tares",
        "stone", "tones", "notes", "onset", "seton",
        "learn", "renal", "snore", "tenor", "stole",
        "planet", "pleats", "plates", "staple", "petals"
    ]
}

private func alternatingPoolsState(
    template: BoardTemplate,
    leftWord: String,
    rightWord: String,
    moves: Int,
    score: Int = 0
) -> GameState {
    let size = template.gridSize * template.gridSize
    var tiles = [Tile?](repeating: nil, count: size)
    let leftIndices = [0, 1, 2, 8]
    let rightIndices = [4, 5, 6, 11]

    for (offset, letter) in Array(leftWord).enumerated() where offset < leftIndices.count {
        tiles[leftIndices[offset]] = TestBuilders.makeTile(letter)
    }
    for (offset, letter) in Array(rightWord).enumerated() where offset < rightIndices.count {
        tiles[rightIndices[offset]] = TestBuilders.makeTile(letter)
    }

    return GameState(
        rows: template.rows,
        cols: template.cols,
        boardTemplate: template,
        tiles: tiles,
        score: score,
        moves: moves,
        inkPoints: 0,
        usedTileIds: [],
        totalLocksBroken: 0,
        lockObjectiveTarget: 4
    )
}
