//
//  Theme.swift
//  Perch
//
//  Created by Kaan Firat.
//

import SwiftUI

/// The colours of the design, all on the notch's black.
enum Theme {
    static let card = Color(hex: 0x1C1C1E)
    static let control = Color(hex: 0x2C2C2E)
    static let track = Color(hex: 0x3A3A3C)
    static let text = Color(hex: 0xF5F5F7)
    static let secondary = Color(hex: 0x98989D)
    static let accent = Color(hex: 0x0A84FF)
    static let green = Color(hex: 0x30D158)
    static let yellow = Color(hex: 0xFFD60A)
    static let red = Color(hex: 0xFF453A)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// A key's name on a small grey cap, as in the shortcut hints.
struct KeyCap: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(.system(size: 11))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.control, in: RoundedRectangle(cornerRadius: 4))
    }
}

/// The blue disc with a keyboard in it that means "the tv wants text",
/// with a ring pulsing out of it.
struct KeyboardBadge: View {
    var size: CGFloat = 18
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(Theme.accent)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "keyboard")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .background {
                Circle()
                    .stroke(Theme.accent, lineWidth: 2)
                    .scaleEffect(pulsing ? 1.8 : 1)
                    .opacity(pulsing ? 0 : 0.6)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulsing = true }
            }
            .accessibilityHidden(true)
    }
}

/// Four bars moving while something plays.
struct Equalizer: View {
    private static let heights: [CGFloat] = [6, 12, 8, 10]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(Self.heights.indices, id: \.self) { index in
                    let swing = (sin(time * 5 + Double(index) * 1.7) + 1) / 2
                    Capsule()
                        .fill(Theme.text)
                        .frame(width: 2, height: 4 + (Self.heights[index] - 4) * swing)
                }
            }
            .frame(height: 12)
        }
        .accessibilityHidden(true)
    }
}

extension TimeInterval {
    /// "1:12:40" or "4:05".
    var clockString: String {
        let total = Int(max(0, self).rounded(.down))
        let (hours, minutes, seconds) = (total / 3600, total / 60 % 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}
