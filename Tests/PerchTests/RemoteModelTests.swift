//
//  RemoteModelTests.swift
//  Perch
//
//  Created by Kaan Firat.
//

import XCTest
@testable import PerchApp

@MainActor
final class RemoteModelTests: XCTestCase {
    // MARK: - Screen

    func testScreenFollowsTheLink() {
        XCTAssertEqual(screen(.disconnected), .chooseDevice)
        XCTAssertEqual(screen(.connecting), .connecting)
        XCTAssertEqual(screen(.pairing), .pin)
        XCTAssertEqual(screen(.connected), .remote)
        XCTAssertEqual(screen(.localNetworkDenied), .networkDenied)
        XCTAssertEqual(screen(.failed("no")), .failed("no"))
    }

    func testKeyboardFocusOpensTypingOnlyWhileConnected() {
        XCTAssertEqual(screen(.connected, keyboard: true), .typing)
        XCTAssertEqual(screen(.connecting, keyboard: true), .connecting)
    }

    func testDismissedTypingStaysOnTheRemote() {
        XCTAssertEqual(screen(.connected, keyboard: true, dismissed: true), .remote)
    }

    // MARK: - Compact

    func testCompactState() {
        XCTAssertEqual(compact(.disconnected), .offline)
        XCTAssertEqual(compact(.failed("no")), .offline)
        XCTAssertEqual(compact(.pairing), .pairing)
        XCTAssertEqual(compact(.connected), .idle)
        XCTAssertEqual(compact(.connected, playing: true), .playing)
    }

    func testKeyboardRequestWinsOverPlaying() {
        XCTAssertEqual(compact(.connected, playing: true, keyboard: true), .keyboard)
    }

    // MARK: - Typing

    func testTypingStartsFromWhatTheTVHolds() {
        let tv = FakeTV()
        let model = RemoteModel(session: tv)
        tv.link = .connected
        tv.remoteText = "yüzük"
        tv.keyboardFocused = true
        model.keyboardFocusChanged(true)

        XCTAssertEqual(model.draft, "yüzük")
        XCTAssertEqual(model.screen, .typing)
    }

    func testEveryChangeToTheDraftGoesToTheTV() {
        let tv = FakeTV()
        let model = RemoteModel(session: tv)
        tv.link = .connected
        tv.keyboardFocused = true
        model.keyboardFocusChanged(true)

        model.draft = "y"
        model.draft = "yü"
        XCTAssertEqual(tv.sent.suffix(2), ["y", "yü"])
    }

    func testNothingIsSentWithoutAFocusedField() {
        let tv = FakeTV()
        let model = RemoteModel(session: tv)
        tv.link = .connected

        model.draft = "hello"
        XCTAssertTrue(tv.sent.isEmpty)
    }

    func testLeavingTypingComesBackAfterTheNotchCloses() {
        let tv = FakeTV()
        let model = RemoteModel(session: tv)
        tv.link = .connected
        tv.keyboardFocused = true

        model.leaveTyping()
        XCTAssertEqual(model.screen, .remote)
        model.panelClosed()
        XCTAssertEqual(model.screen, .typing)
    }

    func testLosingFocusClearsTheDraft() {
        let tv = FakeTV()
        let model = RemoteModel(session: tv)
        tv.link = .connected
        tv.keyboardFocused = true
        model.keyboardFocusChanged(true)
        model.draft = "abc"

        tv.keyboardFocused = false
        model.keyboardFocusChanged(false)
        XCTAssertEqual(model.draft, "")
        XCTAssertEqual(model.screen, .remote)
    }

    func testConnectingStallsOnlyWhileItLasts() {
        let model = RemoteModel(session: FakeTV(), stallDelay: 0.05)

        model.screenChanged(.connecting)
        XCTAssertFalse(model.connectingStalled)
        let waited = expectation(description: "stall delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { waited.fulfill() }
        wait(for: [waited], timeout: 2)
        XCTAssertTrue(model.connectingStalled)

        model.screenChanged(.remote)
        XCTAssertFalse(model.connectingStalled)
    }

    func testPressReachesTheTVAndLightsThePad() {
        let tv = FakeTV()
        let model = RemoteModel(session: tv)

        model.press(.left)
        XCTAssertEqual(tv.pressed, [.left])
        XCTAssertEqual(model.pressed, .left)
    }

    // MARK: - Helpers

    private func screen(_ link: TVLink, keyboard: Bool = false, dismissed: Bool = false) -> Screen {
        RemoteModel.screenFor(link: link, keyboardFocused: keyboard, typingDismissed: dismissed)
    }

    private func compact(_ link: TVLink, playing: Bool = false, keyboard: Bool = false) -> CompactState {
        RemoteModel.compactFor(link: link, isPlaying: playing, keyboardFocused: keyboard)
    }
}

@MainActor
private final class FakeTV: TVSession {
    var link: TVLink = .disconnected
    var devices: [TVDevice] = []
    var deviceName: String?
    var nowPlaying: TVNowPlaying?
    var keyboardFocused = false
    var remoteText = ""

    var pressed: [TVButton] = []
    var sent: [String] = []

    func start() {}
    func connect(to device: TVDevice) {}
    func submitPIN(_ pin: String) {}
    func retry() {}
    func forget() {}
    func press(_ button: TVButton) { pressed.append(button) }
    func skip(by seconds: Double) {}
    func sendText(_ text: String) { sent.append(text) }
}
