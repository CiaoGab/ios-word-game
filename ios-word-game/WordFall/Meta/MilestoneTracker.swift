import Foundation
import Combine

/// Persistent tracker for cross-run milestone counters and unlocked perks.
/// Saved to and loaded from UserDefaults as JSON.
final class MilestoneTracker: ObservableObject {

    // MARK: - UserDefaults key

    static let defaultsKey = "wordfall.milestoneTracker.v1"

    // MARK: - Counters (all persisted)

    struct Counters: Codable {
        var totalLocksBroken: Int = 0
        /// Keyed by word-length string: "3", "4", "5", "6".
        var wordsByLength: [String: Int] = [:]
        /// Keyed by uppercase letter string: "A", "E", etc.
        var wordsContainingLetter: [String: Int] = [:]
        var runsStarted: Int = 0
        var runsCompleted: Int = 0
        var bestRoundReached: Int = 0
    }

    // MARK: - Published state

    @Published private(set) var counters: Counters
    @Published private(set) var unlockedPerks: Set<PerkID>
    /// Perks newly unlocked during the most recent milestone check (cleared on next check).
    @Published private(set) var justUnlocked: [PerkID] = []

    // MARK: - Instance key (allows test isolation)

    private let key: String

    // MARK: - Init

    /// Production initializer — uses the shared UserDefaults key.
    init() {
        self.key = Self.defaultsKey
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(SaveData.self, from: data) {
            self.counters = saved.counters
            self.unlockedPerks = saved.unlockedPerks
        } else {
            self.counters = Counters()
            self.unlockedPerks = defaultUnlockedPerks
        }
    }

    /// Test initializer — uses a supplied key so tests don't pollute real data.
    init(defaultsKey: String) {
        self.key = defaultsKey
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(SaveData.self, from: data) {
            self.counters = saved.counters
            self.unlockedPerks = saved.unlockedPerks
        } else {
            self.counters = Counters()
            self.unlockedPerks = defaultUnlockedPerks
        }
    }

    // MARK: - Recording

    func recordLocksBroken(_ count: Int) {
        guard count > 0 else { return }
        counters.totalLocksBroken += count
        checkMilestones()
        save()
    }

    /// Call with the accepted (uppercased) word after each successful submission.
    func recordWord(_ word: String) {
        let upper = word.uppercased()
        counters.wordsByLength["\(upper.count)", default: 0] += 1
        for ch in upper {
            counters.wordsContainingLetter[String(ch), default: 0] += 1
        }
        checkMilestones()
        save()
    }

    func recordRunStarted() {
        counters.runsStarted += 1
        save()
    }

    func recordRunCompleted(boardReached: Int) {
        if boardReached >= RunState.Tunables.totalBoards {
            counters.runsCompleted += 1
        }
        if boardReached > counters.bestRoundReached {
            counters.bestRoundReached = boardReached
        }
        save()
    }

    // MARK: - Query

    func milestoneProgress(for id: MilestoneID) -> (current: Int, threshold: Int) {
        let threshold = id.definition.threshold
        let current: Int
        switch id {
        case .break50Locks:
            current = counters.totalLocksBroken
        case .make50SixLetterWords:
            current = counters.wordsByLength["6"] ?? 0
        case .useLetterAIn100Words:
            current = counters.wordsContainingLetter["A"] ?? 0
        }
        return (current, threshold)
    }

    // MARK: - Private

    private func checkMilestones() {
        justUnlocked = []
        for milestoneID in MilestoneID.allCases {
            let milestone = milestoneID.definition
            guard !unlockedPerks.contains(milestone.unlocksPerkID) else { continue }
            let (current, threshold) = milestoneProgress(for: milestoneID)
            if current >= threshold {
                unlockedPerks.insert(milestone.unlocksPerkID)
                justUnlocked.append(milestone.unlocksPerkID)
            }
        }
    }

    private func save() {
        let saveData = SaveData(counters: counters, unlockedPerks: unlockedPerks)
        if let encoded = try? JSONEncoder().encode(saveData) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    // MARK: - Persistence model

    private struct SaveData: Codable {
        var counters: Counters
        var unlockedPerks: Set<PerkID>
    }
}
