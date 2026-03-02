import Foundation

final class WordDictionary {
    private let words: Set<String>
    private let sortedWords: [String]

    init(words: Set<String>) {
        let normalized = words.map { Self.normalize($0) }.filter { !$0.isEmpty }
        let effectiveWords = normalized.isEmpty ? Self.fallbackWords : normalized
        self.words = Set(effectiveWords)
        self.sortedWords = self.words.sorted()
    }

    func buildTrie() -> WordTrie {
        let root = WordTrie()
        for word in words {
            root.insert(word)
        }
        return root
    }

    func contains(_ word: String) -> Bool {
        words.contains(Self.normalize(word))
    }

    func containsEitherDirection(_ word: String) -> Bool {
        matchedWordEitherDirection(word) != nil
    }

    func matchedWordEitherDirection(_ word: String) -> String? {
        let normalized = Self.normalize(word)
        guard !normalized.isEmpty else { return nil }
        if words.contains(normalized) {
            return normalized
        }
        let reversed = String(normalized.reversed())
        if words.contains(reversed) {
            return reversed
        }
        return nil
    }

    func firstWord(lengths: ClosedRange<Int> = 3...6) -> String? {
        sortedWords.first { lengths.contains($0.count) }
    }

    static func loadFromBundle(resource: String = "words_3_6", bundle: Bundle = .main) -> WordDictionary {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            print("[Dictionary] Missing \(resource).json in bundle. Fallback words loaded: \(fallbackWords.count).")
            print("[Dictionary] If missing in Xcode: select words_3_6.json -> File Inspector target membership includes ios-word-game, then Build Phases -> Copy Bundle Resources includes words_3_6.json.")
            logLengthCounts(words: fallbackWords, source: "fallback")
            return WordDictionary(words: Set(fallbackWords))
        }

        guard
            let data = try? Data(contentsOf: url),
            let list = try? JSONDecoder().decode([String].self, from: data)
        else {
            print("[Dictionary] Failed to decode \(resource).json. Fallback words loaded: \(fallbackWords.count).")
            logLengthCounts(words: fallbackWords, source: "fallback")
            return WordDictionary(words: Set(fallbackWords))
        }

        let filtered = list
            .map { normalize($0) }
            .filter { (3...6).contains($0.count) }
        guard !filtered.isEmpty else {
            print("[Dictionary] \(resource).json produced 0 usable words. Fallback words loaded: \(fallbackWords.count).")
            logLengthCounts(words: fallbackWords, source: "fallback")
            return WordDictionary(words: Set(fallbackWords))
        }
        print("[Dictionary] Loaded \(filtered.count) words from \(url.lastPathComponent) at \(url.path).")
        logLengthCounts(words: filtered, source: url.lastPathComponent)
        return WordDictionary(words: Set(filtered))
    }

    private static func normalize(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func logLengthCounts(words: [String], source: String) {
        let counts = words.reduce(into: [Int: Int]()) { partial, word in
            partial[word.count, default: 0] += 1
        }
        print("[Dictionary] \(source) counts len3=\(counts[3, default: 0]) len4=\(counts[4, default: 0]) len5=\(counts[5, default: 0]) len6=\(counts[6, default: 0])")
    }

    private static let fallbackWords: [String] = [
        "cat", "dog", "sun", "moon", "star", "game", "word", "fall", "rain", "tile", "grid", "code", "swift"
    ]
}
