import Foundation
import SpriteKit
import Combine

@MainActor
final class GameSessionController: ObservableObject {

    enum SubmitOutcome: Equatable {
        case idle
        case valid
        case invalid
    }

    // MARK: - HUD state

    @Published var score: Int = 0
    @Published var moves: Int = 0
    @Published var shufflesRemaining: Int = 0
    @Published var boardScore: Int = 0
    @Published var boardScoreTarget: Int = 0
    @Published var boardLockTarget: Int = 0
    @Published var objectivesText: String = "Break Locks: 0/0"

    // MARK: - Debug state

    @Published var lastSubmittedWord: String = ""
    @Published var status: String = "idle"
    @Published var locksBrokenThisMove: Int = 0
    @Published var locksBrokenTotal: Int = 0
    @Published var currentLockedCount: Int = 0
    @Published var usedTileIdsCount: Int = 0
    @Published var isAnimating: Bool = false
    @Published var activePathLength: Int = 0
    @Published var currentSelectionIndices: [Int] = []
    @Published var currentSelectionLetters: [Character] = []
    @Published var currentSelectionMeta: [SelectionTileMeta] = []
    @Published var currentSelectionWord: String = ""
    @Published var currentWordText: String = ""
    @Published var isPaused: Bool = false
    @Published var lastSubmitOutcome: SubmitOutcome = .idle
    @Published var lastSubmitPoints: Int = 0
    /// Changes for each submit feedback event so UI can animate repeated same-outcome events.
    @Published var submitFeedbackEventID: UUID = UUID()
    @Published var hintPath: [Int]? = nil
    @Published var hintWord: String? = nil
    @Published var hintIsValid: Bool = false

    // MARK: - Run system state

    @Published var runState: RunState? = nil
    @Published var showPerkDraft: Bool = false
    @Published var perkDraftOptions: [Perk] = []
    @Published var showRunSummary: Bool = false
    @Published var runSummaryBoard: Int = 0
    @Published var runSummaryWon: Bool = false
    /// True while the round clear stamp is visible before the perk draft appears.
    @Published var showRoundClearStamp: Bool = false

    // MARK: - Powerup state

    /// True while waiting for the player to tap a tile to receive a wildcard.
    @Published var isPlacingWildcard: Bool = false
    /// Non-nil while a toast "+1 Hint" etc. is visible.
    @Published var powerupToast: String? = nil
    /// True when at least one undo snapshot is available.
    @Published var canUndo: Bool = false

    // MARK: - Milestone tracker (persisted across sessions)

    let milestoneTracker: MilestoneTracker

    // MARK: - Core engine

    let scene: BoardScene

    private let dictionary: WordDictionary
    private var bag: LetterBag
    private var state: GameState
    private var idleTimer: Timer? = nil
    private var hintTask: Task<Void, Never>? = nil
    private let idleDelay: TimeInterval = 6.0

    // MARK: - Undo

    private struct UndoSnapshot {
        let gameState: GameState
        let inventory: Inventory
        let locksBrokenThisBoard: Int
        let scoreThisBoard: Int
        let wordUseCounts: [String: Int]
        let pendingMoveFraction: Double
        let lockRefundMovesGranted: Int
        let lockRefundRealLocks: Int
        let freshSparkCount: Int
        let freeHintUsed: Bool
        let freeUndoUsed: Bool
    }

    private var undoSnapshot: UndoSnapshot? = nil {
        didSet { canUndo = undoSnapshot != nil }
    }

    // MARK: - Toast

    private var toastTask: Task<Void, Never>? = nil
    private var roundClearTask: Task<Void, Never>? = nil
    private var submitFeedbackResetTask: Task<Void, Never>? = nil

    // MARK: - Tunables

    enum Tunables {
        /// Shuffle attempts before fallback regeneration.
        static let shuffleRetries: Int = 5
        /// Regeneration attempts to recover a dead board during shuffle.
        static let shuffleRegenerationRetries: Int = 120
        /// Seconds that the reward toast remains visible.
        static let toastDuration: TimeInterval = 2.0
        /// Seconds the round-clear stamp is shown before perk draft appears.
        static var roundClearStampDuration: TimeInterval {
            AppSettings.reduceMotion ? 0.45 : 1.0
        }
        /// Seconds that valid-submit word feedback ("+points") remains visible.
        static let validSubmitFeedbackDuration: TimeInterval = 0.6
    }

    // MARK: - Derived UI state

    private var isInputSuppressed: Bool {
        isPaused || isAnimating || showPerkDraft || showRunSummary || showRoundClearStamp
    }

    // MARK: - Init

    init(rows: Int = 7, cols: Int = 7, milestoneTracker: MilestoneTracker = MilestoneTracker()) {
        self.milestoneTracker = milestoneTracker
        self.bag = LetterBag()
        self.dictionary = WordDictionary.loadFromBundle()
        let initialSize = max(rows, cols)
        let initialTemplate = BoardTemplate.full(
            gridSize: initialSize,
            id: "boot_\(initialSize)x\(initialSize)",
            name: "Bootstrap \(initialSize)x\(initialSize)"
        )

        var initialBag = bag
        self.state = Resolver.initialState(template: initialTemplate, dictionary: dictionary, bag: &initialBag)
        self.bag = initialBag

        self.scene = BoardScene(rows: initialTemplate.rows, cols: initialTemplate.cols, size: CGSize(width: 360, height: 360))
        configureSceneCallbacks()
        scene.renderBoard(tiles: state.tiles)
        syncHUD()
        syncDebugFields(locksBrokenThisMove: 0, submittedWord: "", status: "idle")
    }

