//
//  Preferences.swift
//  Perch
//
//  Created by Kaan Firat.
//

import Foundation
import NotchKit
import Observation
import ServiceManagement

/// What the user has chosen, kept in the defaults.
@MainActor
@Observable
final class Preferences {
    /// ⌥T. Key code 17 is T; 0x0800 is optionKey.
    static let defaultShortcut = Shortcut(keyCode: 17, modifiers: 0x0800)

    private enum Key {
        static let shortcutKeyCode = "shortcutKeyCode"
        static let shortcutModifiers = "shortcutModifiers"
        static let setupDone = "setupDone"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Opens and closes the remote from anywhere.
    var shortcut: Shortcut {
        didSet {
            defaults.set(Int(shortcut.keyCode), forKey: Key.shortcutKeyCode)
            defaults.set(Int(shortcut.modifiers), forKey: Key.shortcutModifiers)
        }
    }

    /// The setup window has been gone through once.
    var setupDone: Bool {
        didSet { defaults.set(setupDone, forKey: Key.setupDone) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.shortcutKeyCode) != nil {
            shortcut = Shortcut(keyCode: UInt32(defaults.integer(forKey: Key.shortcutKeyCode)),
                                modifiers: UInt32(defaults.integer(forKey: Key.shortcutModifiers)))
        } else {
            shortcut = Self.defaultShortcut
        }
        setupDone = defaults.bool(forKey: Key.setupDone)
    }

    /// Whether macOS starts Perch at login. The system keeps this, not the defaults.
    var launchesAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Perch: couldn't change the login item: \(error.localizedDescription)")
            }
        }
    }
}
