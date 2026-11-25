//
//  main.swift
//  Perch
//
//  Created by Kaan Firat.
//

import AppKit
import PerchApp

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var remote: RemoteController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        remote = RemoteController(arguments: CommandLine.arguments)
        remote?.start()
    }

    /// Opening Perch again while it runs opens the remote. With no menu bar
    /// item, that, the shortcut and the notch itself are the ways in.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        remote?.open()
        return false
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