    func updateSceneSize(_ size: CGSize) {
        scene.updateLayout(for: size)
    }

    // MARK: - Run lifecycle

    /// Starts a fresh 15-board roguelike run.
    func startRun() {
        beginFreshRun()
    }

    /// Fully restarts the run from board 1 (same as Start Screen -> Play Run).
    func restartRun() {
        beginFreshRun()
    }

    private func beginFreshRun() {
        milestoneTracker.recordRunStarted()
        roundClearTask?.cancel()
        roundClearTask = nil
        toastTask?.cancel()
        toastTask = nil
        submitFeedbackResetTask?.cancel()
        submitFeedbackResetTask = nil
        idleTimer?.invalidate()
        idleTimer = nil
        clearHint()
        scene.wildcardPlacingMode = false
        var fresh = RunState()
        // Starter kit: every run begins with 1 hint.
        // Shuffles are now board-level (5/board), not inventory.
        // To change starting counts edit the lines below.
        fresh.inventory.hints    = 1
        runState = fresh
        showRunSummary = false
        showPerkDraft = false
        showRoundClearStamp = false
        isPaused = false
        isAnimating = false
        isPlacingWildcard = false
        powerupToast = nil
        undoSnapshot = nil
        resetWordFeedback()
        updateSceneInputLock()
        resetBoardForRound(fresh.boardIndex)
    }

    /// Ends the current run, records stats, and shows the summary screen.
    func endRun(won: Bool) {
        roundClearTask?.cancel()
        roundClearTask = nil
        submitFeedbackResetTask?.cancel()
        submitFeedbackResetTask = nil
        let board = runState?.boardIndex ?? 0
        milestoneTracker.recordRunCompleted(boardReached: board)
        runSummaryBoard = board
        runSummaryWon = won
        showPerkDraft = false
        showRoundClearStamp = false
        showRunSummary = true
        isPaused = false
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false
        updateSceneInputLock()
        clearHint()
        resetWordFeedback()
        undoSnapshot = nil
    }

    /// Called when the player picks a modifier from the draft overlay.
    func advanceBoardAfterModifierSelection(_ perkId: PerkID) {
        roundClearTask?.cancel()
        roundClearTask = nil
        submitFeedbackResetTask?.cancel()
        submitFeedbackResetTask = nil
        guard var run = runState else { return }

        if !run.activePerks.contains(perkId) {
            run.activePerks.append(perkId)
        }

        if run.boardIndex >= RunState.Tunables.totalBoards {
            // Last board just cleared — run is won
            runState = run
            showPerkDraft = false
            showRoundClearStamp = false
            endRun(won: true)
            return
        }

        run.boardIndex += 1
        run.resetBoardCounters()
        runState = run
        showPerkDraft = false
        showRoundClearStamp = false
        isPaused = false
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false
        undoSnapshot = nil
        resetBoardForRound(run.boardIndex)
        updateSceneInputLock()
    }

    /// Dismisses the run summary and returns to the idle (no-run) state.
    func dismissRunSummary() {
        roundClearTask?.cancel()
        roundClearTask = nil
        submitFeedbackResetTask?.cancel()
        submitFeedbackResetTask = nil
        showRunSummary = false
        showRoundClearStamp = false
        showPerkDraft = false
        isPaused = false
        runState = nil
        undoSnapshot = nil
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false
        resetWordFeedback()
        updateSceneInputLock()
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        updateSceneInputLock()
    }

    /// Resets the current board while preserving run progression (board index + active perks).
    func restartCurrentBoard() {
        guard var run = runState else { return }
        roundClearTask?.cancel()
        roundClearTask = nil
        submitFeedbackResetTask?.cancel()
        submitFeedbackResetTask = nil
        run.resetBoardCounters()
        runState = run
        showPerkDraft = false
        showRunSummary = false
        showRoundClearStamp = false
        isPaused = false
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false
        powerupToast = nil
        undoSnapshot = nil
        resetBoardForRound(run.boardIndex)
        updateSceneInputLock()
    }

    /// Ends the active run and returns to menu without showing the summary overlay.
    func quitRunToMenu() {
        let board = runState?.boardIndex ?? 0
        milestoneTracker.recordRunCompleted(boardReached: board)
        roundClearTask?.cancel()
        roundClearTask = nil
        toastTask?.cancel()
        toastTask = nil
        submitFeedbackResetTask?.cancel()
        submitFeedbackResetTask = nil
        runState = nil
        showPerkDraft = false
        showRunSummary = false
        showRoundClearStamp = false
        isPaused = false
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false
        powerupToast = nil
        undoSnapshot = nil
        clearHint()
        resetWordFeedback()
        updateSceneInputLock()
    }

    // MARK: - Submit path

