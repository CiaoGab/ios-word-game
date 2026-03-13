import Foundation

enum RoundBucketType: String, Equatable {
    case normal
    case milestone
}

enum BoardFamily: String, Equatable {
    case standard6x6
    case lightStones6x6
    case denseStones6x6
    case diamond6x6
    case hourglass6x6
    case splitLanes6x6
}

struct BoardGenerationProfile: Equatable {
    let attemptBudget: Int
    let minimumMediumWords: Int
    let maxConsonantDuplicates: Int
    let maxRareLetters: Int

    static let fallback = BoardGenerationProfile(
        attemptBudget: 8,
        minimumMediumWords: 3,
        maxConsonantDuplicates: 4,
        maxRareLetters: 2
    )
}

struct RoundObjectiveProgress: Equatable {
    var submissionsUsed: Int = 0
    var totalWordsMade: Int = 0
    var qualifyingWordCount: Int = 0
    var rareLettersUsed: Int = 0
    var bestWordPoints: Int = 0
    var distinctStartingLetters: Set<Character> = []
}

struct RoundObjectiveDefinition: Equatable {
    enum Kind: Equatable {
        case totalWords(target: Int)
        case wordsWithMinimumLength(count: Int, minimumLength: Int)
        case vowelHeavyWords(count: Int, minimumVowels: Int)
        case rareLettersUsed(target: Int)
        case maxSubmissions(limit: Int)
        case wordsWorthAtLeast(count: Int, minimumPoints: Int)
        case uniqueLetterWords(count: Int)
        case distinctStartingLetters(count: Int)
    }

    let kind: Kind

    var isRequiredForRoundClear: Bool {
        switch kind {
        case .maxSubmissions:
            return true
        default:
            return false
        }
    }

    var presentationLabel: String {
        isRequiredForRoundClear ? "OBJECTIVE" : "BONUS"
    }

    var shortDescription: String {
        switch kind {
        case .totalWords(let target):
            return "Make \(target) words"
        case .wordsWithMinimumLength(let count, let minimumLength):
            return "Make \(count) \(minimumLength)+ letter \(count == 1 ? "word" : "words")"
        case .vowelHeavyWords(let count, _):
            return "Make \(count) vowel-heavy \(count == 1 ? "word" : "words")"
        case .rareLettersUsed(let target):
            return "Use at least \(target) rare \(target == 1 ? "letter" : "letters")"
        case .maxSubmissions(let limit):
            return "Hit target in \(limit) submissions"
        case .wordsWorthAtLeast(let count, let minimumPoints):
            return "Make \(count) \(minimumPoints)+ point \(count == 1 ? "word" : "words")"
        case .uniqueLetterWords(let count):
            return "Make \(count) no-repeat \(count == 1 ? "word" : "words")"
        case .distinctStartingLetters(let count):
            return "Make \(count) words with different starts"
        }
    }

    func progressText(using progress: RoundObjectiveProgress) -> String {
        switch kind {
        case .totalWords(let target):
            return "Words: \(progress.totalWordsMade)/\(target)"
        case .wordsWithMinimumLength(let count, let minimumLength):
            return "\(minimumLength)+ letters: \(progress.qualifyingWordCount)/\(count)"
        case .vowelHeavyWords(let count, _):
            return "Vowel-heavy: \(progress.qualifyingWordCount)/\(count)"
        case .rareLettersUsed(let target):
            return "Rare letters: \(progress.rareLettersUsed)/\(target)"
        case .maxSubmissions(let limit):
            return "Submits: \(progress.submissionsUsed)/\(limit)"
        case .wordsWorthAtLeast(let count, let minimumPoints):
            return "\(minimumPoints)+ pts: \(progress.qualifyingWordCount)/\(count)"
        case .uniqueLetterWords(let count):
            return "No-repeat words: \(progress.qualifyingWordCount)/\(count)"
        case .distinctStartingLetters(let count):
            return "Distinct starts: \(progress.distinctStartingLetters.count)/\(count)"
        }
    }

