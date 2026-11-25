//
//  RemoteController.swift
//  Perch
//
//  Created by Kaan Firat.
//

import AppKit
import NotchKit
import Observation
import SwiftUI

/// Puts Perch in the notch: owns the notch, the shortcut and the model,
/// and keeps the notch in step with the model.
@MainActor
public final class RemoteController {
    /// How long the wings come out when the tv starts playing.
    private static let playingFlash: TimeInterval = 2.5

    private let model: RemoteModel
    private let preferences = Preferences()
    private var setup: SetupWindow?
    /// The notch is up and the session running; setup comes first.
    private var started = false
    /// Debug builds show the setup window with `--setup`, and the mock tv skips it otherwise.
    private var forcesSetup = false
    private var skipsSetup = false
    private var notch: Notch?
    private var hotKey: GlobalHotKey?
    private var watchers: [Watcher] = []
    /// Debug builds open the notch at launch with `--open`.
    private var opensAtLaunch = false

    public init(arguments: [String]) {
        #if DEBUG
        opensAtLaunch = arguments.contains("--open")
        forcesSetup = arguments.contains("--setup")
        if let mock = MockTV(arguments: arguments) {
            skipsSetup = true
            model = RemoteModel(session: mock)
            return
        }
        #endif
        model = RemoteModel(session: LiveTV())
    }

    /// Shows the setup window the first time, and the notch after it.
    public func start() {
        if forcesSetup || !(preferences.setupDone || skipsSetup) {
            showSetup()
        } else {
            startRemote()
        }
    }

    /// The permissions window, at first launch and from the notch's menu.
    private func showSetup() {
        if setup == nil {
            setup = SetupWindow(preferences: preferences) { [weak self] in
                self?.setup = nil
                self?.startRemote()
            }
        }
        setup?.show()
    }

    private func startRemote() {
        guard !started else { return }
        started = true
        let model = model
        let preferences = preferences
        model.onShowSetup = { [weak self] in self?.showSetup() }

        var configuration = NotchConfiguration()
        configuration.measuredSides = .both
        configuration.keyboardFocus = .whenOpenedDeliberately
        // Next to another notch app Perch keeps the right half; alone it has both.
        configuration.residency = NotchResidency(id: "perch", side: .trailing)

        let notch = Notch(configuration: configuration) {
            LeadingWing(model: model)
        } compactTrailing: {
            TrailingWing(model: model)
        } compactLine: {
            CompactLine(model: model)
        } expanded: {
            PanelView(model: model, preferences: preferences)
        } request: {
            KeyboardRequest(preferences: preferences)
        } menu: {
            NotchMenu(model: model)
        }
        notch.onKeyDown = { [weak self] event in self?.keyDown(event) ?? false }
        notch.onCollapse = { model.panelClosed() }
        notch.onResidentsChange = { [weak notch] in
            model.neighbours = (notch?.otherResidents ?? []).map {
                Neighbour(id: $0.id, wantsAttention: $0.isRequesting)
            }
        }
        model.onSwitch = { [weak notch] neighbour in
            guard let resident = notch?.otherResidents.first(where: { $0.id == neighbour.id }) else { return }
            notch?.handOver(to: resident)
        }

        hotKey = GlobalHotKey { [weak notch] in notch?.toggleExpanded() }

        // The session settles on where it stands before the notch first
        // reads it, so the notch opens at the right size.
        model.session.start()
        notch.expandedContentSize = model.panelSize
        notch.show()
        self.notch = notch
        watch()

        // Nothing paired yet: open on the list of tvs rather than wait to be found.
        if model.screen == .chooseDevice || opensAtLaunch {
            notch.expand()
        }
    }

    /// Opens the remote, for when Perch is launched again while running.
    public func open() {
        notch?.expand()
    }

    // MARK: - Model to notch

    private func watch() {
        guard let notch else { return }
        let model = model
        let preferences = preferences

        watchers = [
            Watcher({ preferences.shortcut }) { [weak self] shortcut, _ in
                if self?.hotKey?.register(shortcut) != true {
                    NSLog("Perch: couldn't register \(shortcut.displayString); another app has it")
                }
            },
            Watcher({ model.panelSize }) { size, _ in
                notch.expandedContentSize = size
            },
            Watcher({ model.session.keyboardFocused }) { focused, _ in
                model.keyboardFocusChanged(focused)
            },
            Watcher({ model.compact }) { compact, previous in
                if compact == .keyboard {
                    notch.showRequest()
                } else {
                    notch.hideRequest()
                }
                // The tv started playing: say so, even over a full menu bar.
                if compact == .playing, previous == .idle {
                    notch.showWings(for: Self.playingFlash)
                }
            },
            Watcher({ model.screen }) { screen, _ in
                model.screenChanged(screen)
                // The tv is showing a pin; don't make the user come looking.
                if screen == .pin, !notch.isExpanded {
                    notch.expand()
                }
            },
        ]
    }

    // MARK: - Keyboard

    private func keyDown(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.isDisjoint(with: [.control, .option]) else { return false }
        let action = KeyCommands.action(keyCode: event.keyCode, command: modifiers.contains(.command),
                                        screen: model.screen)
        switch action {
        case .press(let button): model.press(button)
        case .leaveTyping: model.leaveTyping()
        case .close: notch?.collapse()
        case nil: return false
        }
        return true
    }
}

/// Calls `onChange` with an observable value as it stands, and again
/// whenever it changes, with the value before it. Lives as long as it's held.
@MainActor
private final class Watcher {
    private let stop: () -> Void

    init<Value: Equatable>(_ value: @escaping @MainActor () -> Value,
                           onChange: @escaping @MainActor (_ new: Value, _ old: Value) -> Void) {
        var last = value()
        // Observation fires once per registration, so each change reads
        // the value again to keep following it.
        var rearm: (() -> Void)?
        rearm = {
            let current = withObservationTracking(value) {
                DispatchQueue.main.async { MainActor.assumeIsolated { rearm?() } }
            }
            guard current != last else { return }
            let previous = last
            last = current
            onChange(current, previous)
        }
        stop = { rearm = nil }
        onChange(last, last)
        rearm?()
    }

    deinit { stop() }
}
