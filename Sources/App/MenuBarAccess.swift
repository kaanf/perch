//
//  MenuBarAccess.swift
//  Perch
//
//  Created by Kaan Firat.
//

import AppKit
import ApplicationServices

/// The Accessibility permission, which Perch wants for one thing: reading
/// where the frontmost app's menus end, so the left wing can get out of
/// their way. Without it the left side always counts as free, and the
/// wings sit on top of long menus instead of dropping to the line.
enum MenuBarAccess {
    private static let settings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

    static var isGranted: Bool { AXIsProcessTrusted() }

    /// Puts Perch in the Accessibility list, with the system's request the
    /// first time, and opens that list for the user to switch it on.
    static func request() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let settings { NSWorkspace.shared.open(settings) }
    }
}
