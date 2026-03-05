import Foundation

// MARK: - Modifier model

enum ModifierRarity: String, Codable, CaseIterable, Hashable {
    case common = "COMMON"
    case uncommon = "UNCOMMON"
    case rare = "RARE"
    case epic = "EPIC"
}

enum ModifierID: String, Codable, CaseIterable, Hashable {
    // Existing v1 pool (repurposed into run-wide modifiers)
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
    case lockSplash
    case bigGame
    case vowelBloomPlus

    // Additional v1 run-wide modifiers
    case overclockedBoots
    case austerityPact
    case wildcardSmith
    case salvageRights
    case bossHunter
    case titanTribute
    case echoChamber
}

struct Modifier: Identifiable {
    let id: ModifierID
    let name: String
    let description: String
    let rarity: ModifierRarity
    let tags: [String]
}

// MARK: - Compatibility aliases (legacy perk naming)

typealias PerkID = ModifierID
typealias Perk = Modifier

// MARK: - Draft tunables

enum ModifierDraftTunables {
    /// Weighted rarity roll used when building 1-of-3 draft options.
    /// Increase a weight to make that rarity appear more frequently.
    static let rarityWeights: [ModifierRarity: Int] = [
        .common: 58,
        .uncommon: 30,
        .rare: 10,
        .epic: 2
    ]
}

// MARK: - ModifierID → definition

