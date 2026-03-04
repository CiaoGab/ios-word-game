import Foundation

// MARK: - PowerupType

enum PowerupType: CaseIterable {
    case hint, shuffle, wildcard, undo

    var displayName: String {
        switch self {
        case .hint:     return "Hint"
        case .shuffle:  return "Shuffle"
        case .wildcard: return "Wildcard"
        case .undo:     return "Undo"
        }
    }

    var systemIcon: String {
        switch self {
        case .hint:     return "lightbulb"
        case .shuffle:  return "shuffle"
        case .wildcard: return "questionmark"
        case .undo:     return "arrow.uturn.backward"
        }
    }
}

// MARK: - Inventory

struct Inventory {
    var hints: Int = 0
    var shuffles: Int = 0
    var wildcards: Int = 0
    var undos: Int = 0

    subscript(_ type: PowerupType) -> Int {
        get {
            switch type {
            case .hint:     return hints
            case .shuffle:  return shuffles
            case .wildcard: return wildcards
            case .undo:     return undos
            }
        }
        set {
            switch type {
            case .hint:     hints     = max(0, newValue)
            case .shuffle:  shuffles  = max(0, newValue)
            case .wildcard: wildcards = max(0, newValue)
            case .undo:     undos     = max(0, newValue)
            }
        }
    }

    /// Adds `count` of the given powerup type. Safe to call with any positive count.
    mutating func grantPowerup(_ type: PowerupType, count: Int = 1) {
        self[type] += count
    }

    /// Decrements the given powerup type by 1. Returns `true` if consumed, `false` if count was 0.
    @discardableResult
    mutating func consume(_ type: PowerupType) -> Bool {
        guard self[type] > 0 else { return false }
        self[type] -= 1
        return true
    }
}
