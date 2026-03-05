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
    @Published private(set) var runTotalScore: Int = 0
    @Published private(set) var runBoardsCleared: Int = 0
    @Published private(set) var runLocksBrokenTotal: Int = 0
    @Published private(set) var runWordsBuiltTotal: Int = 0
    @Published private(set) var runBestWord: String = ""
    @Published private(set) var runBestWordScore: Int = 0
    @Published private(set) var runSummarySnapshot: RunSummarySnapshot? = nil
    /// True while the round clear stamp is visible before the perk draft appears.
    @Published var showRoundClearStamp: Bool = false
    /// Pulsed true when a board is initialized so the UI can show intro banner.
    @Published var showBanner: Bool = false
    @Published private(set) var currentAct: Int = 1
    @Published private(set) var boardIndex: Int = 1
    @Published private(set) var templateDisplayName: String = "STANDARD"
    @Published private(set) var hasStones: Bool = false
    @Published private(set) var isBoss: Bool = false

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

    private var dictionary: WordDictionary
    private var bag: LetterBag
    private var state: GameState
    private var hintTask: Task<Void, Never>? = nil

    private struct ModifierWordContext {
        var usedFreshTile: Bool = false
    }
    private var modifierWordContext = ModifierWordContext()

    // MARK: - Undo

    private struct UndoSnapshot {
        let gameState: GameState
        let inventory: Inventory
        let locksBrokenThisBoard: Int
        let scoreThisBoard: Int
        let wordUseCounts: [String: Int]
        let pendingMoveFraction: Double
        let modifierPendingMoveFraction: Double
        let freshSparkCount: Int
        let freeHintChargesRemaining: Int
        let freeUndoChargesRemaining: Int
        let runTotalScore: Int
        let runLocksBrokenTotal: Int
        let runWordsBuiltTotal: Int
        let runBestWord: String
        let runBestWordScore: Int
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
        clearHint()
        scene.wildcardPlacingMode = false
        var fresh = RunState()
        // Starter kit: every run begins with 1 hint.
        // Shuffles are now board-level (5/board), not inventory.
        // To change starting counts edit the lines below.
        fresh.inventory.hints    = 1
        runState = fresh
        showRunSummary = false
        runSummaryBoard = 0
        runSummaryWon = false
        runSummarySnapshot = nil
        showPerkDraft = false
        showRoundClearStamp = false
        runTotalScore = 0
        runBoardsCleared = 0
        runLocksBrokenTotal = 0
        runWordsBuiltTotal = 0
        runBestWord = ""
        runBestWordScore = 0
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
        let totalBoards = RunState.Tunables.totalBoards
        let board = runState?.boardIndex ?? 0
        let inferredCleared = won ? totalBoards : max(0, board - 1)
        let boardsCleared = min(totalBoards, max(runBoardsCleared, inferredCleared))

        runSummarySnapshot = RunSummarySnapshot(
            wonRun: won,
            totalScore: runTotalScore,
            boardsCleared: boardsCleared,
            totalBoards: totalBoards,
            boardReached: board,
            locksBroken: runLocksBrokenTotal,
            wordsBuilt: runWordsBuiltTotal,
            bestWord: runBestWord,
            bestWordScore: runBestWordScore
        )
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

        let duplicatesEnabled = run.activePerks.contains(.echoChamber)
        if duplicatesEnabled || !run.activePerks.contains(perkId) {
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
        runSummaryBoard = 0
        runSummaryWon = false
        showRoundClearStamp = false
        showPerkDraft = false
        isPaused = false
        runState = nil
        runSummarySnapshot = nil
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
        runSummaryBoard = 0
        runSummaryWon = false
        runSummarySnapshot = nil
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
        runSummarySnapshot = nil
        showPerkDraft = false
        showRunSummary = false
        runSummaryBoard = 0
        runSummaryWon = false
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

    func computeSubmitCost(selectionIndices: [Int]) -> Int {
        var cost = 1
        let containsLocked = selectionIndices.contains { index in
            guard index >= 0, index < state.tiles.count else { return false }
            guard let tile = state.tiles[index], tile.isLetterTile else { return false }
            return tile.freshness == .freshLocked
        }
        if containsLocked {
            cost += 1
        }
        return cost
    }

    func submitPath(indices: [Int]) {
        guard !isInputSuppressed else { return }

        clearHint()
        let scoreBeforeSubmit = state.score
        let submitCost = computeSubmitCost(selectionIndices: indices)
        guard state.moves >= submitCost else {
            Haptics.notifyWarning()
            showPowerupToast("Not enough moves")
            syncDebugFields(locksBrokenThisMove: 0, submittedWord: "", status: "rejected:notEnoughMoves")
            publishSubmitOutcome(.invalid, points: 0, autoReset: false)
            return
        }

        // Resolve any wildcard tiles in the path before sending to the resolver.
        var effectiveState = state
        if indices.contains(where: { state.tiles[$0]?.kind == .wildcard }) {
            guard let resolved = resolveWildcardsInPath(indices, tiles: state.tiles) else {
                Haptics.notifyWarning()
                syncDebugFields(locksBrokenThisMove: 0, submittedWord: "?", status: "rejected:wildcardNoMatch")
                publishSubmitOutcome(.invalid, points: 0, autoReset: false)
                return
            }
            for (boardIndex, letter) in resolved.substitutions {
                effectiveState.tiles[boardIndex]?.letter = letter
            }
        }

        let preMoveState = effectiveState
        // Tentatively spend submit moves before validation.
        effectiveState.moves = max(0, effectiveState.moves - submitCost)

        var localBag = bag
        let result = Resolver.reduce(
            state: effectiveState,
            action: .submitPath(indices: indices),
            dictionary: dictionary,
            bag: &localBag
        )

        guard result.accepted else {
            Haptics.notifyWarning()
            let rejection = result.rejectionReason?.rawValue ?? "unknown"
            syncDebugFields(
                locksBrokenThisMove: 0,
                submittedWord: result.lastSubmittedWord,
                status: "rejected:\(rejection)"
            )
            // Invalid submit refunds full tentative cost by leaving persistent state unchanged.
            publishSubmitOutcome(.invalid, points: 0, autoReset: false)
            moves = state.moves
            return
        }

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
            let baseWordScore = Scoring.wordScore(letterSum: letterSum, length: wordLen, useCount: useCount)

            // Replace the resolver's raw base score with our penalized + floored score.
            // (Resolver already added result.scoreDelta; we correct it here.)
            state.score = scoreBeforeSubmit + baseWordScore
            score = state.score
            let usedFreshTile = indices
                .compactMap { preMoveState.tiles[$0] }
                .contains { !preMoveState.usedTileIds.contains($0.id) }
            modifierWordContext = ModifierWordContext(
                usedFreshTile: usedFreshTile
            )

            #if DEBUG
            let lenMult = Scoring.lengthMultiplier(for: wordLen)
            let repeatMult = Scoring.repeatMultiplier(useCount: useCount)
            print("[Score] word=\(wordKey) baseSum=\(letterSum) lenMult=\(lenMult) useCount=\(useCount) repeatMult=\(repeatMult) wordScore=\(baseWordScore) scoreThisBoardBefore=\(run.scoreThisBoard)")
            #endif

            let hookDelta = onWordAccepted(
                word: wordKey,
                length: wordLen,
                baseScore: baseWordScore,
                locksBrokenThisMove: result.locksBrokenThisMove,
                run: &run
            )
            run.wordUseCounts[wordKey] = useCount + 1

            if hookDelta.scoreDelta != 0 {
                state.score = max(0, state.score + hookDelta.scoreDelta)
            }
            if hookDelta.moveDelta != 0 {
                state.moves = max(0, state.moves + hookDelta.moveDelta)
            }

            run.locksBrokenThisBoard += max(0, result.locksBrokenThisMove + hookDelta.lockDelta)

            // --- Built-in move refunds, modified by run-wide hooks ---
            var frac = run.pendingMoveFraction
            if wordLen == 5 {
                frac += RunState.Tunables.fiveLetterRefund * run.lengthRefundMultiplierThisBoard
            } else if wordLen >= 6 {
                frac += RunState.Tunables.sixLetterRefund * run.lengthRefundMultiplierThisBoard
            }
            frac += Double(result.locksBrokenThisMove) * RunState.Tunables.lockBreakRefund * run.lockBreakRefundMultiplierThisBoard
            let wholeMoves = Int(frac)
            run.pendingMoveFraction = frac - Double(wholeMoves)
            if wholeMoves > 0 { state.moves += wholeMoves }

            let modifierWholeMoves = Int(run.modifierPendingMoveFraction)
            if modifierWholeMoves > 0 {
                state.moves += modifierWholeMoves
                run.modifierPendingMoveFraction -= Double(modifierWholeMoves)
            }

            let boardWordScore = max(1, baseWordScore + hookDelta.scoreDelta)
            run.scoreThisBoard += boardWordScore
            runTotalScore += boardWordScore
            runWordsBuiltTotal += 1
            runLocksBrokenTotal += max(0, result.locksBrokenThisMove)
            if boardWordScore > runBestWordScore {
                runBestWordScore = boardWordScore
                runBestWord = wordKey
            }

            #if DEBUG
            print("[Score] scoreThisBoardAfter=\(run.scoreThisBoard)")
            #endif

            runState = run

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

        clearCurrentSelection()
        let pointsGained = max(0, state.score - scoreBeforeSubmit)
        publishSubmitOutcome(.valid, points: pointsGained, autoReset: true)

        isAnimating = true
        updateSceneInputLock()

        guard !result.events.isEmpty else {
            scene.renderBoard(tiles: state.tiles)
            isAnimating = false
            if runState != nil, result.accepted {
                checkRunConditions()
            }
            updateSceneInputLock()
            return
        }

        scene.play(events: result.events) { [weak self] in
            guard let self else { return }
            self.scene.renderBoard(tiles: self.state.tiles)
            self.isAnimating = false
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

        // Board-level free hint charges from modifiers.
        if run.freeHintChargesRemaining > 0 {
            run.freeHintChargesRemaining -= 1
            runState = run
        } else {
            guard run.inventory.consume(.hint) else { return }
            runState = run
        }

        computeAndPublishHint()
    }

    // MARK: - Powerup: Shuffle

    /// Shuffles letters within each column segment (split by stones/mask) using this board's shuffle budget.
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
        let usedFreeUndo = run.freeUndoChargesRemaining > 0
        if usedFreeUndo {
            run.freeUndoChargesRemaining -= 1
        } else {
            guard run.inventory.consume(.undo) else { return }
        }
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false

        // Restore game state
        state = snap.gameState
        score = state.score
        moves = state.moves

        // Restore run fields affected by gameplay
        run.inventory = snap.inventory
        // Re-apply undo cost, because snapshot has pre-undo values.
        if usedFreeUndo {
            run.freeUndoChargesRemaining = max(0, snap.freeUndoChargesRemaining - 1)
        } else {
            _ = run.inventory.consume(.undo)
            run.freeUndoChargesRemaining = snap.freeUndoChargesRemaining
        }
        run.locksBrokenThisBoard   = snap.locksBrokenThisBoard
        run.scoreThisBoard         = snap.scoreThisBoard
        run.wordUseCounts          = snap.wordUseCounts
        run.pendingMoveFraction    = snap.pendingMoveFraction
        run.modifierPendingMoveFraction = snap.modifierPendingMoveFraction
        run.freshSparkCount        = snap.freshSparkCount
        run.freeHintChargesRemaining = snap.freeHintChargesRemaining
        runState = run
        runTotalScore = snap.runTotalScore
        runLocksBrokenTotal = snap.runLocksBrokenTotal
        runWordsBuiltTotal = snap.runWordsBuiltTotal
        runBestWord = snap.runBestWord
        runBestWordScore = snap.runBestWordScore

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

    #if DEBUG
    func configureForTesting(
        state: GameState,
        dictionary: WordDictionary,
        bag: LetterBag = LetterBag(),
        runState: RunState? = nil
    ) {
        self.state = state
        self.dictionary = dictionary
        self.bag = bag
        self.runState = runState
        scene.configureGrid(rows: state.rows, cols: state.cols)
        scene.renderBoard(tiles: state.tiles)
        syncHUD()
        syncDebugFields(locksBrokenThisMove: 0, submittedWord: "", status: "testConfigured")
        clearSubmitFeedback()
    }
    #endif

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
        let baseMoves = RunState.moves(for: boardIdx)
        let baseLockTarget = RunState.locksGoal(for: boardIdx, template: template)
        let baseScoreTarget = RunState.scoreGoal(for: boardIdx, template: template)

        guard var run = runState else { return }
        let boardStart = onBoardStart(
            baseMoves: baseMoves,
            baseLockTarget: baseLockTarget,
            baseScoreTarget: baseScoreTarget,
            baseShuffles: RunState.Tunables.shufflesPerBoard
        )
        run.lockTargetThisBoard = boardStart.lockTarget
        run.scoreTargetThisBoard = boardStart.scoreTarget
        run.shufflesRemaining = boardStart.shuffles
        run.freeHintChargesRemaining = boardStart.freeHintCharges
        run.freeUndoChargesRemaining = boardStart.freeUndoCharges
        run.lengthRefundMultiplierThisBoard = boardStart.lengthRefundMultiplier
        run.lockBreakRefundMultiplierThisBoard = boardStart.lockBreakRefundMultiplier
        run.guaranteedBonusRewardsThisBoard = boardStart.guaranteedBonusRewards
        run.extraRewardRollChanceThisBoard = boardStart.extraRewardRollChance
        run.rewardHintWeightDeltaThisBoard = boardStart.rewardHintWeightDelta
        run.rewardWildcardWeightDeltaThisBoard = boardStart.rewardWildcardWeightDelta
        run.rewardUndoWeightDeltaThisBoard = boardStart.rewardUndoWeightDelta
        runState = run

        var newBag = LetterBag()
        newBag.excludedLetters = boardStart.excludedLetters
        bag = newBag

        var initialBag = bag
        state = Resolver.initialState(
            template: template,
            moves: boardStart.moves,
            dictionary: dictionary,
            bag: &initialBag,
            lockObjectiveTarget: boardStart.lockTarget
        )
        // Preserve excludedLetters through the bag copy
        bag = initialBag
        bag.excludedLetters = newBag.excludedLetters

        scene.configureGrid(rows: template.rows, cols: template.cols)
        scene.renderBoard(tiles: state.tiles)
        publishBoardIntro(boardIdx: boardIdx, template: template)
        resetWordFeedback()
        syncHUD()
        syncDebugFields(locksBrokenThisMove: 0, submittedWord: "", status: "boardStart:\(boardIdx)")
    }

    private func publishBoardIntro(boardIdx: Int, template: BoardTemplate) {
        boardIndex = boardIdx
        currentAct = max(1, min(3, ((boardIdx - 1) / 5) + 1))
        isBoss = boardIdx % 5 == 0
        hasStones = !template.stones.isEmpty
        templateDisplayName = templateBannerName(for: template, isBoss: isBoss)

        // Pulse the trigger so GameScreen can show the intro each new board.
        showBanner = false
        DispatchQueue.main.async { [weak self] in
            self?.showBanner = true
        }
    }

    private func templateBannerName(for template: BoardTemplate, isBoss: Bool) -> String {
        if isBoss {
            return "BOSS"
        }
        let id = template.id.lowercased()
        if id.contains("diamond") {
            return "DIAMOND"
        }
        if id.contains("six") {
            return "SIX"
        }
        if id.contains("standard") {
            return "STANDARD"
        }

        return template.name.uppercased()
    }

    // MARK: - Modifier hooks

    private struct WordAcceptedHookDelta {
        var scoreDelta: Int = 0
        var moveDelta: Int = 0
        var lockDelta: Int = 0
    }

    private struct BoardStartHookResult {
        var moves: Int
        var lockTarget: Int
        var scoreTarget: Int
        var shuffles: Int
        var freeHintCharges: Int
        var freeUndoCharges: Int
        var lengthRefundMultiplier: Double
        var lockBreakRefundMultiplier: Double
        var guaranteedBonusRewards: Int
        var extraRewardRollChance: Double
        var rewardHintWeightDelta: Int
        var rewardWildcardWeightDelta: Int
        var rewardUndoWeightDelta: Int
        var excludedLetters: Set<Character>
    }

    private struct BoardClearHookResult {
        var rewardTable: [(PowerupType, Int)]
        var guaranteedBonusRewards: Int
        var extraRewardRollChance: Double
    }

    /// Centralized run-wide word hook.
    /// Returns score/move/lock deltas that apply after a valid word resolve.
    private func onWordAccepted(
        word: String,
        length: Int,
        baseScore: Int,
        locksBrokenThisMove: Int,
        run: inout RunState
    ) -> WordAcceptedHookDelta {
        var delta = WordAcceptedHookDelta()
        let upper = word.uppercased()
        let vowelCount = upper.filter { LetterBag.vowelSet.contains($0) }.count

        for modifier in run.activePerks {
            switch modifier {
            case .lockRefund:
                if locksBrokenThisMove > 0 {
                    run.modifierPendingMoveFraction += 0.5 * Double(locksBrokenThisMove)
                } else {
                    delta.scoreDelta -= 6
                }
            case .freshSpark:
                if modifierWordContext.usedFreshTile, run.freshSparkCount < 3 {
                    delta.lockDelta += 1
                    run.freshSparkCount += 1
                }
            case .longBreaker:
                switch length {
                case 3: delta.lockDelta -= 1
                case 5: delta.lockDelta += 1
                case 6: delta.lockDelta += 2
                default: break
                }
            case .straightShooter:
                break
            case .freeHint:
                break
            case .freeUndo:
                break
            case .rareRelief:
                delta.scoreDelta -= 5
            case .consonantCrunch:
                if vowelCount <= 1 {
                    delta.scoreDelta += 12
                    delta.lockDelta += 1
                } else if vowelCount >= 3 {
                    delta.scoreDelta -= 8
                }
            case .vowelBloom:
                delta.scoreDelta += vowelCount > 0 ? vowelCount * 4 : -8
            case .tightGloves:
                if length == 3 {
                    delta.scoreDelta -= 12
                }
            case .lockSplash:
                if locksBrokenThisMove >= 2 {
                    delta.lockDelta += 2
                    delta.scoreDelta -= 10
                }
            case .bigGame:
                if length >= 6 {
                    delta.scoreDelta += Int((Double(baseScore) * 0.40).rounded())
                } else if length == 3 {
                    delta.scoreDelta -= Int((Double(baseScore) * 0.25).rounded())
                }
            case .vowelBloomPlus:
                delta.scoreDelta += Int((Double(baseScore) * 0.30).rounded())
            case .overclockedBoots:
                break
            case .austerityPact:
                delta.scoreDelta += Int((Double(baseScore) * 0.35).rounded())
            case .wildcardSmith:
                break
            case .salvageRights:
                break
            case .bossHunter:
                break
            case .titanTribute:
                if run.isBossBoard {
                    delta.scoreDelta += Int((Double(baseScore) * 0.40).rounded())
                } else {
                    delta.scoreDelta -= Int((Double(baseScore) * 0.10).rounded())
                }
            case .echoChamber:
                break
            }
        }

        return delta
    }

    /// Centralized run-wide board-start hook.
    /// Applies moves/targets/shuffles/reward-state modifiers for this board.
    private func onBoardStart(
        baseMoves: Int,
        baseLockTarget: Int,
        baseScoreTarget: Int,
        baseShuffles: Int
    ) -> BoardStartHookResult {
        guard let run = runState else {
            return BoardStartHookResult(
                moves: baseMoves,
                lockTarget: baseLockTarget,
                scoreTarget: baseScoreTarget,
                shuffles: baseShuffles,
                freeHintCharges: 0,
                freeUndoCharges: 0,
                lengthRefundMultiplier: 1.0,
                lockBreakRefundMultiplier: 1.0,
                guaranteedBonusRewards: 0,
                extraRewardRollChance: 0.0,
                rewardHintWeightDelta: 0,
                rewardWildcardWeightDelta: 0,
                rewardUndoWeightDelta: 0,
                excludedLetters: []
            )
        }

        var moves = baseMoves
        var shuffles = baseShuffles
        var freeHints = 0
        var freeUndos = 0

        var lockTargetFlat = 0
        var scoreTargetMultiplier = 1.0

        var lengthRefundMultiplier = 1.0
        let lockBreakRefundMultiplier = 1.0
        var guaranteedBonusRewards = 0
        var extraRewardRollChance = 0.0
        var rewardHintWeightDelta = 0
        var rewardWildcardWeightDelta = 0
        let rewardUndoWeightDelta = 0
        var excludedLetters: Set<Character> = []

        for modifier in run.activePerks {
            switch modifier {
            case .lockRefund:
                break
            case .freshSpark:
                break
            case .longBreaker:
                break
            case .straightShooter:
                shuffles += 1
                moves -= 1
            case .freeHint:
                freeHints += 1
                scoreTargetMultiplier *= 1.10
            case .freeUndo:
                freeUndos += 1
                scoreTargetMultiplier *= 1.08
            case .rareRelief:
                excludedLetters.formUnion(["Q", "Z", "X", "J", "K"])
            case .consonantCrunch:
                break
            case .vowelBloom:
                break
            case .tightGloves:
                moves += 1
            case .lockSplash:
                break
            case .bigGame:
                break
            case .vowelBloomPlus:
                lengthRefundMultiplier = 0.0
            case .overclockedBoots:
                moves += 2
                scoreTargetMultiplier *= 1.20
            case .austerityPact:
                moves -= 2
            case .wildcardSmith:
                rewardWildcardWeightDelta += 20
                rewardHintWeightDelta -= 10
            case .salvageRights:
                lockTargetFlat += 1
                extraRewardRollChance += 0.35
            case .bossHunter:
                break
            case .titanTribute:
                break
            case .echoChamber:
                break
            }
        }

        var lockTarget = max(1, baseLockTarget + lockTargetFlat)
        var scoreTarget = max(1, Int(ceil(Double(baseScoreTarget) * scoreTargetMultiplier)))

        onBossBoard(
            moves: &moves,
            lockTarget: &lockTarget,
            scoreTarget: &scoreTarget,
            guaranteedBonusRewards: &guaranteedBonusRewards,
            activeModifiers: run.activePerks,
            isBossBoard: run.isBossBoard
        )

        return BoardStartHookResult(
            moves: max(1, moves),
            lockTarget: lockTarget,
            scoreTarget: scoreTarget,
            shuffles: max(0, shuffles),
            freeHintCharges: max(0, freeHints),
            freeUndoCharges: max(0, freeUndos),
            lengthRefundMultiplier: max(0, lengthRefundMultiplier),
            lockBreakRefundMultiplier: max(0, lockBreakRefundMultiplier),
            guaranteedBonusRewards: max(0, guaranteedBonusRewards),
            extraRewardRollChance: min(0.95, max(0, extraRewardRollChance)),
            rewardHintWeightDelta: rewardHintWeightDelta,
            rewardWildcardWeightDelta: rewardWildcardWeightDelta,
            rewardUndoWeightDelta: rewardUndoWeightDelta,
            excludedLetters: excludedLetters
        )
    }

    /// Centralized boss-board hook for boss-specific modifier effects.
    private func onBossBoard(
        moves: inout Int,
        lockTarget: inout Int,
        scoreTarget: inout Int,
        guaranteedBonusRewards: inout Int,
        activeModifiers: [PerkID],
        isBossBoard: Bool
    ) {
        for modifier in activeModifiers {
            switch modifier {
            case .bossHunter:
                if isBossBoard {
                    moves += 2
                    lockTarget = max(1, Int(ceil(Double(lockTarget) * 0.85)))
                } else {
                    moves -= 1
                }
            case .titanTribute:
                if isBossBoard {
                    guaranteedBonusRewards += 1
                }
            default:
                break
            }
        }
    }

    /// Centralized board-clear hook for reward table and bonus grants.
    private func onBoardClear(baseRewardTable: [(PowerupType, Int)]) -> BoardClearHookResult {
        guard let run = runState else {
            return BoardClearHookResult(
                rewardTable: baseRewardTable,
                guaranteedBonusRewards: 0,
                extraRewardRollChance: 0
            )
        }

        var hintWeight = baseRewardTable.first(where: { $0.0 == .hint })?.1 ?? 0
        var wildcardWeight = baseRewardTable.first(where: { $0.0 == .wildcard })?.1 ?? 0
        var undoWeight = baseRewardTable.first(where: { $0.0 == .undo })?.1 ?? 0

        hintWeight = max(0, hintWeight + run.rewardHintWeightDeltaThisBoard)
        wildcardWeight = max(0, wildcardWeight + run.rewardWildcardWeightDeltaThisBoard)
        undoWeight = max(0, undoWeight + run.rewardUndoWeightDeltaThisBoard)

        var table: [(PowerupType, Int)] = [
            (.hint, hintWeight),
            (.wildcard, wildcardWeight),
            (.undo, undoWeight)
        ]
        let totalWeight = table.reduce(0) { $0 + $1.1 }
        if totalWeight <= 0 {
            table = baseRewardTable
        }

        return BoardClearHookResult(
            rewardTable: table,
            guaranteedBonusRewards: run.guaranteedBonusRewardsThisBoard,
            extraRewardRollChance: run.extraRewardRollChanceThisBoard
        )
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

        let baseRewardTable: [(PowerupType, Int)] = [
            (.hint,     45),
            (.wildcard, 30),
            (.undo,     25)
        ]
        let hook = onBoardClear(baseRewardTable: baseRewardTable)

        func pickReward(_ table: [(PowerupType, Int)]) -> PowerupType {
            let total = table.reduce(0) { $0 + max(0, $1.1) }
            guard total > 0 else { return .hint }
            let roll = Int.random(in: 0..<total)
            var cumulative = 0
            for (type, weight) in table {
                cumulative += max(0, weight)
                if roll < cumulative {
                    return type
                }
            }
            return .hint
        }

        var granted: [PowerupType] = []
        let firstReward = pickReward(hook.rewardTable)
        run.inventory.grantPowerup(firstReward)
        granted.append(firstReward)

        if hook.guaranteedBonusRewards > 0 {
            for _ in 0..<hook.guaranteedBonusRewards {
                let extra = pickReward(hook.rewardTable)
                run.inventory.grantPowerup(extra)
                granted.append(extra)
            }
        }

        if hook.extraRewardRollChance > 0, Double.random(in: 0..<1) < hook.extraRewardRollChance {
            let extra = pickReward(hook.rewardTable)
            run.inventory.grantPowerup(extra)
            granted.append(extra)
        }

        runState = run
        let byType = Dictionary(grouping: granted, by: { $0 }).mapValues { $0.count }
        let toast = byType
            .map { key, value in "+\(value) \(key.displayName)" }
            .sorted()
            .joined(separator: "  ")
        showPowerupToast(toast)
    }

    // MARK: - Round clear transition

    private func beginRoundClearTransition() {
        guard let run = runState else { return }
        guard !showRoundClearStamp else { return }
        runBoardsCleared = min(
            RunState.Tunables.totalBoards,
            max(runBoardsCleared, run.boardIndex)
        )

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
            guard !Task.isCancelled, let run = self.runState else { return }

            if run.boardIndex >= RunState.Tunables.totalBoards {
                self.showRoundClearStamp = false
                self.endRun(won: true)
                return
            }

            self.perkDraftOptions = self.generatePerkDraftOptions()
            self.showPerkDraft = true
            self.showRoundClearStamp = false
            self.updateSceneInputLock()
        }
    }

    // MARK: - Perk draft generation

    func generatePerkDraftOptions() -> [Perk] {
        guard let run = runState else { return [] }

        let unlocked = milestoneTracker.unlockedPerks
        let duplicatesEnabled = run.activePerks.contains(.echoChamber)

        var poolIDs: [PerkID]
        if duplicatesEnabled {
            poolIDs = Array(unlocked)
        } else {
            let active = Set(run.activePerks)
            poolIDs = Array(unlocked.subtracting(active))
        }
        if poolIDs.isEmpty {
            poolIDs = Array(unlocked)
        }

        var selected: [Perk] = []
        var selectedIDs: Set<PerkID> = []

        while selected.count < 3 {
            let available = poolIDs.filter { !selectedIDs.contains($0) }
            guard !available.isEmpty else { break }

            let rolledRarity = rollDraftRarity()
            let rarityCandidates = available.filter { $0.definition.rarity == rolledRarity }
            let source = rarityCandidates.isEmpty ? available : rarityCandidates
            guard let chosen = source.randomElement() else { break }

            selected.append(chosen.definition)
            selectedIDs.insert(chosen)
        }

        if selected.count < 3 {
            for candidate in Array(unlocked).shuffled() {
                guard selected.count < 3 else { break }
                guard !selectedIDs.contains(candidate) else { continue }
                selected.append(candidate.definition)
                selectedIDs.insert(candidate)
            }
        }

        return Array(selected.prefix(3))
    }

    private func rollDraftRarity() -> ModifierRarity {
        let weights = ModifierDraftTunables.rarityWeights
        let total = weights.values.reduce(0, +)
        guard total > 0 else { return .common }
        let roll = Int.random(in: 0..<total)
        var cumulative = 0
        for rarity in ModifierRarity.allCases {
            cumulative += max(0, weights[rarity] ?? 0)
            if roll < cumulative {
                return rarity
            }
        }
        return .common
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

    /// Shuffles letters in-place within each column segment.
    /// Segments are separated by stones and non-playable cells.
    /// Metadata (lock state, wildcard kind, infusion, IDs) is preserved.
    private func shuffledTiles(_ tiles: [Tile?]) -> [Tile?] {
        var result = tiles
        let rows = state.rows
        let cols = state.cols
        let template = state.boardTemplate

        for col in 0..<cols {
            for segment in columnSegments(col: col, rows: rows, cols: cols, template: template) {
                let letterIndices = segment.filter { index in
                    guard let tile = tiles[index] else { return false }
                    guard tile.isLetterTile else { return false }
                    // Preserve wildcard behavior by keeping wildcard letters unchanged.
                    return tile.kind != .wildcard
                }
                guard letterIndices.count >= 2 else { continue }

                var shuffledLetters = letterIndices.compactMap { tiles[$0]?.letter }
                shuffledLetters.shuffle()

                for (offset, index) in letterIndices.enumerated() {
                    guard var tile = result[index] else { continue }
                    tile.letter = shuffledLetters[offset]
                    result[index] = tile
                }
            }
        }

        return result
    }

    private func columnSegments(
        col: Int,
        rows: Int,
        cols: Int,
        template: BoardTemplate
    ) -> [[Int]] {
        var segments: [[Int]] = []
        var activeSegment: [Int] = []

        for row in 0..<rows {
            let index = row * cols + col
            let isBarrier = !template.isPlayable(index) || template.isStone(index)

            if isBarrier {
                if !activeSegment.isEmpty {
                    segments.append(activeSegment)
                    activeSegment.removeAll(keepingCapacity: true)
                }
                continue
            }

            activeSegment.append(index)
        }

        if !activeSegment.isEmpty {
            segments.append(activeSegment)
        }

        return segments
    }

    /// Regenerates non-locked, non-wildcard tiles with fresh letters from the bag.
    /// Tile metadata and IDs are preserved.
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
            guard var tile = state.tiles[i] else { continue }
            if !tile.isLetterTile || tile.freshness == .freshLocked || tile.kind == .wildcard { continue }
            let next = bag.nextTile(respecting: LetterBag.rareCaps, existingCounts: &existingCounts)
            tile.letter = next.letter
            state.tiles[i] = tile
        }
    }

    private func injectGuaranteedHintPath() -> Bool {
        guard let guaranteedWord = guaranteedHintWord() else { return false }
        let letters = Array(guaranteedWord.uppercased())
        guard (4...8).contains(letters.count) else { return false }

        let tiles = state.tiles
        let path = tiles.indices.filter { isMovableLetter(at: $0, in: tiles) }
        guard path.count >= letters.count else { return false }

        for (offset, index) in path.enumerated() {
            guard offset < letters.count else { break }
            guard var tile = state.tiles[index], tile.isLetterTile else { return false }
            tile.letter = letters[offset]
            state.tiles[index] = tile
        }
        return boardHasValidHint(state.tiles)
    }

    private func guaranteedHintWord() -> String? {
        if let dictionaryWord = dictionary.firstWord(lengths: 4...6) {
            return dictionaryWord
        }
        let fallbackWords = ["game", "word", "tile", "grid", "fall", "rain", "swift", "stone"]
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
        guard let hint = HintFinder.findFreePickHint(
            state: testState,
            dictionary: dictionary,
            preferredLengths: [8, 7, 6, 5, 4]
        ) else {
            return false
        }
        return HintFinder.validateFreePickHint(hint, state: testState, dictionary: dictionary)
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
            modifierPendingMoveFraction: run.modifierPendingMoveFraction,
            freshSparkCount: run.freshSparkCount,
            freeHintChargesRemaining: run.freeHintChargesRemaining,
            freeUndoChargesRemaining: run.freeUndoChargesRemaining,
            runTotalScore: runTotalScore,
            runLocksBrokenTotal: runLocksBrokenTotal,
            runWordsBuiltTotal: runWordsBuiltTotal,
            runBestWord: runBestWord,
            runBestWordScore: runBestWordScore
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

    // MARK: - Hint system (powerup-triggered only)

    private func clearHint() {
        hintTask?.cancel()
        hintTask = nil
        hintPath = nil
        hintWord = nil
        hintIsValid = false
    }

    private func computeAndPublishHint() {
        guard !isInputSuppressed else { return }
        hintTask?.cancel()
        let currentState = state
        let dict = dictionary
        hintTask = Task.detached(priority: .userInitiated) { [weak self] in
            let hint = HintFinder.findFreePickHint(
                state: currentState,
                dictionary: dict,
                preferredLengths: [6, 5, 4]
            )
            let isValid = hint.map { HintFinder.validateFreePickHint($0, state: currentState, dictionary: dict) } ?? false
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                self.hintPath = isValid ? hint?.indices : nil
                self.hintWord = isValid ? hint?.word : nil
                self.hintIsValid = isValid
                if let indices = hint?.indices, isValid {
                    self.scene.setSelection(indices: indices)
                } else {
                    Haptics.notifyWarning()
                }
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
            boardScoreTarget = run.scoreGoalForBoard
            boardLockTarget = run.locksGoalForBoard
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
