import Foundation

func neighbors(of index: Int, gridSize: Int, mode: AdjacencyMode) -> [Int] {
    guard gridSize > 0 else { return [] }
    let maxIndex = gridSize * gridSize
    guard index >= 0, index < maxIndex else { return [] }

    let row = index / gridSize
    let col = index % gridSize

    let deltas: [(Int, Int)]
    switch mode {
    case .hvOnly:
        deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    case .hvAndDiagonals:
        deltas = [
            (-1, -1), (-1, 0), (-1, 1),
            (0, -1),            (0, 1),
            (1, -1),  (1, 0),   (1, 1)
        ]
    }

    var result: [Int] = []
    result.reserveCapacity(deltas.count)

    for (dr, dc) in deltas {
        let nextRow = row + dr
        let nextCol = col + dc
        guard nextRow >= 0, nextRow < gridSize, nextCol >= 0, nextCol < gridSize else { continue }
        result.append((nextRow * gridSize) + nextCol)
    }

    return result
}
