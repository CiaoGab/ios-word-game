import Foundation

enum SubmissionRejectionReason: String {
    case invalidLength
    case outOfBounds
    case reusedTile
    case nonAdjacent
    case emptyTile
    case notInDictionary
}

struct ResolverResult {
    let newState: GameState
    let events: [GameEvent]
    let accepted: Bool
    let acceptedWord: String?
    let rejectionReason: SubmissionRejectionReason?
    let scoreDelta: Int
    let movesDelta: Int
    let inkDelta: Int
    let clearedCount: Int
    let locksBrokenThisMove: Int
    let currentLockedCount: Int
    let lastSubmittedWord: String
}

enum Resolver {
    static let minWordLen = 3
    static let maxWordLen = 6
    static let targetLocks = GameState.defaultTargetLocks

    static let hardLockLetters: Set<Character> = ["Q", "Z", "X", "J", "K", "V", "W"]
    private static let preferredConsonants: Set<Character> = ["T", "N", "R", "S", "L", "D", "G", "C", "M", "P", "H", "B", "F", "Y"]

    static func initialState(
        rows: Int = GameState.defaultRows,
        cols: Int = GameState.defaultCols,
        moves: Int = GameState.defaultMoves,
        dictionary: WordDictionary,
        bag: inout LetterBag
    ) -> GameState {
        var initial = GameState(
            rows: rows,
            cols: cols,
            tiles: generateFilledTiles(rows: rows, cols: cols, bag: &bag),
            score: 0,
            moves: moves,
            inkPoints: 0,
            usedTileIds: [],
            totalLocksBroken: 0,
            lockObjectiveTarget: targetLocks
        )

        ensureTargetLocks(state: &initial)
        return initial
    }

    static func reduce(
        state: GameState,
        action: GameAction,
        dictionary: WordDictionary,
        bag: inout LetterBag
    ) -> ResolverResult {
        switch action {
        case .submitPath(let indices):
            return reducePath(state: state, path: indices, dictionary: dictionary, bag: &bag)
        }
    }

    private static func reducePath(
        state: GameState,
        path: [Int],
        dictionary: WordDictionary,
        bag: inout LetterBag
    ) -> ResolverResult {
        if let rejection = validatePath(path, rows: state.rows, cols: state.cols) {
            return rejected(state: state, reason: rejection, path: path, submittedWord: "")
        }

        guard let rawWord = Selection.word(from: state.tiles, indices: path) else {
            return rejected(state: state, reason: .emptyTile, path: path, submittedWord: "")
        }

        guard let acceptedWord = dictionary.matchedWordEitherDirection(rawWord) else {
            return rejected(state: state, reason: .notInDictionary, path: path, submittedWord: rawWord)
        }

        var newState = state
        var events: [GameEvent] = []
        var clearIndices: [Int] = []
        var lockBreakIndices: [Int] = []

        for index in path {
            guard var tile = newState.tiles[index] else { continue }
            newState.usedTileIds.insert(tile.id)

            switch tile.freshness {
            case .freshLocked:
                tile.freshness = .freshUnlocked
                newState.tiles[index] = tile
                lockBreakIndices.append(index)
            case .normal, .freshUnlocked:
                clearIndices.append(index)
            }
        }

        let locksBrokenThisMove = lockBreakIndices.count
        if !lockBreakIndices.isEmpty {
            events.append(.lockBreak(indices: lockBreakIndices.sorted()))
        }

        let letterSum = LetterValues.sum(for: acceptedWord)
        let points = Scoring.baseWordPoints(letterSum: letterSum, length: acceptedWord.count)
        let ink = Scoring.inkPoints(letterSum: letterSum, length: acceptedWord.count, isCascade: false)
        newState.score += points
        newState.inkPoints += ink
        newState.moves = max(0, newState.moves - 1)
        newState.totalLocksBroken += locksBrokenThisMove

        for index in clearIndices {
            newState.tiles[index] = nil
        }

        if !clearIndices.isEmpty {
            events.append(.clear(ClearEvent(
                indices: clearIndices.sorted(),
                word: acceptedWord,
                awardedPoints: points,
                isCascade: false,
                cascadeStep: 0
            )))
        }

        applyGravityAndSpawn(state: &newState, events: &events, bag: &bag)
        ensureTargetLocks(state: &newState)

        let scoreDelta = newState.score - state.score
        let movesDelta = newState.moves - state.moves
        let inkDelta = newState.inkPoints - state.inkPoints
        let currentLockedCount = countLockedTiles(in: newState.tiles)

        return ResolverResult(
            newState: newState,
            events: events,
            accepted: true,
            acceptedWord: acceptedWord,
            rejectionReason: nil,
            scoreDelta: scoreDelta,
            movesDelta: movesDelta,
            inkDelta: inkDelta,
            clearedCount: clearIndices.count,
            locksBrokenThisMove: locksBrokenThisMove,
            currentLockedCount: currentLockedCount,
            lastSubmittedWord: rawWord
        )
    }