    func submitPath(indices: [Int]) {
        guard !isInputSuppressed else { return }

        clearHint()
        let scoreBeforeSubmit = state.score

        // Resolve any wildcard tiles in the path before sending to the resolver.
        var effectiveState = state
        if indices.contains(where: { state.tiles[$0]?.kind == .wildcard }) {
            guard let resolved = resolveWildcardsInPath(indices, tiles: state.tiles) else {
                // No valid word found with wildcard substitutions — reject silently.
                Haptics.notifyWarning()
                syncDebugFields(locksBrokenThisMove: 0, submittedWord: "?", status: "rejected:wildcardNoMatch")
                clearCurrentSelection()
                publishSubmitOutcome(.invalid, points: 0, autoReset: false)
                return
            }
            // Apply resolved letters to a temporary state copy.
            for (boardIndex, letter) in resolved.substitutions {
                effectiveState.tiles[boardIndex]?.letter = letter
            }
        }

        // Capture board state before resolver mutates it (needed for freshSpark check).
        let preMoveState = effectiveState

        var localBag = bag
        let result = Resolver.reduce(
            state: effectiveState,
            action: .submitPath(indices: indices),
            dictionary: dictionary,
            bag: &localBag
        )

        if result.accepted {
            // Save undo snapshot BEFORE applying new state.
            saveUndoSnapshot()

            bag = localBag
            state = result.newState
            score = result.newState.score
            moves = result.newState.moves
            Haptics.submitAcceptedLight()

            if var run = runState {
                // --- New scoring: compute final word score with repeat penalty + floor ---
                // Uses Scoring.wordScore so the penalty never truncates a word to 0 points.
                let wordKey = (result.acceptedWord ?? "").uppercased()
                let wordLen = wordKey.count
                let useCount = run.wordUseCounts[wordKey, default: 0]
                let letterSum = LetterValues.sum(for: wordKey)
                let wordScore = Scoring.wordScore(letterSum: letterSum, length: wordLen, useCount: useCount)

                // Replace the resolver's raw base score with our penalized + floored score.
                // (Resolver already added result.scoreDelta; we correct it here.)
                state.score = scoreBeforeSubmit + wordScore
                score = state.score
                run.wordUseCounts[wordKey] = useCount + 1

                #if DEBUG
                let lenMult = Scoring.lengthMultiplier(for: wordLen)
                let repeatMult = Scoring.repeatMultiplier(useCount: useCount)
                print("[Score] word=\(wordKey) baseSum=\(letterSum) lenMult=\(lenMult) useCount=\(useCount) repeatMult=\(repeatMult) wordScore=\(wordScore) scoreThisBoardBefore=\(run.scoreThisBoard)")
                #endif

                runState = run

                // --- Perk effects (may further adjust score/moves) ---
                processPerkEffects(
                    word: result.acceptedWord ?? result.lastSubmittedWord,
                    path: indices,
                    preMoveState: preMoveState,
                    result: result
                )

                // --- Built-in move refunds (fractional buffer) ---
                if var runAfterPerks = runState {
                    var frac = runAfterPerks.pendingMoveFraction
                    if wordLen == 5 {
                        frac += RunState.Tunables.fiveLetterRefund
                    } else if wordLen >= 6 {
                        frac += RunState.Tunables.sixLetterRefund
                    }
                    frac += Double(result.locksBrokenThisMove) * RunState.Tunables.lockBreakRefund
                    let wholeMoves = Int(frac)
                    runAfterPerks.pendingMoveFraction = frac - Double(wholeMoves)
                    if wholeMoves > 0 { state.moves += wholeMoves }

                    // Board score always increases by wordScore (>= minPoints, never 0).
                    // Perk score adjustments affect state.score (total) but not the
                    // board objective, keeping the objective readable and predictable.
                    runAfterPerks.scoreThisBoard += wordScore

                    #if DEBUG
                    print("[Score] scoreThisBoardAfter=\(runAfterPerks.scoreThisBoard)")
                    #endif

                    runState = runAfterPerks
                }

                milestoneTracker.recordLocksBroken(result.locksBrokenThisMove)
                if let word = result.acceptedWord {
                    milestoneTracker.recordWord(word)
                }

                // Re-sync HUD after all adjustments.
                score = state.score
                moves = state.moves
            }

            syncDebugFields(
                locksBrokenThisMove: result.locksBrokenThisMove,
                submittedWord: result.lastSubmittedWord,
                status: "accepted"
            )
        } else {
            Haptics.notifyWarning()
            let rejection = result.rejectionReason?.rawValue ?? "unknown"
            syncDebugFields(
                locksBrokenThisMove: 0,
                submittedWord: result.lastSubmittedWord,
                status: "rejected:\(rejection)"
            )
        }

        // Clear selection immediately so the word pill resets before the animation plays.
        clearCurrentSelection()
        if result.accepted {
            let pointsGained = max(0, state.score - scoreBeforeSubmit)
            publishSubmitOutcome(.valid, points: pointsGained, autoReset: true)
        } else {
            publishSubmitOutcome(.invalid, points: 0, autoReset: false)
        }

        isAnimating = true
        updateSceneInputLock()

        guard !result.events.isEmpty else {
            scene.renderBoard(tiles: state.tiles)
            isAnimating = false
            if runState != nil, result.accepted {
                checkRunConditions()
            }
            updateSceneInputLock()
            resetIdleTimer()
            return
        }

        scene.play(events: result.events) { [weak self] in
            guard let self else { return }
            self.scene.renderBoard(tiles: self.state.tiles)
            self.isAnimating = false
            self.resetIdleTimer()
            if self.runState != nil, result.accepted {
                self.checkRunConditions()
            }
            self.updateSceneInputLock()
        }
    }

