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

    struct DebugRunOptions: Equatable {
        var roundMetricsLoggingEnabled: Bool
        var startRound: Int

        static func appSettings() -> Self {
            Self(
                roundMetricsLoggingEnabled: false,
                startRound: AppSettings.debugStartRound
            )
        }

        var normalizedStartRound: Int {
            min(max(startRound, 1), RunState.Tunables.totalRounds)
        }
    }

    enum RoundDebugOutcome: String, Codable {
        case cleared
        case failed
    }

    struct RoundDebugMetrics: Codable, Equatable {
        let outcome: RoundDebugOutcome
        let roundIndex: Int
        let act: Int
        let isChallengeRound: Bool
        let movesStart: Int
        let movesEnd: Int
        let scoreTarget: Int
        let scoreThisRound: Int
        let locksAvailable: Int
        let locksBrokenThisRound: Int
        let numberOfSubmits: Int
        let avgWordLength: Double
        let avgPointsPerWord: Double
        let bestWord: String?
        let bestWordPoints: Int
        let longWordCount: Int
        let lockedSubmitCount: Int
        let netMoveRefunds: Int
        let shufflesUsed: Int
        let hintsUsed: Int
        let invalidSubmitCount: Int
    }

    struct ScoreTuningSnapshot: Codable, Equatable {
        let lengthMultipliers: [Int: Double]
        let repeatPenaltyFloor: Double
        let lockBonusPerLock: Int
        let bucketScoreMultipliers: [Int: Double]
        let milestoneScoreMultipliers: [Int: Double]
    }

    struct LateRunSanityReport: Codable, Equatable {
        let trackedRounds: [Int]
        let missingRounds: [Int]
        let capturedAllLateRounds: Bool
        let clearedRounds: [Int]
        let failedRounds: [Int]
        let allRoundsCleared: Bool
        let avgSubmitsPerRound: Double
        let avgLocksBrokenPerRound: Double
        let avgLongWordsPerRound: Double
        let avgPointsPerWord: Double
        let avgRoundScore: Double
        let meetsTargets: Bool
        let failingChecks: [String]
        let tuningSnapshot: ScoreTuningSnapshot
    }

    private struct RoundDebugTracker {
        let roundIndex: Int
        let act: Int
        let isChallengeRound: Bool
        let movesStart: Int
        let scoreTarget: Int
        let locksAvailable: Int
        var numberOfSubmits: Int = 0
        var totalWordLength: Int = 0
        var totalPoints: Int = 0
        var bestWord: String? = nil
        var bestWordPoints: Int = 0
        var longWordCount: Int = 0
        var lockedSubmitCount: Int = 0
        var netMoveRefunds: Int = 0
        var shufflesUsed: Int = 0
        var hintsUsed: Int = 0
        var invalidSubmitCount: Int = 0
    }

    // MARK: - HUD state

    @Published var score: Int = 0
    @Published var moves: Int = 0
    @Published var shufflesRemaining: Int = 0
    @Published var boardScore: Int = 0
    @Published var boardScoreTarget: Int = 0
    @Published var boardLockTarget: Int = 0
    @Published var objectivesText: String = "Score: 0/0"

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
    @Published private(set) var lastSubmitFeedbackDetail: String? = nil
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
    @Published var runSummaryRound: Int = 0
    @Published var runSummaryWon: Bool = false
    @Published private(set) var runTotalScore: Int = 0
    @Published private(set) var runRoundsCleared: Int = 0
    @Published private(set) var runLocksBrokenTotal: Int = 0
    @Published private(set) var runWordsBuiltTotal: Int = 0
    @Published private(set) var runBestWord: String = ""
    @Published private(set) var runBestWordScore: Int = 0
    @Published private(set) var runChallengeRoundsCleared: Int = 0
    @Published private(set) var runRareLetterWordUsed: Bool = false
    @Published private(set) var runRareLetterWordsTotal: Int = 0
    @Published private(set) var runXPEarned: Int = 0
    @Published private(set) var runSummarySnapshot: RunSummarySnapshot? = nil
    /// True while the round clear stamp is visible before the perk draft appears.
    @Published var showRoundClearStamp: Bool = false
    /// Non-nil while the round-cleared popup is showing. Set to nil to dismiss.
    @Published var roundClearedInfo: RoundClearedOverlay.Info? = nil
    /// Pulsed true when a board is initialized so the UI can show intro banner.
    @Published var showBanner: Bool = false
    @Published private(set) var currentAct: Int = 1
    @Published private(set) var currentRound: Int = 1
    @Published private(set) var templateDisplayName: String = "STANDARD"
    @Published private(set) var hasStones: Bool = false
    @Published private(set) var isChallengeRound: Bool = false
    @Published private(set) var currentChallengeDisplayName: String? = nil
    @Published private(set) var currentChallengePrimaryText: String? = nil
    @Published private(set) var currentChallengeSecondaryLabel: String? = nil
    @Published private(set) var currentChallengeSecondaryText: String? = nil
    @Published private(set) var currentChallengeRuleText: String? = nil
    @Published private(set) var lastRoundDebugMetrics: RoundDebugMetrics? = nil
    @Published private(set) var lastRoundDebugMetricsLog: String? = nil
    @Published private(set) var roundDebugHistory: [RoundDebugMetrics] = []
    @Published private(set) var lateRunSanityReport: LateRunSanityReport? = nil
    @Published private(set) var lateRunSanityReportLog: String? = nil
    @Published private(set) var scoreTargetCurve: [RunState.ScoreTargetCurveEntry] = []
    @Published private(set) var scoreTargetCurveLog: String? = nil

    // MARK: - Powerup state

    /// True while waiting for the player to tap a tile to receive a wildcard.
    @Published var isPlacingWildcard: Bool = false
    /// Non-nil while a toast "+1 Hint" etc. is visible.
    @Published var powerupToast: String? = nil
    /// True when at least one undo snapshot is available.
    @Published var canUndo: Bool = false

    // MARK: - Milestone tracker (persisted across sessions)

    let milestoneTracker: MilestoneTracker
    let playerProfile: PlayerProfile

    // MARK: - Core engine

    let scene: BoardScene

    private var dictionary: WordDictionary
    private var bag: LetterBag
    private var state: GameState
    private var hintTask: Task<Void, Never>? = nil
    private var debugRunOptions: DebugRunOptions = .appSettings()
    private var roundDebugTracker: RoundDebugTracker? = nil
    #if DEBUG
    private var bypassSceneEventPlaybackForTesting: Bool = false
    #endif

    private struct ModifierWordContext {
        var usedFreshTile: Bool = false
    }
    private var modifierWordContext = ModifierWordContext()
    private static let lateRunSanityRounds = Array(40...50)
    private static let rareLetters: Set<Character> = ["J", "Q", "X", "Z", "K"]

    // MARK: - Undo

    private struct UndoSnapshot {
        let gameState: GameState
        let inventory: Inventory
        let locksBrokenThisBoard: Int
        let scoreThisBoard: Int
        let wordUseCounts: [String: Int]
        let pendingMoveFraction: Double
        let modifierPendingMoveFraction: Double
        let lastChallengeRegionIDThisBoard: Int?
        let roundObjectiveProgressThisBoard: RoundObjectiveProgress
        let freshSparkCount: Int
        let freeHintChargesRemaining: Int
        let freeUndoChargesRemaining: Int
        let pencilGripRefundUsedThisBoard: Bool
        let spareSealDiscountUsedThisBoard: Bool
        let milestoneLockDiscountUsedThisBoard: Bool
        let runTotalScore: Int
        let runLocksBrokenTotal: Int
        let runWordsBuiltTotal: Int
        let runBestWord: String
        let runBestWordScore: Int
        let runRareLetterWordsTotal: Int
        let runRareLetterWordUsed: Bool
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
        isPaused || isAnimating || showPerkDraft || showRunSummary || showRoundClearStamp || roundClearedInfo != nil
    }

    // MARK: - Init

    init(
        rows: Int = 6,
        cols: Int = 6,
        milestoneTracker: MilestoneTracker = MilestoneTracker(),
        playerProfile: PlayerProfile? = nil
    ) {
        self.milestoneTracker = milestoneTracker
        self.playerProfile = playerProfile ?? PlayerProfile()
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

    /// Starts a fresh 50-round roguelike run.
    func startRun(
        starterPerks: [StarterPerkID]? = nil,
        debugOptions: DebugRunOptions? = nil
    ) {
        beginFreshRun(
            starterPerks: starterPerks ?? playerProfile.equippedStarterPerks,
            debugOptions: debugOptions ?? .appSettings()
        )
    }

    /// Fully restarts the run from round 1 (same as Start Screen -> Play Run).
    func restartRun(
        starterPerks: [StarterPerkID]? = nil,
        debugOptions: DebugRunOptions? = nil
    ) {
        beginFreshRun(
            starterPerks: starterPerks ?? playerProfile.equippedStarterPerks,
            debugOptions: debugOptions ?? .appSettings()
        )
    }

    private func beginFreshRun(
        starterPerks: [StarterPerkID],
        debugOptions: DebugRunOptions
    ) {
        #if DEBUG
        bypassSceneEventPlaybackForTesting = false
        #endif
        self.debugRunOptions = debugOptions
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
        fresh.equippedStarterPerks = Array(starterPerks.prefix(playerProfile.availableEquipSlots))
        applyDebugBootstrap(to: &fresh, options: debugOptions)
        runState = fresh
        showRunSummary = false
        runSummaryRound = 0
        runSummaryWon = false
        runSummarySnapshot = nil
        showPerkDraft = false
        showRoundClearStamp = false
        roundClearedInfo = nil
        runTotalScore = 0
        runRoundsCleared = max(0, fresh.roundIndex - 1)
        runLocksBrokenTotal = 0
        runWordsBuiltTotal = 0
        runBestWord = ""
        runBestWordScore = 0
        runChallengeRoundsCleared = Self.challengeRoundsCleared(before: fresh.roundIndex)
        runRareLetterWordUsed = false
        runRareLetterWordsTotal = 0
        runXPEarned = 0
        isPaused = false
        isAnimating = false
        isPlacingWildcard = false
        powerupToast = nil
        undoSnapshot = nil
        roundDebugTracker = nil
        lastRoundDebugMetrics = nil
        lastRoundDebugMetricsLog = nil
        roundDebugHistory = []
        lateRunSanityReport = nil
        lateRunSanityReportLog = nil
        refreshScoreTargetCurveSnapshot()
        resetWordFeedback()
        updateSceneInputLock()
        resetBoardForRound(fresh.roundIndex)
    }

    /// Ends the current run, records stats, and shows the summary screen.
    func endRun(won: Bool) {
        roundClearTask?.cancel()
        roundClearTask = nil
        submitFeedbackResetTask?.cancel()
        submitFeedbackResetTask = nil
        let totalRounds = RunState.Tunables.totalRounds
        let round = runState?.roundIndex ?? 0
        let inferredCleared = won ? totalRounds : max(0, round - 1)
        let roundsCleared = min(totalRounds, max(runRoundsCleared, inferredCleared))
        let xpEarned = Self.calculateXP(
            roundsCleared: roundsCleared,
            totalScore: runTotalScore,
            challengeRoundsCleared: runChallengeRoundsCleared,
            rareLetterWordUsed: runRareLetterWordUsed
        )
        runXPEarned = xpEarned
        let newUnlocks = playerProfile.recordRunEnd(
            xpEarned: xpEarned,
            wordsBuilt: runWordsBuiltTotal,
            locksBroken: runLocksBrokenTotal,
            rareLetterWords: runRareLetterWordsTotal,
            roundReached: max(round, roundsCleared),
            wonRun: won
        )

        runSummarySnapshot = RunSummarySnapshot(
            wonRun: won,
            totalScore: runTotalScore,
            xpEarned: xpEarned,
            totalXPAfterRun: playerProfile.totalXP,
            roundsCleared: roundsCleared,
            totalRounds: totalRounds,
            roundReached: round,
            locksBroken: runLocksBrokenTotal,
            wordsBuilt: runWordsBuiltTotal,
            bestWord: runBestWord,
            bestWordScore: runBestWordScore,
            challengeRoundsCleared: runChallengeRoundsCleared,
            rareLetterWordUsed: runRareLetterWordUsed,
            newUnlocks: newUnlocks
        )
        milestoneTracker.recordRunCompleted(boardReached: round)
        runSummaryRound = round
        runSummaryWon = won
        showPerkDraft = false
        showRoundClearStamp = false
        roundClearedInfo = nil
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

        if run.roundIndex >= RunState.Tunables.totalRounds {
            // Last board just cleared — run is won
            runState = run
            showPerkDraft = false
            showRoundClearStamp = false
            endRun(won: true)
            return
        }

        run.roundIndex += 1
        run.resetBoardCounters()
        runState = run
        showPerkDraft = false
        showRoundClearStamp = false
        isPaused = false
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false
        undoSnapshot = nil
        resetBoardForRound(run.roundIndex)
        updateSceneInputLock()
    }


    /// Advances to the next board without a perk draft.
    /// Temporary bypass while mid-run perk selection is disabled.
    /// To re-enable drafts, remove this call and restore the perk-draft trigger
    /// in beginRoundClearTransition().
    private func advanceBoardSkippingDraft() {
        guard var run = runState else { return }
        run.roundIndex += 1
        run.resetBoardCounters()
        runState = run
        showPerkDraft = false
        showRoundClearStamp = false
        roundClearedInfo = nil
        isPaused = false
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false
        undoSnapshot = nil
        resetBoardForRound(run.roundIndex)
        updateSceneInputLock()
    }

    /// Called when the player taps "Next Round" on the round-cleared popup.
    func confirmRoundCleared() {
        roundClearedInfo = nil
        advanceBoardSkippingDraft()
    }

    /// Dismisses the run summary and returns to the idle (no-run) state.
    func dismissRunSummary() {
        roundClearTask?.cancel()
        roundClearTask = nil
        submitFeedbackResetTask?.cancel()
        submitFeedbackResetTask = nil
        showRunSummary = false
        runSummaryRound = 0
        runSummaryWon = false
        showRoundClearStamp = false
        showPerkDraft = false
        roundClearedInfo = nil
        isPaused = false
        runXPEarned = 0
        runRareLetterWordsTotal = 0
        runState = nil
        currentChallengeDisplayName = nil
        currentChallengePrimaryText = nil
        currentChallengeSecondaryLabel = nil
        currentChallengeSecondaryText = nil
        currentChallengeRuleText = nil
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

    /// Resets the current round while preserving run progression.
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
        runSummaryRound = 0
        runSummaryWon = false
        runSummarySnapshot = nil
        showRoundClearStamp = false
        roundClearedInfo = nil
        isPaused = false
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false
        powerupToast = nil
        undoSnapshot = nil
        resetBoardForRound(run.roundIndex)
        updateSceneInputLock()
    }

    /// Ends the active run and returns to menu without showing the summary overlay.
    func quitRunToMenu() {
        let round = runState?.roundIndex ?? 0
        milestoneTracker.recordRunCompleted(boardReached: round)
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
        runSummaryRound = 0
        runSummaryWon = false
        showRoundClearStamp = false
        roundClearedInfo = nil
        isPaused = false
        runChallengeRoundsCleared = 0
        runRareLetterWordUsed = false
        runRareLetterWordsTotal = 0
        runXPEarned = 0
        isPlacingWildcard = false
        scene.wildcardPlacingMode = false
        currentChallengeDisplayName = nil
        currentChallengePrimaryText = nil
        currentChallengeSecondaryLabel = nil
        currentChallengeSecondaryText = nil
        currentChallengeRuleText = nil
        powerupToast = nil
        undoSnapshot = nil
        clearHint()
        resetWordFeedback()
        updateSceneInputLock()
    }

    // MARK: - Submit path

    func computeSubmitCost(selectionIndices: [Int]) -> Int {
        let baseCost: Int
        switch state.boardTemplate.specialRule {
        case .taxSubmitCost:
            baseCost = 2
        default:
            baseCost = 1
        }

        var cost = baseCost
        let containsLocked = selectionContainsLockedTiles(selectionIndices)
        if containsLocked {
            cost += 1
            cost -= availableLockedSubmitDiscounts()
        }
        return max(0, cost)
    }

    var minimumSubmitLength: Int {
        Resolver.minimumWordLength(for: state.boardTemplate)
    }

    var maximumSubmitLength: Int {
        Resolver.maxWordLen
    }

    func submitCostLabel(selectionIndices: [Int]) -> String {
        let submitCost = computeSubmitCost(selectionIndices: selectionIndices)
        switch (state.boardTemplate.specialRule, submitCost) {
        case (.taxSubmitCost, 3):
            return "Cost: 3 (LOCKED)"
        case (.taxSubmitCost, _):
            return "Cost: 2"
        case (_, 2):
            return "Cost: 2 (LOCKED)"
        default:
            return "Cost: 1"
        }
    }

    func submitPath(indices: [Int]) {
        guard !isInputSuppressed else { return }

        clearHint()
        let scoreBeforeSubmit = state.score
        let submitCost = computeSubmitCost(selectionIndices: indices)
        let usedLockedSubmit = selectionContainsLockedTiles(indices)
        guard state.moves >= submitCost else {
            recordInvalidSubmitForDebug()
            Haptics.notifyWarning()
            SoundManager.shared.playInvalidSubmit()
            showPowerupToast("Not enough moves")
            syncDebugFields(locksBrokenThisMove: 0, submittedWord: "", status: "rejected:notEnoughMoves")
            publishSubmitOutcome(.invalid, points: 0, autoReset: false)
            return
        }

        // Resolve any wildcard tiles in the path before sending to the resolver.
        var effectiveState = state
        if indices.contains(where: { state.tiles[$0]?.kind == .wildcard }) {
            guard let resolved = resolveWildcardsInPath(indices, tiles: state.tiles) else {
                recordInvalidSubmitForDebug()
                applyInvalidSubmitBonusIfNeeded()
                Haptics.notifyWarning()
                SoundManager.shared.playInvalidSubmit()
                syncDebugFields(locksBrokenThisMove: 0, submittedWord: "?", status: "rejected:wildcardNoMatch")
                publishSubmitOutcome(.invalid, points: 0, autoReset: false)
                return
            }
            for (boardIndex, letter) in resolved.substitutions {
                effectiveState.tiles[boardIndex]?.letter = letter
            }
        }

        if let rejection = challengeRuleRejection(for: indices, run: runState) {
            recordInvalidSubmitForDebug()
            Haptics.notifyWarning()
            SoundManager.shared.playInvalidSubmit()
            publishChallengeRuleRejection(rejection, submittedWord: resultWordForRejectedPath(indices))
            return
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
            recordInvalidSubmitForDebug()
            applyInvalidSubmitBonusIfNeeded()
            Haptics.notifyWarning()
            SoundManager.shared.playInvalidSubmit()
            let rejection = result.rejectionReason?.rawValue ?? "unknown"
            switch result.rejectionReason {
            case .mixedQuadrants:
                showPowerupToast("Use one pool")
            case .mixedPools:
                showPowerupToast("Use one pool")
            case .samePoolTwice:
                showPowerupToast("Switch pools")
            case .minimumWordLength:
                showPowerupToast("Use \(minimumSubmitLength)+ letters")
            default:
                break
            }
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
        SoundManager.shared.playValidSubmit()
        var submitFeedbackDetail: String? = nil

        if var run = runState {
            // --- Step 1 scoring: letter sum -> length multiplier -> repeat penalty -> lock bonus ---
            let wordKey = (result.acceptedWord ?? "").uppercased()
            let wordLen = wordKey.count
            let useCount = run.wordUseCounts[wordKey, default: 0]
            let letterSum = LetterValues.sum(for: wordKey)
            let baseWordScore = WordScorer().scoreWord(
                letters: wordKey,
                lockCount: result.locksBrokenThisMove,
                wordUseCounts: run.wordUseCounts
            )

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
            let lenMult = WordScorer.lengthMultiplier(for: wordLen)
            let repeatMult = WordScorer.repeatMultiplier(forPriorUseCount: useCount)
            let lockBonus = max(0, result.locksBrokenThisMove) * WordScorer.Tunables.lockBonusPerLock
            print("[Score] word=\(wordKey) baseSum=\(letterSum) lenMult=\(lenMult) useCount=\(useCount) repeatMult=\(repeatMult) lockBonus=\(lockBonus) wordScore=\(baseWordScore) scoreThisBoardBefore=\(run.scoreThisBoard)")
            #endif

            let hookDelta = onWordAccepted(
                word: wordKey,
                length: wordLen,
                baseScore: baseWordScore,
                locksBrokenThisMove: result.locksBrokenThisMove,
                run: &run
            )
            submitFeedbackDetail = hookDelta.feedbackDetail
            run.wordUseCounts[wordKey] = useCount + 1

            if hookDelta.scoreDelta != 0 {
                state.score = max(0, state.score + hookDelta.scoreDelta)
            }
            if hookDelta.moveDelta != 0 {
                state.moves = max(0, state.moves + hookDelta.moveDelta)
            }

            let lockBreakRefunds = applyLockBreakMoveRefund(
                lockCount: result.locksBrokenThisMove,
                run: &run
            )
            if lockBreakRefunds > 0 {
                state.moves += lockBreakRefunds
            }

            run.locksBrokenThisBoard += max(0, result.locksBrokenThisMove)

            let refundedMoves = applyLongWordMoveRefund(length: wordLen, run: &run)
            if refundedMoves > 0 {
                state.moves += refundedMoves
            }

            let modifierWholeMoves = Int(run.modifierPendingMoveFraction)
            if modifierWholeMoves > 0 {
                state.moves += modifierWholeMoves
                run.modifierPendingMoveFraction -= Double(modifierWholeMoves)
            }

            let totalMoveRefunds = lockBreakRefunds + refundedMoves + modifierWholeMoves
            if totalMoveRefunds > 0 {
                showPowerupToast(refundToastText(for: totalMoveRefunds))
            }

            let boardWordScore = max(1, baseWordScore + hookDelta.scoreDelta)
            recordAcceptedSubmitForDebug(
                word: wordKey,
                points: boardWordScore,
                length: wordLen,
                usedLockedTiles: usedLockedSubmit,
                moveRefunds: totalMoveRefunds
            )
            run.scoreThisBoard += boardWordScore
            updateRoundObjectiveProgress(
                word: wordKey,
                points: boardWordScore,
                run: &run
            )
            runTotalScore += boardWordScore
            runWordsBuiltTotal += 1
            runLocksBrokenTotal += max(0, result.locksBrokenThisMove)
            let usedRareLetters = Self.wordContainsRareLetter(wordKey)
            runRareLetterWordUsed = runRareLetterWordUsed || usedRareLetters
            if usedRareLetters {
                runRareLetterWordsTotal += 1
            }
            if boardWordScore > runBestWordScore {
                runBestWordScore = boardWordScore
                runBestWord = wordKey
            }

            if state.boardTemplate.specialRule == .alternatingPools {
                run.lastChallengeRegionIDThisBoard = singleRegionID(for: indices, template: state.boardTemplate)
            }

            if usedLockedSubmit {
                consumeLockedSubmitDiscounts(run: &run)
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
        publishSubmitOutcome(
            .valid,
            points: pointsGained,
            autoReset: true,
            detail: submitFeedbackDetail
        )

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

        #if DEBUG
        if bypassSceneEventPlaybackForTesting {
            scene.renderBoard(tiles: state.tiles)
            isAnimating = false
            if runState != nil, result.accepted {
                checkRunConditions()
            }
            updateSceneInputLock()
            return
        }
        #endif

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

    private func selectionContainsLockedTiles(_ selectionIndices: [Int]) -> Bool {
        selectionIndices.contains { index in
            guard index >= 0, index < state.tiles.count else { return false }
            guard let tile = state.tiles[index], tile.isLetterTile else { return false }
            return tile.freshness == .freshLocked
        }
    }

    private func availableLockedSubmitDiscounts() -> Int {
        guard let run = runState else { return 0 }
        var discounts = 0
        if run.equippedStarterPerks.contains(.spareSeal), !run.spareSealDiscountUsedThisBoard {
            discounts += 1
        }
        if playerProfile.unlockedLifetimeMilestones.contains(.break150Locks),
           !run.milestoneLockDiscountUsedThisBoard {
            discounts += 1
        }
        return discounts
    }

    private func consumeLockedSubmitDiscounts(run: inout RunState) {
        if run.equippedStarterPerks.contains(.spareSeal), !run.spareSealDiscountUsedThisBoard {
            run.spareSealDiscountUsedThisBoard = true
        }
        if playerProfile.unlockedLifetimeMilestones.contains(.break150Locks),
           !run.milestoneLockDiscountUsedThisBoard {
            run.milestoneLockDiscountUsedThisBoard = true
        }
    }

    private func applyInvalidSubmitBonusIfNeeded() {
        guard var run = runState else { return }
        guard run.equippedStarterPerks.contains(.pencilGrip), !run.pencilGripRefundUsedThisBoard else {
            return
        }
        run.pencilGripRefundUsedThisBoard = true
        runState = run
        state.moves += 1
        moves = state.moves
        showPowerupToast("Pencil Grip +1 Move")
    }

    private func challengeRuleRejection(
        for indices: [Int],
        run: RunState?
    ) -> SubmissionRejectionReason? {
        guard state.boardTemplate.specialRule == .alternatingPools else { return nil }
        guard let run, let regionID = singleRegionID(for: indices, template: state.boardTemplate) else {
            return nil
        }
        if run.lastChallengeRegionIDThisBoard == regionID {
            return .samePoolTwice
        }
        return nil
    }

    private func publishChallengeRuleRejection(
        _ rejection: SubmissionRejectionReason,
        submittedWord: String
    ) {
        applyInvalidSubmitBonusIfNeeded()
        let status = "rejected:\(rejection.rawValue)"
        switch rejection {
        case .mixedQuadrants:
            showPowerupToast("Use one pool")
        case .mixedPools:
            showPowerupToast("Use one pool")
        case .samePoolTwice:
            showPowerupToast("Switch pools")
        case .minimumWordLength:
            showPowerupToast("Use \(minimumSubmitLength)+ letters")
        default:
            break
        }
        syncDebugFields(
            locksBrokenThisMove: 0,
            submittedWord: submittedWord,
            status: status
        )
        publishSubmitOutcome(.invalid, points: 0, autoReset: false)
        moves = state.moves
    }

    private func resultWordForRejectedPath(_ indices: [Int]) -> String {
        Selection.word(from: state.tiles, indices: indices) ?? ""
    }

    private func singleRegionID(for indices: [Int], template: BoardTemplate) -> Int? {
        let regions = Set(indices.compactMap { template.regionID(for: $0) })
        guard regions.count == 1 else { return nil }
        return regions.first
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

        recordHintUseForDebug()
        SoundManager.shared.playPowerupUse()
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
        recordShuffleUseForDebug()
        SoundManager.shared.playPowerupUse()
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
        SoundManager.shared.playPowerupUse()
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
        run.lastChallengeRegionIDThisBoard = snap.lastChallengeRegionIDThisBoard
        run.roundObjectiveProgressThisBoard = snap.roundObjectiveProgressThisBoard
        run.freshSparkCount        = snap.freshSparkCount
        run.freeHintChargesRemaining = snap.freeHintChargesRemaining
        run.pencilGripRefundUsedThisBoard = snap.pencilGripRefundUsedThisBoard
        run.spareSealDiscountUsedThisBoard = snap.spareSealDiscountUsedThisBoard
        run.milestoneLockDiscountUsedThisBoard = snap.milestoneLockDiscountUsedThisBoard
        runState = run
        runTotalScore = snap.runTotalScore
        runLocksBrokenTotal = snap.runLocksBrokenTotal
        runWordsBuiltTotal = snap.runWordsBuiltTotal
        runBestWord = snap.runBestWord
        runBestWordScore = snap.runBestWordScore
        runRareLetterWordsTotal = snap.runRareLetterWordsTotal
        runRareLetterWordUsed = snap.runRareLetterWordUsed

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
        runState: RunState? = nil,
        debugOptions: DebugRunOptions = DebugRunOptions(
            roundMetricsLoggingEnabled: false,
            startRound: 1
        )
    ) {
        self.state = state
        self.dictionary = dictionary
        self.bag = bag
        if var runState {
            if runState.roundObjectiveThisBoard == nil {
                runState.roundObjectiveThisBoard = RunState.objective(for: runState.roundIndex)
            }
            self.runState = runState
        } else {
            self.runState = nil
        }
        self.debugRunOptions = debugOptions
        isAnimating = false
        isPaused = false
        showPerkDraft = false
        showRunSummary = false
        showRoundClearStamp = false
        roundClearedInfo = nil
        showBanner = false
        bypassSceneEventPlaybackForTesting = true
        roundDebugHistory = []
        lateRunSanityReport = nil
        lateRunSanityReportLog = nil
        refreshScoreTargetCurveSnapshot()
        if let runState {
            beginRoundDebugTracking(run: runState, state: state)
        } else {
            roundDebugTracker = nil
        }
        scene.configureGrid(rows: state.rows, cols: state.cols)
        scene.renderBoard(tiles: state.tiles)
        syncHUD()
        syncDebugFields(locksBrokenThisMove: 0, submittedWord: "", status: "testConfigured")
        clearSubmitFeedback()
    }

    func finalizeCurrentRoundDebugMetricsForTesting(outcome: RoundDebugOutcome) {
        finalizeRoundDebugMetrics(outcome: outcome)
    }

    var rareSpawnRateMultiplierForTesting: Double {
        bag.rareSpawnRateMultiplier
    }

    func configureRunSummaryTrackingForTesting(
        totalScore: Int,
        roundsCleared: Int,
        locksBroken: Int,
        wordsBuilt: Int,
        bestWord: String,
        bestWordScore: Int,
        challengeRoundsCleared: Int,
        rareLetterWordUsed: Bool,
        rareLetterWordsTotal: Int
    ) {
        runTotalScore = totalScore
        runRoundsCleared = roundsCleared
        runLocksBrokenTotal = locksBroken
        runWordsBuiltTotal = wordsBuilt
        runBestWord = bestWord
        runBestWordScore = bestWordScore
        runChallengeRoundsCleared = challengeRoundsCleared
        runRareLetterWordUsed = rareLetterWordUsed
        runRareLetterWordsTotal = rareLetterWordsTotal
    }
    #endif

    static func buildLateRunSanityReport(from metricsHistory: [RoundDebugMetrics]) -> LateRunSanityReport? {
        let expectedRounds = lateRunSanityRounds
        let expectedSet = Set(expectedRounds)

        var latestByRound: [Int: RoundDebugMetrics] = [:]
        for metrics in metricsHistory where expectedSet.contains(metrics.roundIndex) {
            latestByRound[metrics.roundIndex] = metrics
        }

        let relevant = expectedRounds.compactMap { latestByRound[$0] }
        guard !relevant.isEmpty else { return nil }

        let trackedRounds = relevant.map(\.roundIndex)
        let missingRounds = expectedRounds.filter { latestByRound[$0] == nil }
        let clearedRounds = relevant.filter { $0.outcome == .cleared }.map(\.roundIndex)
        let failedRounds = relevant.filter { $0.outcome == .failed }.map(\.roundIndex)

        let avgSubmits = roundedMetric(
            Double(relevant.map(\.numberOfSubmits).reduce(0, +)) / Double(relevant.count)
        )
        let avgLocksBroken = roundedMetric(
            Double(relevant.map(\.locksBrokenThisRound).reduce(0, +)) / Double(relevant.count)
        )
        let avgLongWords = roundedMetric(
            Double(relevant.map(\.longWordCount).reduce(0, +)) / Double(relevant.count)
        )
        let avgPointsPerWord = roundedMetric(
            relevant.map(\.avgPointsPerWord).reduce(0, +) / Double(relevant.count)
        )
        let avgRoundScore = roundedMetric(
            Double(relevant.map(\.scoreThisRound).reduce(0, +)) / Double(relevant.count)
        )

        let tuningSnapshot = ScoreTuningSnapshot(
            lengthMultipliers: WordScorer.Tunables.lengthMultipliers,
            repeatPenaltyFloor: WordScorer.Tunables.repeatPenaltyFloor,
            lockBonusPerLock: WordScorer.Tunables.lockBonusPerLock,
            bucketScoreMultipliers: Dictionary(uniqueKeysWithValues: (1...RunState.Tunables.totalBuckets).map { bucket in
                let round = ((bucket - 1) * RunState.Tunables.roundsPerBucket) + 1
                return (bucket, RunState.progression(for: round).bucketConfig.scoreMultiplier)
            }),
            milestoneScoreMultipliers: Dictionary(uniqueKeysWithValues: (1...RunState.Tunables.totalBuckets).map { bucket in
                let round = bucket * RunState.Tunables.roundsPerBucket
                return (bucket, RunState.progression(for: round).bucketConfig.milestoneScoreMultiplier)
            })
        )

        var failingChecks: [String] = []
        if !missingRounds.isEmpty {
            failingChecks.append("Missing telemetry for rounds: \(missingRounds.map(String.init).joined(separator: ","))")
        }
        if !failedRounds.isEmpty {
            failingChecks.append("Failed rounds present: \(failedRounds.map(String.init).joined(separator: ","))")
        }
        if !(10.0...12.0).contains(avgSubmits) {
            failingChecks.append("Avg submits \(avgSubmits) outside 10-12")
        }
        if !(2.0...4.0).contains(avgLocksBroken) {
            failingChecks.append("Avg locks broken \(avgLocksBroken) outside 2-4")
        }
        if !(1.0...2.0).contains(avgLongWords) {
            failingChecks.append("Avg long words \(avgLongWords) outside 1-2")
        }
        if !(250.0...500.0).contains(avgPointsPerWord) {
            failingChecks.append("Avg points/word \(avgPointsPerWord) outside 250-500")
        }
        if !(3500.0...6500.0).contains(avgRoundScore) {
            failingChecks.append("Avg round score \(avgRoundScore) outside 3500-6500")
        }

        return LateRunSanityReport(
            trackedRounds: trackedRounds,
            missingRounds: missingRounds,
            capturedAllLateRounds: missingRounds.isEmpty,
            clearedRounds: clearedRounds,
            failedRounds: failedRounds,
            allRoundsCleared: failedRounds.isEmpty && missingRounds.isEmpty,
            avgSubmitsPerRound: avgSubmits,
            avgLocksBrokenPerRound: avgLocksBroken,
            avgLongWordsPerRound: avgLongWords,
            avgPointsPerWord: avgPointsPerWord,
            avgRoundScore: avgRoundScore,
            meetsTargets: failingChecks.isEmpty,
            failingChecks: failingChecks,
            tuningSnapshot: tuningSnapshot
        )
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
        let progression = RunState.progression(for: boardIdx)
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
        run.roundObjectiveThisBoard = progression.objective
        run.roundObjectiveProgressThisBoard = RoundObjectiveProgress()
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
        newBag.rareSpawnRateMultiplier = boardStart.rareSpawnRateMultiplier
        bag = newBag

        var initialBag = bag
        state = Resolver.initialState(
            template: template,
            moves: boardStart.moves,
            dictionary: dictionary,
            bag: &initialBag,
            lockObjectiveTarget: 0,  // locks removed from core run — no locked tiles placed
            generationProfile: RunState.generationProfile(for: boardIdx)
        )
        // Preserve excludedLetters through the bag copy
        bag = initialBag
        bag.excludedLetters = newBag.excludedLetters
        beginRoundDebugTracking(run: run, state: state)

        scene.configureGrid(rows: template.rows, cols: template.cols)
        scene.configureTemplate(template)
        scene.renderBoard(tiles: state.tiles)
        publishBoardIntro(boardIdx: boardIdx, template: template)
        resetWordFeedback()
        syncHUD()
        syncDebugFields(locksBrokenThisMove: 0, submittedWord: "", status: "boardStart:\(boardIdx)")
        #if DEBUG
        print("[BoardStart] round=\(boardIdx) act=\(RunState.act(for: boardIdx)) " +
              "size=\(template.gridSize)x\(template.gridSize) " +
              "moves=\(boardStart.moves) locks=\(boardStart.lockTarget) " +
              "scoreTarget=\(boardStart.scoreTarget) " +
              "rareRate=\(String(format: "%.2f", boardStart.rareSpawnRateMultiplier))x " +
              "challenge=\(run.isChallengeRound)")
        #endif
    }

    private func publishBoardIntro(boardIdx: Int, template: BoardTemplate) {
        let challenge = ChallengeRoundResolver.resolve(roundIndex: boardIdx)
        let roundObjective = runState?.roundObjectiveThisBoard
        currentRound = boardIdx
        currentAct = RunState.act(for: boardIdx)
        isChallengeRound = challenge != nil
        currentChallengeDisplayName = challenge?.displayName
        currentChallengePrimaryText = challenge?.primaryRuleText
        currentChallengeSecondaryLabel = challenge == nil ? nil : roundObjective?.presentationLabel
        currentChallengeSecondaryText = challenge == nil ? nil : roundObjective?.shortDescription
        currentChallengeRuleText = challengePrimaryText(ruleSummary: challenge?.ruleSummary)
        hasStones = !template.stones.isEmpty
        templateDisplayName = templateBannerName(
            for: template,
            challengeDisplayName: challenge?.displayName,
            isChallengeRound: isChallengeRound
        )

        // Pulse the trigger so GameScreen can show the intro each new board.
        showBanner = false
        DispatchQueue.main.async { [weak self] in
            self?.showBanner = true
        }
    }

    private func templateBannerName(
        for template: BoardTemplate,
        challengeDisplayName: String?,
        isChallengeRound: Bool
    ) -> String {
        if isChallengeRound, let challengeDisplayName {
            return challengeDisplayName
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

    private func challengePrimaryText(ruleSummary: String?) -> String? {
        let trimmed = ruleSummary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Modifier hooks

    private struct WordAcceptedHookDelta {
        var scoreDelta: Int = 0
        var moveDelta: Int = 0
        var lockDelta: Int = 0
        var feedbackDetail: String? = nil
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
        var rareSpawnRateMultiplier: Double
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

        for perk in run.equippedStarterPerks {
            switch perk {
            case .pencilGrip:
                break
            case .cleanInk:
                if length >= 6 {
                    delta.scoreDelta += Int((Double(baseScore) * 0.10).rounded())
                    delta.feedbackDetail = "Clean Ink +10%"
                }
            case .spareSeal:
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
                excludedLetters: [],
                rareSpawnRateMultiplier: 1.0
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
        var rareSpawnRateMultiplier = 1.0

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

        let unlockedMilestones = playerProfile.unlockedLifetimeMilestones
        if unlockedMilestones.contains(.build100Words) {
            shuffles += 1
        }
        if unlockedMilestones.contains(.use25RareLetterWords) {
            rareSpawnRateMultiplier *= 1.05
        }

        rareSpawnRateMultiplier *= RunState.rareSpawnMultiplier(for: run.roundIndex)
        if run.isBossBoard, unlockedMilestones.contains(.reachRound20) {
            moves += 1
        }

        var lockTarget = max(0, baseLockTarget + lockTargetFlat)  // 6x6 rebalance: 0 locks allowed in Act 1 early rounds
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
            excludedLetters: excludedLetters,
            rareSpawnRateMultiplier: max(0, rareSpawnRateMultiplier)
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

    private func updateRoundObjectiveProgress(
        word: String,
        points: Int,
        run: inout RunState
    ) {
        run.roundObjectiveProgressThisBoard.submissionsUsed += 1
        run.roundObjectiveProgressThisBoard.totalWordsMade += 1
        run.roundObjectiveProgressThisBoard.bestWordPoints = max(
            run.roundObjectiveProgressThisBoard.bestWordPoints,
            points
        )

        guard let objective = run.roundObjectiveThisBoard else { return }

        switch objective.kind {
        case .totalWords:
            break
        case .wordsWithMinimumLength(_, let minimumLength):
            if word.count >= minimumLength {
                run.roundObjectiveProgressThisBoard.qualifyingWordCount += 1
            }
        case .vowelHeavyWords(_, let minimumVowels):
            let vowelCount = word.filter { LetterBag.vowelSet.contains($0) }.count
            if vowelCount >= minimumVowels {
                run.roundObjectiveProgressThisBoard.qualifyingWordCount += 1
            }
        case .rareLettersUsed:
            let rareLetters = word.reduce(0) { partial, letter in
                partial + (Self.rareLetters.contains(letter) ? 1 : 0)
            }
            run.roundObjectiveProgressThisBoard.rareLettersUsed += rareLetters
        case .maxSubmissions:
            break
        case .wordsWorthAtLeast(_, let minimumPoints):
            if points >= minimumPoints {
                run.roundObjectiveProgressThisBoard.qualifyingWordCount += 1
            }
        case .uniqueLetterWords:
            if Set(word).count == word.count {
                run.roundObjectiveProgressThisBoard.qualifyingWordCount += 1
            }
        case .distinctStartingLetters:
            if let first = word.first {
                run.roundObjectiveProgressThisBoard.distinctStartingLetters.insert(first)
            }
        }
    }

    private func currentObjectiveSatisfied(run: RunState) -> Bool {
        guard let objective = run.roundObjectiveThisBoard else { return true }
        return objective.isSatisfied(by: run.roundObjectiveProgressThisBoard)
    }

    private func currentObjectiveHardFailed(run: RunState) -> Bool {
        guard let objective = run.roundObjectiveThisBoard else { return false }
        let scoreReached = run.scoreThisBoard >= run.scoreGoalForBoard
        return objective.hasHardFailed(by: run.roundObjectiveProgressThisBoard, scoreReached: scoreReached)
    }

    // MARK: - Run condition check

    private func checkRunConditions() {
        guard let run = runState else { return }

        if run.scoreThisBoard >= run.scoreGoalForBoard, currentObjectiveSatisfied(run: run) {
            beginRoundClearTransition()
            return
        }

        if currentObjectiveHardFailed(run: run) {
            finalizeRoundDebugMetrics(outcome: .failed)
            endRun(won: false)
            return
        }

        if state.moves <= 0 && (run.scoreThisBoard < run.scoreGoalForBoard || !currentObjectiveSatisfied(run: run)) {
            finalizeRoundDebugMetrics(outcome: .failed)
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
        finalizeRoundDebugMetrics(outcome: .cleared)
        runRoundsCleared = min(
            RunState.Tunables.totalRounds,
            max(runRoundsCleared, run.roundIndex)
        )
        if run.isChallengeRound {
            runChallengeRoundsCleared = min(
                Self.challengeRoundsCleared(before: RunState.Tunables.totalRounds + 1),
                runChallengeRoundsCleared + 1
            )
        }

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
            SoundManager.shared.playRoundCleared()
            self.grantRoundReward()

            try? await Task.sleep(
                nanoseconds: UInt64(Tunables.roundClearStampDuration * 1_000_000_000)
            )
            guard !Task.isCancelled, let run = self.runState else { return }

            if run.roundIndex >= RunState.Tunables.totalRounds {
                self.showRoundClearStamp = false
                self.endRun(won: true)
                return
            }

            // Show round-cleared popup (pauses run until player taps "Next Round").
            // To skip the popup and auto-advance, replace with advanceBoardSkippingDraft().
            // To restore perk drafts, restore the commented-out 4 lines in the bypass comment above.
            self.showRoundClearStamp = false
            guard let capturedRun = self.runState else { return }
            self.roundClearedInfo = RoundClearedOverlay.Info(
                roundIndex: capturedRun.roundIndex,
                act: capturedRun.act,
                isChallengeRound: capturedRun.isChallengeRound,
                challengeDisplayName: self.currentChallengeDisplayName,
                scoreThisRound: capturedRun.scoreThisBoard,
                scoreGoal: capturedRun.scoreGoalForBoard,
                movesRemaining: self.moves
            )
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
        guard (Resolver.minWordLen...Resolver.maxWordLen).contains(letters.count) else { return false }

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
        guard let hint = Self.findHint(
            state: testState,
            runState: runState,
            dictionary: dictionary,
            preferredLengths: [6, 5, 4]
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
            lastChallengeRegionIDThisBoard: run.lastChallengeRegionIDThisBoard,
            roundObjectiveProgressThisBoard: run.roundObjectiveProgressThisBoard,
            freshSparkCount: run.freshSparkCount,
            freeHintChargesRemaining: run.freeHintChargesRemaining,
            freeUndoChargesRemaining: run.freeUndoChargesRemaining,
            pencilGripRefundUsedThisBoard: run.pencilGripRefundUsedThisBoard,
            spareSealDiscountUsedThisBoard: run.spareSealDiscountUsedThisBoard,
            milestoneLockDiscountUsedThisBoard: run.milestoneLockDiscountUsedThisBoard,
            runTotalScore: runTotalScore,
            runLocksBrokenTotal: runLocksBrokenTotal,
            runWordsBuiltTotal: runWordsBuiltTotal,
            runBestWord: runBestWord,
            runBestWordScore: runBestWordScore,
            runRareLetterWordsTotal: runRareLetterWordsTotal,
            runRareLetterWordUsed: runRareLetterWordUsed
        )
    }

    private func applyLongWordMoveRefund(length: Int, run: inout RunState) -> Int {
        let refundMultiplier = max(0, run.lengthRefundMultiplierThisBoard)
        guard refundMultiplier > 0 else { return 0 }

        guard length >= 6 else {
            return 0
        }

        // Step 28 economy schedule:
        // 6: +1
        // 7-8: +1 +0.25 pending
        // 9-10: +1 +0.50 pending
        // 11-12: +1 +0.75 pending
        // 13-20+: +1 max (no additional pending)
        var rawRefund = RunState.Tunables.longWordBaseRefund
        switch length {
        case 7...8:
            rawRefund += RunState.Tunables.sevenToEightBonusRefund
        case 9...10:
            rawRefund += RunState.Tunables.nineToTenBonusRefund
        case 11...12:
            rawRefund += RunState.Tunables.elevenToTwelveBonusRefund
        default:
            break
        }
        rawRefund *= refundMultiplier

        var refundedMoves = Int(rawRefund.rounded(.down))
        run.pendingMoveFraction += rawRefund - Double(refundedMoves)

        let pendingWholeMoves = Int(run.pendingMoveFraction)
        if pendingWholeMoves > 0 {
            refundedMoves += pendingWholeMoves
            run.pendingMoveFraction -= Double(pendingWholeMoves)
        }

        return refundedMoves
    }

    private func applyLockBreakMoveRefund(lockCount: Int, run: inout RunState) -> Int {
        guard lockCount > 0 else { return 0 }
        let refundMultiplier = max(0, run.lockBreakRefundMultiplierThisBoard)
        guard refundMultiplier > 0 else { return 0 }
        return max(0, Int((Double(lockCount) * refundMultiplier).rounded(.down)))
    }

    private func refundToastText(for refundedMoves: Int) -> String {
        refundedMoves == 1 ? "+1 Move" : "+\(refundedMoves) Moves"
    }

    private func applyDebugBootstrap(to run: inout RunState, options: DebugRunOptions) {
        let startRound = options.normalizedStartRound
        guard startRound > 1 else { return }

        run.roundIndex = startRound
        run.wordUseCounts = seededWordUseCounts()
        run.activePerks = [.tightGloves, .freeHint, .vowelBloom]
        run.inventory.hints = 2
        run.inventory.wildcards = 1
        run.inventory.undos = 1
    }

    private func seededWordUseCounts() -> [String: Int] {
        let seededWords = [
            "GAME", "WORD", "TILE", "LOCK", "SCORE", "ROUND",
            "BOARD", "CHAIN", "CLEAR", "STONE", "TRACE", "GLOW",
            "LIGHT", "RAIN", "FALL", "SWIFT", "SPELL", "STACK"
        ]

        return seededWords.enumerated().reduce(into: [String: Int]()) { result, entry in
            let count = entry.offset.isMultiple(of: 3) ? 3 : 2
            result[entry.element] = count
        }
    }

    private func beginRoundDebugTracking(run: RunState, state: GameState) {
        roundDebugTracker = RoundDebugTracker(
            roundIndex: run.roundIndex,
            act: run.act,
            isChallengeRound: run.isChallengeRound,
            movesStart: state.moves,
            scoreTarget: run.scoreGoalForBoard,
            locksAvailable: countLockedTiles(in: state.tiles)
        )
    }

    private func recordAcceptedSubmitForDebug(
        word: String,
        points: Int,
        length: Int,
        usedLockedTiles: Bool,
        moveRefunds: Int
    ) {
        guard var tracker = roundDebugTracker else { return }
        tracker.numberOfSubmits += 1
        tracker.totalWordLength += length
        tracker.totalPoints += points
        if usedLockedTiles {
            tracker.lockedSubmitCount += 1
        }
        if length >= 7 {
            tracker.longWordCount += 1
        }
        tracker.netMoveRefunds += max(0, moveRefunds)
        if points > tracker.bestWordPoints {
            tracker.bestWord = word
            tracker.bestWordPoints = points
        }
        roundDebugTracker = tracker
    }

    private func recordInvalidSubmitForDebug() {
        guard var tracker = roundDebugTracker else { return }
        tracker.invalidSubmitCount += 1
        roundDebugTracker = tracker
    }

    private func recordHintUseForDebug() {
        guard var tracker = roundDebugTracker else { return }
        tracker.hintsUsed += 1
        roundDebugTracker = tracker
    }

    private func recordShuffleUseForDebug() {
        guard var tracker = roundDebugTracker else { return }
        tracker.shufflesUsed += 1
        roundDebugTracker = tracker
    }

    private func finalizeRoundDebugMetrics(outcome: RoundDebugOutcome) {
        guard let run = runState, let tracker = roundDebugTracker else { return }

        let submits = max(0, tracker.numberOfSubmits)
        let avgWordLength = submits > 0 ? Self.roundedMetric(Double(tracker.totalWordLength) / Double(submits)) : 0
        let avgPointsPerWord = submits > 0 ? Self.roundedMetric(Double(tracker.totalPoints) / Double(submits)) : 0

        let metrics = RoundDebugMetrics(
            outcome: outcome,
            roundIndex: tracker.roundIndex,
            act: tracker.act,
            isChallengeRound: tracker.isChallengeRound,
            movesStart: tracker.movesStart,
            movesEnd: state.moves,
            scoreTarget: tracker.scoreTarget,
            scoreThisRound: run.scoreThisBoard,
            locksAvailable: tracker.locksAvailable,
            locksBrokenThisRound: run.locksBrokenThisBoard,
            numberOfSubmits: tracker.numberOfSubmits,
            avgWordLength: avgWordLength,
            avgPointsPerWord: avgPointsPerWord,
            bestWord: tracker.bestWord,
            bestWordPoints: tracker.bestWordPoints,
            longWordCount: tracker.longWordCount,
            lockedSubmitCount: tracker.lockedSubmitCount,
            netMoveRefunds: tracker.netMoveRefunds,
            shufflesUsed: tracker.shufflesUsed,
            hintsUsed: tracker.hintsUsed,
            invalidSubmitCount: tracker.invalidSubmitCount
        )

        lastRoundDebugMetrics = metrics
        roundDebugTracker = nil
        roundDebugHistory.append(metrics)
        refreshLateRunSanityReport()

        if let json = Self.jsonString(for: metrics) {
            lastRoundDebugMetricsLog = json
            if debugRunOptions.roundMetricsLoggingEnabled {
                print("[RoundMetrics] \(json)")
            }
        } else {
            lastRoundDebugMetricsLog = nil
        }
    }

    private func refreshScoreTargetCurveSnapshot() {
        scoreTargetCurve = RunState.scoreTargetCurve()
        if let json = Self.jsonString(for: scoreTargetCurve) {
            scoreTargetCurveLog = json
            if debugRunOptions.roundMetricsLoggingEnabled {
                print("[ScoreCurve] \(json)")
            }
        } else {
            scoreTargetCurveLog = nil
        }
    }

    private func refreshLateRunSanityReport() {
        lateRunSanityReport = Self.buildLateRunSanityReport(from: roundDebugHistory)
        guard let report = lateRunSanityReport else {
            lateRunSanityReportLog = nil
            return
        }

        if let json = Self.jsonString(for: report) {
            lateRunSanityReportLog = json
            if debugRunOptions.roundMetricsLoggingEnabled {
                print("[LateRunSanity] \(json)")
            }
        } else {
            lateRunSanityReportLog = nil
        }
    }

    private static func jsonString<T: Encodable>(for value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func roundedMetric(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    nonisolated static func calculateXP(
        roundsCleared: Int,
        totalScore: Int,
        challengeRoundsCleared: Int,
        rareLetterWordUsed: Bool
    ) -> Int {
        let baseXP = 40
        let roundsXP = 12 * max(0, roundsCleared)
        let scoreXP = max(0, totalScore) / 250
        let challengeXP = 25 * max(0, challengeRoundsCleared)
        let rareXP = rareLetterWordUsed ? 10 : 0
        return baseXP + roundsXP + scoreXP + challengeXP + rareXP
    }

    nonisolated static func wordContainsRareLetter(_ word: String) -> Bool {
        return word.uppercased().contains { rareLetters.contains($0) }
    }

    nonisolated static func challengeRoundsCleared(before roundIndex: Int) -> Int {
        guard roundIndex > 1 else { return 0 }
        return (1..<roundIndex).reduce(into: 0) { count, round in
            if RunState.isChallengeRound(for: round) {
                count += 1
            }
        }
    }

    private func countLockedTiles(in tiles: [Tile?]) -> Int {
        tiles.compactMap { $0 }.filter { $0.freshness == .freshLocked }.count
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

    private func publishSubmitOutcome(
        _ outcome: SubmitOutcome,
        points: Int,
        autoReset: Bool,
        detail: String? = nil
    ) {
        submitFeedbackResetTask?.cancel()
        submitFeedbackResetTask = nil
        lastSubmitOutcome = outcome
        lastSubmitPoints = max(0, points)
        lastSubmitFeedbackDetail = detail
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
        lastSubmitFeedbackDetail = nil
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
        let currentRunState = runState
        let dict = dictionary
        hintTask = Task.detached(priority: .userInitiated) { [weak self] in
            let hint = GameSessionController.findHint(
                state: currentState,
                runState: currentRunState,
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

    nonisolated private static func findHint(
        state: GameState,
        runState: RunState?,
        dictionary: WordDictionary,
        preferredLengths: [Int]
    ) -> HintPath? {
        let minimumLength = Resolver.minimumWordLength(for: state.boardTemplate)
        let lengths = preferredLengths.filter { $0 >= minimumLength }

        switch state.boardTemplate.specialRule {
        case .singlePoolPerWord, .alternatingPools:
            let blockedRegion = state.boardTemplate.specialRule == .alternatingPools
                ? runState?.lastChallengeRegionIDThisBoard
                : nil

            for regionID in state.boardTemplate.regionIDs where regionID != blockedRegion {
                let allowedIndices = Set(
                    state.boardTemplate.regions.compactMap { index, candidateRegionID in
                        candidateRegionID == regionID ? index : nil
                    }
                )
                if let hint = HintFinder.findFreePickHint(
                    state: state,
                    dictionary: dictionary,
                    preferredLengths: lengths,
                    allowedIndices: allowedIndices
                ) {
                    return hint
                }
            }
            return nil
        default:
            return HintFinder.findFreePickHint(
                state: state,
                dictionary: dictionary,
                preferredLengths: lengths
            )
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
            var parts = ["Score: \(run.scoreThisBoard)/\(run.scoreGoalForBoard)"]
            if let objective = run.roundObjectiveThisBoard {
                parts.append(objective.progressText(using: run.roundObjectiveProgressThisBoard))
            }
            self.objectivesText = parts.joined(separator: " · ")
        } else {
            self.objectivesText = "Score: \(state.score)"
        }
    }
}