    func isSatisfied(by progress: RoundObjectiveProgress) -> Bool {
        switch kind {
        case .totalWords(let target):
            return progress.totalWordsMade >= target
        case .wordsWithMinimumLength(let count, _):
            return progress.qualifyingWordCount >= count
        case .vowelHeavyWords(let count, _):
            return progress.qualifyingWordCount >= count
        case .rareLettersUsed(let target):
            return progress.rareLettersUsed >= target
        case .maxSubmissions(let limit):
            return progress.submissionsUsed <= limit
        case .wordsWorthAtLeast(let count, _):
            return progress.qualifyingWordCount >= count
        case .uniqueLetterWords(let count):
            return progress.qualifyingWordCount >= count
        case .distinctStartingLetters(let count):
            return progress.distinctStartingLetters.count >= count
        }
    }

    func hasHardFailed(by progress: RoundObjectiveProgress, scoreReached: Bool) -> Bool {
        switch kind {
        case .maxSubmissions(let limit):
            return progress.submissionsUsed >= limit && !scoreReached
        default:
            return false
        }
    }
}

struct BucketConfig: Equatable {
    let bucketIndex: Int
    let roundRange: ClosedRange<Int>
    let normalMoves: Int
    let milestoneMoves: Int
    let scoreMultiplier: Double
    let milestoneScoreMultiplier: Double
    let rareSpawnMultiplier: Double
    let generationProfile: BoardGenerationProfile
    let normalBoardCycle: [BoardFamily]
    let normalObjectives: [RoundObjectiveDefinition]
    let objectiveLocalRounds: Set<Int>
    let milestoneKind: ChallengeRoundKind
    let milestoneObjective: RoundObjectiveDefinition?
    let milestoneLockBonus: Int
}

struct RoundProgressionPlan: Equatable {
    let roundIndex: Int
    let bucketIndex: Int
    let bucketLocalRound: Int
    let bucketConfig: BucketConfig
    let roundType: RoundBucketType
    let boardFamily: BoardFamily?
    let challengeKind: ChallengeRoundKind?
    let objective: RoundObjectiveDefinition?

    var isMilestoneRound: Bool {
        roundType == .milestone
    }

    var moves: Int {
        isMilestoneRound ? bucketConfig.milestoneMoves : bucketConfig.normalMoves
    }

    var scoreMultiplier: Double {
        let base = bucketConfig.scoreMultiplier
        return isMilestoneRound ? base * bucketConfig.milestoneScoreMultiplier : base
    }
}

/// Tracks the state of a single 50-round roguelike run.
struct RunState {

    struct ScoreTargetCurveEntry: Codable, Equatable {
        let roundIndex: Int
        let act: Int
        let bucketLocalRound: Int
        let isChallengeRound: Bool
        let moves: Int
        let lockTarget: Int
        let baseScoreTarget: Int
        let finalScoreTarget: Int
    }

    // MARK: - Tunables

    enum Tunables {
        // Round count
        static let totalRounds: Int = 50
        static let totalBoards: Int = totalRounds
        static let shufflesPerBoard: Int = 5
        static let roundsPerBucket: Int = 10
        static let totalBuckets: Int = 5

        static let scoreBase: Int = 120
        static let scorePerRound: Int = 55
        static let scoreRampFactor: Int = 8
        static let scoreRampDivisor: Int = 10

        // Built-in move refunds (always active, no perk required)
        static let longWordBaseRefund: Double = 1.0
        static let sevenToEightBonusRefund: Double = 0.25
        static let nineToTenBonusRefund: Double = 0.50
        static let elevenToTwelveBonusRefund: Double = 0.75

    }

    // MARK: - Run-wide fields

    /// Current round number, 1-indexed (1...50).
    var roundIndex: Int = 1

    /// Modifiers selected so far in this run.
    /// Duplicates are blocked by default and only allowed after Echo Chamber.
    var activePerks: [PerkID] = []

    /// Pre-run equipped starter perks selected from the profile loadout.
    var equippedStarterPerks: [StarterPerkID] = []

    /// Powerup inventory (hints, wildcards, undos). Shuffles are tracked separately.
    var inventory: Inventory = Inventory()

    /// How many times each word (uppercased) has been submitted this run.
    /// Used for the repeat-word score penalty. NOT reset per board.
    var wordUseCounts: [String: Int] = [:]