    // MARK: - Powerup: Hint

    /// Manually triggers a hint. Consumes 1 hint from inventory unless the freeHint perk applies.
    func useHint() {
        guard !isInputSuppressed else { return }
        guard var run = runState else { return }
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false

        // Free hint perk: one free hint per board before consuming inventory.
        if run.activePerks.contains(.freeHint), !run.freeHintUsed {
            run.freeHintUsed = true
            runState = run
        } else {
            guard run.inventory.consume(.hint) else { return }
            runState = run
        }

        computeAndPublishHint()
    }

    // MARK: - Powerup: Shuffle

    /// Shuffles non-locked, non-wildcard tiles using this board's shuffle budget.
    func useShuffle() {
        guard !isInputSuppressed else { return }
        guard var run = runState else { return }
        guard run.shufflesRemaining > 0 else { return }
        let originalTiles = state.tiles
        run.shufflesRemaining -= 1
        runState = run
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false

        let maxAttempts = Tunables.shuffleRetries
        var found = false
        for _ in 0..<maxAttempts {
            let candidate = shuffledTiles(originalTiles)
            if boardHasValidHint(candidate) {
                state.tiles = candidate
                found = true
                break
            }
        }

        if !found {
            state.tiles = originalTiles
            for _ in 0..<Tunables.shuffleRegenerationRetries {
                regenerateMoveableTiles()
                if boardHasValidHint(state.tiles) {
                    found = true
                    break
                }
            }
        }

        if !found, injectGuaranteedHintPath() {
            found = boardHasValidHint(state.tiles)
        }

        if !found {
            state.tiles = originalTiles
        }

        syncHUD()
        clearHint()
        clearCurrentSelection()
        scene.renderBoard(tiles: state.tiles)
        syncDebugFields(locksBrokenThisMove: 0, submittedWord: "", status: "shuffle")
    }

    // MARK: - Powerup: Wildcard (place)

    /// Enters wildcard-placing mode. The next tile tap will convert that tile to a wildcard.
    func startWildcardPlacement() {
        guard !isInputSuppressed else { return }
        guard let run = runState, run.inventory.wildcards > 0 else { return }

        // Tap again to cancel placement mode.
        if isPlacingWildcard {
            isPlacingWildcard = false
            scene.wildcardPlacingMode = false
            return
        }

        clearHint()
        isPlacingWildcard = true
        scene.wildcardPlacingMode = true
    }

    /// Called by the scene callback when the player taps a tile during wildcard-placing mode.
    func placeWildcardAt(index: Int) {
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false

        guard var run = runState else { return }
        guard run.inventory.consume(.wildcard) else { return }
        runState = run

        guard var tile = state.tiles[index], tile.isLetterTile else { return }
        tile.kind = .wildcard
        tile.letter = "?"   // display letter; resolved on submit
        state.tiles[index] = tile

        clearHint()
        scene.renderBoard(tiles: state.tiles)
    }

    // MARK: - Powerup: Undo

    /// Restores the last undo snapshot.
    func useUndo() {
        guard !isInputSuppressed else { return }
        guard var run = runState else { return }
        guard let snap = undoSnapshot else { return }
        guard run.inventory.consume(.undo) else { return }
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false

        // Restore game state
        state = snap.gameState
        score = state.score
        moves = state.moves

        // Restore run fields affected by gameplay
        run.inventory = snap.inventory
        // Re-apply the consumed undo (consume reduced it, but snap has pre-submit value)
        _ = run.inventory.consume(.undo)
        run.locksBrokenThisBoard   = snap.locksBrokenThisBoard
        run.scoreThisBoard         = snap.scoreThisBoard
        run.wordUseCounts          = snap.wordUseCounts
        run.pendingMoveFraction    = snap.pendingMoveFraction
        run.lockRefundMovesGranted = snap.lockRefundMovesGranted
        run.lockRefundRealLocks    = snap.lockRefundRealLocks
        run.freshSparkCount        = snap.freshSparkCount
        run.freeHintUsed           = snap.freeHintUsed
        run.freeUndoUsed           = snap.freeUndoUsed
        runState = run

        undoSnapshot = nil

        clearCurrentSelection()
        clearHint()
        scene.renderBoard(tiles: state.tiles)
        syncHUD()
        syncDebugFields(locksBrokenThisMove: 0, submittedWord: "", status: "undo")
    }

    func currentBoard() -> [Tile?] {
        state.tiles
    }

    /// Clears the current tile selection from both the scene and published state.
    func clearCurrentSelection() {
        scene.clearSelection()
        currentSelectionIndices = []
        currentSelectionLetters = []
        currentSelectionMeta = []
        currentSelectionWord = ""
        currentWordText = ""
        activePathLength = 0
    }

