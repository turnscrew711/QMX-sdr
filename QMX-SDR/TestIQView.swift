//
//  TestIQView.swift
//  QMX-SDR
//
//  Minimal screen to validate USB IQ capture: shows USB status and sample rate.
//

import SwiftUI

struct TestIQView: View {
    @State private var capture = IQCaptureService()
    @State private var statusMessage = "Tap Start to begin."
    @State private var lastUpdate = Date()

    var body: some View {
        VStack(spacing: 20) {
            Text("Test IQ Capture")
                .font(.headline)

            Text(statusMessage)
                .multilineTextAlignment(.center)
                .padding()

            if capture.sampleRate > 0 {
                Text("Sample rate: \(Int(capture.sampleRate)) Hz")
                Text("Channels: \(capture.channelCount)")
                Text("Buffer frames: \(capture.lastBufferFrameCount)")
            }
            Text(capture.hasUSBInput ? "USB input selected" : "Using default input (no USB found)")

            if capture.sampleRate > 0 {
                Text("Last update: \(lastUpdate, style: .time)")
            }

            Button(capture.sampleRate > 0 ? "Stop" : "Start") {
                toggleCapture()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onDisappear {
            capture.stop()
        }
    }

    private func toggleCapture() {
        if capture.sampleRate > 0 {
            capture.stop()
            statusMessage = "Stopped."
        } else {
            do {
                capture.onSamples = { [self] _, _ in
                    Task { @MainActor in
                        lastUpdate = Date()
                    }
                }
                try capture.start()
                statusMessage = "Running. Connect QMX (IQ mode) via USB for 48 kHz stereo."
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    TestIQView()
}