    // MARK: - Per-board counters (reset by resetBoardCounters each board)

    /// Lock-break progress toward this board's lock goal.
    var locksBrokenThisBoard: Int = 0

    /// Score earned on this board toward this board's score goal.
    var scoreThisBoard: Int = 0

    /// Shuffles remaining for this board.
    var shufflesRemaining: Int = Tunables.shufflesPerBoard

    /// Fractional move buffer for built-in long-word refunds.
    var pendingMoveFraction: Double = 0.0

    // MARK: - Per-board modifier state (reset each board)

    /// Number of times freshSpark has triggered this board. Cap: 3.
    var freshSparkCount: Int = 0

    /// Free hint charges granted by modifiers for this board.
    var freeHintChargesRemaining: Int = 0

    /// Free undo charges granted by modifiers for this board.
    var freeUndoChargesRemaining: Int = 0

    /// Fractional move buffer from modifier-specific move refunds.
    var modifierPendingMoveFraction: Double = 0.0

    /// Last region used by region-based challenge rules on this board.
    var lastChallengeRegionIDThisBoard: Int? = nil

    /// Round-scoped starter perk / milestone passive flags.
    var pencilGripRefundUsedThisBoard: Bool = false
    var spareSealDiscountUsedThisBoard: Bool = false
    var milestoneLockDiscountUsedThisBoard: Bool = false

    /// Dynamic objectives after applying onBoardStart/onBossBoard modifiers.
    var lockTargetThisBoard: Int = 0
    var scoreTargetThisBoard: Int = 0
    var roundObjectiveThisBoard: RoundObjectiveDefinition? = nil
    var roundObjectiveProgressThisBoard: RoundObjectiveProgress = RoundObjectiveProgress()

    /// Dynamic refund multipliers set on board start.
    var lengthRefundMultiplierThisBoard: Double = 1.0
    var lockBreakRefundMultiplierThisBoard: Double = 1.0

    /// Dynamic reward adjustments set on board start.
    var guaranteedBonusRewardsThisBoard: Int = 0
    var extraRewardRollChanceThisBoard: Double = 0.0
    var rewardHintWeightDeltaThisBoard: Int = 0
    var rewardWildcardWeightDeltaThisBoard: Int = 0
    var rewardUndoWeightDeltaThisBoard: Int = 0

    // MARK: - Derived

    var boardIndex: Int {
        get { roundIndex }
        set { roundIndex = newValue }
    }

    var act: Int { RunState.act(for: roundIndex) }
    var bucket: Int { RunState.bucket(for: roundIndex) }
    var bucketLocalRound: Int { RunState.bucketLocalRound(for: roundIndex) }
    var isChallengeRound: Bool { RunState.isChallengeRound(for: roundIndex) }
    var isBossBoard: Bool { isChallengeRound }
    var challengeRound: ChallengeRoundDefinition? { RunState.challengeRound(for: roundIndex) }
    var boardTemplate: BoardTemplate { BoardTemplate.template(for: roundIndex) }
    var movesForRound: Int { RunState.moves(for: roundIndex) }
    var movesForBoard: Int { movesForRound }
    var locksGoalForBoard: Int {
        if lockTargetThisBoard > 0 { return lockTargetThisBoard }
        return RunState.locksGoal(for: roundIndex, template: boardTemplate)
    }
    var scoreGoalForBoard: Int {
        if scoreTargetThisBoard > 0 { return scoreTargetThisBoard }
        return RunState.scoreGoal(for: roundIndex, template: boardTemplate)
    }

    // MARK: - Board scaling formulas

    static func act(for round: Int) -> Int {
        bucket(for: round)
    }

    static func bucket(for round: Int) -> Int {
        let clamped = max(1, min(Tunables.totalRounds, round))
        return ((clamped - 1) / Tunables.roundsPerBucket) + 1
    }

    static func bucketLocalRound(for round: Int) -> Int {
        let clamped = max(1, min(Tunables.totalRounds, round))
        return ((clamped - 1) % Tunables.roundsPerBucket) + 1
    }

    static func isMilestoneRound(for round: Int) -> Bool {
        bucketLocalRound(for: round) == Tunables.roundsPerBucket
    }

