//
//  KeyCommands.swift
//  Perch
//
//  Created by Kaan Firat.
//

import Foundation

/// What a key press on the Mac does while the notch has the keyboard.
public enum KeyAction: Equatable {
    case press(TVButton)
    /// From typing back to the remote.
    case leaveTyping
    /// Close the notch.
    case close
}

public enum KeyCommands {
    private enum Key {
        static let returnKey: UInt16 = 36
        static let space: UInt16 = 49
        static let escape: UInt16 = 53
        static let keypadEnter: UInt16 = 76
        static let left: UInt16 = 123
        static let right: UInt16 = 124
        static let down: UInt16 = 125
        static let up: UInt16 = 126
    }

    /// The action for a key on a screen, or nil to leave the key to
    /// whatever has focus in the notch: a text field, mostly.
    public static func action(keyCode: UInt16, command: Bool, screen: Screen) -> KeyAction? {
        switch screen {
        case .remote:
            switch (keyCode, command) {
            case (Key.up, true): return .press(.volumeUp)
            case (Key.down, true): return .press(.volumeDown)
            case (_, true): return nil
            case (Key.up, _): return .press(.up)
            case (Key.down, _): return .press(.down)
            case (Key.left, _): return .press(.left)
            case (Key.right, _): return .press(.right)
            case (Key.returnKey, _), (Key.keypadEnter, _): return .press(.select)
            case (Key.escape, _): return .press(.back)
            case (Key.space, _): return .press(.playPause)
            default: return nil
            }
        case .typing:
            // The arrows stay with the text field, to move the caret.
            guard !command else { return nil }
            switch keyCode {
            case Key.escape, Key.returnKey, Key.keypadEnter: return .leaveTyping
            default: return nil
            }
        case .chooseDevice, .connecting, .pin, .failed, .networkDenied:
            return keyCode == Key.escape && !command ? .close : nil
        }
    }
}
