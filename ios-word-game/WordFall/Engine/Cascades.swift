import Foundation

struct MatchedSegment {
    let indices: [Int]
    let word: String

    var length: Int {
        indices.count
    }
}

struct MatchResult {
    let segments: [MatchedSegment]
    let clearIndices: Set<Int>
    /// Total candidates collected across all scanned lines before the per-line
    /// containment filter runs. Equals segments.count when no subwords were dropped.
    let rawCandidateCount: Int
}

enum WordMatcher {
    static func findAllMatches(
        tiles: [Tile?],
        rows: Int,
        cols: Int,
        dictionary: WordDictionary,
        minLen: Int = 4,
        maxLen: Int = 6,
        mode: String = "cascade"
    ) -> MatchResult {
        findMatches(
            tiles: tiles,
            rows: rows,
            cols: cols,
            dictionary: dictionary,
            minLen: minLen,
            maxLen: maxLen,
            mode: mode,
            rowsToScan: nil,
            colsToScan: nil
        )
    }

    static func findMatches(
        tiles: [Tile?],
        rows: Int,
        cols: Int,
        dictionary: WordDictionary,
        minLen: Int = 4,
        maxLen: Int = 6,
        mode: String = "cascade",
        rowsToScan: Set<Int>?,
        colsToScan: Set<Int>?
    ) -> MatchResult {
        guard rows > 0, cols > 0 else {
            return MatchResult(segments: [], clearIndices: [], rawCandidateCount: 0)
        }

        let targetRows = (rowsToScan ?? Set(0..<rows))
            .filter { $0 >= 0 && $0 < rows }
            .sorted()
        let targetCols = (colsToScan ?? Set(0..<cols))
            .filter { $0 >= 0 && $0 < cols }
            .sorted()

        var seenCanonicalKeys: Set<String> = []
        var segments: [MatchedSegment] = []
        var totalRawCandidateCount = 0

        let lengths = minLen...maxLen

        // Horizontal segments (left -> right only).
        for row in targetRows {
            let lineIndices = (0..<cols).map { row * cols + $0 }
            let lineResult = matchesInLine(
                lineIndices: lineIndices,
                tiles: tiles,
                dictionary: dictionary,
                lengths: lengths
            )
            totalRawCandidateCount += lineResult.rawCount

            for segment in lineResult.segments {
                let canonicalKey = canonicalSegmentKey(for: segment)
                guard seenCanonicalKeys.insert(canonicalKey).inserted else { continue }
                segments.append(segment)
            }
        }

        // Vertical segments (top -> bottom only).
        for col in targetCols {
            let lineIndices = (0..<rows).map { ($0 * cols) + col }
            let lineResult = matchesInLine(
                lineIndices: lineIndices,
                tiles: tiles,
                dictionary: dictionary,
                lengths: lengths
            )
            totalRawCandidateCount += lineResult.rawCount

            for segment in lineResult.segments {
                let canonicalKey = canonicalSegmentKey(for: segment)
                guard seenCanonicalKeys.insert(canonicalKey).inserted else { continue }
                segments.append(segment)
            }
        }

        let clearIndices = Set(segments.flatMap(\.indices))
        return MatchResult(
            segments: segments,
            clearIndices: clearIndices,
            rawCandidateCount: totalRawCandidateCount
        )
    }

    // MARK: - Per-line matching

    private struct LineResult {
        let segments: [MatchedSegment]
        /// Candidate count before the containment filter (after exact-dup dedup).
        let rawCount: Int
    }

    private static func matchesInLine(
        lineIndices: [Int],
        tiles: [Tile?],
        dictionary: WordDictionary,
        lengths: ClosedRange<Int>
    ) -> LineResult {
        guard !lineIndices.isEmpty else { return LineResult(segments: [], rawCount: 0) }

        var candidates: [MatchedSegment] = []
        var exactSeen: Set<String> = []

        for start in lineIndices.indices {
            for length in lengths {
                let end = start + length - 1
                guard end < lineIndices.count else { continue }

                let indices = Array(lineIndices[start...end])
                guard
                    let word = Selection.word(from: tiles, indices: indices),
                    let matchedWord = dictionary.matchedWordEitherDirection(word)
                else {
                    continue
                }

                let segment = MatchedSegment(indices: indices, word: matchedWord)
                let exactKey = exactSegmentKey(for: segment)
                guard exactSeen.insert(exactKey).inserted else { continue }

                candidates.append(segment)
            }
        }

        let rawCount = candidates.count

        // Sort: longer segments first; break ties by letter-value sum (higher-scoring word wins).
        let sorted = candidates.sorted {
            if $0.length != $1.length { return $0.length > $1.length }
            return LetterValues.sum(for: $0.word) > LetterValues.sum(for: $1.word)
        }

        // Drop any segment whose indices are fully contained within an already-kept segment.
        var keptIndexSets: [Set<Int>] = []
        var kept: [MatchedSegment] = []
        for segment in sorted {
            let idxSet = Set(segment.indices)
            guard !keptIndexSets.contains(where: { $0.isSuperset(of: idxSet) }) else { continue }
            keptIndexSets.append(idxSet)
            kept.append(segment)
        }

        return LineResult(segments: kept, rawCount: rawCount)
    }

    private static func exactSegmentKey(for segment: MatchedSegment) -> String {
        "\(segment.word)|\(segment.indices.map(String.init).joined(separator: ","))"
    }

    private static func canonicalSegmentKey(for segment: MatchedSegment) -> String {
        let reversedIndices = segment.indices.reversed()
        let forwardIndexKey = segment.indices.map(String.init).joined(separator: ",")
        let reverseIndexKey = reversedIndices.map(String.init).joined(separator: ",")
        let normalizedIndexKey = min(forwardIndexKey, reverseIndexKey)

        let reversedWord = String(segment.word.reversed())
        let normalizedWord = min(segment.word, reversedWord)
        return "\(normalizedWord)|\(normalizedIndexKey)"
    }
}
