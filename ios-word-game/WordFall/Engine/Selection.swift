import Foundation

enum Selection {
    private static let allDirections: [(Int, Int)] = [
        (-1, 0),
        (0, -1), (0, 1),
        (1, 0)
    ]

    static func lineIndices(from start: Int, to end: Int, rows: Int, cols: Int, maxLength: Int = 6) -> [Int] {
        guard
            (0..<(rows * cols)).contains(start),
            (0..<(rows * cols)).contains(end)
        else {
            return []
        }

        let startRow = start / cols
        let startCol = start % cols
        let endRow = end / cols
        let endCol = end % cols
        let deltaRow = endRow - startRow
        let deltaCol = endCol - startCol

        guard let direction = snappedDirection(deltaRow: deltaRow, deltaCol: deltaCol) else {
            return [start]
        }

        let steps = max(abs(deltaRow), abs(deltaCol))
        let targetLength = min(maxLength, steps + 1)

        var indices: [Int] = [start]
        var row = startRow
        var col = startCol

        while indices.count < targetLength {
            row += direction.0
            col += direction.1
            guard row >= 0, row < rows, col >= 0, col < cols else {
                break
            }
            indices.append(row * cols + col)
        }

        return indices
    }

    static func isStraightContiguous(
        _ indices: [Int],
        rows: Int,
        cols: Int,
        allowedLengths: ClosedRange<Int> = 4...6
    ) -> Bool {
        guard allowedLengths.contains(indices.count), Set(indices).count == indices.count else {
            return false
        }

        guard indices.allSatisfy({ (0..<(rows * cols)).contains($0) }) else {
            return false
        }

        // A single tile is trivially a straight contiguous selection.
        if indices.count == 1 {
            return true
        }

        let first = indices[0]
        let second = indices[1]
        let firstRow = first / cols
        let firstCol = first % cols
        let secondRow = second / cols
        let secondCol = second % cols
        let directionRow = secondRow - firstRow
        let directionCol = secondCol - firstCol

        guard abs(directionRow) + abs(directionCol) == 1 else {
            return false
        }

        for index in 1..<indices.count {
            let prev = indices[index - 1]
            let current = indices[index]
            let prevRow = prev / cols
            let prevCol = prev % cols
            let curRow = current / cols
            let curCol = current % cols
            if (curRow - prevRow) != directionRow || (curCol - prevCol) != directionCol {
                return false
            }
        }

        return true
    }

    static func word(from tiles: [Tile?], indices: [Int]) -> String? {
        var letters: [Character] = []
        letters.reserveCapacity(indices.count)

        for index in indices {
            guard index >= 0, index < tiles.count, let tile = tiles[index] else {
                return nil
            }
            guard tile.isLetterTile else { return nil }
            letters.append(tile.letter)
        }

        return String(letters).lowercased()
    }

    private static func snappedDirection(deltaRow: Int, deltaCol: Int) -> (Int, Int)? {
        guard deltaRow != 0 || deltaCol != 0 else { return nil }

        if deltaRow == 0 {
            return (0, deltaCol > 0 ? 1 : -1)
        }
        if deltaCol == 0 {
            return (deltaRow > 0 ? 1 : -1, 0)
        }
        // Snap to the dominant cardinal axis.
        if abs(deltaRow) >= abs(deltaCol) {
            return (deltaRow > 0 ? 1 : -1, 0)
        } else {
            return (0, deltaCol > 0 ? 1 : -1)
        }
    }
}