    /// Removes the last tile from the current selection (backtrack one step).
    func removeLastSelectionTile() {
        guard !currentSelectionIndices.isEmpty else { return }
        scene.popLastTile()
    }

    // MARK: - Private setup

    private func configureSceneCallbacks() {
        scene.onRequestBoard = { [weak self] in
            self?.currentBoard() ?? []
        }
        scene.onRequestAdjacencyMode = { [weak self] in
            self?.state.boardTemplate.adjacency ?? .hvOnly
        }

        scene.onAnyTouch = { [weak self] in
            Task { @MainActor in
                self?.handleAnyTouch()
            }
        }

        scene.onSelectionChanged = { [weak self] indices in
            Task { @MainActor in
                guard let self else { return }
                self.currentSelectionIndices = indices
                self.activePathLength = indices.count
                // For display: use effective letter (wildcard tiles show "?")
                let display = indices.isEmpty
                    ? ""
                    : (self.displayWord(from: self.state.tiles, indices: indices) ?? "")
                self.currentSelectionWord = display
                self.currentWordText = display.uppercased()
                self.currentSelectionLetters = indices.compactMap { i in
                    guard let tile = self.state.tiles[i] else { return nil }
                    guard tile.isLetterTile else { return nil }
                    return tile.kind == .wildcard ? "?" : tile.letter
                }
                self.currentSelectionMeta = indices.compactMap { i in
                    guard let tile = self.state.tiles[i] else { return nil }
                    guard tile.isLetterTile else { return nil }
                    return SelectionTileMeta(
                        isWildcard: tile.kind == .wildcard,
                        freshness: tile.freshness,
                        infusion: tile.infusion
                    )
                }
                if self.lastSubmitOutcome != .idle || self.lastSubmitPoints != 0 {
                    self.clearSubmitFeedback()
                }
            }
        }

        scene.onWildcardPlace = { [weak self] index in
            Task { @MainActor in
                self?.placeWildcardAt(index: index)
            }
        }
    }

    // MARK: - Run board management

    /// Seeds a fresh board with the correct move count for the given board index.
    private func resetBoardForRound(_ boardIdx: Int) {
        let template = BoardTemplate.template(for: boardIdx)
        let movesCount = RunState.moves(for: boardIdx)
        let lockTarget = RunState.locksGoal(for: boardIdx, template: template)

        var newBag = LetterBag()
        // rareRelief: prevent Q/Z/X/J/K from spawning for the entire run
        if let run = runState, run.activePerks.contains(.rareRelief) {
            newBag.excludedLetters = ["Q", "Z", "X", "J", "K"]
        }
        bag = newBag

        var initialBag = bag
        state = Resolver.initialState(
            template: template,
            moves: movesCount,
            dictionary: dictionary,
            bag: &initialBag,
            lockObjectiveTarget: lockTarget
        )
        // Preserve excludedLetters through the bag copy
        bag = initialBag
        bag.excludedLetters = newBag.excludedLetters

        // tightGloves: +3 bonus moves at the start of each board
        if let run = runState, run.activePerks.contains(.tightGloves) {
            state.moves += 3
        }

        scene.configureGrid(rows: template.rows, cols: template.cols)
        scene.renderBoard(tiles: state.tiles)
        resetWordFeedback()
        syncHUD()
        syncDebugFields(locksBrokenThisMove: 0, submittedWord: "", status: "boardStart:\(boardIdx)")
    }

    // MARK: - Perk hooks

    /// Applies active perk effects after a valid word is accepted.
    /// Mutates `state.score`, `state.moves`, and `runState.locksBrokenThisBoard`.
    private func processPerkEffects(
        word: String,
        path: [Int],
        preMoveState: GameState,
        result: ResolverResult
    ) {
        guard var run = runState else { return }

        let wordLen = word.count
        let upper = word.uppercased()
        let vowelCount = upper.filter { LetterBag.vowelSet.contains($0) }.count
        let isStraight = Selection.isStraightContiguous(
            path, rows: state.rows, cols: state.cols, allowedLengths: 3...6
        )

        var runLockProgress = result.locksBrokenThisMove
        var scoreAdj = 0
        var moveAdj = 0

        // longBreaker: override lock progress by word length
        if run.activePerks.contains(.longBreaker) {
            switch wordLen {
            case 3: runLockProgress = 0
            case 5: runLockProgress += 1
            case 6: runLockProgress += 2
            default: break
            }
        }

        // tightGloves: 3-letter words yield zero lock progress
        if run.activePerks.contains(.tightGloves), wordLen == 3 {
            runLockProgress = 0
        }

        // freshSpark: first never-used tile in path → +1 lock progress (max 3/board)
        if run.activePerks.contains(.freshSpark), run.freshSparkCount < 3 {
            let hasNewTile = path
                .compactMap { preMoveState.tiles[$0] }
                .contains { !preMoveState.usedTileIds.contains($0.id) }
            if hasNewTile {
                runLockProgress += 1
                run.freshSparkCount += 1
            }
        }

        // straightShooter: straight path → +1 lock; turning path → -15 score
        if run.activePerks.contains(.straightShooter) {
            if isStraight {
                runLockProgress += 1
            } else {
                scoreAdj -= 15
            }
        }

        // consonantCrunch: ≤1 vowel → +1 lock; each vowel → -1 score
        if run.activePerks.contains(.consonantCrunch) {
            if vowelCount <= 1 {
                runLockProgress += 1
            }
            scoreAdj -= vowelCount
        }

        // vowelBloom: +5 score per vowel; -5 if no vowels
        if run.activePerks.contains(.vowelBloom) {
            scoreAdj += vowelCount > 0 ? vowelCount * 5 : -5
        }

        // rareRelief: -5 score per word (rare-letter spawn filter via bag.excludedLetters)
        if run.activePerks.contains(.rareRelief) {
            scoreAdj -= 5
        }

        // lockRefund: every 3 real locks broken → +1 move (cap: +2/board)
        if run.activePerks.contains(.lockRefund) {
            let prevLocks = run.lockRefundRealLocks
            let newLocks = prevLocks + result.locksBrokenThisMove
            run.lockRefundRealLocks = newLocks
            let prevGrants = run.lockRefundMovesGranted
            let newGrants = min(2, newLocks / 3)
            let granted = newGrants - prevGrants
            if granted > 0 {
                moveAdj += granted
                run.lockRefundMovesGranted = newGrants
            }
        }

        // Apply adjustments to live game state
        if scoreAdj != 0 { state.score = max(0, state.score + scoreAdj) }
        if moveAdj > 0   { state.moves += moveAdj }

        run.locksBrokenThisBoard += max(0, runLockProgress)
        runState = run
    }

