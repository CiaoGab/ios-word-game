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

    /// Perks the player has selected, accumulated across previous boards.
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

    /// Shuffles remaining for this board (starts at Tunables.shufflesPerBoard).
    var shufflesRemaining: Int = Tunables.shufflesPerBoard

    /// Fractional move buffer for built-in refunds (e.g. 0.5 accumulates across 5-letter words).
    var pendingMoveFraction: Double = 0.0

    // MARK: - Per-board perk counters (reset by resetBoardCounters each board)

    /// Moves granted so far by the lockRefund perk this board. Cap: 2.
    var lockRefundMovesGranted: Int = 0

    /// Real (unmodified) locks broken this board, used for the lockRefund threshold.
    var lockRefundRealLocks: Int = 0

    /// Number of times freshSpark has triggered this board. Cap: 3.
    var freshSparkCount: Int = 0

    /// Whether the freeHint allowance was consumed this board.
    var freeHintUsed: Bool = false

    /// Whether the freeUndo allowance was consumed this board.
    var freeUndoUsed: Bool = false

    // MARK: - Derived

    var isBossBoard: Bool { boardIndex % 5 == 0 }
    var boardTemplate: BoardTemplate { BoardTemplate.template(for: boardIndex) }
    var movesForBoard: Int { RunState.moves(for: boardIndex) }
    var locksGoalForBoard: Int { RunState.locksGoal(for: boardIndex, template: boardTemplate) }
    var scoreGoalForBoard: Int { RunState.scoreGoal(for: boardIndex, template: boardTemplate) }

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
        lockRefundMovesGranted = 0
        lockRefundRealLocks = 0
        freshSparkCount = 0
        freeHintUsed = false
        freeUndoUsed = false
    }
}
