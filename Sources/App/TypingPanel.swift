//
//  TypingPanel.swift
//  Perch
//
//  Created by Kaan Firat.
//

import AppKit
import SwiftUI

/// Keyboard mode: the tv has a text field focused, and this box is the
/// Mac's end of it. It opens holding what the tv's field holds, and every
/// change goes straight to the tv.
struct TypingPanel: View {
    @Bindable var model: RemoteModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                KeyboardBadge(size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text("The TV is waiting for you to type")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(model.session.deviceName ?? "Apple TV")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                Button { model.leaveTyping() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Leave keyboard mode")
            }

            HStack(spacing: 8) {
                TextField("Text for the TV", text: $model.draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.text)
                    .focused($focused)
                    .accessibilityLabel("Text to send to the TV")
                if !model.draft.isEmpty {
                    Button { model.draft = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.accent, lineWidth: 2) }

            HStack(spacing: 6) {
                Circle().fill(Theme.green).frame(width: 6, height: 6)
                Text("Syncing live").font(.system(size: 11)).foregroundStyle(Theme.secondary)
                Spacer()
                KeyCap("↵")
                KeyCap("esc")
                Text("back to remote").font(.system(size: 11)).foregroundStyle(Theme.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .onAppear {
            focused = true
            // Focus selects the whole field, and the next key would wipe
            // what the tv already holds; put the caret at the end instead.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                (NSApp.keyWindow?.firstResponder as? NSTextView)?.moveToEndOfDocument(nil)
            }
        }
    }
}