    // MARK: - Run condition check

    private func checkRunConditions() {
        guard let run = runState else { return }

        // Both goals must be met to clear the board.
        if run.locksBrokenThisBoard >= run.locksGoalForBoard
            && run.scoreThisBoard >= run.scoreGoalForBoard {
            beginRoundClearTransition()
            return
        }

        if state.moves <= 0 {
            endRun(won: false)
        }
    }

    // MARK: - Round reward

    /// Weighted random powerup reward granted on board win.
    /// Weights: hint 45%, wildcard 30%, undo 25%.
    /// (Shuffles are now board-level, not a reward.)
    /// To change weights, edit the `rewardTable` array below.
    private func grantRoundReward() {
        guard var run = runState else { return }

        let rewardTable: [(PowerupType, Int)] = [
            (.hint,     45),
            (.wildcard, 30),
            (.undo,     25)
        ]

        let total = rewardTable.reduce(0) { $0 + $1.1 }
        let roll = Int.random(in: 0..<total)
        var cumulative = 0
        var chosen: PowerupType = .hint

        for (type, weight) in rewardTable {
            cumulative += weight
            if roll < cumulative {
                chosen = type
                break
            }
        }

        run.inventory.grantPowerup(chosen)
        runState = run
        showPowerupToast("+1 \(chosen.displayName)")
    }

    // MARK: - Round clear transition

    private func beginRoundClearTransition() {
        guard runState != nil else { return }
        guard !showRoundClearStamp else { return }

        roundClearTask?.cancel()
        roundClearTask = Task { @MainActor [weak self] in
            guard let self else { return }
            // If a valid-word flash is still showing, let its timer expire naturally
            // instead of cutting it off. The tile selection is always cleared immediately.
            if self.lastSubmitOutcome != .valid {
                self.clearSubmitFeedback()
            }
            self.clearCurrentSelection()
            self.showRoundClearStamp = true
            self.updateSceneInputLock()
            Haptics.notifyRoundClearSuccess()
            self.grantRoundReward()

            try? await Task.sleep(
                nanoseconds: UInt64(Tunables.roundClearStampDuration * 1_000_000_000)
            )
            guard !Task.isCancelled, self.runState != nil else { return }

            self.perkDraftOptions = self.generatePerkDraftOptions()
            self.showPerkDraft = true
            self.showRoundClearStamp = false
            self.updateSceneInputLock()
        }
    }

    // MARK: - Perk draft generation

    func generatePerkDraftOptions() -> [Perk] {
        guard let run = runState else { return [] }

        let activeSet = Set(run.activePerks)
        let unlocked = milestoneTracker.unlockedPerks

        // Prefer perks not already active
        var pool = unlocked.subtracting(activeSet).map { $0.definition }

        var selected: [Perk] = []

        // Act 1 (boards 1–4): ensure at least one lock-help modifier in the draft
        if run.boardIndex <= 4 {
            if let helper = pool.filter({ $0.isLockHelp }).randomElement() {
                selected.append(helper)
                pool.removeAll { $0.id == helper.id }
            }
        }

        for perk in pool.shuffled() {
            guard selected.count < 3 else { break }
            if !selected.contains(where: { $0.id == perk.id }) {
                selected.append(perk)
            }
        }

        // If pool ran dry, allow repeats from all unlocked perks
        if selected.count < 3 {
            for perk in unlocked.map({ $0.definition }).shuffled() {
                guard selected.count < 3 else { break }
                if !selected.contains(where: { $0.id == perk.id }) {
                    selected.append(perk)
                }
            }
        }

        return Array(selected.prefix(3))
    }

    // MARK: - Wildcard resolution

    /// Tries A-Z substitutions for wildcard tiles in `path` and returns the first valid word
    /// along with a map of board-index → substituted letter. Returns nil if no valid word exists.
    private struct WildcardResolution {
        let word: String
        let substitutions: [Int: Character]
    }

