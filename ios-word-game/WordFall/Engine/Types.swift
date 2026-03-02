import Foundation

enum TileFreshness: Equatable {
    case normal
    case freshLocked
    case freshUnlocked
}

struct Tile: Equatable {
    let id: UUID
    let letter: Character
    var freshness: TileFreshness = .normal
}

struct GameState {
    let rows: Int
    let cols: Int
    var tiles: [Tile?]
    var score: Int
    var moves: Int
    var inkPoints: Int
    var usedTileIds: Set<UUID>
    var totalLocksBroken: Int
    var lockObjectiveTarget: Int

    static let defaultRows = 7
    static let defaultCols = 7
    static let defaultMoves = 20
    static let defaultTargetLocks = 6
}

enum GameAction {
    case submitPath(indices: [Int])
}

struct DropMove {
    let tileID: UUID
    let fromIndex: Int
    let toIndex: Int
}

struct SpawnMove {
    let tile: Tile
    let toIndex: Int
    let spawnRowOffset: Int
}

struct ClearEvent {
    let indices: [Int]
    let word: String
    let awardedPoints: Int
    let isCascade: Bool
    let cascadeStep: Int
}

enum GameEvent {
    case lockBreak(indices: [Int])
    case clear(ClearEvent)
    case drop([DropMove])
    case spawn([SpawnMove])
}