    static func progression(for round: Int) -> RoundProgressionPlan {
        let clamped = max(1, min(Tunables.totalRounds, round))
        let bucketIndex = bucket(for: clamped)
        let localRound = bucketLocalRound(for: clamped)
        let config = bucketConfigs[bucketIndex - 1]
        let isMilestone = localRound == Tunables.roundsPerBucket

        let objective: RoundObjectiveDefinition?
        if isMilestone {
            objective = config.milestoneObjective
        } else if config.objectiveLocalRounds.contains(localRound),
                  !config.normalObjectives.isEmpty,
                  let slot = config.objectiveLocalRounds.sorted().firstIndex(of: localRound) {
            objective = config.normalObjectives[slot % config.normalObjectives.count]
        } else {
            objective = nil
        }

        return RoundProgressionPlan(
            roundIndex: clamped,
            bucketIndex: bucketIndex,
            bucketLocalRound: localRound,
            bucketConfig: config,
            roundType: isMilestone ? .milestone : .normal,
            boardFamily: isMilestone ? nil : config.normalBoardCycle[(localRound - 1) % config.normalBoardCycle.count],
            challengeKind: isMilestone ? config.milestoneKind : nil,
            objective: objective
        )
    }

    static func boardFamily(for round: Int) -> BoardFamily? {
        progression(for: round).boardFamily
    }

    static func objective(for round: Int) -> RoundObjectiveDefinition? {
        progression(for: round).objective
    }

    static func generationProfile(for round: Int) -> BoardGenerationProfile {
        progression(for: round).bucketConfig.generationProfile
    }

    static func rareSpawnMultiplier(for round: Int) -> Double {
        progression(for: round).bucketConfig.rareSpawnMultiplier
    }

    static func isChallengeRound(for round: Int) -> Bool {
        isMilestoneRound(for: round)
    }

    static func challengeRound(for round: Int) -> ChallengeRoundDefinition? {
        let clamped = max(1, min(Tunables.totalRounds, round))
        return ChallengeRoundResolver.resolve(roundIndex: clamped)
    }

    static func moves(for board: Int) -> Int {
        progression(for: board).moves
    }

    static func locksGoal(for board: Int, template: BoardTemplate? = nil) -> Int {
        _ = template
        let plan = progression(for: board)
        let localRound = plan.bucketLocalRound
        let base = max(0, plan.bucketIndex - 1 + (localRound >= 6 ? 1 : 0))
        let challengeBonus = plan.isMilestoneRound ? plan.bucketConfig.milestoneLockBonus : 0
        return max(0, base + challengeBonus)
    }

    static func baseScoreTarget(for board: Int) -> Int {
        let round = max(1, min(Tunables.totalRounds, board))
        let offset = round - 1
        return Tunables.scoreBase
            + (Tunables.scorePerRound * offset)
            + (Tunables.scoreRampFactor * ((offset * offset) / Tunables.scoreRampDivisor))
    }

    static func adjustedBaseScoreTarget(for board: Int) -> Int {
        let plan = progression(for: board)
        let base = baseScoreTarget(for: board)
        return max(1, Int((Double(base) * plan.bucketConfig.scoreMultiplier).rounded(.toNearestOrAwayFromZero)))
    }

    static func scoreGoal(for board: Int, template: BoardTemplate? = nil) -> Int {
        _ = template
        let plan = progression(for: board)
        let base = adjustedBaseScoreTarget(for: board)
        guard plan.isMilestoneRound else { return roundToNearestFive(Double(base)) }
        return max(1, roundToNearestFive(Double(base) * plan.bucketConfig.milestoneScoreMultiplier))
    }

    static func scoreTargetCurve() -> [ScoreTargetCurveEntry] {
        (1...Tunables.totalRounds).map { round in
            let template = BoardTemplate.template(for: round)
            let plan = progression(for: round)
            return ScoreTargetCurveEntry(
                roundIndex: round,
                act: plan.bucketIndex,
                bucketLocalRound: plan.bucketLocalRound,
                isChallengeRound: isChallengeRound(for: round),
                moves: moves(for: round),
                lockTarget: locksGoal(for: round, template: template),
                baseScoreTarget: adjustedBaseScoreTarget(for: round),
                finalScoreTarget: scoreGoal(for: round, template: template)
            )
        }
    }

