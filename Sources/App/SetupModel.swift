//
//  SetupModel.swift
//  Perch
//
//  Created by Kaan Firat.
//

import AppKit
import NotchKit
import Observation

/// The state of the setup window: which permissions have been given, and
/// the choices made on the way.
@MainActor
@Observable
final class SetupModel {
    enum Permission: Equatable {
        case idle
        /// Asked; the answer is the user's to give.
        case waiting
        case granted
        case denied
    }

    let preferences: Preferences
    private(set) var network: Permission = .idle
    private(set) var accessibility: Permission
    /// On unless the user turns it off; applied when setup finishes.
    var launchesAtLogin: Bool
    /// The next key press with a modifier becomes the shortcut.
    private(set) var recordingShortcut = false

    @ObservationIgnored private let networkCheck = LocalNetworkCheck()
    @ObservationIgnored private var accessibilityPoll: Timer?
    @ObservationIgnored private var keyMonitor: Any?

    init(preferences: Preferences) {
        self.preferences = preferences
        accessibility = MenuBarAccess.isGranted ? .granted : .idle
        // First time through it starts on; later it shows what's set.
        launchesAtLogin = preferences.setupDone ? preferences.launchesAtLogin : true
    }

    var canContinue: Bool { network == .granted }

    /// Brings up the system's local network request, and waits for the answer.
    func askForNetwork() {
        network = .waiting
        networkCheck.start { [weak self] answer in
            self?.network = answer == .granted ? .granted : .denied
        }
    }

    /// Opens the Accessibility list and watches for Perch being switched on.
    func askForAccessibility() {
        MenuBarAccess.request()
        accessibility = .waiting
        accessibilityPoll?.invalidate()
        accessibilityPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, MenuBarAccess.isGranted else { return }
                self.accessibility = .granted
                timer.invalidate()
            }
        }
    }

    func toggleShortcutRecording() {
        recordingShortcut ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recordingShortcut = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Esc backs out; anything without a modifier isn't a shortcut.
                if event.keyCode != 53, let shortcut = Shortcut(event: event) {
                    self.preferences.shortcut = shortcut
                }
                self.stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        recordingShortcut = false
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Setup is over: keep the choices and let go of everything running.
    func finish() {
        stopRecording()
        networkCheck.stop()
        accessibilityPoll?.invalidate()
        if preferences.launchesAtLogin != launchesAtLogin {
            preferences.launchesAtLogin = launchesAtLogin
        }
        preferences.setupDone = true
    }
}
