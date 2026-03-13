import Foundation
import Combine

enum ProfileUnlockID: String, Codable, CaseIterable, Hashable, Identifiable {
    case equipSlot1
    case equipSlot2
    case perkLibraryTier2
    case rerollPerRun
    case startingPowerup
    case equipSlot3
    case challengeInsight
    case perkLibraryTier3
    case equipSlot4
    case ascension1

    var id: String { rawValue }

    var threshold: Int {
        switch self {
        case .equipSlot1: return 150
        case .equipSlot2: return 300
        case .perkLibraryTier2: return 500
        case .rerollPerRun: return 700
        case .startingPowerup: return 900
        case .equipSlot3: return 1200
        case .challengeInsight: return 1500
        case .perkLibraryTier3: return 1800
        case .equipSlot4: return 2200
        case .ascension1: return 2600
        }
    }

    var phaseLabel: String {
        switch self {
        case .equipSlot1, .equipSlot2:
            return "Phase 1"
        case .perkLibraryTier2, .rerollPerRun, .startingPowerup:
            return "Phase 2"
        case .equipSlot3, .challengeInsight, .perkLibraryTier3:
            return "Phase 3"
        case .equipSlot4, .ascension1:
            return "Phase 4"
        }
    }

    var title: String {
        switch self {
        case .equipSlot1: return "Equip Slot 1"
        case .equipSlot2: return "Equip Slot 2"
        case .perkLibraryTier2: return "Perk Library Tier 2"
        case .rerollPerRun: return "1 Reroll per Run"
        case .startingPowerup: return "+1 Starting Powerup"
        case .equipSlot3: return "Equip Slot 3"
        case .challengeInsight: return "Challenge Insight"
        case .perkLibraryTier3: return "Perk Library Tier 3"
        case .equipSlot4: return "Equip Slot 4"
        case .ascension1: return "Ascension 1"
        }
    }

    static func unlocked(atXP totalXP: Int) -> Set<ProfileUnlockID> {
        Set(allCases.filter { totalXP >= $0.threshold })
    }
}

@MainActor
final class PlayerProfile: ObservableObject {
    static let defaultsKey = "wordfall.playerProfile.v1"

    struct Stats: Codable, Equatable {
        var totalXP: Int = 0
        var totalWordsBuilt: Int = 0
        var totalLocksBroken: Int = 0
        var totalRareLetterWords: Int = 0
        var highestRoundReached: Int = 0
        var runsCompleted: Int = 0
    }

    @Published private(set) var stats: Stats
    @Published private(set) var unlockedThresholds: Set<ProfileUnlockID>
    @Published private(set) var justUnlocked: [ProfileUnlockID] = []
    @Published private(set) var equippedStarterPerks: [StarterPerkID]

    private let key: String

    init() {
        self.key = Self.defaultsKey
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(SaveData.self, from: data) {
            let unlocks = saved.earnedUnlocks.union(ProfileUnlockID.unlocked(atXP: saved.stats.totalXP))
            self.stats = saved.stats
            self.unlockedThresholds = unlocks
            self.equippedStarterPerks = Self.normalizedStarterPerks(
                saved.equippedStarterPerks,
                unlockedThresholds: unlocks
            )
        } else {
            self.stats = Stats()
            self.unlockedThresholds = []
            self.equippedStarterPerks = []
        }
    }

    init(defaultsKey: String) {
        self.key = defaultsKey
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(SaveData.self, from: data) {
            let unlocks = saved.earnedUnlocks.union(ProfileUnlockID.unlocked(atXP: saved.stats.totalXP))
            self.stats = saved.stats
            self.unlockedThresholds = unlocks
            self.equippedStarterPerks = Self.normalizedStarterPerks(
                saved.equippedStarterPerks,
                unlockedThresholds: unlocks
            )
        } else {
            self.stats = Stats()
            self.unlockedThresholds = []
            self.equippedStarterPerks = []
        }
    }

    var totalXP: Int { stats.totalXP }

