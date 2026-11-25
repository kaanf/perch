//
//  KeyCommandsTests.swift
//  Perch
//
//  Created by Kaan Firat.
//

import XCTest
@testable import PerchApp

final class KeyCommandsTests: XCTestCase {
    private let left: UInt16 = 123, right: UInt16 = 124, down: UInt16 = 125, up: UInt16 = 126
    private let returnKey: UInt16 = 36, escape: UInt16 = 53, space: UInt16 = 49, letterA: UInt16 = 0

    func testArrowsReturnAndEscapeDriveTheRemote() {
        XCTAssertEqual(action(up), .press(.up))
        XCTAssertEqual(action(down), .press(.down))
        XCTAssertEqual(action(left), .press(.left))
        XCTAssertEqual(action(right), .press(.right))
        XCTAssertEqual(action(returnKey), .press(.select))
        XCTAssertEqual(action(escape), .press(.back))
        XCTAssertEqual(action(space), .press(.playPause))
    }

    func testCommandArrowsAreVolume() {
        XCTAssertEqual(action(up, command: true), .press(.volumeUp))
        XCTAssertEqual(action(down, command: true), .press(.volumeDown))
        XCTAssertNil(action(left, command: true))
    }

    func testOtherKeysAreLeftAlone() {
        XCTAssertNil(action(letterA))
    }

    func testTypingKeepsItsKeysExceptTheWayOut() {
        XCTAssertNil(action(left, screen: .typing))
        XCTAssertNil(action(space, screen: .typing))
        XCTAssertNil(action(letterA, screen: .typing))
        XCTAssertEqual(action(escape, screen: .typing), .leaveTyping)
        XCTAssertEqual(action(returnKey, screen: .typing), .leaveTyping)
    }

    func testEscapeClosesTheSetupScreens() {
        for screen in [Screen.chooseDevice, .connecting, .pin, .failed("no"), .networkDenied] {
            XCTAssertEqual(action(escape, screen: screen), .close)
            XCTAssertNil(action(returnKey, screen: screen))
        }
    }

    private func action(_ keyCode: UInt16, command: Bool = false, screen: Screen = .remote) -> KeyAction? {
        KeyCommands.action(keyCode: keyCode, command: command, screen: screen)
    }
}
