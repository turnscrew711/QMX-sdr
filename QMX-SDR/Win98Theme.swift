//
//  Win98Theme.swift
//  QMX-SDR
//
//  Windows 98–style colors and rectangular button appearance.
//

import SwiftUI

enum Win98 {
    static let buttonFace = Color(red: 0.75, green: 0.75, blue: 0.75)
    static let buttonHighlight = Color(red: 1, green: 1, blue: 1)
    static let buttonShadow = Color(red: 0.5, green: 0.5, blue: 0.5)
    static let buttonDarkShadow = Color(red: 0.25, green: 0.25, blue: 0.25)
    static let windowBackground = Color(red: 0.87, green: 0.87, blue: 0.87)
    static let surface = Color(red: 0.83, green: 0.83, blue: 0.83)
}

/// Same look as Win98ButtonStyle (for Menu label so Band matches Menu/BT buttons).
struct Win98Box: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Win98.buttonFace)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Win98.buttonDarkShadow, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Win98.buttonHighlight, lineWidth: 1)
                    .padding(1)
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

extension View {
    func win98Box() -> some View { modifier(Win98Box()) }
}

struct Win98ButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Win98.buttonFace)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Win98.buttonDarkShadow, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Win98.buttonHighlight, lineWidth: 1)
                    .padding(1)
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
