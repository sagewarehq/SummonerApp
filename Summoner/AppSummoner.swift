//
//  AppSummoner.swift
//  Summoner
//

import AppKit

/// Launches or activates a target app by bundle identifier (FR-2).
enum AppSummoner {
    @MainActor
    static func summon(bundleID: String) {
        // Toggle behavior (FR-2.3): if the target is already frontmost, hide it.
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier == bundleID {
            frontmost.hide()
            return
        }

        // FR-2.4: unresolvable bundle ID is a silent no-op on trigger.
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}
