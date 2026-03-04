import Foundation
@testable import ios_word_game

enum LockState {
    case none
    case locked
    case unlocked
}

enum TestBuilders {
    static let defaultRows = GameState.defaultRows
    static let defaultCols = GameState.defaultCols
    static let defaultBoard: [Tile?] = Array(
        repeating: nil,
        count: GameState.defaultRows * GameState.defaultCols
    )

    static func makeTile(
        letter: Character,
        value: Int = 1,
        lockState: LockState = .none,
        isWildcard: Bool = false,
        id: UUID = UUID()
    ) -> Tile {
        // Tile score values are derived by the engine's LetterValues, not stored on Tile.
        _ = value

        var tile = Tile(id: id, letter: isWildcard ? "?" : letter)
        switch lockState {
        case .none:
            tile.freshness = .normal
        case .locked:
            tile.freshness = .freshLocked
        case .unlocked:
            tile.freshness = .freshUnlocked
        }
        tile.kind = isWildcard ? .wildcard : .normal
        return tile
    }

    static func makeState(
        tiles: [Tile?] = defaultBoard,
        moves: Int = 20,
        score: Int = 0,
        usedTileIds: Set<UUID> = [],
        locksBroken: Int = 0,
        rows: Int = defaultRows,
        cols: Int = defaultCols,
        inkPoints: Int = 0,
        lockObjectiveTarget: Int = GameState.defaultTargetLocks
    ) -> GameState {
        let boardCount = rows * cols
        var normalizedTiles = tiles
        if normalizedTiles.count < boardCount {
            normalizedTiles += Array(repeating: nil, count: boardCount - normalizedTiles.count)
        } else if normalizedTiles.count > boardCount {
            normalizedTiles = Array(normalizedTiles.prefix(boardCount))
        }

        return GameState(
            rows: rows,
            cols: cols,
            tiles: normalizedTiles,
            score: score,
            moves: moves,
            inkPoints: inkPoints,
            usedTileIds: usedTileIds,
            totalLocksBroken: locksBroken,
            lockObjectiveTarget: lockObjectiveTarget
        )
    }

    // Compatibility helpers used by existing tests.
    static func makeTile(_ letter: Character, freshness: TileFreshness = .normal, id: UUID = UUID()) -> Tile {
        let lockState: LockState
        switch freshness {
        case .normal:
            lockState = .none
        case .freshLocked:
            lockState = .locked
        case .freshUnlocked:
            lockState = .unlocked
        }

        return makeTile(letter: letter, lockState: lockState, id: id)
    }

    static func makeState(rows: Int, cols: Int, tiles: [Tile?]) -> GameState {
        makeState(
            tiles: tiles,
            moves: 5,
            score: 0,
            usedTileIds: [],
            locksBroken: 0,
            rows: rows,
            cols: cols,
            inkPoints: 0,
            lockObjectiveTarget: 6
        )
    }
}
