//
//  LiveTV.swift
//  Perch
//
//  Created by Kaan Firat.
//

import AppKit
import Observation
import PerchCore

/// The real Apple TV, through perch-core. The only file that knows it.
///
/// Most of what it reports is read straight off `AppleTVManager`, which is
/// observable itself, so changes there reach whoever read them here.
@MainActor
@Observable
final class LiveTV: TVSession {
    private let manager = AppleTVManager()
    /// The tvs Perch holds keys for. Kept here so listing devices doesn't
    /// go to the keychain on every redraw.
    private var pairedIDs: Set<String> = []
    @ObservationIgnored private var wakeObserver: Any?

    var link: TVLink {
        switch manager.connectionStatus {
        case .disconnected: return .disconnected
        case .connecting: return .connecting
        case .pairing: return .pairing
        case .connected: return .connected
        case .localNetworkDenied: return .localNetworkDenied
        case .error(let message): return .failed(message)
        }
    }

    var devices: [TVDevice] {
        manager.discoveredDevices.map {
            TVDevice(id: $0.id, name: $0.name, isPaired: pairedIDs.contains($0.id))
        }
    }

    var deviceName: String? { manager.connectedDeviceName }

    var nowPlaying: TVNowPlaying? {
        let media = manager.mrpManager
        guard let state = media.nowPlaying, let title = state.title, !title.isEmpty else { return nil }
        let app = manager.installedApps.first { $0.bundleID == media.activeAppBundleID }?.name
        return TVNowPlaying(title: title, detail: state.artist ?? app, artwork: state.artworkData,
                            duration: state.duration, isPlaying: state.isPlaying,
                            position: state.elapsedTime ?? 0, positionDate: state.timestamp)
    }

    var keyboardFocused: Bool { manager.keyboardFocused }
    var remoteText: String { manager.remoteText }

    func start() {
        PerchCoreLog.verbose = ProcessInfo.processInfo.environment["PERCH_VERBOSE"] != nil
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconnectAfterWake() }
        }
        retry()
    }

    func connect(to device: TVDevice) {
        guard let found = manager.discoveredDevices.first(where: { $0.id == device.id }) else { return }
        manager.connect(to: found)
    }

    func submitPIN(_ pin: String) {
        manager.submitPIN(pin)
    }

    func retry() {
        pairedIDs = Set(KeychainStorage.allPairedDeviceIDs())
        // Connecting pauses the search; without a tv to go back to, the
        // list needs it running again.
        manager.startScanning()
        if let last = manager.lastConnectedDeviceID, pairedIDs.contains(last) {
            manager.connectToLastConnectedDevice()
        } else {
            manager.disconnect()
        }
    }

    func forget() {
        if let id = manager.connectedDeviceID ?? manager.lastConnectedDeviceID {
            KeychainStorage.delete(for: id)
        }
        manager.disconnect()
        retry()
    }

    func press(_ button: TVButton) {
        manager.pressButton(Self.companionButton(button))
    }

    func skip(by seconds: Double) {
        manager.mrpManager.sendSkip(seconds < 0 ? .skipBackward : .skipForward, interval: Float(abs(seconds)))
    }

    func sendText(_ text: String) {
        manager.updateRemoteText(text)
    }

    /// The connection doesn't survive sleep, and the tv may have changed
    /// address meanwhile.
    private func reconnectAfterWake() {
        guard link != .pairing else { return }
        retry()
    }

    private static func companionButton(_ button: TVButton) -> CompanionButton {
        switch button {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .select: return .select
        case .back: return .menu
        case .home: return .home
        case .playPause: return .playPause
        case .volumeUp: return .volumeUp
        case .volumeDown: return .volumeDown
        case .sleep: return .sleep
        }
    }
}
