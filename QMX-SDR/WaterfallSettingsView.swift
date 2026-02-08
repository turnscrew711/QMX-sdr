//
//  WaterfallSettingsView.swift
//  QMX-SDR
//
//  Sheet with sliders for sensitivity, gamma, and palette.
//

import SwiftUI

/// When true, we're in Xcode Preview: use local state only so sliders don't crash the canvas.
private var isPreviewCanvas: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

struct WaterfallSettingsView: View {
    @Binding var sensitivity: Float
    @Binding var gamma: Float
    @Binding var palette: WaterfallPalette
    @Binding var inputGain: Float
    @Environment(\.dismiss) private var dismiss

    @State private var previewSensitivity: Double = 1.0
    @State private var previewGamma: Double = 0.92
    @State private var previewPalette: WaterfallPalette = .blueRed
    @State private var previewInputGain: Double = 0.5

    private func gainBinding() -> Binding<Double> {
        Binding(
            get: { isPreviewCanvas ? previewInputGain : Double(inputGain) },
            set: { if isPreviewCanvas { previewInputGain = $0 } else { inputGain = Float($0) } }
        )
    }
    private func sensitivityBinding() -> Binding<Double> {
        Binding(
            get: { isPreviewCanvas ? previewSensitivity : Double(sensitivity) },
            set: { if isPreviewCanvas { previewSensitivity = $0 } else { sensitivity = Float($0) } }
        )
    }
    private func gammaBinding() -> Binding<Double> {
        Binding(
            get: { isPreviewCanvas ? previewGamma : Double(gamma) },
            set: { if isPreviewCanvas { previewGamma = $0 } else { gamma = Float($0) } }
        )
    }
    private func paletteBinding() -> Binding<WaterfallPalette> {
        if isPreviewCanvas {
            return $previewPalette
        } else {
            return $palette
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Input level") {
                    HStack {
                        Text("Gain")
                        Slider(value: gainBinding(), in: 0.1...1.0)
                        Text(String(format: "%.0f%%", (isPreviewCanvas ? Float(previewInputGain) : inputGain) * 100))
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 36, alignment: .trailing)
                    }
                    Text("Lower = less mic/room noise. Use when not on USB IQ.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Sensitivity") {
                    HStack {
                        Text("Contrast")
                        Slider(value: sensitivityBinding(), in: 0.5...2.0)
                        Text(String(format: "%.2f", isPreviewCanvas ? Float(previewSensitivity) : sensitivity))
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 36, alignment: .trailing)
                    }
                    Text("Higher = more contrast (weak signals stand out more).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Coloration") {
                    HStack {
                        Text("Gamma")
                        Slider(value: gammaBinding(), in: 0.5...2.0)
                        Text(String(format: "%.2f", isPreviewCanvas ? Float(previewGamma) : gamma))
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 36, alignment: .trailing)
                    }
                    Text("Lower = darker darks; higher = flatter, brighter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Palette", selection: paletteBinding()) {
                        ForEach(WaterfallPalette.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .onAppear {
                if isPreviewCanvas {
                    previewSensitivity = Double(sensitivity)
                    previewGamma = Double(gamma)
                    previewPalette = palette
                    previewInputGain = Double(inputGain)
                }
            }
            .background(Win98.windowBackground)
            .navigationTitle("Waterfall Display")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Win98.surface, for: .navigationBar)
            .tint(Win98.surface)
        }
        .overlay(alignment: .topTrailing) {
            Win98ToolbarDoneLabel { dismiss() }
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Waterfall settings") {
    struct PreviewWrapper: View {
        @State private var sensitivity: Float = 1.0
        @State private var gamma: Float = 0.92
        @State private var palette: WaterfallPalette = .blueRed
        @State private var inputGain: Float = 0.5
        var body: some View {
            WaterfallSettingsView(sensitivity: $sensitivity, gamma: $gamma, palette: $palette, inputGain: $inputGain)
        }
    }
    return PreviewWrapper()
}
