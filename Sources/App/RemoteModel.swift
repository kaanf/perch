//
//  RemoteModel.swift
//  Perch
//
//  Created by Kaan Firat.
//

import Foundation
import Observation

/// What the open notch shows.
public enum Screen: Equatable {
    /// Not connected, and no paired tv to go back to: the tvs on the network.
    case chooseDevice
    case connecting
    case pin
    case remote
    /// The tv has a text field focused and the Mac keyboard feeds it.
    case typing
    case failed(String)
    case networkDenied
}

/// What the closed notch says.
public enum CompactState: Equatable {
    case offline
    case pairing
    case idle
    case playing
    /// The tv wants text.
    case keyboard
}

/// Another app living in the same notch, to switch over to.
public struct Neighbour: Identifiable, Equatable {
    public let id: String
    /// It has something waiting for the user.
    public let wantsAttention: Bool

    public init(id: String, wantsAttention: Bool) {
        self.id = id
        self.wantsAttention = wantsAttention
    }
}

/// The interface's state, worked out from the session, and the few things
/// only the interface knows: the text being typed and which button just
/// went down.
@MainActor
@Observable
public final class RemoteModel {
    public let session: any TVSession

    /// The Mac's copy of the tv's text field. Every change goes to the tv.
    public var draft = "" {
        didSet {
            guard draft != oldValue, session.keyboardFocused else { return }
            session.sendText(draft)
        }
    }

    /// The other apps sharing the notch, for the switch buttons.
    public var neighbours: [Neighbour] = []
    /// Hands the open notch over to a neighbour.
    @ObservationIgnored public var onSwitch: ((Neighbour) -> Void)?

    /// Opens the setup window again.
    @ObservationIgnored public var onShowSetup: (() -> Void)?

    /// The user went back to the remote while the tv still wants text.
    public private(set) var typingDismissed = false
    /// The button that was just sent, for the pad to light up.
    public private(set) var pressed: TVButton?
    @ObservationIgnored private var pressedReset: DispatchWorkItem?
    /// Connecting has gone on long enough that something is in the way.
    /// macOS blocking the local network looks exactly like this: the
    /// connection just never gets anywhere, and nothing reports why.
    public private(set) var connectingStalled = false
    @ObservationIgnored private var stallTimer: DispatchWorkItem?
    @ObservationIgnored private let stallDelay: TimeInterval

    /// - Parameter stallDelay: How long connecting may take before the
    ///   interface offers help.
    public init(session: any TVSession, stallDelay: TimeInterval = 8) {
        self.session = session
        self.stallDelay = stallDelay
    }

    public var screen: Screen {
        Self.screenFor(link: session.link, keyboardFocused: session.keyboardFocused, typingDismissed: typingDismissed)
    }

    public var compact: CompactState {
        Self.compactFor(link: session.link, isPlaying: session.nowPlaying?.isPlaying == true,
                     keyboardFocused: session.keyboardFocused)
    }

    /// The size of the open content for the current screen.
    public var panelSize: CGSize {
        switch screen {
        case .chooseDevice:
            return CGSize(width: 320, height: 46 + CGFloat(max(1, session.devices.count)) * 40)
        case .connecting: return connectingStalled ? CGSize(width: 340, height: 138) : CGSize(width: 280, height: 76)
        case .pin: return CGSize(width: 280, height: 114)
        case .remote: return CGSize(width: 548, height: 258)
        case .typing: return CGSize(width: 512, height: 146)
        case .failed: return CGSize(width: 320, height: 112)
        case .networkDenied: return CGSize(width: 340, height: 124)
        }
    }

    public nonisolated static func screenFor(link: TVLink, keyboardFocused: Bool, typingDismissed: Bool) -> Screen {
        switch link {
        case .disconnected: return .chooseDevice
        case .connecting: return .connecting
        case .pairing: return .pin
        case .connected: return keyboardFocused && !typingDismissed ? .typing : .remote
        case .localNetworkDenied: return .networkDenied
        case .failed(let message): return .failed(message)
        }
    }

    public nonisolated static func compactFor(link: TVLink, isPlaying: Bool, keyboardFocused: Bool) -> CompactState {
        switch link {
        case .connected: return keyboardFocused ? .keyboard : isPlaying ? .playing : .idle
        case .pairing: return .pairing
        case .disconnected, .connecting, .localNetworkDenied, .failed: return .offline
        }
    }

    // MARK: - Actions

    public func press(_ button: TVButton) {
        session.press(button)
        pressed = button
        pressedReset?.cancel()
        let reset = DispatchWorkItem { [weak self] in self?.pressed = nil }
        pressedReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: reset)
    }

    /// Back to the remote, leaving the tv's text field as it is.
    public func leaveTyping() {
        typingDismissed = true
    }

    public func resumeTyping() {
        typingDismissed = false
    }

    /// A text field on the tv got or lost focus. A new field starts from
    /// what the tv already holds in it.
    public func keyboardFocusChanged(_ focused: Bool) {
        typingDismissed = false
        draft = focused ? session.remoteText : ""
    }

    /// The screen changed. Starts the clock on connecting, and stops it
    /// on anything else.
    public func screenChanged(_ screen: Screen) {
        stallTimer?.cancel()
        stallTimer = nil
        connectingStalled = false
        guard screen == .connecting else { return }
        let timer = DispatchWorkItem { [weak self] in self?.connectingStalled = true }
        stallTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + stallDelay, execute: timer)
    }

    /// The notch closed: next time it opens straight into typing again.
    public func panelClosed() {
        typingDismissed = false
    }
}
