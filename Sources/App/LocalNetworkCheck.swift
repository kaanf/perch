//
//  LocalNetworkCheck.swift
//  Perch
//
//  Created by Kaan Firat.
//

import Foundation
import Network

/// Asks for local network access and finds out the answer.
///
/// macOS has no call for either. Touching the local network brings up the
/// system's request, and the only way to learn the answer is to try: this
/// advertises a Bonjour service and looks for it. Finding it means access
/// was given; a refused lookup means it wasn't (Apple's TN3179).
@MainActor
final class LocalNetworkCheck {
    enum Answer {
        case granted
        case denied
    }

    /// Must be listed under NSBonjourServices in Info.plist.
    private static let serviceType = "_perchcheck._tcp"

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var onAnswer: ((Answer) -> Void)?

    /// Starts asking. `onAnswer` may be called more than once: a refusal
    /// turns into `granted` if the user allows access in Settings while
    /// this is still running.
    func start(onAnswer: @escaping (Answer) -> Void) {
        stop()
        self.onAnswer = onAnswer

        let listener = try? NWListener(using: .tcp)
        listener?.service = NWListener.Service(name: UUID().uuidString, type: Self.serviceType)
        listener?.newConnectionHandler = { $0.cancel() }
        listener?.stateUpdateHandler = { [weak self] state in
            guard case .waiting(let error) = state, Self.isDenial(error) else { return }
            Task { @MainActor in self?.onAnswer?(.denied) }
        }
        listener?.start(queue: .main)
        self.listener = listener

        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: .tcp)
        browser.stateUpdateHandler = { [weak self] state in
            guard case .waiting(let error) = state, Self.isDenial(error) else { return }
            Task { @MainActor in self?.onAnswer?(.denied) }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard !results.isEmpty else { return }
            Task { @MainActor in
                self?.onAnswer?(.granted)
                self?.stop()
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        listener?.cancel()
        browser?.cancel()
        listener = nil
        browser = nil
        onAnswer = nil
    }

    private nonisolated static func isDenial(_ error: NWError) -> Bool {
        if case .dns(let code) = error { return code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied) }
        return false
    }
}
