import Foundation

enum Gravity {
    static func apply(tiles: [Tile?], rows: Int, cols: Int) -> (tiles: [Tile?], drops: [DropMove], emptyIndices: [Int]) {
        var compacted = tiles
        var drops: [DropMove] = []

        for col in 0..<cols {
            var writeRow = rows - 1

            for readRow in stride(from: rows - 1, through: 0, by: -1) {
                let readIndex = readRow * cols + col
                guard let tile = compacted[readIndex] else { continue }

                let writeIndex = writeRow * cols + col
                compacted[readIndex] = nil
                compacted[writeIndex] = tile

                if readIndex != writeIndex {
                    drops.append(DropMove(tileID: tile.id, fromIndex: readIndex, toIndex: writeIndex))
                }

                writeRow -= 1
            }

            while writeRow >= 0 {
                compacted[writeRow * cols + col] = nil
                writeRow -= 1
            }
        }

        let empties = compacted.indices.filter { compacted[$0] == nil }
        return (compacted, drops, empties)
    }

    static func spawn(
        into tiles: [Tile?],
        emptyIndices: [Int],
        rows: Int,
        cols: Int,
        bag: inout LetterBag
    ) -> (tiles: [Tile?], spawns: [SpawnMove]) {
        var filled = tiles
        var spawns: [SpawnMove] = []

        // Seed existing letter counts from tiles already on the board so spawned
        // tiles respect both per-board rare-letter caps and the hard vowel cap.
        var existingCounts: [Character: Int] = [:]
        for tile in tiles.compactMap({ $0 }) {
            existingCounts[tile.letter, default: 0] += 1
        }

        for col in 0..<cols {
            let columnEmpties = emptyIndices
                .filter { ($0 % cols) == col }
                .sorted { ($0 / cols) < ($1 / cols) }

            for (position, index) in columnEmpties.enumerated() {
                let tile = bag.nextTile(respecting: LetterBag.rareCaps, existingCounts: &existingCounts)
                filled[index] = tile
                let offset = columnEmpties.count - position
                spawns.append(SpawnMove(tile: tile, toIndex: index, spawnRowOffset: max(1, offset)))
            }
        }

        return (filled, spawns)
    }
}
