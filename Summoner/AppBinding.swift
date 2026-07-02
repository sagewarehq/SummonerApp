//
//  AppBinding.swift
//  Summoner
//

import Foundation

/// A single app-to-key binding. Keyed by bundle identifier so it survives
/// app relocation (FR-3.5). `key` is a single uppercase character, A–Z or 0–9;
/// empty until the user assigns one.
struct AppBinding: Codable, Identifiable, Equatable {
    let id: UUID
    var bundleID: String
    var appName: String
    var key: String
}
