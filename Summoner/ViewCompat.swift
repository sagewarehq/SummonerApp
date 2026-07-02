//
//  ViewCompat.swift
//  Summoner
//

import SwiftUI

extension View {
    /// `onChange(of:perform:)` was deprecated in macOS 14 in favor of the
    /// two-parameter form, which doesn't exist on macOS 13. This picks the
    /// right one at runtime and compiles warning-free at any deployment target.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14.0, *) {
            onChange(of: value) { _, newValue in action(newValue) }
        } else {
            onChangeLegacy(of: value, perform: action)
        }
    }

    // Matching the deprecation of the API it wraps silences the warning here.
    @available(macOS, deprecated: 14.0)
    private func onChangeLegacy<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        onChange(of: value, perform: action)
    }
}
