import Foundation

struct HintPath {
    let indices: [Int]
    let word: String
}

enum HintFinder {
    /// Finds a playable word using free-pick tile rules (no adjacency constraints).
    /// Preferred lengths are tried in order; first match wins.
    static func findFreePickHint(
        state: GameState,
        dictionary: WordDictionary,
        preferredLengths: [Int] = [6, 5, 4],
        allowedIndices: Set<Int>? = nil
    ) -> HintPath? {
        let lengths = preferredLengths.filter { (Resolver.minWordLen...Resolver.maxWordLen).contains($0) }
        guard !lengths.isEmpty else { return nil }

        for length in lengths {
            let candidates = dictionary.words(ofLength: length)
            for word in candidates {
                if let indices = buildTilePath(for: word, tiles: state.tiles, allowedIndices: allowedIndices) {
                    return HintPath(indices: indices, word: word)
                }
            }
        }
        return nil
    }

    static func validateFreePickHint(
        _ hint: HintPath,
        state: GameState,
        dictionary: WordDictionary
    ) -> Bool {
        let path = hint.indices
        let word = hint.word
        guard path.count == word.count, Set(path).count == path.count else { return false }
        guard dictionary.contains(word) else { return false }

        let expected = Array(word.uppercased())
        for (offset, index) in path.enumerated() {
            guard index >= 0, index < state.tiles.count else { return false }
            guard let tile = state.tiles[index], tile.isLetterTile else { return false }
            if tile.kind == .wildcard {
                continue
            }
            if tile.letter != expected[offset] {
                return false
            }
        }
        return true
    }

    private static func buildTilePath(
        for word: String,
        tiles: [Tile?],
        allowedIndices: Set<Int>? = nil
    ) -> [Int]? {
        let chars = Array(word.uppercased())
        guard !chars.isEmpty else { return nil }

        var indicesByLetter: [Character: [Int]] = [:]
        var wildcardIndices: [Int] = []

        for index in tiles.indices {
            if let allowedIndices, !allowedIndices.contains(index) {
                continue
            }
            guard let tile = tiles[index], tile.isLetterTile else { continue }
            if tile.kind == .wildcard {
                wildcardIndices.append(index)
            } else {
                indicesByLetter[tile.letter, default: []].append(index)
            }
        }

        var path = Array(repeating: -1, count: chars.count)
        var used: Set<Int> = []

        func assign(_ offset: Int) -> Bool {
            if offset == chars.count {
                return true
            }

            let letter = chars[offset]
            var options: [Int] = []
            if let exact = indicesByLetter[letter] {
                options.append(contentsOf: exact)
            }
            options.append(contentsOf: wildcardIndices)

            for index in options where !used.contains(index) {
                used.insert(index)
                path[offset] = index
                if assign(offset + 1) {
                    return true
                }
                used.remove(index)
            }
            return false
        }

        return assign(0) ? path : nil
    }
}
