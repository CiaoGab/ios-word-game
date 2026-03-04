import Foundation

enum AvailableWords {
    static func count(tiles: [Tile?], rows: Int, cols: Int, dictionary: WordDictionary) -> Int {
        countPossibleSwaps(tiles: tiles, rows: rows, cols: cols, dictionary: dictionary, stopAfter: 0)
    }

    static func hasAnyValidSwap(tiles: [Tile?], rows: Int, cols: Int, dictionary: WordDictionary) -> Bool {
        countPossibleSwaps(tiles: tiles, rows: rows, cols: cols, dictionary: dictionary, stopAfter: 1) > 0
    }

    /// Count valid swaps, stopping early once `earlyExitAt` is reached (0 = count all).
    /// Use this in hot loops (e.g. reshuffle checks) to avoid scanning the full board
    /// when only a minimum threshold matters.
    static func countValidSwaps(
        tiles: [Tile?],
        rows: Int,
        cols: Int,
        dictionary: WordDictionary,
        earlyExitAt: Int = 0
    ) -> Int {
        countPossibleSwaps(tiles: tiles, rows: rows, cols: cols, dictionary: dictionary, stopAfter: earlyExitAt)
    }

    /// Returns the board indices of the first adjacent pair that produces a player-valid word
    /// (3–6 letters, HV). Returns nil if no valid swap exists. Efficient: scans right/down
    /// pairs only and exits on the first hit.
    static func findOneValidSwap(
        tiles: [Tile?],
        rows: Int,
        cols: Int,
        dictionary: WordDictionary
    ) -> (a: Int, b: Int)? {
        guard rows > 0, cols > 0 else { return nil }

        for row in 0..<rows {
            for col in 0..<cols {
                let index = row * cols + col
                guard let tile = tiles[index], tile.isLetterTile else { continue }

                for (deltaRow, deltaCol) in [(0, 1), (1, 0)] {
                    let nextRow = row + deltaRow
                    let nextCol = col + deltaCol
                    guard nextRow < rows, nextCol < cols else { continue }

                    let neighborIndex = nextRow * cols + nextCol
                    guard let neighborTile = tiles[neighborIndex], neighborTile.isLetterTile else { continue }

                    var swapped = tiles
                    swapped.swapAt(index, neighborIndex)

                    let matches = WordMatcher.findMatches(
                        tiles: swapped,
                        rows: rows,
                        cols: cols,
                        dictionary: dictionary,
                        minLen: 3,
                        maxLen: 6,
                        mode: "player",
                        rowsToScan: [row, nextRow],
                        colsToScan: [col, nextCol]
                    )

                    if !matches.segments.isEmpty {
                        return (index, neighborIndex)
                    }
                }
            }
        }

        return nil
    }

    private static func countPossibleSwaps(
        tiles: [Tile?],
        rows: Int,
        cols: Int,
        dictionary: WordDictionary,
        stopAfter: Int
    ) -> Int {
        guard rows > 0, cols > 0 else { return 0 }

        var validSwapCount = 0

        for row in 0..<rows {
            for col in 0..<cols {
                let index = row * cols + col
                guard let tile = tiles[index], tile.isLetterTile else { continue }

                for (deltaRow, deltaCol) in [(0, 1), (1, 0)] {
                    let nextRow = row + deltaRow
                    let nextCol = col + deltaCol
                    guard nextRow < rows, nextCol < cols else { continue }

                    let neighborIndex = nextRow * cols + nextCol
                    guard let neighborTile = tiles[neighborIndex], neighborTile.isLetterTile else { continue }

                    var swapped = tiles
                    swapped.swapAt(index, neighborIndex)

                    // Dead-board detection uses PLAYER rules (3–6).
                    let matches = WordMatcher.findMatches(
                        tiles: swapped,
                        rows: rows,
                        cols: cols,
                        dictionary: dictionary,
                        minLen: 3,
                        maxLen: 6,
                        mode: "player",
                        rowsToScan: [row, nextRow],
                        colsToScan: [col, nextCol]
                    )

                    guard !matches.segments.isEmpty else { continue }

                    validSwapCount += 1
                    if stopAfter > 0, validSwapCount >= stopAfter {
                        return validSwapCount
                    }
                }
            }
        }

        return validSwapCount
    }
}
