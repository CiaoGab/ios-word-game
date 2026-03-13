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

enum BoardVisualStyle: Equatable {
    case standard
    case triplePoolsBalanced
}

struct BoardTemplate: Equatable {
    let id: String
    let name: String
    let gridSize: Int
    let adjacency: AdjacencyMode
    let mask: Set<Int>
    let stones: Set<Int>
    let specialRule: ChallengeSpecialRule
    let regions: [Int: Int]
    let minimumVowelsPerRegion: Int
    let visualStyle: BoardVisualStyle

    init(
        id: String,
        name: String,
        gridSize: Int,
        adjacency: AdjacencyMode = .hvOnly,
        mask: Set<Int>,
        stones: Set<Int> = [],
        specialRule: ChallengeSpecialRule = .none,
        regions: [Int: Int] = [:],
        minimumVowelsPerRegion: Int = 0,
        visualStyle: BoardVisualStyle = .standard
    ) {
        let cellCount = gridSize * gridSize
        let validMask = Set(mask.filter { $0 >= 0 && $0 < cellCount })
        self.id = id
        self.name = name
        self.gridSize = gridSize
        self.adjacency = adjacency
        self.mask = validMask
        self.stones = Set(stones.filter { validMask.contains($0) })
        self.specialRule = specialRule
        self.regions = regions.reduce(into: [Int: Int]()) { result, entry in
            if validMask.contains(entry.key) {
                result[entry.key] = entry.value
            }
        }
        self.minimumVowelsPerRegion = max(0, minimumVowelsPerRegion)
        self.visualStyle = visualStyle
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

    func regionID(for index: Int) -> Int? {
        regions[index]
    }

    var regionIDs: [Int] {
        Array(Set(regions.values)).sorted()
    }

    static func full(
        gridSize: Int,
        id: String,
        name: String,
        adjacency: AdjacencyMode = .hvOnly,
        stones: Set<Int> = [],
        specialRule: ChallengeSpecialRule = .none,
        regions: [Int: Int] = [:],
        minimumVowelsPerRegion: Int = 0,
        visualStyle: BoardVisualStyle = .standard
    ) -> BoardTemplate {
        let count = gridSize * gridSize
        return BoardTemplate(
            id: id,
            name: name,
            gridSize: gridSize,
            adjacency: adjacency,
            mask: Set(0..<count),
            stones: stones,
            specialRule: specialRule,
            regions: regions,
            minimumVowelsPerRegion: minimumVowelsPerRegion,
            visualStyle: visualStyle
        )
    }

    static func template(for roundIndex: Int) -> BoardTemplate {
        let round = max(1, min(RunState.Tunables.totalRounds, roundIndex))

        if let challenge = ChallengeRoundResolver.resolve(roundIndex: round) {
            return challenge.boardTemplate
        }

        guard let family = RunState.boardFamily(for: round) else {
            return standard6x6
        }
        return template(for: family)
    }

    static func template(for family: BoardFamily) -> BoardTemplate {
        switch family {
        case .standard6x6:
            return standard6x6
        case .lightStones6x6:
            return lightStones6x6
        case .denseStones6x6:
            return denseStones6x6
        case .diamond6x6:
            return diamond6x6
        case .hourglass6x6:
            return hourglass6x6
        case .splitLanes6x6:
            return splitLanes6x6
        }
    }

    private static let standard6x6: BoardTemplate = .full(
        gridSize: 6,
        id: "standard_6x6",
        name: "Standard"
    )

    private static let lightStones6x6: BoardTemplate = .full(
        gridSize: 6,
        id: "light_stones_6x6",
        name: "Light Stones",
        stones: indices(6, coords: [(2, 2), (3, 3)])
    )

    private static let denseStones6x6: BoardTemplate = .full(
        gridSize: 6,
        id: "dense_stones_6x6",
        name: "Dense Stones",
        stones: indices(6, coords: [(1, 3), (3, 1), (4, 4)])
    )

    private static let diamond6x6: BoardTemplate = BoardTemplate(
        id: "diamond_6x6",
        name: "Diamond",
        gridSize: 6,
        adjacency: .hvAndDiagonals,
        mask: maskFromRows(6, rows: [
            [2, 3],
            [1, 2, 3, 4],
            [0, 1, 2, 3, 4, 5],
            [0, 1, 2, 3, 4, 5],
            [1, 2, 3, 4],
            [2, 3]
        ]),
        stones: indices(6, coords: [(1, 3)])
    )

    private static let hourglass6x6: BoardTemplate = BoardTemplate(
        id: "hourglass_6x6",
        name: "Hourglass",
        gridSize: 6,
        adjacency: .hvAndDiagonals,
        mask: maskFromRows(6, rows: [
            [1, 2, 3, 4],
            [0, 1, 2, 3, 4, 5],
            [1, 2, 3, 4],
            [2, 3],
            [1, 2, 3, 4],
            [0, 1, 2, 3, 4, 5]
        ])
    )

    private static let splitLanes6x6: BoardTemplate = BoardTemplate(
        id: "split_lanes_6x6",
        name: "Split Lanes",
        gridSize: 6,
        mask: maskFromRows(6, rows: Array(repeating: [0, 1, 2, 4, 5], count: 6))
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

    static let defaultRows = 6
    static let defaultCols = 6
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
