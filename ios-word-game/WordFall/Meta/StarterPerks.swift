import Foundation

enum StarterPerkID: String, Codable, CaseIterable, Hashable, Identifiable {
    case pencilGrip
    case cleanInk
    case spareSeal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pencilGrip:
            return "Pencil Grip"
        case .cleanInk:
            return "Clean Ink"
        case .spareSeal:
            return "Spare Seal"
        }
    }

    var summary: String {
        switch self {
        case .pencilGrip:
            return "First invalid submit each round grants +1 move."
        case .cleanInk:
            return "6+ letter words gain +10% score."
        case .spareSeal:
            return "First locked submit each round costs 1 less."
        }
    }

    var detail: String {
        switch self {
        case .pencilGrip:
            return "Turns the first whiff of the round into a tempo gain instead of a dead turn."
        case .cleanInk:
            return "Rewards building longer words without changing the baseline economy."
        case .spareSeal:
            return "Lets you crack into lock lines earlier without eating the full surcharge."
        }
    }
}