    private static func applyGravityAndSpawn(state: inout GameState, events: inout [GameEvent], bag: inout LetterBag) {
        let gravityResult = Gravity.apply(tiles: state.tiles, rows: state.rows, cols: state.cols)
        state.tiles = gravityResult.tiles

        if !gravityResult.drops.isEmpty {
            events.append(.drop(gravityResult.drops))
        }

        let spawnResult = Gravity.spawn(
            into: state.tiles,
            emptyIndices: gravityResult.emptyIndices,
            rows: state.rows,
            cols: state.cols,
            bag: &bag
        )

        state.tiles = spawnResult.tiles
        if !spawnResult.spawns.isEmpty {
            events.append(.spawn(spawnResult.spawns))
        }
    }

    private static func ensureTargetLocks(state: inout GameState) {
        let currentLockedCount = countLockedTiles(in: state.tiles)
        guard currentLockedCount < targetLocks else { return }

        let needed = targetLocks - currentLockedCount
        let candidates = lockCandidates(tiles: state.tiles, usedTileIds: state.usedTileIds)
        guard !candidates.isEmpty else { return }

        for index in candidates.prefix(needed) {
            guard var tile = state.tiles[index] else { continue }
            tile.freshness = .freshLocked
            state.tiles[index] = tile
        }
    }

    private static func lockCandidates(tiles: [Tile?], usedTileIds: Set<UUID>) -> [Int] {
        var prioritized: [(index: Int, priority: Int)] = []

        for index in tiles.indices {
            guard let tile = tiles[index] else { continue }
            guard tile.freshness == .normal else { continue }
            guard !usedTileIds.contains(tile.id) else { continue }
            guard !hardLockLetters.contains(tile.letter) else { continue }

            prioritized.append((index, lockPriority(for: tile.letter)))
        }

        prioritized.shuffle()
        prioritized.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.index < rhs.index
        }

        return prioritized.map(\.index)
    }

    private static func lockPriority(for letter: Character) -> Int {
        if LetterBag.vowelSet.contains(letter) {
            return 0
        }
        if preferredConsonants.contains(letter) {
            return 1
        }
        return 2
    }

    private static func countLockedTiles(in tiles: [Tile?]) -> Int {
        tiles.compactMap { $0 }.filter { $0.freshness == .freshLocked }.count
    }

    private static func generateFilledTiles(rows: Int, cols: Int, bag: inout LetterBag) -> [Tile?] {
        var tiles = [Tile?](repeating: nil, count: rows * cols)
        var existingCounts: [Character: Int] = [:]
        for index in tiles.indices {
            tiles[index] = bag.nextTile(respecting: LetterBag.rareCaps, existingCounts: &existingCounts)
        }
        return tiles
    }

    private static func pathIsAdjacent(_ path: [Int], cols: Int) -> Bool {
        guard path.count >= 2 else { return true }

        for idx in 1..<path.count {
            let a = path[idx - 1]
            let b = path[idx]
            let rowDelta = abs(a / cols - b / cols)
            let colDelta = abs(a % cols - b % cols)
            if rowDelta + colDelta != 1 {
                return false
            }
        }

        return true
    }

    private static func validatePath(_ path: [Int], rows: Int, cols: Int) -> SubmissionRejectionReason? {
        guard (minWordLen...maxWordLen).contains(path.count) else {
            return .invalidLength
        }

        let boardSize = rows * cols
        guard path.allSatisfy({ (0..<boardSize).contains($0) }) else {
            return .outOfBounds
        }

        guard Set(path).count == path.count else {
            return .reusedTile
        }

        guard pathIsAdjacent(path, cols: cols) else {
            return .nonAdjacent
        }

        return nil
    }

    private static func rejected(
        state: GameState,
        reason: SubmissionRejectionReason,
        path: [Int],
        submittedWord: String
    ) -> ResolverResult {
        return ResolverResult(
            newState: state,
            events: [],
            accepted: false,
            acceptedWord: nil,
            rejectionReason: reason,
            scoreDelta: 0,
            movesDelta: 0,
            inkDelta: 0,
            clearedCount: 0,
            locksBrokenThisMove: 0,
            currentLockedCount: countLockedTiles(in: state.tiles),
            lastSubmittedWord: submittedWord.isEmpty ? "" : submittedWord
        )
    }
}
