import Foundation
import SpriteKit
import Combine

@MainActor
final class GameSessionController: ObservableObject {
    @Published var score: Int = 0
    @Published var moves: Int = 0
    @Published var objectivesText: String = "Break Locks: 0/0"

    @Published var lastSubmittedWord: String = ""
    @Published var status: String = "idle"
    @Published var locksBrokenThisMove: Int = 0
    @Published var locksBrokenTotal: Int = 0
    @Published var currentLockedCount: Int = 0
    @Published var usedTileIdsCount: Int = 0
    @Published var isAnimating: Bool = false
    @Published var activePathLength: Int = 0
    @Published var hintPath: [Int]? = nil
    @Published var hintWord: String? = nil
    @Published var hintIsValid: Bool = false

    let scene: BoardScene

    private let dictionary: WordDictionary
    private var bag: LetterBag
    private var state: GameState
    private var idleTimer: Timer? = nil
    private var hintTask: Task<Void, Never>? = nil
    private let idleDelay: TimeInterval = 6.0

    init(rows: Int = 7, cols: Int = 7) {
        self.bag = LetterBag()
        self.dictionary = WordDictionary.loadFromBundle()

        var initialBag = bag
        self.state = Resolver.initialState(rows: rows, cols: cols, dictionary: dictionary, bag: &initialBag)
        self.bag = initialBag

        self.scene = BoardScene(rows: rows, cols: cols, size: CGSize(width: 360, height: 360))
        configureSceneCallbacks()
        scene.renderBoard(tiles: state.tiles)
        syncHUD()
        syncDebugFields(locksBrokenThisMove: 0, submittedWord: "", status: "idle")
    }

    func updateSceneSize(_ size: CGSize) {
        scene.updateLayout(for: size)
    }

    func submitPath(indices: [Int]) {
        guard !isAnimating else { return }

        clearHint() // a new submission makes any pending hint stale

        var localBag = bag
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: indices),
            dictionary: dictionary,
            bag: &localBag
        )

        if result.accepted {
            bag = localBag
            state = result.newState
            score = result.newState.score
            moves = result.newState.moves
            Haptics.notifySuccess()
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

        isAnimating = true
        scene.inputLocked = true

        guard !result.events.isEmpty else {
            scene.renderBoard(tiles: state.tiles)
            isAnimating = false
            scene.inputLocked = false
            resetIdleTimer()
            return
        }

        scene.play(events: result.events) { [weak self] in
            guard let self else { return }
            self.scene.renderBoard(tiles: self.state.tiles)
            self.isAnimating = false
            self.scene.inputLocked = false
            self.resetIdleTimer()
        }
    }

    /// Immediately computes and shows a hint path (manual trigger hook).
    func requestHint() {
        computeAndPublishHint()
    }

    func currentBoard() -> [Tile?] {
        state.tiles
    }

    // MARK: - Private setup

    private func configureSceneCallbacks() {
        scene.onSubmitPath = { [weak self] path in
            Task { @MainActor in
                self?.submitPath(indices: path)
            }
        }

        scene.onRequestBoard = { [weak self] in
            self?.currentBoard() ?? []
        }

        scene.onAnyTouch = { [weak self] in
            Task { @MainActor in
                self?.handleAnyTouch()
            }
        }

        scene.onPathLengthChanged = { [weak self] length in
            Task { @MainActor in
                self?.activePathLength = length
            }
        }
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
        hintTask?.cancel()
        let currentState = state
        let dict = dictionary
        hintTask = Task.detached(priority: .userInitiated) { [weak self] in
            let hint = HintFinder.findHint3(state: currentState, dictionary: dict)
            let isValid = hint.map { HintFinder.validateHint($0.indices, state: currentState, dictionary: dict) } ?? false
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                self.hintPath = hint?.indices
                self.hintWord = hint?.word
                self.hintIsValid = isValid
                self.scene.applyHint(hint?.indices)
            }
        }
    }

    private func syncHUD() {
        score = state.score
        moves = state.moves
    }

    private func syncDebugFields(locksBrokenThisMove: Int, submittedWord: String, status: String) {
        self.locksBrokenThisMove = locksBrokenThisMove
        self.lastSubmittedWord = submittedWord
        self.status = status
        self.locksBrokenTotal = state.totalLocksBroken
        self.currentLockedCount = state.tiles.compactMap { $0 }.filter { $0.freshness == .freshLocked }.count
        self.usedTileIdsCount = state.usedTileIds.count
        self.objectivesText = "Break Locks: \(state.totalLocksBroken)/\(state.lockObjectiveTarget)"
    }
}
