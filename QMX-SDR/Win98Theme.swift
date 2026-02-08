//
//  Win98Theme.swift
//  QMX-SDR
//
//  Windows 98–style colors and rectangular button appearance.
//

import SwiftUI

enum Win98 {
    static let buttonFace = Color(red: 0.55, green: 0.55, blue: 0.55)
    static let buttonHighlight = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let buttonShadow = Color(red: 0.38, green: 0.38, blue: 0.38)
    static let buttonDarkShadow = Color(red: 0.18, green: 0.18, blue: 0.18)
    static let windowBackground = Color(red: 0.90, green: 0.90, blue: 0.90)
    static let surface = Color(red: 0.86, green: 0.86, blue: 0.86)
}

/// Same look as Win98ButtonStyle (for Menu label so Band matches Menu/BT buttons). Opaque background so iOS Menu does not show a lighter square behind.
struct Win98Box: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Win98.buttonFace)
            .overlay(
                Rectangle()
                    .stroke(Win98.buttonDarkShadow, lineWidth: 1)
            )
            .clipShape(Rectangle())
    }
}

extension View {
    func win98Box() -> some View { modifier(Win98Box()) }

    /// Gray row background for List rows in menu/settings (classic SDR look).
    func win98ListRow() -> some View {
        listRowBackground(Win98.surface)
    }
}

/// Toolbar “Done” button: Win98 look, full label (no “D” truncation). Uses a tappable view instead of Button so the system does not draw a pill/bubble behind it.
struct Win98ToolbarDoneLabel: View {
    let action: () -> Void
    var body: some View {
        Text("Done")
            .fixedSize(horizontal: true, vertical: false)
            .frame(minWidth: 52, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Win98.buttonFace)
            .overlay(Rectangle().stroke(Win98.buttonDarkShadow, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { action() }
    }
}

struct Win98ButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Win98.buttonFace)
            .overlay(
                Rectangle()
                    .stroke(Win98.buttonDarkShadow, lineWidth: 1)
            )
            .overlay(
                Rectangle()
                    .stroke(Win98.buttonHighlight, lineWidth: 1)
                    .padding(1)
                    .allowsHitTesting(false)
            )
            .clipShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
