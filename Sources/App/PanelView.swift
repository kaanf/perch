//
//  PanelView.swift
//  Perch
//
//  Created by Kaan Firat.
//

import AppKit
import SwiftUI

/// The open notch: one of the screens, by what the model says.
struct PanelView: View {
    let model: RemoteModel
    let preferences: Preferences

    var body: some View {
        Group {
            switch model.screen {
            case .chooseDevice: DeviceList(model: model)
            case .connecting: ConnectingView(model: model)
            case .pin: PinEntry(model: model)
            case .remote: RemotePanel(model: model, shortcut: preferences.shortcut.displayString)
            case .typing: TypingPanel(model: model)
            case .failed(let message): FailedView(model: model, message: message)
            case .networkDenied: NetworkDeniedView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The notch's right-click menu.
struct NotchMenu: View {
    let model: RemoteModel

    var body: some View {
        if model.session.link == .connected {
            Button("Bu Apple TV'yi unut") { model.session.forget() }
            Divider()
        }
        Button("Kurulum ve İzinler…") { model.onShowSetup?() }
        Divider()
        #if DEBUG
        if let mock = model.session as? MockTV {
            Menu("Sahte TV") {
                ForEach(MockTV.Scenario.allCases, id: \.self) { scenario in
                    Button(scenario.title) { mock.apply(scenario) }
                }
            }
            Divider()
        }
        #endif
        Button("Perch'ten Çık") { NSApp.terminate(nil) }
    }
}
