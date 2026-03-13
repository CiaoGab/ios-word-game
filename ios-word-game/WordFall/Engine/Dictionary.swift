import Foundation

final class WordTrie {
    var children: [Character: WordTrie] = [:]
    var isWord: Bool = false

    func insert(_ word: String) {
        var node = self
        for ch in word {
            if node.children[ch] == nil {
                node.children[ch] = WordTrie()
            }
            node = node.children[ch]!
        }
        node.isWord = true
    }

    func child(for ch: Character) -> WordTrie? {
        children[ch]
    }
}

final class WordDictionary {
    /// 3-letter common words only (zipf >= 4.0, no abbreviations).
    private let words3Common: Set<String>
    /// 4-20 letter words (existing common list, minus blocklist).
    private let words4to20: Set<String>

    // MARK: - Init

    /// Designated init for production: two separate sets, validated by length.
    init(words3Common: Set<String>, words4to20: Set<String>) {
        self.words3Common = words3Common
        self.words4to20 = words4to20
    }

    /// Convenience init used in tests: merges all words into the appropriate bucket by length.
    convenience init(words: Set<String>) {
        let normalized = Set(words.map { Self.normalize($0) }.filter { !$0.isEmpty })
        let w3 = normalized.filter { $0.count == 3 }
        let w420 = normalized.filter { (4...20).contains($0.count) }
        self.init(words3Common: w3, words4to20: w420)
    }

    // MARK: - Trie

    func buildTrie() -> WordTrie {
        let root = WordTrie()
        for word in words3Common { root.insert(word) }
        for word in words4to20   { root.insert(word) }
        return root
    }

    // MARK: - Lookup

    func contains(_ word: String) -> Bool {
        let w = Self.normalize(word)
        return set(forLength: w.count).contains(w)
    }

    func containsEitherDirection(_ word: String) -> Bool {
        matchedWordEitherDirection(word) != nil
    }

    /// Returns the canonical form of `word` that exists in the dictionary (forward
    /// or reversed), or `nil` if neither direction matches.
    /// Word must be built from path order — do NOT sort or rearrange letters.
    func matchedWordEitherDirection(_ word: String) -> String? {
        let normalized = Self.normalize(word)
        guard !normalized.isEmpty else { return nil }
        let bucket = set(forLength: normalized.count)
        if bucket.contains(normalized) {
            return normalized
        }
        let reversed = String(normalized.reversed())
        if bucket.contains(reversed) {
            return reversed
        }
        return nil
    }

    func firstWord(lengths: ClosedRange<Int> = 3...6) -> String? {
        let all = words3Common.union(words4to20)
        return all.sorted().first { lengths.contains($0.count) }
    }

    func words(ofLength length: Int) -> [String] {
        let source = length == 3 ? words3Common : words4to20
        return source.filter { $0.count == length }.sorted()
    }

    // MARK: - Bundle loading

    static func loadFromBundle(bundle: Bundle = .main) -> WordDictionary {
        let w3  = loadSet(resource: "words3_common",  bundle: bundle, expectedLengths: 3...3)
        let w420 = loadSet(resource: "words4to6",     bundle: bundle, expectedLengths: 4...20)

        let effective3  = w3.isEmpty  ? Set(fallbackWords.filter { $0.count == 3 }) : w3
        let effective420 = w420.isEmpty ? Set(fallbackWords.filter { (4...20).contains($0.count) }) : w420

        if w3.isEmpty {
            print("[Dictionary] words3_common.json missing or empty — using \(effective3.count) fallback 3-letter words.")
            print("[Dictionary] If missing in Xcode: select words3_common.json -> File Inspector target membership includes ios-word-game, then Build Phases -> Copy Bundle Resources.")
        }
        if w420.isEmpty {
            print("[Dictionary] words4to6.json missing or empty — using \(effective420.count) fallback 4-20-letter words.")
        }

        return WordDictionary(words3Common: effective3, words4to20: effective420)
    }

    // MARK: - Private helpers

    private func set(forLength length: Int) -> Set<String> {
        length == 3 ? words3Common : words4to20
    }

    private static func loadSet(
        resource: String,
        bundle: Bundle,
        expectedLengths: ClosedRange<Int>
    ) -> Set<String> {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            print("[Dictionary] \(resource).json not found in bundle.")
            return []
        }
        guard
            let data = try? Data(contentsOf: url),
            let list = try? JSONDecoder().decode([String].self, from: data)
        else {
            print("[Dictionary] Failed to decode \(resource).json.")
            return []
        }
        let filtered = list
            .map { normalize($0) }
            .filter { expectedLengths.contains($0.count) && !$0.isEmpty }
        print("[Dictionary] Loaded \(filtered.count) words from \(resource).json (len \(expectedLengths.lowerBound)-\(expectedLengths.upperBound)).")
        return Set(filtered)
    }

    private static func normalize(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static let fallbackWords: [String] = [
        "cat", "dog", "sun", "the", "and", "for",
        "moon", "star", "game", "word", "fall", "rain", "tile", "grid", "code", "swift"
    ]
}
