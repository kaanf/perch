//
//  RemotePanel.swift
//  Perch
//
//  Created by Kaan Firat.
//

import SwiftUI

/// The open remote: what's playing, the pad, and the buttons around it.
struct RemotePanel: View {
    let model: RemoteModel
    let shortcut: String

    var body: some View {
        VStack(spacing: 10) {
            header
            HStack(alignment: .center, spacing: 14) {
                NowPlayingCard(model: model)
                DirectionPad(model: model)
                VStack(spacing: 10) {
                    buttons
                    volume
                }
                .frame(maxWidth: .infinity)
            }
            typingRow
            hints
        }
        .padding(.horizontal, 18)
        .padding(.top, 2)
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack {
            Label {
                Text(model.session.deviceName ?? "Apple TV").font(.system(size: 13, weight: .semibold))
            } icon: {
                Image(systemName: "tv").font(.system(size: 12))
            }
            .foregroundStyle(Theme.text)
            Spacer()
            ForEach(model.neighbours) { neighbour in
                switchButton(neighbour)
            }
            HStack(spacing: 5) {
                Circle().fill(Theme.green).frame(width: 6, height: 6)
                Text("Connected").font(.system(size: 11)).foregroundStyle(Theme.secondary)
            }
        }
        .frame(height: 24)
    }

    /// Over to another app in the notch. Blue when it has something waiting.
    private func switchButton(_ neighbour: Neighbour) -> some View {
        Button { model.onSwitch?(neighbour) } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 9, weight: .semibold))
                Text(neighbour.id).font(.system(size: 11))
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(neighbour.wantsAttention ? Theme.accent : Theme.control, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Switch to \(neighbour.id)")
    }

    private var buttons: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 8) {
            GridRow {
                RoundButton(model: model, button: .back, symbol: "chevron.left", title: "Back")
                RoundButton(model: model, button: .home, symbol: "tv", title: "Home")
            }
            GridRow {
                RoundButton(model: model, button: .playPause, symbol: "playpause.fill", title: "Play")
                RoundButton(model: model, button: .sleep, symbol: "power", title: "Sleep")
            }
        }
    }

    private var volume: some View {
        HStack(spacing: 8) {
            volumeButton(.volumeDown, symbol: "speaker.minus.fill", label: "Volume down")
            Text("Volume").font(.system(size: 11)).foregroundStyle(Theme.secondary)
            volumeButton(.volumeUp, symbol: "speaker.plus.fill", label: "Volume up")
        }
    }

    private func volumeButton(_ button: TVButton, symbol: String, label: String) -> some View {
        Button { model.press(button) } label: {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 26)
                .background(model.pressed == button ? Theme.accent : Theme.control, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// The tv only takes text while one of its fields has focus, so this
    /// row says which it is, and leads back to typing if it was left.
    @ViewBuilder private var typingRow: some View {
        if model.session.keyboardFocused {
            Button { model.resumeTyping() } label: {
                HStack(spacing: 8) {
                    KeyboardBadge(size: 16)
                    Text("The TV wants text. Back to typing").font(.system(size: 12)).foregroundStyle(Theme.text)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(Theme.accent, lineWidth: 1.5) }
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "keyboard").font(.system(size: 12))
                Text("When a text field opens on the TV, you type here").font(.system(size: 12))
                Spacer()
            }
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var hints: some View {
        HStack(spacing: 12) {
            hint("←↑↓→", "move")
            hint("↵", "select")
            hint("esc", "back")
            hint("space", "play")
            hint("⌘ ↑↓", "volume")
            Spacer()
            hint(shortcut, "close")
        }
    }

    private func hint(_ key: String, _ meaning: String) -> some View {
        HStack(spacing: 5) {
            KeyCap(key)
            Text(meaning).font(.system(size: 11)).foregroundStyle(Theme.secondary)
        }
    }
}

/// A round button with its name under it.
private struct RoundButton: View {
    let model: RemoteModel
    let button: TVButton
    let symbol: String
    let title: String

    var body: some View {
        Button { model.press(button) } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .frame(width: 34, height: 34)
                    .background(model.pressed == button ? Theme.accent : Theme.control, in: Circle())
                Text(title).font(.system(size: 10)).foregroundStyle(Theme.secondary)
            }
            .frame(width: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Up, down, left, right, and select in the middle.
private struct DirectionPad: View {
    let model: RemoteModel

    private static let size: CGFloat = 124

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(Theme.card)
            arrow(.up, symbol: "chevron.up", label: "Up").frame(maxHeight: .infinity, alignment: .top)
            arrow(.down, symbol: "chevron.down", label: "Down").frame(maxHeight: .infinity, alignment: .bottom)
            arrow(.left, symbol: "chevron.left", label: "Left").frame(maxWidth: .infinity, alignment: .leading)
            arrow(.right, symbol: "chevron.right", label: "Right").frame(maxWidth: .infinity, alignment: .trailing)
            Button { model.press(.select) } label: {
                Circle()
                    .fill(model.pressed == .select ? Theme.accent : Theme.control)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select")
        }
        .padding(4)
        .frame(width: Self.size, height: Self.size)
    }

    private func arrow(_ button: TVButton, symbol: String, label: String) -> some View {
        Button { model.press(button) } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(model.pressed == button ? .white : Theme.secondary)
                .frame(width: 36, height: 36)
                .background(model.pressed == button ? Theme.accent : .clear, in: RoundedRectangle(cornerRadius: 9))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// What the tv is playing, with its progress and the transport buttons.
private struct NowPlayingCard: View {
    let model: RemoteModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let playing = model.session.nowPlaying {
                HStack(spacing: 10) {
                    Artwork(data: playing.artwork, size: 40, radius: 7)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playing.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        if let detail = playing.detail {
                            Text(detail).font(.system(size: 11)).foregroundStyle(Theme.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                Progress(playing: playing)
                HStack(spacing: 18) {
                    transport("gobackward.10", label: "Back 10 seconds") { model.session.skip(by: -10) }
                    transport(playing.isPlaying ? "pause.fill" : "play.fill", label: "Play or pause") {
                        model.press(.playPause)
                    }
                    transport("goforward.10", label: "Forward 10 seconds") { model.session.skip(by: 10) }
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "play.tv").font(.system(size: 20)).foregroundStyle(Theme.secondary)
                    Text("Nothing is playing").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
        .frame(width: 204, height: 124)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func transport(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The progress bar with the time gone and the time left. It keeps its
/// own clock so the rest of the card isn't redrawn every second.
private struct Progress: View {
    let playing: TVNowPlaying

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = playing.position(at: context.date)
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    Capsule().fill(Theme.track)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Theme.text).frame(width: geometry.size.width * fraction(position))
                        }
                }
                .frame(height: 3)
                if let duration = playing.duration, duration > 0 {
                    HStack {
                        Text(position.clockString)
                        Spacer()
                        Text("-" + (duration - position).clockString)
                    }
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(Theme.secondary)
                }
            }
        }
    }

    private func fraction(_ position: TimeInterval) -> CGFloat {
        guard let duration = playing.duration, duration > 0 else { return 0 }
        return CGFloat(min(1, max(0, position / duration)))
    }
}