extension ModifierID {
    var definition: Modifier {
        switch self {
        case .lockRefund:
            return Modifier(
                id: self,
                name: "Lock Dividend",
                description: "+0.5 move refund per lock broken. Tradeoff: words that break 0 locks lose 6 score.",
                rarity: .common,
                tags: ["lock", "move_refund", "tradeoff"]
            )
        case .freshSpark:
            return Modifier(
                id: self,
                name: "Fresh Spark",
                description: "Word uses at least one never-used tile: +1 lock progress (max 3 triggers per board).",
                rarity: .uncommon,
                tags: ["lock", "path_freshness"]
            )
        case .longBreaker:
            return Modifier(
                id: self,
                name: "Long Breaker",
                description: "3-letter words: -1 lock progress. 5-letter: +1 lock. 6-letter: +2 locks.",
                rarity: .common,
                tags: ["lock", "length", "tradeoff"]
            )
        case .straightShooter:
            return Modifier(
                id: self,
                name: "Tactician Map",
                description: "Start each board with +1 Shuffle. Tradeoff: start each board with -1 move.",
                rarity: .common,
                tags: ["economy", "shuffle", "moves", "tradeoff"]
            )
        case .freeHint:
            return Modifier(
                id: self,
                name: "Scout Kit",
                description: "Start each board with +1 Hint. Tradeoff: score target +10%.",
                rarity: .common,
                tags: ["economy", "hint", "target", "tradeoff"]
            )
        case .freeUndo:
            return Modifier(
                id: self,
                name: "Safety Net",
                description: "First Undo each board is free. Tradeoff: score target +8%.",
                rarity: .common,
                tags: ["economy", "undo", "target", "tradeoff"]
            )
        case .rareRelief:
            return Modifier(
                id: self,
                name: "Rare Relief",
                description: "Q/Z/X/J/K never spawn this run. Tradeoff: every accepted word loses 5 score.",
                rarity: .rare,
                tags: ["utility", "spawn", "score", "tradeoff"]
            )
        case .consonantCrunch:
            return Modifier(
                id: self,
                name: "Consonant Crunch",
                description: "If word has <=1 vowel: +12 score and +1 lock. If 3+ vowels: -8 score.",
                rarity: .uncommon,
                tags: ["score", "lock", "vowels", "tradeoff"]
            )
        case .vowelBloom:
            return Modifier(
                id: self,
                name: "Vowel Bloom",
                description: "+4 score per vowel. Tradeoff: 0-vowel words lose 8 score.",
                rarity: .common,
                tags: ["score", "vowels", "tradeoff"]
            )
        case .tightGloves:
            return Modifier(
                id: self,
                name: "Reserve Tank",
                description: "Start each board with +1 move. Tradeoff: 3-letter words lose 12 score.",
                rarity: .common,
                tags: ["moves", "score", "length", "tradeoff"]
            )
        case .lockSplash:
            return Modifier(
                id: self,
                name: "Demolition Plan",
                description: "If a word breaks 2+ locks: +2 extra lock progress and -10 score.",
                rarity: .rare,
                tags: ["lock", "burst", "tradeoff"]
            )
        case .bigGame:
            return Modifier(
                id: self,
                name: "Big Game",
                description: "6-letter words gain +40% base score. 3-letter words lose 25% base score.",
                rarity: .rare,
                tags: ["score_multiplier", "length", "tradeoff"]
            )
        case .vowelBloomPlus:
            return Modifier(
                id: self,
                name: "Glass Ledger",
                description: "+30% base score on every word. Tradeoff: disables 5/6-letter move refunds.",
                rarity: .rare,
                tags: ["score_multiplier", "move_refund", "tradeoff"]
            )
        case .overclockedBoots:
            return Modifier(
                id: self,
                name: "Overclocked Boots",
                description: "Start each board with +2 moves. Tradeoff: score target +20%.",
                rarity: .uncommon,
                tags: ["moves", "target", "tradeoff"]
            )
        case .austerityPact:
            return Modifier(
                id: self,
                name: "Austerity Pact",
                description: "All words gain +35% base score. Tradeoff: start each board with -2 moves.",
                rarity: .rare,
                tags: ["score_multiplier", "moves", "tradeoff"]
            )
        case .wildcardSmith:
            return Modifier(
                id: self,
                name: "Wildcard Smith",
                description: "Board-clear reward odds shift: Wildcard +20 weight, Hint -10 weight.",
                rarity: .uncommon,
                tags: ["economy", "reward_weights", "wildcard"]
            )
        case .salvageRights:
            return Modifier(
                id: self,
                name: "Salvage Rights",
                description: "On board clear, 35% chance to gain one extra random reward. Tradeoff: lock target +1.",
                rarity: .rare,
                tags: ["economy", "reward_bonus", "locks_target", "tradeoff"]
            )
        case .bossHunter:
            return Modifier(
                id: self,
                name: "Boss Hunter",
                description: "Boss boards: +2 moves and lock target -15%. Non-boss boards: -1 move.",
                rarity: .uncommon,
                tags: ["boss", "moves", "lock_target", "tradeoff"]
            )
        case .titanTribute:
            return Modifier(
                id: self,
                name: "Titan Tribute",
                description: "Boss boards: +40% base score and +1 guaranteed extra reward. Non-boss words: -10% base score.",
                rarity: .rare,
                tags: ["boss", "score_multiplier", "rewards", "tradeoff"]
            )
        case .echoChamber:
            return Modifier(
                id: self,
                name: "Echo Chamber",
                description: "Enables duplicate modifier picks in future drafts. Duplicate picks stack.",
                rarity: .epic,
                tags: ["draft", "duplicates", "stacking"]
            )
        }
    }
}

// MARK: - Default pool

/// Modifiers available at run start before any milestone unlocks.
/// Keep this separate from `ModifierID.allCases` so milestones can add later unlocks.
let defaultUnlockedModifiers: Set<ModifierID> = [
    .lockRefund, .freshSpark, .longBreaker, .straightShooter,
    .freeHint, .freeUndo, .rareRelief, .consonantCrunch, .vowelBloom, .tightGloves,
    .vowelBloomPlus, .overclockedBoots, .austerityPact, .wildcardSmith,
    .salvageRights, .bossHunter, .titanTribute
]

/// Legacy alias used by existing code/tests.
let defaultUnlockedPerks: Set<PerkID> = defaultUnlockedModifiers
