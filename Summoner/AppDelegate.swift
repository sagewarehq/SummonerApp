//
//  AppDelegate.swift
//  Summoner
//

import AppKit
import Combine
import SwiftUI

/// Owns the binding store and manages the splash and settings windows.
/// Windows are plain NSWindows (not SwiftUI scenes) so they can be shown
/// programmatically at launch.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let store = BindingStore()

    private var splashWindow: NSWindow?
    private var settingsWindow: NSWindow?

    private static let splashDuration: TimeInterval = 1.6

    func applicationDidFinishLaunching(_ notification: Notification) {
        showSplashThenSettings()
    }

    // MARK: - Splash

    private func showSplashThenSettings() {
        let splash = makeSplashWindow()
        splashWindow = splash
        // Always dead-center on the primary display; center() picks the
        // "current" screen and sits above vertical center. Use frame, not
        // visibleFrame, so the Dock and menu bar don't skew the position.
        if let contentView = splash.contentViewController?.view {
            splash.setContentSize(contentView.fittingSize)
        }
        if let screen = NSScreen.screens.first ?? NSScreen.main {
            let size = splash.frame.size
            splash.setFrameOrigin(NSPoint(x: screen.frame.midX - size.width / 2,
                                          y: screen.frame.midY - size.height / 2))
        }
        splash.alphaValue = 0
        splash.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            splash.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.splashDuration) { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.35
                splash.animator().alphaValue = 0
            }, completionHandler: {
                // AppKit invokes this on the main thread; the closure just isn't typed that way.
                MainActor.assumeIsolated {
                    splash.orderOut(nil)
                    self.splashWindow = nil
                    self.showSettings()
                }
            })
        }
    }

    private func makeSplashWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero,
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        window.contentViewController = NSHostingController(rootView: SplashView())
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        return window
    }

    // MARK: - Settings window

    func showSettings() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: .zero,
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered,
                              defer: false)
        window.contentViewController = NSHostingController(
            rootView: SettingsView().environmentObject(store)
        )
        window.title = "Summoner Settings"
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}