    var availableEquipSlots: Int {
        [
            ProfileUnlockID.equipSlot1,
            .equipSlot2,
            .equipSlot3,
            .equipSlot4
        ].filter(unlockedThresholds.contains).count
    }

    var perkLibraryTier: Int {
        if unlockedThresholds.contains(.perkLibraryTier3) { return 3 }
        if unlockedThresholds.contains(.perkLibraryTier2) { return 2 }
        return 1
    }

    var rerollsPerRun: Int {
        unlockedThresholds.contains(.rerollPerRun) ? 1 : 0
    }

    var startingPowerupBonus: Int {
        unlockedThresholds.contains(.startingPowerup) ? 1 : 0
    }

    var hasChallengeInsight: Bool {
        unlockedThresholds.contains(.challengeInsight)
    }

    var ascensionLevel: Int {
        unlockedThresholds.contains(.ascension1) ? 1 : 0
    }

    var nextLockedUnlock: ProfileUnlockID? {
        ProfileUnlockID.allCases.first { !unlockedThresholds.contains($0) }
    }

    var unlockedLifetimeMilestones: Set<LifetimeMilestoneID> {
        Set(LifetimeMilestoneID.allCases.filter { milestone in
            milestone.progressValue(from: stats) >= milestone.threshold
        })
    }

    func lifetimeMilestoneProgress(for id: LifetimeMilestoneID) -> (current: Int, threshold: Int) {
        (id.progressValue(from: stats), id.threshold)
    }

    func setEquippedStarterPerks(_ perks: [StarterPerkID]) {
        equippedStarterPerks = Self.normalizedStarterPerks(perks, unlockedThresholds: unlockedThresholds)
        save()
    }

    @discardableResult
    func recordRunEnd(
        xpEarned: Int,
        wordsBuilt: Int,
        locksBroken: Int,
        rareLetterWords: Int,
        roundReached: Int,
        wonRun: Bool
    ) -> [ProfileUnlockID] {
        let previousUnlocks = unlockedThresholds
        stats.totalXP += max(0, xpEarned)
        stats.totalWordsBuilt += max(0, wordsBuilt)
        stats.totalLocksBroken += max(0, locksBroken)
        stats.totalRareLetterWords += max(0, rareLetterWords)
        stats.highestRoundReached = max(stats.highestRoundReached, max(0, roundReached))
        if wonRun {
            stats.runsCompleted += 1
        }

        unlockedThresholds.formUnion(ProfileUnlockID.unlocked(atXP: stats.totalXP))
        equippedStarterPerks = Self.normalizedStarterPerks(
            equippedStarterPerks,
            unlockedThresholds: unlockedThresholds
        )
        justUnlocked = ProfileUnlockID.allCases.filter {
            unlockedThresholds.contains($0) && !previousUnlocks.contains($0)
        }
        save()
        return justUnlocked
    }

    func reset() {
        stats = Stats()
        unlockedThresholds = []
        justUnlocked = []
        equippedStarterPerks = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func save() {
        let saveData = SaveData(
            stats: stats,
            earnedUnlocks: unlockedThresholds,
            equippedStarterPerks: equippedStarterPerks
        )
        if let encoded = try? JSONEncoder().encode(saveData) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    private static func normalizedStarterPerks(
        _ perks: [StarterPerkID],
        unlockedThresholds: Set<ProfileUnlockID>
    ) -> [StarterPerkID] {
        let maxSlots = [
            ProfileUnlockID.equipSlot1,
            .equipSlot2,
            .equipSlot3,
            .equipSlot4
        ].filter(unlockedThresholds.contains).count

        var seen: Set<StarterPerkID> = []
        var normalized: [StarterPerkID] = []
        for perk in perks {
            guard !seen.contains(perk) else { continue }
            seen.insert(perk)
            normalized.append(perk)
            if normalized.count >= maxSlots {
                break
            }
        }
        return normalized
    }

    private struct SaveData: Codable {
        var stats: Stats
        var earnedUnlocks: Set<ProfileUnlockID>
        var equippedStarterPerks: [StarterPerkID] = []
    }
}
