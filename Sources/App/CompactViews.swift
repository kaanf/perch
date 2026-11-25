//
//  CompactViews.swift
//  Perch
//
//  Created by Kaan Firat.
//

import SwiftUI

/// The wing right of the notch: a tv and how it's doing. It reads on its
/// own, because next to another notch app it's the only wing Perch gets.
struct TrailingWing: View {
    let model: RemoteModel

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "tv")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(model.compact == .offline ? Theme.secondary : Theme.text)
            status
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    @ViewBuilder private var status: some View {
        switch model.compact {
        case .offline: dot(Theme.track)
        case .pairing: dot(Theme.yellow)
        case .idle: dot(Theme.green)
        case .playing: Equalizer()
        case .keyboard: KeyboardBadge(size: 16)
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 6, height: 6)
    }

    private var label: String {
        switch model.compact {
        case .offline: return "Apple TV bağlı değil"
        case .pairing: return "Apple TV eşleşiyor"
        case .idle: return "Apple TV bağlı"
        case .playing: return "Apple TV oynatıyor"
        case .keyboard: return "Apple TV yazı istiyor"
        }
    }
}

/// The wing left of the notch: an extra, empty unless there's something
/// to add to what the right wing says.
struct LeadingWing: View {
    let model: RemoteModel

    var body: some View {
        switch model.compact {
        case .playing:
            Artwork(data: model.session.nowPlaying?.artwork, size: 20, radius: 5)
        case .keyboard:
            Text("Yaz")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text)
        case .offline, .pairing, .idle:
            EmptyView()
        }
    }
}

/// The line under the notch when the wings don't fit: the connection.
/// Bright while playing, faint while idle, blue when the tv wants text.
struct CompactLine: View {
    let model: RemoteModel

    var body: some View {
        Capsule().fill(color)
    }

    private var color: Color {
        switch model.compact {
        case .offline: return .white.opacity(0.12)
        case .pairing: return Theme.yellow.opacity(0.7)
        case .idle: return .white.opacity(0.28)
        case .playing: return .white.opacity(0.8)
        case .keyboard: return Theme.accent
        }
    }
}

/// The pill under the notch while the tv wants text and there's no wing
/// to say so.
struct KeyboardRequest: View {
    let preferences: Preferences

    var body: some View {
        HStack(spacing: 7) {
            KeyboardBadge()
            Text("TV yazı istiyor")
                .font(.system(size: 12))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 0)
            KeyCap(preferences.shortcut.displayString)
        }
        .padding(.leading, 7)
        .padding(.trailing, 8)
    }
}

/// What's playing as a small square, or a placeholder without artwork.
struct Artwork: View {
    let data: Data?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        Group {
            if let data, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Theme.track.overlay {
                    Image(systemName: "play.fill")
                        .font(.system(size: size * 0.36))
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .accessibilityHidden(true)
    }
}
