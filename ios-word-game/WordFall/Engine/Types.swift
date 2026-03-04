import Foundation

enum TileFreshness: Equatable {
    case normal
    case freshLocked
    case freshUnlocked
}

enum TileKind: Equatable {
    case normal
    case wildcard
    case stone
}

/// Visual-only tile accent marker. Gameplay/scoring logic does not depend on this value.
enum TileInfusion: String, Equatable {
    case none
    case x2
    case x3
    case bonus
}

struct Tile: Equatable {
    let id: UUID
    var letter: Character
    var freshness: TileFreshness = .normal
    var kind: TileKind = .normal
    var infusion: TileInfusion = .none

    var isStone: Bool { kind == .stone }
    var isLetterTile: Bool { kind != .stone }

    static func stone(id: UUID = UUID()) -> Tile {
        Tile(id: id, letter: "#", freshness: .normal, kind: .stone, infusion: .none)
    }
}

enum AdjacencyMode: Equatable {
    case hvOnly
    case hvAndDiagonals
}

struct BoardTemplate: Equatable {
    let id: String
    let name: String
    let gridSize: Int
    let adjacency: AdjacencyMode
    let mask: Set<Int>
    let stones: Set<Int>

    init(
        id: String,
        name: String,
        gridSize: Int,
        adjacency: AdjacencyMode = .hvOnly,
        mask: Set<Int>,
        stones: Set<Int> = []
    ) {
        let cellCount = gridSize * gridSize
        let validMask = Set(mask.filter { $0 >= 0 && $0 < cellCount })
        self.id = id
        self.name = name
        self.gridSize = gridSize
        self.adjacency = adjacency
        self.mask = validMask
        self.stones = Set(stones.filter { validMask.contains($0) })
    }

    func isPlayable(_ index: Int) -> Bool {
        mask.contains(index)
    }

    func isStone(_ index: Int) -> Bool {
        stones.contains(index)
    }

    var playableCount: Int {
        mask.count
    }

    var rows: Int { gridSize }
    var cols: Int { gridSize }

    static func full(
        gridSize: Int,
        id: String,
        name: String,
        adjacency: AdjacencyMode = .hvOnly,
        stones: Set<Int> = []
    ) -> BoardTemplate {
        let count = gridSize * gridSize
        return BoardTemplate(
            id: id,
            name: name,
            gridSize: gridSize,
            adjacency: adjacency,
            mask: Set(0..<count),
            stones: stones
        )
    }

    static func template(for boardIndex: Int) -> BoardTemplate {
        switch boardIndex {
        case 1, 2, 3, 4:
            return act1Standard7
        case 5:
            return boss5Hourglass
        case 6:
            return act2SixA
        case 7:
            return act2DiamondA
        case 8:
            return act2SixB
        case 9:
            return act2DiamondB
        case 10:
            return boss10Trident
        case 11:
            return act3SixA
        case 12:
            return act3DiamondA
        case 13:
            return act3SixB
        case 14:
            return act3DiamondB
        case 15:
            return boss15Fortress
        default:
            return act1Standard7
        }
    }

    private static let act1Standard7: BoardTemplate = .full(
        gridSize: 7,
        id: "act1_standard_7x7",
        name: "Act 1 Standard"
    )

    private static let boss5Hourglass: BoardTemplate = BoardTemplate(
        id: "boss5_hourglass",
        name: "Boss 5 Hourglass",
        gridSize: 7,
        adjacency: .hvAndDiagonals,
        mask: maskFromRows(7, rows: [
            [1, 2, 3, 4, 5],
            [0, 1, 2, 3, 4, 5, 6],
            [1, 2, 3, 4, 5],
            [2, 3, 4],
            [1, 2, 3, 4, 5],
            [0, 1, 2, 3, 4, 5, 6],
            [1, 2, 3, 4, 5]
        ])
    )

    private static let act2SixA: BoardTemplate = .full(
        gridSize: 6,
        id: "act2_six_a",
        name: "Act 2 Six A",
        stones: indices(6, coords: [(2, 2), (3, 3)])
    )

    private static let act2DiamondA: BoardTemplate = BoardTemplate(
        id: "act2_diamond_a",
        name: "Act 2 Diamond A",
        gridSize: 7,
        adjacency: .hvAndDiagonals,
        mask: diamondMask(7, radius: 4),
        stones: indices(7, coords: [(2, 3)])
    )

