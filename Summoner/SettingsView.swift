//
//  SettingsView.swift
//  Summoner
//

import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: BindingStore
    @FocusState private var focusedKey: UUID?
    @State private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Text("Leader key:")
                Text("⌃ ⌥ ⌘").fontWeight(.semibold)
                Text("(fixed)").foregroundColor(.secondary)
            }

            bindingList

            Button("＋ Add App…", action: addApp)

            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onChangeCompat(of: launchAtLogin) { enabled in
                    applyLaunchAtLogin(enabled)
                }
        }
        .padding(20)
        .frame(width: 460, height: 380, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture {
            // Clicking empty space de-focuses the key field; macOS won't do it on its own.
            focusedKey = nil
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .onAppear {
            store.refreshMissingApps()
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var bindingList: some View {
        ScrollView {
            VStack(spacing: 2) {
                if store.bindings.isEmpty {
                    Text("No bindings yet. Add an app to get started.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    ForEach(store.bindings) { binding in
                        BindingRowView(binding: binding, focusedKey: $focusedKey)
                    }
                }
            }
            .padding(4)
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        )
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let id = store.addApp(at: url) {
            DispatchQueue.main.async { focusedKey = id }
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled { try service.unregister() }
            }
        } catch {
            NSLog("Summoner: launch-at-login change failed. \(error)")
        }
        // Reflect actual status (FR-6.2), e.g. if register() threw.
        launchAtLogin = service.status == .enabled
    }
}

private struct BindingRowView: View {
    @EnvironmentObject private var store: BindingStore
    let binding: AppBinding
    var focusedKey: FocusState<UUID?>.Binding
    @State private var keyText = ""

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: store.icon(for: binding))
                .resizable()
                .frame(width: 24, height: 24)
            Text(binding.appName)
                .lineLimit(1)
            Spacer()
            Text("⌃⌥⌘ +")
                .foregroundColor(.secondary)
            TextField("", text: $keyText)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .frame(width: 36)
                .focused(focusedKey, equals: binding.id)
                .onChangeCompat(of: keyText) { newValue in
                    handleKeyInput(newValue)
                }
                .onHover { hovering in
                    if !hovering { handleKeyInput(keyText) }
                }
                .onChangeCompat(of: focusedKey.wrappedValue) { focused in
                    if focused != binding.id { handleKeyInput(keyText) }
                }
                .onSubmit { handleKeyInput(keyText) }
            Button {
                store.remove(binding.id)
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove binding")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.red, lineWidth: issueText == nil ? 0 : 1.5)
        )
        .help(issueText ?? "")
        .onAppear { keyText = binding.key }
        .onChangeCompat(of: binding.key) { newValue in
            if keyText != newValue { keyText = newValue }
        }
    }

    /// Highest-priority issue for this row, if any (duplicate > not found > registration).
    private var issueText: String? {
        if store.duplicateConflict == binding.id {
            return "This key is already in use"
        }
        if store.missingApps.contains(binding.id) {
            return "App not found"
        }
        if store.registrationFailures.contains(binding.id) {
            return "Shortcut unavailable (reserved by the system or another app)"
        }
        return nil
    }

    /// Sanitizes typed input to a single valid A–Z/0–9 character and saves it,
    /// reverting the field if the key is invalid or already taken (FR-3.4).
    private func handleKeyInput(_ raw: String) {
        let sanitized = raw.uppercased().filter { KeyCodes.isValid($0) }
        guard let char = sanitized.last.map(String.init) else {
            if keyText != binding.key { keyText = binding.key }
            return
        }
        if char == binding.key {
            if keyText != char { keyText = char }
            return
        }
        let accepted = store.setKey(char, for: binding.id)
        let resolved = accepted ? char : binding.key
        if keyText != resolved { keyText = resolved }
    }
}
