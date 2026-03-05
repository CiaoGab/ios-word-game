import Foundation

/// Tracks the state of a single 15-board roguelike run.
struct RunState {

    // MARK: - Tunables

    enum Tunables {
        // Board count
        static let totalBoards: Int = 15
        static let shufflesPerBoard: Int = 5

        // Moves scaling: base - (board-1)/3; boss boards get a bonus
        static let movesBase: Int = 22
        static let movesFloor: Int = 14
        static let movesBossBonus: Int = 3

        // Locks goal: locksBase + board + (board-1)/3; boss boards ×1.5
        static let locksBase: Int = 4
        static let bossLockMult: Double = 1.5

        // Score goal: scoreBase + (board-1)*scorePerBoard; boss boards ×1.5
        static let scoreBase: Int = 80
        static let scorePerBoard: Int = 40
        static let bossScoreMult: Double = 1.5

        // Built-in move refunds (always active, no perk required)
        static let fiveLetterRefund: Double = 0.5
        static let sixLetterRefund: Double = 1.0
        static let lockBreakRefund: Double = 0.25

    }

    // MARK: - Run-wide fields

    /// Current board number, 1-indexed (1…15).
    var boardIndex: Int = 1

    /// Modifiers selected so far in this run.
    /// Duplicates are blocked by default and only allowed after Echo Chamber.
    var activePerks: [PerkID] = []

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

    /// Fractional move buffer for built-in refunds (e.g. 0.5 accumulates across 5-letter words).
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

    /// Dynamic objectives after applying onBoardStart/onBossBoard modifiers.
    var lockTargetThisBoard: Int = 0
    var scoreTargetThisBoard: Int = 0

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

    var isBossBoard: Bool { boardIndex % 5 == 0 }
    var boardTemplate: BoardTemplate { BoardTemplate.template(for: boardIndex) }
    var movesForBoard: Int { RunState.moves(for: boardIndex) }
    var locksGoalForBoard: Int {
        if lockTargetThisBoard > 0 { return lockTargetThisBoard }
        return RunState.locksGoal(for: boardIndex, template: boardTemplate)
    }
    var scoreGoalForBoard: Int {
        if scoreTargetThisBoard > 0 { return scoreTargetThisBoard }
        return RunState.scoreGoal(for: boardIndex, template: boardTemplate)
    }

    // MARK: - Board scaling formulas

    /// Moves budget for a given board.
    /// Base decreases by 1 every 3 boards (floor: 14). Boss boards get +3 bonus.
    static func moves(for board: Int) -> Int {
        let base = max(Tunables.movesFloor, Tunables.movesBase - (board - 1) / 3)
        return base + (board % 5 == 0 ? Tunables.movesBossBonus : 0)
    }

    /// Lock goal for a given board.
    /// Formula:
    ///   1) baseLocks = locksBase + board + (board-1)/3
    ///   2) scaled = ceil(baseLocks * playableMultiplier * 0.9)
    ///   3) boss boards apply ×bossLockMult after scaling
    static func locksGoal(for board: Int, template: BoardTemplate? = nil) -> Int {
        let base = Tunables.locksBase + board + (board - 1) / 3
        let chosenTemplate = template ?? BoardTemplate.template(for: board)
        let playableMultiplier = Double(chosenTemplate.playableCount) / 49.0
        let scaled = max(1, Int(ceil(Double(base) * playableMultiplier * 0.9)))
        if board % 5 == 0 {
            return max(1, Int(ceil(Double(scaled) * Tunables.bossLockMult)))
        }
        return scaled
    }

    /// Score goal for a given board.
    /// Formula:
    ///   1) baseScore = scoreBase + (board-1)*scorePerBoard
    ///   2) scaled = round(baseScore * playableMultiplier)
    ///   3) boss boards apply ×bossScoreMult after scaling
    static func scoreGoal(for board: Int, template: BoardTemplate? = nil) -> Int {
        let base = Tunables.scoreBase + (board - 1) * Tunables.scorePerBoard
        let chosenTemplate = template ?? BoardTemplate.template(for: board)
        let playableMultiplier = Double(chosenTemplate.playableCount) / 49.0
        let scaled = max(1, Int((Double(base) * playableMultiplier).rounded()))
        if board % 5 == 0 {
            return max(1, Int(ceil(Double(scaled) * Tunables.bossScoreMult)))
        }
        return scaled
    }

    // MARK: - Helpers

    mutating func resetBoardCounters() {
        locksBrokenThisBoard = 0
        scoreThisBoard = 0
        shufflesRemaining = Tunables.shufflesPerBoard
        pendingMoveFraction = 0.0
        freshSparkCount = 0
        freeHintChargesRemaining = 0
        freeUndoChargesRemaining = 0
        modifierPendingMoveFraction = 0.0
        lockTargetThisBoard = 0
        scoreTargetThisBoard = 0
        lengthRefundMultiplierThisBoard = 1.0
        lockBreakRefundMultiplierThisBoard = 1.0
        guaranteedBonusRewardsThisBoard = 0
        extraRewardRollChanceThisBoard = 0.0
        rewardHintWeightDeltaThisBoard = 0
        rewardWildcardWeightDeltaThisBoard = 0
        rewardUndoWeightDeltaThisBoard = 0
    }
}
