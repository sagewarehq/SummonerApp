//
//  SplashView.swift
//  Summoner
//

import SwiftUI

/// Branding card shown briefly at launch inside a borderless window.
struct SplashView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "keyboard")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tint)
            Text("Summoner")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("⌃ ⌥ ⌘ + key — switch to any app, instantly")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(width: 360, height: 230)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
