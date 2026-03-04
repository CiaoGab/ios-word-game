import Foundation

// MARK: - PerkID

enum PerkID: String, Codable, CaseIterable, Hashable {
    // v1 – all unlocked by default at game start
    case lockRefund
    case freshSpark
    case longBreaker
    case straightShooter
    case freeHint
    case freeUndo
    case rareRelief
    case consonantCrunch
    case vowelBloom
    case tightGloves

    // Milestone-unlocked (scaffolded now, effects implemented in future updates)
    case lockSplash
    case bigGame
    case vowelBloomPlus
}

// MARK: - Perk definition

struct Perk: Identifiable {
    let id: PerkID
    let name: String
    let description: String
    /// Nil means no trade-off.
    let tradeoff: String?
    /// True if this perk directly helps with breaking locks (prioritised in rounds 1–3).
    let isLockHelp: Bool
}

// MARK: - PerkID → definition

extension PerkID {
    var definition: Perk {
        switch self {
        case .lockRefund:
            return Perk(id: .lockRefund, name: "Lock Refund",
                description: "Every 3 locks broken → +1 move (cap: +2/round)",
                tradeoff: nil, isLockHelp: true)
        case .freshSpark:
            return Perk(id: .freshSpark, name: "Fresh Spark",
                description: "First never-used tile in path → +1 lock progress (max +3/round)",
                tradeoff: nil, isLockHelp: true)
        case .longBreaker:
            return Perk(id: .longBreaker, name: "Long Breaker",
                description: "5-letter: +1 lock, 6-letter: +2 extra locks",
                tradeoff: "3-letter words give 0 lock progress", isLockHelp: true)
        case .straightShooter:
            return Perk(id: .straightShooter, name: "Straight Shooter",
                description: "Straight path (no turns) breaks +1 lock",
                tradeoff: "Turned words score −15", isLockHelp: false)
        case .freeHint:
            return Perk(id: .freeHint, name: "Free Hint",
                description: "1 free hint per round",
                tradeoff: nil, isLockHelp: false)
        case .freeUndo:
            return Perk(id: .freeUndo, name: "Free Undo",
                description: "1 free undo per round",
                tradeoff: nil, isLockHelp: false)
        case .rareRelief:
            return Perk(id: .rareRelief, name: "Rare Relief",
                description: "Q/Z/X/J/K never spawn this run",
                tradeoff: "−5 score per word", isLockHelp: false)
        case .consonantCrunch:
            return Perk(id: .consonantCrunch, name: "Consonant Crunch",
                description: "≤1 vowel in word → +1 lock progress",
                tradeoff: "Each vowel in word reduces score by 1", isLockHelp: false)
        case .vowelBloom:
            return Perk(id: .vowelBloom, name: "Vowel Bloom",
                description: "+5 score per vowel in valid word",
                tradeoff: "−5 score if word has 0 vowels", isLockHelp: false)
        case .tightGloves:
            return Perk(id: .tightGloves, name: "Tight Gloves",
                description: "+3 moves each round",
                tradeoff: "3-letter words don't count for lock progress", isLockHelp: false)
        case .lockSplash:
            return Perk(id: .lockSplash, name: "Lock Splash",
                description: "Breaking a lock grants +1 progress to adjacent locks (future)",
                tradeoff: nil, isLockHelp: true)
        case .bigGame:
            return Perk(id: .bigGame, name: "Big Game",
                description: "6-letter words grant double lock progress (future)",
                tradeoff: nil, isLockHelp: false)
        case .vowelBloomPlus:
            return Perk(id: .vowelBloomPlus, name: "Vowel Bloom+",
                description: "Enhanced vowel scoring (future)",
                tradeoff: nil, isLockHelp: false)
        }
    }
}

// MARK: - Default pool

/// The 10 perks available at run start before any milestone unlocks.
/// Tweak this set to change the starting draft pool.
let defaultUnlockedPerks: Set<PerkID> = [
    .lockRefund, .freshSpark, .longBreaker, .straightShooter,
    .freeHint, .freeUndo, .rareRelief, .consonantCrunch, .vowelBloom, .tightGloves
]
