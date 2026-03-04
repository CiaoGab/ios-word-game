import Foundation

enum Gravity {
    static func apply(
        tiles: [Tile?],
        rows: Int,
        cols: Int,
        template: BoardTemplate
    ) -> (tiles: [Tile?], drops: [DropMove], emptyIndices: [Int]) {
        var compacted = tiles
        var drops: [DropMove] = []

        for col in 0..<cols {
            var row = rows - 1
            while row >= 0 {
                let index = row * cols + col
                if !template.isPlayable(index) {
                    compacted[index] = nil
                    row -= 1
                    continue
                }

                if compacted[index]?.kind == .stone {
                    row -= 1
                    continue
                }

                let segmentEnd = row
                while row >= 0 {
                    let probeIndex = row * cols + col
                    if !template.isPlayable(probeIndex) {
                        break
                    }
                    if compacted[probeIndex]?.kind == .stone {
                        break
                    }
                    row -= 1
                }
                let segmentStart = row + 1
                compactSegment(
                    tiles: &compacted,
                    col: col,
                    rows: segmentStart...segmentEnd,
                    cols: cols,
                    drops: &drops
                )

                if row >= 0 {
                    let barrierIndex = row * cols + col
                    if !template.isPlayable(barrierIndex) {
                        compacted[barrierIndex] = nil
                    }
                    row -= 1
                }
            }
        }

        let empties = compacted.indices.filter {
            template.isPlayable($0) && !template.isStone($0) && compacted[$0] == nil
        }
        return (compacted, drops, empties)
    }

    static func spawn(
        into tiles: [Tile?],
        emptyIndices: [Int],
        rows: Int,
        cols: Int,
        template: BoardTemplate,
        bag: inout LetterBag
    ) -> (tiles: [Tile?], spawns: [SpawnMove]) {
        var filled = tiles
        var spawns: [SpawnMove] = []

        // Seed existing letter counts from tiles already on the board so spawned
        // tiles respect both per-board rare-letter caps and the hard vowel cap.
        var existingCounts: [Character: Int] = [:]
        for tile in tiles.compactMap({ $0 }) {
            guard tile.isLetterTile else { continue }
            existingCounts[tile.letter, default: 0] += 1
        }

        for col in 0..<cols {
            let columnEmpties = emptyIndices
                .filter { ($0 % cols) == col }
                .sorted { ($0 / cols) < ($1 / cols) }

            for (position, index) in columnEmpties.enumerated() {
                guard template.isPlayable(index), !template.isStone(index) else { continue }
                let tile = bag.nextTile(respecting: LetterBag.rareCaps, existingCounts: &existingCounts)
                filled[index] = tile
                let offset = columnEmpties.count - position
                spawns.append(SpawnMove(tile: tile, toIndex: index, spawnRowOffset: max(1, offset)))
            }
        }

        return (filled, spawns)
    }

    private static func compactSegment(
        tiles: inout [Tile?],
        col: Int,
        rows: ClosedRange<Int>,
        cols: Int,
        drops: inout [DropMove]
    ) {
        var writeRow = rows.upperBound

        for readRow in stride(from: rows.upperBound, through: rows.lowerBound, by: -1) {
            let readIndex = readRow * cols + col
            guard let tile = tiles[readIndex], tile.isLetterTile else { continue }

            let writeIndex = writeRow * cols + col
            tiles[readIndex] = nil
            tiles[writeIndex] = tile

            if readIndex != writeIndex {
                drops.append(DropMove(tileID: tile.id, fromIndex: readIndex, toIndex: writeIndex))
            }

            writeRow -= 1
        }

        while writeRow >= rows.lowerBound {
            tiles[writeRow * cols + col] = nil
            writeRow -= 1
        }
    }
}
