//
//  SummonerApp.swift
//  Summoner
//
//  Created by Jesse Panganiban on 7/2/26.
//

import SwiftUI

@main
struct SummonerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Summoner", systemImage: "keyboard") {
            MenuContent()
                .environmentObject(delegate)
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject private var delegate: AppDelegate

    var body: some View {
        Button("Settings…") {
            delegate.showSettings()
        }
        Divider()
        Button("Quit Summoner") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
