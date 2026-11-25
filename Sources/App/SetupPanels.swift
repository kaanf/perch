//
//  SetupPanels.swift
//  Perch
//
//  Created by Kaan Firat.
//

import AppKit
import SwiftUI

/// The tvs on the network, to pick the one to pair with.
struct DeviceList: View {
    let model: RemoteModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apple TV seç")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
            if model.session.devices.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Ağda Apple TV aranıyor").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }
                .frame(height: 34)
            } else {
                VStack(spacing: 6) {
                    ForEach(model.session.devices) { device in
                        Button { model.session.connect(to: device) } label: { row(device) }
                            .buttonStyle(.plain)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private func row(_ device: TVDevice) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "tv").font(.system(size: 12)).foregroundStyle(Theme.text)
            Text(device.name).font(.system(size: 13)).foregroundStyle(Theme.text).lineLimit(1)
            Spacer()
            Text(device.isPaired ? "Bağlan" : "Eşleştir").font(.system(size: 11)).foregroundStyle(Theme.secondary)
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}

/// The four digits the tv is showing.
struct PinEntry: View {
    let model: RemoteModel
    @State private var pin = ""
    @State private var submitted = false
    @FocusState private var focused: Bool

    private static let length = 4

    var body: some View {
        VStack(spacing: 10) {
            Text("TV'de görünen kodu gir")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
            HStack(spacing: 8) {
                ForEach(0..<Self.length, id: \.self) { index in
                    Text(digit(at: index))
                        .font(.system(size: 17, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .frame(width: 32, height: 38)
                        .background(Theme.control, in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            if index == pin.count, !submitted {
                                RoundedRectangle(cornerRadius: 6).stroke(Theme.accent, lineWidth: 2)
                            }
                        }
                }
            }
            // The boxes are drawn from this field, which takes the typing
            // and is otherwise out of sight.
            .background {
                TextField("Kod", text: $pin)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .opacity(0.01)
                    .accessibilityLabel("Eşleştirme kodu")
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            Text(submitted ? "Doğrulanıyor" : "\(model.session.deviceName ?? "Apple TV") ile eşleşiyor")
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .onAppear { focused = true }
        .onChange(of: pin) { _, entered in
            let digits = String(entered.filter(\.isNumber).prefix(Self.length))
            if digits != entered { pin = digits }
            guard digits.count == Self.length, !submitted else { return }
            submitted = true
            model.session.submitPIN(digits)
        }
    }

    private func digit(at index: Int) -> String {
        index < pin.count ? String(pin[pin.index(pin.startIndex, offsetBy: index)]) : ""
    }
}

struct ConnectingView: View {
    let model: RemoteModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("\(model.session.deviceName ?? "Apple TV") bağlanıyor")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
            }
            if model.connectingStalled {
                Text("Uzun sürdü. Apple TV kapalı olabilir ya da macOS, Perch'ün yerel ağa erişmesine izin vermiyor olabilir.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    PillButton(title: "Yerel ağ ayarları") { LocalNetworkSettings.open() }
                    PillButton(title: "Tekrar dene") { model.session.retry() }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// System Settings › Privacy & Security › Local Network.
enum LocalNetworkSettings {
    private static let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")

    static func open() {
        if let url { NSWorkspace.shared.open(url) }
    }
}

struct FailedView: View {
    let model: RemoteModel
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Label("Bağlanılamadı", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            PillButton(title: "Tekrar dene") { model.session.retry() }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// macOS is keeping Perch off the local network; only Settings fixes that.
struct NetworkDeniedView: View {
    var body: some View {
        VStack(spacing: 10) {
            Label("Yerel ağ izni gerekli", systemImage: "wifi.exclamationmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("Perch, Apple TV'ni bulmak için yerel ağa erişmeli. İzni verince kendiliğinden bağlanır.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PillButton(title: "Ayarları aç") { LocalNetworkSettings.open() }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 26)
                .background(Theme.accent, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
