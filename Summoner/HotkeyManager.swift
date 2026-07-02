//
//  HotkeyManager.swift
//  Summoner
//

import Carbon.HIToolbox
import Foundation

/// Registers global ⌃⌥⌘+key hotkeys via Carbon `RegisterEventHotKey` and
/// dispatches triggers back to `onTrigger`. No Accessibility or Input
/// Monitoring permissions required; works inside the App Sandbox.
@MainActor
final class HotkeyManager {
    var onTrigger: ((AppBinding) -> Void)?

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var bindingsByHotKeyID: [UInt32: AppBinding] = [:]
    private var nextHotKeyID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private static let signature: OSType = 0x534D_4E52 // "SMNR"
    private static let leaderMask = UInt32(controlKey | optionKey | cmdKey)

    /// Re-registers all hotkeys from scratch (FR-1.3). Bindings without an
    /// assigned key are skipped. Returns the IDs of bindings whose
    /// registration failed (FR-1.4).
    func register(_ bindings: [AppBinding]) -> Set<UUID> {
        installEventHandlerIfNeeded()
        unregisterAll()

        var failures = Set<UUID>()
        for binding in bindings {
            guard let keyCode = KeyCodes.code(for: binding.key) else { continue }
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: nextHotKeyID)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(keyCode,
                                             Self.leaderMask,
                                             hotKeyID,
                                             GetEventDispatcherTarget(),
                                             0,
                                             &ref)
            if status == noErr, let ref {
                hotKeyRefs.append(ref)
                bindingsByHotKeyID[nextHotKeyID] = binding
                nextHotKeyID += 1
            } else {
                failures.insert(binding.id)
            }
        }
        return failures
    }

    func unregisterAll() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        bindingsByHotKeyID.removeAll()
    }

    func handleTrigger(hotKeyID: UInt32) {
        guard let binding = bindingsByHotKeyID[hotKeyID] else { return }
        onTrigger?(binding)
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(),
                            hotkeyEventCallback,
                            1,
                            &eventType,
                            Unmanaged.passUnretained(self).toOpaque(),
                            &eventHandler)
    }
}

// Carbon requires a C function pointer; it cannot capture context, so the
// manager instance travels through `userData`. Carbon dispatches hotkey
// events on the main thread.
private let hotkeyEventCallback: EventHandlerUPP = { _, event, userData in
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event,
                                   EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID),
                                   nil,
                                   MemoryLayout<EventHotKeyID>.size,
                                   nil,
                                   &hotKeyID)
    guard status == noErr, let userData else { return status }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated {
        manager.handleTrigger(hotKeyID: hotKeyID.id)
    }
    return noErr
}
