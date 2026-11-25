//
//  MockTV.swift
//  Perch
//
//  Created by Kaan Firat.
//

#if DEBUG
import Foundation
import Observation

/// A made-up Apple TV, for trying the interface without a real one.
///
///     open build/Perch.app --args --mock-tv playing
///
/// The scenario is one of `MockTV.Scenario`; the notch's right-click menu
/// switches between them while running. Commands are answered the way the
/// tv would, near enough: connecting asks for a pin, any pin but 0000 is
/// right, play/pause flips what's playing.
@MainActor
@Observable
final class MockTV: TVSession {
    enum Scenario: String, CaseIterable {
        /// No tv paired yet: the list of tvs on the network.
        case unpaired
        case pairing
        case connecting
        case idle
        case playing
        /// Playing, and a text field just got focus.
        case keyboard
        case failed
        case networkDenied = "network-denied"

        var title: String {
            switch self {
            case .unpaired: return "Not paired (device list)"
            case .pairing: return "Pairing (PIN)"
            case .connecting: return "Connecting"
            case .idle: return "Connected, idle"
            case .playing: return "Playing"
            case .keyboard: return "Keyboard requested"
            case .failed: return "Error"
            case .networkDenied: return "No local network access"
            }
        }
    }

    private(set) var scenario: Scenario
    private(set) var link: TVLink = .disconnected
    private(set) var devices: [TVDevice] = []
    private(set) var deviceName: String?
    private(set) var nowPlaying: TVNowPlaying?
    private(set) var keyboardFocused = false
    private(set) var remoteText = ""
    /// What the tv's text field holds now, for the debug menu to show.
    private(set) var sentText = ""

    /// The scenario named after `--mock-tv`, or nil without that argument.
    init?(arguments: [String]) {
        guard let flag = arguments.firstIndex(of: "--mock-tv") else { return nil }
        let name = arguments.indices.contains(flag + 1) ? arguments[flag + 1] : ""
        scenario = Scenario(rawValue: name) ?? .idle
    }

    func start() {
        apply(scenario)
    }

    func apply(_ scenario: Scenario) {
        self.scenario = scenario
        devices = [
            TVDevice(id: "living-room", name: "Living Room", isPaired: scenario != .unpaired && scenario != .pairing),
            TVDevice(id: "bedroom", name: "Bedroom", isPaired: false),
        ]
        deviceName = scenario == .unpaired ? nil : "Living Room"
        nowPlaying = nil
        keyboardFocused = false
        remoteText = ""
        sentText = ""

        switch scenario {
        case .unpaired: link = .disconnected
        case .pairing: link = .pairing
        case .connecting: link = .connecting
        case .idle: link = .connected
        case .playing:
            link = .connected
            nowPlaying = Self.film
        case .keyboard:
            link = .connected
            nowPlaying = Self.film
            keyboardFocused = true
            remoteText = "the lord"
            sentText = remoteText
        case .failed: link = .failed("The Apple TV didn't answer")
        case .networkDenied: link = .localNetworkDenied
        }
    }

    func connect(to device: TVDevice) {
        deviceName = device.name
        link = .connecting
        after(0.6) { [self] in
            if device.isPaired { apply(.idle) } else { link = .pairing }
        }
    }

    func submitPIN(_ pin: String) {
        after(0.6) { [self] in
            if pin == "0000" {
                link = .failed("Wrong code")
            } else {
                apply(.idle)
            }
        }
    }

    func retry() {
        apply(.unpaired)
    }

    func forget() {
        apply(.unpaired)
    }

    func press(_ button: TVButton) {
        print("mock tv: \(button)")
        guard button == .playPause, var playing = nowPlaying else { return }
        playing.position = playing.position(at: Date())
        playing.positionDate = Date()
        playing.isPlaying.toggle()
        nowPlaying = playing
    }

    func skip(by seconds: Double) {
        guard var playing = nowPlaying else { return }
        playing.position = max(0, playing.position(at: Date()) + seconds)
        playing.positionDate = Date()
        nowPlaying = playing
    }

    func sendText(_ text: String) {
        print("mock tv: text \"\(text)\"")
        sentText = text
    }

    private func after(_ seconds: TimeInterval, _ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            MainActor.assumeIsolated(work)
        }
    }

    private static var film: TVNowPlaying {
        TVNowPlaying(title: "Night Train", detail: "TV", duration: 2 * 3600 + 4 * 60,
                     isPlaying: true, position: 3600 + 12 * 60 + 40)
    }
}
#endif