    private func resolveWildcardsInPath(_ path: [Int], tiles: [Tile?]) -> WildcardResolution? {
        // Build the letter array for the path; record which positions are wildcards.
        var letters: [Character] = []
        var wildcardOffsets: [Int] = []   // offsets into `letters` (and `path`) that are wildcards

        for (offset, boardIndex) in path.enumerated() {
            guard let tile = tiles[boardIndex] else { return nil }
            guard tile.isLetterTile else { return nil }
            if tile.kind == .wildcard {
                letters.append("A")   // placeholder
                wildcardOffsets.append(offset)
            } else {
                letters.append(tile.letter)
            }
        }

        guard !wildcardOffsets.isEmpty else { return nil }

        let alphabet: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

        // Recursive substitution with trie-based pruning.
        let trie = dictionary.buildTrie()

        func trySubstitutions(wcIdx: Int, current: inout [Character]) -> String? {
            if wcIdx == wildcardOffsets.count {
                let word = String(current).lowercased()
                return dictionary.contains(word) ? word : nil
            }
            let offset = wildcardOffsets[wcIdx]
            for letter in alphabet {
                current[offset] = letter
                // Trie prefix pruning: check prefix up to this point.
                let prefix = String(current[0...offset]).lowercased()
                var node = trie as WordTrie?
                for ch in prefix {
                    node = node?.child(for: ch)
                    if node == nil { break }
                }
                guard node != nil else { continue }

                if let found = trySubstitutions(wcIdx: wcIdx + 1, current: &current) {
                    return found
                }
            }
            return nil
        }

        if let word = trySubstitutions(wcIdx: 0, current: &letters) {
            var substitutions: [Int: Character] = [:]
            for offset in wildcardOffsets {
                substitutions[path[offset]] = letters[offset]
            }
            return WildcardResolution(word: word, substitutions: substitutions)
        }
        return nil
    }

    // MARK: - Shuffle helpers

    /// Shuffles non-locked, non-wildcard tiles among their own positions.
    private func shuffledTiles(_ tiles: [Tile?]) -> [Tile?] {
        var moveableIndices: [Int] = []
        var moveableTiles: [Tile] = []

        for i in tiles.indices {
            guard let tile = tiles[i] else { continue }
            if tile.isLetterTile && tile.freshness != .freshLocked && tile.kind != .wildcard {
                moveableIndices.append(i)
                moveableTiles.append(tile)
            }
        }

        moveableTiles.shuffle()
        var result = tiles
        for (i, index) in moveableIndices.enumerated() {
            result[index] = moveableTiles[i]
        }
        return result
    }

    /// Regenerates non-locked, non-wildcard tiles with fresh letters from the bag.
    private func regenerateMoveableTiles() {
        var existingCounts: [Character: Int] = [:]
        for tile in state.tiles.compactMap({ $0 }) {
            guard tile.isLetterTile else { continue }
            if tile.freshness != .freshLocked && tile.kind != .wildcard {
                // Don't count the tiles being replaced.
            } else {
                existingCounts[tile.letter, default: 0] += 1
            }
        }

        for i in state.tiles.indices {
            guard let tile = state.tiles[i] else { continue }
            if !tile.isLetterTile || tile.freshness == .freshLocked || tile.kind == .wildcard { continue }
            state.tiles[i] = bag.nextTile(respecting: LetterBag.rareCaps, existingCounts: &existingCounts)
        }
    }

    private func injectGuaranteedHintPath() -> Bool {
        guard let guaranteedWord = guaranteedHintWord() else { return false }
        let letters = Array(guaranteedWord.uppercased())
        guard letters.count == 3 else { return false }

        let cols = state.cols
        let tiles = state.tiles

        var chosenPath: [Int]? = nil

        outer: for i in tiles.indices {
            guard isMovableLetter(at: i, in: tiles) else { continue }
            for j in neighbors(of: i, gridSize: cols, mode: state.boardTemplate.adjacency) {
                guard isMovableLetter(at: j, in: tiles) else { continue }
                for k in neighbors(of: j, gridSize: cols, mode: state.boardTemplate.adjacency) {
                    guard k != i else { continue }
                    guard isMovableLetter(at: k, in: tiles) else { continue }
                    chosenPath = [i, j, k]
                    break outer
                }
            }
        }

        guard let path = chosenPath else { return false }
        for (offset, index) in path.enumerated() {
            guard var tile = state.tiles[index], tile.isLetterTile else { return false }
            tile.letter = letters[offset]
            state.tiles[index] = tile
        }
        return boardHasValidHint(state.tiles)
    }

    private func guaranteedHintWord() -> String? {
        let fallbackWords = ["cat", "dog", "sun", "run", "map", "tap", "red", "sea", "pen", "top"]
        for word in fallbackWords where dictionary.contains(word) {
            return word
        }
        return nil
    }

    private func isMovableLetter(at index: Int, in tiles: [Tile?]) -> Bool {
        guard index >= 0, index < tiles.count, let tile = tiles[index] else { return false }
        guard tile.isLetterTile else { return false }
        return tile.freshness != .freshLocked && tile.kind != .wildcard
    }

