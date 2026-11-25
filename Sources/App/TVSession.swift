//
//  TVSession.swift
//  Perch
//
//  Created by Kaan Firat.
//

import Foundation

/// Where the connection to the Apple TV stands.
public enum TVLink: Equatable {
    case disconnected
    case connecting
    /// The tv is showing a pin and waiting for it.
    case pairing
    case connected
    /// macOS is blocking local network access for Perch.
    case localNetworkDenied
    case failed(String)
}

/// An Apple TV found on the network.
public struct TVDevice: Identifiable, Equatable {
    public let id: String
    public let name: String
    /// Whether Perch already holds keys for it, so connecting needs no pin.
    public let isPaired: Bool

    public init(id: String, name: String, isPaired: Bool) {
        self.id = id
        self.name = name
        self.isPaired = isPaired
    }
}

/// What the tv is playing.
public struct TVNowPlaying: Equatable {
    public var title: String
    /// The artist, or failing that the app doing the playing.
    public var detail: String?
    public var artwork: Data?
    public var duration: TimeInterval?
    public var isPlaying: Bool
    /// The position at `positionDate`; it runs on from there while playing.
    public var position: TimeInterval
    public var positionDate: Date

    public init(title: String, detail: String? = nil, artwork: Data? = nil, duration: TimeInterval? = nil,
                isPlaying: Bool, position: TimeInterval = 0, positionDate: Date = Date()) {
        self.title = title
        self.detail = detail
        self.artwork = artwork
        self.duration = duration
        self.isPlaying = isPlaying
        self.position = position
        self.positionDate = positionDate
    }

    public func position(at date: Date) -> TimeInterval {
        let running = isPlaying ? date.timeIntervalSince(positionDate) : 0
        let now = max(0, position + running)
        return duration.map { min($0, now) } ?? now
    }
}

/// The buttons Perch sends.
public enum TVButton: Equatable {
    case up, down, left, right, select
    /// Menu on the Siri Remote: back.
    case back
    case home
    case playPause
    case volumeUp, volumeDown
    case sleep
}

/// Everything the interface knows about the Apple TV and can ask of it.
///
/// The views and `RemoteModel` only ever see this, so the same interface
/// runs against the real tv (`LiveTV`) and, in debug builds, a made-up one
/// (`MockTV`). The properties are observable: reading them in a view or in
/// `withObservationTracking` follows their changes.
@MainActor
public protocol TVSession: AnyObject {
    var link: TVLink { get }
    /// The Apple TVs on the network right now.
    var devices: [TVDevice] { get }
    /// The tv being connected to, or connected.
    var deviceName: String? { get }
    var nowPlaying: TVNowPlaying? { get }
    /// A text field is focused on the tv.
    var keyboardFocused: Bool { get }
    /// What that text field held when it got focus.
    var remoteText: String { get }

    /// Starts looking for tvs, and reconnects to the last one if it's paired.
    func start()
    func connect(to device: TVDevice)
    func submitPIN(_ pin: String)
    /// Tries the last tv again, or goes back to the list if there's none.
    func retry()
    /// Drops the connection and the keys for the current tv.
    func forget()

    func press(_ button: TVButton)
    func skip(by seconds: Double)
    /// Makes the tv's focused text field hold `text`.
    func sendText(_ text: String)
}
