//
//  KeyCodes.swift
//  Summoner
//

import Foundation

/// Carbon virtual key codes (ANSI layout) for the allowed trigger keys, A–Z and 0–9.
enum KeyCodes {
    static let table: [Character: UInt32] = [
        "A": 0, "B": 11, "C": 8, "D": 2, "E": 14, "F": 3, "G": 5,
        "H": 4, "I": 34, "J": 38, "K": 40, "L": 37, "M": 46, "N": 45,
        "O": 31, "P": 35, "Q": 12, "R": 15, "S": 1, "T": 17, "U": 32,
        "V": 9, "W": 13, "X": 7, "Y": 16, "Z": 6,
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
        "6": 22, "7": 26, "8": 28, "9": 25,
    ]

    /// Virtual key code for a stored key string, or nil if it isn't a single valid character.
    static func code(for key: String) -> UInt32? {
        guard key.count == 1, let char = key.first else { return nil }
        return table[char]
    }

    static func isValid(_ char: Character) -> Bool {
        table[char] != nil
    }
}
