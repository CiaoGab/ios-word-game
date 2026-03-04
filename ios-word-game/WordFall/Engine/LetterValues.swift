import Foundation

enum LetterValues {
    static let scrabble: [Character: Int] = [
        "A": 1, "E": 1, "I": 1, "O": 1, "U": 1,
        "L": 1, "N": 1, "S": 1, "T": 1, "R": 1,
        "D": 2, "G": 2,
        "B": 3, "C": 3, "M": 3, "P": 3,
        "F": 4, "H": 4,
        "V": 6, "W": 6, "Y": 7,
        "K": 10,
        "J": 12, "X": 12,
        "Q": 15, "Z": 15
    ]

    static func value(for letter: Character) -> Int {
        scrabble[Character(String(letter).uppercased())] ?? 1
    }

    static func sum(for word: String) -> Int {
        word.reduce(0) { partial, character in
            partial + value(for: character)
        }
    }
}