    private func boardHasValidHint(_ tiles: [Tile?]) -> Bool {
        var testState = state
        testState.tiles = tiles
        guard let hint = HintFinder.findHint3(state: testState, dictionary: dictionary) else {
            return false
        }
        return HintFinder.validateHint(hint.indices, state: testState, dictionary: dictionary)
    }

    // MARK: - Undo snapshot

    private func saveUndoSnapshot() {
        guard let run = runState else { return }
        undoSnapshot = UndoSnapshot(
            gameState: state,
            inventory: run.inventory,
            locksBrokenThisBoard: run.locksBrokenThisBoard,
            scoreThisBoard: run.scoreThisBoard,
            wordUseCounts: run.wordUseCounts,
            pendingMoveFraction: run.pendingMoveFraction,
            lockRefundMovesGranted: run.lockRefundMovesGranted,
            lockRefundRealLocks: run.lockRefundRealLocks,
            freshSparkCount: run.freshSparkCount,
            freeHintUsed: run.freeHintUsed,
            freeUndoUsed: run.freeUndoUsed
        )
    }

    // MARK: - Toast

    private func showPowerupToast(_ message: String) {
        toastTask?.cancel()
        powerupToast = message
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(Tunables.toastDuration * 1_000_000_000)
            )
            guard !Task.isCancelled else { return }
            self?.powerupToast = nil
        }
    }

    // MARK: - Display word (respects wildcard "?" display)

    private func displayWord(from tiles: [Tile?], indices: [Int]) -> String? {
        var chars: [Character] = []
        for index in indices {
            guard let tile = tiles[index] else { return nil }
            guard tile.isLetterTile else { return nil }
            chars.append(tile.kind == .wildcard ? "?" : tile.letter)
        }
        return String(chars)
    }

    // MARK: - Submit feedback

    private func publishSubmitOutcome(_ outcome: SubmitOutcome, points: Int, autoReset: Bool) {
        submitFeedbackResetTask?.cancel()
        submitFeedbackResetTask = nil
        lastSubmitOutcome = outcome
        lastSubmitPoints = max(0, points)
        submitFeedbackEventID = UUID()

        guard autoReset else { return }
        submitFeedbackResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(Tunables.validSubmitFeedbackDuration * 1_000_000_000)
            )
            guard !Task.isCancelled, let self else { return }
            self.clearSubmitFeedback()
        }
    }

    private func clearSubmitFeedback() {
        submitFeedbackResetTask?.cancel()
        submitFeedbackResetTask = nil
        lastSubmitOutcome = .idle
        lastSubmitPoints = 0
    }

    private func resetWordFeedback() {
        clearCurrentSelection()
        clearSubmitFeedback()
        currentWordText = ""
    }

    // MARK: - Hint system

    private func handleAnyTouch() {
        clearHint()
        resetIdleTimer()
    }

    private func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.computeAndPublishHint()
            }
        }
    }

    private func clearHint() {
        hintTask?.cancel()
        hintTask = nil
        hintPath = nil
        hintWord = nil
        hintIsValid = false
        scene.applyHint(nil)
    }

    private func computeAndPublishHint() {
        guard !isInputSuppressed else { return }
        hintTask?.cancel()
        let currentState = state
        let dict = dictionary
        hintTask = Task.detached(priority: .userInitiated) { [weak self] in
            let hint = HintFinder.findHint3(state: currentState, dictionary: dict)
            let candidatePath = hint?.indices ?? []
            let isValid = HintFinder.validateHint(candidatePath, state: currentState, dictionary: dict)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                self.hintPath = isValid ? hint?.indices : nil
                self.hintWord = isValid ? hint?.word : nil
                self.hintIsValid = isValid
                self.scene.applyHint(isValid ? hint?.indices : nil)
            }
        }
    }

    private func updateSceneInputLock() {
        scene.inputLocked = isInputSuppressed
    }

    // MARK: - HUD sync

    private func syncHUD() {
        score = state.score
        moves = state.moves
        if let run = runState {
            shufflesRemaining = run.shufflesRemaining
            boardScore = run.scoreThisBoard
            boardScoreTarget = RunState.scoreGoal(for: run.boardIndex, template: run.boardTemplate)
            boardLockTarget = RunState.locksGoal(for: run.boardIndex, template: run.boardTemplate)
        }
    }

    private func syncDebugFields(locksBrokenThisMove: Int, submittedWord: String, status: String) {
        self.locksBrokenThisMove = locksBrokenThisMove
        self.lastSubmittedWord = submittedWord
        self.status = status
        self.locksBrokenTotal = state.totalLocksBroken
        self.currentLockedCount = state.tiles.compactMap { $0 }.filter { $0.isLetterTile && $0.freshness == .freshLocked }.count
        self.usedTileIdsCount = state.usedTileIds.count

        if let run = runState {
            self.objectivesText = "Locks: \(run.locksBrokenThisBoard)/\(run.locksGoalForBoard) · Score: \(run.scoreThisBoard)/\(run.scoreGoalForBoard)"
        } else {
            self.objectivesText = "Break Locks: \(state.totalLocksBroken)/\(state.lockObjectiveTarget)"
        }
    }
}