    private static let act2SixB: BoardTemplate = .full(
        gridSize: 6,
        id: "act2_six_b",
        name: "Act 2 Six B",
        stones: indices(6, coords: [(1, 3), (3, 1), (4, 4)])
    )

    private static let act2DiamondB: BoardTemplate = BoardTemplate(
        id: "act2_diamond_b",
        name: "Act 2 Diamond B",
        gridSize: 7,
        adjacency: .hvAndDiagonals,
        mask: diamondMask(7, radius: 5),
        stones: indices(7, coords: [(3, 1), (3, 5)])
    )

    private static let boss10Trident: BoardTemplate = BoardTemplate(
        id: "boss10_trident",
        name: "Boss 10 Trident",
        gridSize: 7,
        mask: maskFromRows(7, rows: [
            [1, 2, 3, 4, 5],
            [1, 3, 5],
            [1, 3, 5],
            [0, 1, 2, 3, 4, 5, 6],
            [2, 3, 4],
            [2, 4],
            [2, 4]
        ]),
        stones: indices(7, coords: [(1, 3), (5, 4)])
    )

    private static let act3SixA: BoardTemplate = .full(
        gridSize: 6,
        id: "act3_six_a",
        name: "Act 3 Six A",
        stones: indices(6, coords: [(1, 1), (1, 4), (3, 2), (4, 4)])
    )

    private static let act3DiamondA: BoardTemplate = BoardTemplate(
        id: "act3_diamond_a",
        name: "Act 3 Diamond A",
        gridSize: 7,
        adjacency: .hvAndDiagonals,
        mask: diamondMask(7, radius: 4),
        stones: indices(7, coords: [(2, 2), (2, 4), (4, 2), (4, 4)])
    )

    private static let act3SixB: BoardTemplate = .full(
        gridSize: 6,
        id: "act3_six_b",
        name: "Act 3 Six B",
        stones: indices(6, coords: [(0, 4), (2, 1), (2, 4), (4, 2), (5, 3)])
    )

    private static let act3DiamondB: BoardTemplate = BoardTemplate(
        id: "act3_diamond_b",
        name: "Act 3 Diamond B",
        gridSize: 7,
        adjacency: .hvAndDiagonals,
        mask: diamondMask(7, radius: 5),
        stones: indices(7, coords: [(1, 3), (3, 2), (3, 4), (5, 2), (5, 4)])
    )

    private static let boss15Fortress: BoardTemplate = BoardTemplate(
        id: "boss15_fortress",
        name: "Boss 15 Fortress",
        gridSize: 7,
        mask: maskFromRows(7, rows: [
            [1, 2, 3, 4, 5],
            [0, 1, 2, 3, 4, 5, 6],
            [0, 2, 3, 4, 6],
            [0, 2, 4, 6],
            [0, 2, 3, 4, 6],
            [0, 1, 2, 3, 4, 5, 6],
            [1, 2, 3, 4, 5]
        ]),
        stones: indices(7, coords: [(2, 3), (4, 3)])
    )

    private static func indices(_ size: Int, coords: [(Int, Int)]) -> Set<Int> {
        Set(coords.compactMap { row, col in
            guard row >= 0, row < size, col >= 0, col < size else { return nil }
            return row * size + col
        })
    }

    private static func maskFromRows(_ size: Int, rows: [[Int]]) -> Set<Int> {
        var result: Set<Int> = []
        for (row, cols) in rows.enumerated() where row < size {
            for col in cols where col >= 0 && col < size {
                result.insert(row * size + col)
            }
        }
        return result
    }

    private static func diamondMask(_ size: Int, radius: Int) -> Set<Int> {
        let center = size / 2
        var result: Set<Int> = []
        for row in 0..<size {
            for col in 0..<size {
                let distance = abs(row - center) + abs(col - center)
                if distance <= radius {
                    result.insert(row * size + col)
                }
            }
        }
        return result
    }
}

struct GameState {
    let rows: Int
    let cols: Int
    let boardTemplate: BoardTemplate
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

/// Lightweight per-tile metadata exposed to the word-pill tile renderer.
struct SelectionTileMeta {
    let isWildcard: Bool
    let freshness: TileFreshness
    let infusion: TileInfusion
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
