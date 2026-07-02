//
//  BindingStore.swift
//  Summoner
//

import AppKit
import Combine
import Foundation

/// Source of truth for bindings: persistence (FR-4), validation (FR-3.4),
/// and hotkey re-registration on every change (FR-1.3).
@MainActor
final class BindingStore: ObservableObject {
    @Published private(set) var bindings: [AppBinding] = []

    /// Bindings whose `RegisterEventHotKey` call failed ("Shortcut unavailable").
    @Published private(set) var registrationFailures: Set<UUID> = []
    /// Bindings whose bundle ID no longer resolves ("App not found").
    @Published private(set) var missingApps: Set<UUID> = []
    /// Row that owns a key someone else just tried to take (duplicate highlight).
    @Published private(set) var duplicateConflict: UUID?

    private let hotkeys = HotkeyManager()
    private static let defaultsKey = "io.sageware.Summoner.bindings"

    init() {
        hotkeys.onTrigger = { binding in
            AppSummoner.summon(bundleID: binding.bundleID)
        }
        load()
        reloadHotkeys()
    }

    // MARK: - Mutations

    /// Adds a binding for the app at `url` with no key yet, and returns its ID
    /// so the UI can focus the key field. If the app is already bound, returns
    /// the existing binding's ID instead (edge case: same app added twice).
    func addApp(at url: URL) -> UUID? {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else {
            NSLog("Summoner: no bundle identifier for \(url.path)")
            return nil
        }
        if let existing = bindings.first(where: { $0.bundleID == bundleID }) {
            return existing.id
        }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let binding = AppBinding(id: UUID(), bundleID: bundleID, appName: name, key: "")
        bindings.append(binding)
        save()
        return binding.id
    }

    /// Attempts to assign `key` to the given binding. Returns false (and marks
    /// the conflicting row) if another binding already uses that key.
    func setKey(_ key: String, for id: UUID) -> Bool {
        duplicateConflict = nil
        if let owner = bindings.first(where: { $0.key == key && $0.id != id }) {
            duplicateConflict = owner.id
            return false
        }
        guard let index = bindings.firstIndex(where: { $0.id == id }) else { return false }
        bindings[index].key = key
        save()
        reloadHotkeys()
        return true
    }

    func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
        duplicateConflict = nil
        save()
        reloadHotkeys()
    }

    // MARK: - Status

    /// Re-checks which bound apps still resolve (FR-2.4); called when Settings opens.
    func refreshMissingApps() {
        missingApps = Set(
            bindings
                .filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) == nil }
                .map(\.id)
        )
    }

    func icon(for binding: AppBinding) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: binding.bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "questionmark.app", accessibilityDescription: nil)
            ?? NSImage()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey) else {
            bindings = []
            return
        }
        do {
            bindings = try JSONDecoder().decode([AppBinding].self, from: data)
        } catch {
            NSLog("Summoner: failed to decode stored bindings, resetting. \(error)")
            bindings = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(bindings)
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        } catch {
            NSLog("Summoner: failed to encode bindings. \(error)")
        }
    }

    private func reloadHotkeys() {
        registrationFailures = hotkeys.register(bindings)
        let assigned = bindings.filter { !$0.key.isEmpty }
        NSLog("Summoner: registered %d hotkey(s), %d failure(s)",
              assigned.count - registrationFailures.count,
              registrationFailures.count)
    }
}