    // MARK: - Helpers

    private static func roundToNearestFive(_ value: Double) -> Int {
        Int((value / 5.0).rounded(.toNearestOrAwayFromZero)) * 5
    }

    mutating func resetBoardCounters() {
        locksBrokenThisBoard = 0
        scoreThisBoard = 0
        shufflesRemaining = Tunables.shufflesPerBoard
        pendingMoveFraction = 0.0
        freshSparkCount = 0
        freeHintChargesRemaining = 0
        freeUndoChargesRemaining = 0
        modifierPendingMoveFraction = 0.0
        lastChallengeRegionIDThisBoard = nil
        pencilGripRefundUsedThisBoard = false
        spareSealDiscountUsedThisBoard = false
        milestoneLockDiscountUsedThisBoard = false
        lockTargetThisBoard = 0
        scoreTargetThisBoard = 0
        roundObjectiveThisBoard = nil
        roundObjectiveProgressThisBoard = RoundObjectiveProgress()
        lengthRefundMultiplierThisBoard = 1.0
        lockBreakRefundMultiplierThisBoard = 1.0
        guaranteedBonusRewardsThisBoard = 0
        extraRewardRollChanceThisBoard = 0.0
        rewardHintWeightDeltaThisBoard = 0
        rewardWildcardWeightDeltaThisBoard = 0
        rewardUndoWeightDeltaThisBoard = 0
    }

