//
//  SetupWindow.swift
//  Perch
//
//  Created by Kaan Firat.
//

import AppKit
import SwiftUI

/// The window Perch opens the first time it runs: the permissions it
/// needs, asked for one by one with the reason beside each, then on to
/// pairing. The notch's menu brings it back later.
@MainActor
final class SetupWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var model: SetupModel?
    private let preferences: Preferences
    private let onFinish: () -> Void

    /// - Parameter onFinish: Called once the window is done with, by its
    ///   button or by closing it.
    init(preferences: Preferences, onFinish: @escaping () -> Void) {
        self.preferences = preferences
        self.onFinish = onFinish
    }

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            return window.makeKeyAndOrderFront(nil)
        }
        let model = SetupModel(preferences: preferences)
        self.model = model

        let hosting = NSHostingController(rootView: SetupView(model: model) { [weak self] in self?.window?.close() })
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Perch"
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0x1E / 255, green: 0x1E / 255, blue: 0x20 / 255, alpha: 1)
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window

        // An accessory app isn't brought forward by showing a window.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        model?.finish()
        model = nil
        window = nil
        onFinish()
    }
}

struct SetupView: View {
    @Bindable var model: SetupModel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
                Text("Welcome to Perch")
                    .font(.system(size: 22, weight: .semibold))
                Text("Perch needs a couple of permissions. Neither records what you type.")
                    .font(.system(size: 13))
                    .foregroundStyle(Setup.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 0) {
                networkRow
                Setup.divider
                accessibilityRow
                Setup.divider
                shortcutRow
                Setup.divider
                loginRow
            }
            .background(Setup.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.08), lineWidth: 0.5) }

            HStack(spacing: 16) {
                Text("You can open this window again from the notch's right-click menu.")
                    .font(.system(size: 11))
                    .foregroundStyle(Setup.secondary)
                Spacer()
                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Text("Connect Your Apple TV")
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(model.canContinue ? .white : Color(hex: 0x8E8E93))
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(model.canContinue ? Theme.accent : Theme.track, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(!model.canContinue)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .frame(width: 580)
        .foregroundStyle(Theme.text)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Rows

    private var networkRow: some View {
        SetupRow(symbol: "wifi", tint: Theme.accent, title: "Local Network", badge: .required,
                 detail: "To find the Apple TV on your Wi‑Fi and connect to it.") {
            switch model.network {
            case .idle: SetupButton("Allow", prominent: true) { model.askForNetwork() }
            case .waiting: Waiting()
            case .granted: Granted()
            case .denied: SetupButton("Open Settings") { LocalNetworkSettings.open() }
            }
        } note: {
            if model.network == .denied {
                SetupNote("Turn Perch on in System Settings › Privacy & Security › Local Network. This window updates on its own.")
            }
        }
    }

    private var accessibilityRow: some View {
        SetupRow(symbol: "accessibility", tint: Color(hex: 0x5E5CE6), title: "Accessibility", badge: .optional,
                 detail: "Keeps Perch clear of an app's menus when they run long.") {
            switch model.accessibility {
            case .idle, .denied: SetupButton("Open Settings") { model.askForAccessibility() }
            case .waiting: Waiting()
            case .granted: Granted()
            }
        } note: {
            if model.accessibility == .waiting {
                SetupNote("Turn Perch on in System Settings › Privacy & Security › Accessibility. This window updates on its own.")
            }
        }
    }

    private var shortcutRow: some View {
        SetupRow(symbol: "keyboard", tint: Color(hex: 0x48484A), title: "Keyboard Shortcut", badge: nil,
                 detail: "Opens the remote from anywhere.") {
            Button { model.toggleShortcutRecording() } label: {
                HStack(spacing: 8) {
                    if model.recordingShortcut {
                        Text("Press keys").foregroundStyle(Theme.text)
                    } else {
                        Text(model.preferences.shortcut.displayString)
                            .font(.system(size: 12, design: .monospaced))
                        Text("Change").foregroundStyle(Setup.secondary)
                    }
                }
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color(hex: 0x1E1E20), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(model.recordingShortcut ? Theme.accent : .white.opacity(0.14),
                                lineWidth: model.recordingShortcut ? 1.5 : 0.5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change the shortcut, currently \(model.preferences.shortcut.displayString)")
        } note: {
            EmptyView()
        }
    }

    private var loginRow: some View {
        SetupRow(symbol: "power", tint: Theme.green, title: "Launch at Login", badge: nil,
                 detail: "Ready in the notch when your Mac starts.") {
            Toggle("Launch at Login", isOn: $model.launchesAtLogin)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Theme.accent)
        } note: {
            EmptyView()
        }
    }
}

// MARK: - Pieces

private enum Setup {
    static let card = Color(hex: 0x2A2A2D)
    static let secondary = Color(hex: 0xA1A1A6)
    static var divider: some View { Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5) }
}

private enum SetupBadge {
    case required
    case optional
}

/// One line of the list: a tinted symbol, what it is and why, and its
/// control on the right, with room for a note underneath.
private struct SetupRow<Control: View, Note: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    let badge: SetupBadge?
    let detail: String
    @ViewBuilder let control: Control
    @ViewBuilder let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(tint, in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(title).font(.system(size: 13, weight: .semibold))
                        badgeView
                    }
                    Text(detail).font(.system(size: 12)).foregroundStyle(Setup.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                control
            }
            note.padding(.leading, 48)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
    }

    @ViewBuilder private var badgeView: some View {
        switch badge {
        case .required:
            Text("Required")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(hex: 0x6AB4FF))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Theme.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
        case .optional:
            Text("Optional")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(hex: 0xC7C7CC))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Theme.track, in: RoundedRectangle(cornerRadius: 4))
        case nil:
            EmptyView()
        }
    }
}

private struct SetupButton: View {
    let title: String
    var prominent = false
    let action: () -> Void

    init(_ title: String, prominent: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.prominent = prominent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: prominent ? .semibold : .medium))
                .foregroundStyle(prominent ? .white : Theme.text)
                .padding(.horizontal, prominent ? 14 : 12)
                .frame(height: 28)
                .background(prominent ? Theme.accent : Theme.track, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct Granted: View {
    var body: some View {
        Label("Allowed", systemImage: "checkmark")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.green)
    }
}

private struct Waiting: View {
    var body: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            Text("Waiting").font(.system(size: 12)).foregroundStyle(Setup.secondary)
        }
    }
}

private struct SetupNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Color(hex: 0xC7C7CC))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0x1E1E20), in: RoundedRectangle(cornerRadius: 8))
    }
}
