//
//  SpectrumTestView.swift
//  QMX-SDR
//
//  Runs IQ capture -> FFT -> single spectrum line. Confirms scale and center.
//

import SwiftUI

struct SpectrumTestView: View {
    @State private var capture = IQCaptureService()
    @State private var pipeline = SpectrumPipeline()
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 8) {
            Text("Spectrum (48 kHz IQ, 12 kHz offset)")
                .font(.caption)
            SpectrumLineView(magnitude: pipeline.magnitudeDB, useDB: true)
                .frame(height: 160)
                .background(Color.black.opacity(0.3))

            if pipeline.sampleRate > 0 {
                Text("\(Int(pipeline.sampleRate)) Hz · FFT \(pipeline.fftSize)")
                    .font(.caption2)
            }

            Button(isRunning ? "Stop" : "Start") {
                toggle()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onDisappear {
            capture.stop()
            isRunning = false
        }
    }

    private func toggle() {
        if isRunning {
            capture.stop()
            isRunning = false
        } else {
            pipeline.sampleRate = 48000
            capture.onSamples = { [pipeline] samples, _ in
                pipeline.push(samples: samples)
            }
            do {
                try capture.start()
                pipeline.sampleRate = capture.sampleRate
                isRunning = true
            } catch {
                // Show error in UI if needed
            }
        }
    }
}

#Preview {
    SpectrumTestView()
}