    private static let bucketConfigs: [BucketConfig] = [
        BucketConfig(
            bucketIndex: 1,
            roundRange: 1...10,
            normalMoves: 19,
            milestoneMoves: 19,
            scoreMultiplier: 0.86,
            milestoneScoreMultiplier: 1.08,
            rareSpawnMultiplier: 0.35,
            generationProfile: BoardGenerationProfile(
                attemptBudget: 20,
                minimumMediumWords: 5,
                maxConsonantDuplicates: 4,
                maxRareLetters: 1
            ),
            normalBoardCycle: [.standard6x6, .standard6x6, .lightStones6x6, .standard6x6, .diamond6x6],
            normalObjectives: [
                RoundObjectiveDefinition(kind: .totalWords(target: 4)),
                RoundObjectiveDefinition(kind: .wordsWithMinimumLength(count: 1, minimumLength: 5)),
                RoundObjectiveDefinition(kind: .vowelHeavyWords(count: 1, minimumVowels: 3))
            ],
            objectiveLocalRounds: Set([4, 7, 9]),
            milestoneKind: .triplePoolBoard,
            milestoneObjective: RoundObjectiveDefinition(kind: .wordsWithMinimumLength(count: 1, minimumLength: 5)),
            milestoneLockBonus: 1
        ),
        BucketConfig(
            bucketIndex: 2,
            roundRange: 11...20,
            normalMoves: 18,
            milestoneMoves: 18,
            scoreMultiplier: 0.89,
            milestoneScoreMultiplier: 1.10,
            rareSpawnMultiplier: 0.55,
            generationProfile: BoardGenerationProfile(
                attemptBudget: 16,
                minimumMediumWords: 4,
                maxConsonantDuplicates: 4,
                maxRareLetters: 2
            ),
            normalBoardCycle: [.standard6x6, .standard6x6, .lightStones6x6, .diamond6x6, .splitLanes6x6, .standard6x6],
            normalObjectives: [
                RoundObjectiveDefinition(kind: .wordsWithMinimumLength(count: 2, minimumLength: 6)),
                RoundObjectiveDefinition(kind: .maxSubmissions(limit: 7)),
                RoundObjectiveDefinition(kind: .totalWords(target: 5)),
                RoundObjectiveDefinition(kind: .rareLettersUsed(target: 1))
            ],
            objectiveLocalRounds: Set([3, 5, 7, 9]),
            milestoneKind: .pyramidBoard,
            milestoneObjective: RoundObjectiveDefinition(kind: .maxSubmissions(limit: 7)),
            milestoneLockBonus: 1
        ),
        BucketConfig(
            bucketIndex: 3,
            roundRange: 21...30,
            normalMoves: 17,
            milestoneMoves: 17,
            scoreMultiplier: 0.93,
            milestoneScoreMultiplier: 1.12,
            rareSpawnMultiplier: 0.75,
            generationProfile: BoardGenerationProfile(
                attemptBudget: 12,
                minimumMediumWords: 3,
                maxConsonantDuplicates: 4,
                maxRareLetters: 2
            ),
            normalBoardCycle: [.standard6x6, .lightStones6x6, .diamond6x6, .hourglass6x6, .splitLanes6x6],
            normalObjectives: [
                RoundObjectiveDefinition(kind: .wordsWithMinimumLength(count: 2, minimumLength: 7)),
                RoundObjectiveDefinition(kind: .wordsWorthAtLeast(count: 1, minimumPoints: 20)),
                RoundObjectiveDefinition(kind: .rareLettersUsed(target: 2)),
                RoundObjectiveDefinition(kind: .maxSubmissions(limit: 6))
            ],
            objectiveLocalRounds: Set([2, 4, 6, 8]),
            milestoneKind: .taxRound,
            milestoneObjective: RoundObjectiveDefinition(kind: .wordsWorthAtLeast(count: 1, minimumPoints: 20)),
            milestoneLockBonus: 1
        ),
        BucketConfig(
            bucketIndex: 4,
            roundRange: 31...40,
            normalMoves: 16,
            milestoneMoves: 16,
            scoreMultiplier: 0.98,
            milestoneScoreMultiplier: 1.15,
            rareSpawnMultiplier: 0.95,
            generationProfile: BoardGenerationProfile(
                attemptBudget: 10,
                minimumMediumWords: 3,
                maxConsonantDuplicates: 5,
                maxRareLetters: 3
            ),
            normalBoardCycle: [.denseStones6x6, .diamond6x6, .hourglass6x6, .splitLanes6x6, .standard6x6],
            normalObjectives: [
                RoundObjectiveDefinition(kind: .wordsWithMinimumLength(count: 2, minimumLength: 7)),
                RoundObjectiveDefinition(kind: .maxSubmissions(limit: 5)),
                RoundObjectiveDefinition(kind: .wordsWorthAtLeast(count: 3, minimumPoints: 15)),
                RoundObjectiveDefinition(kind: .uniqueLetterWords(count: 3)),
                RoundObjectiveDefinition(kind: .distinctStartingLetters(count: 3))
            ],
            objectiveLocalRounds: Set([2, 4, 5, 7, 9]),
            milestoneKind: .alternatingPools,
            milestoneObjective: RoundObjectiveDefinition(kind: .wordsWithMinimumLength(count: 2, minimumLength: 6)),
            milestoneLockBonus: 1
        ),
        BucketConfig(
            bucketIndex: 5,
            roundRange: 41...50,
            normalMoves: 15,
            milestoneMoves: 15,
            scoreMultiplier: 1.02,
            milestoneScoreMultiplier: 1.18,
            rareSpawnMultiplier: 1.10,
            generationProfile: BoardGenerationProfile(
                attemptBudget: 14,
                minimumMediumWords: 3,
                maxConsonantDuplicates: 5,
                maxRareLetters: 3
            ),
            normalBoardCycle: [.denseStones6x6, .splitLanes6x6, .diamond6x6, .hourglass6x6, .standard6x6],
            normalObjectives: [
                RoundObjectiveDefinition(kind: .wordsWithMinimumLength(count: 2, minimumLength: 7)),
                RoundObjectiveDefinition(kind: .wordsWorthAtLeast(count: 1, minimumPoints: 25)),
                RoundObjectiveDefinition(kind: .maxSubmissions(limit: 6)),
                RoundObjectiveDefinition(kind: .rareLettersUsed(target: 2)),
                RoundObjectiveDefinition(kind: .distinctStartingLetters(count: 3))
            ],
            objectiveLocalRounds: Set([2, 4, 5, 7, 8, 9]),
            milestoneKind: .finalExam,
            milestoneObjective: nil,
            milestoneLockBonus: 1
        )
    ]
}
