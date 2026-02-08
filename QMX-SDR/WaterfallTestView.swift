//
//  WaterfallTestView.swift
//  QMX-SDR
//
//  IQ capture -> FFT -> waterfall + spectrum line.
//

import SwiftUI

struct WaterfallTestView: View {
    @State private var capture = IQCaptureService()
    @State private var pipeline = SpectrumPipeline()
    @State private var waterfallBuffer = WaterfallBuffer(binCount: defaultFFTSize, maxRows: 256)
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Waterfall (48 kHz IQ)")
                .font(.caption)
            WaterfallView(buffer: waterfallBuffer)
                .frame(height: 220)
            SpectrumLineView(magnitude: pipeline.magnitudeDB, useDB: true)
                .frame(height: 100)
            Button(isRunning ? "Stop" : "Start") {
                toggle()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .background(Color.black.opacity(0.2))
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
            capture.onSamples = { [pipeline, waterfallBuffer] samples, _ in
                pipeline.push(samples: samples)
                if !pipeline.magnitudeDB.isEmpty {
                    waterfallBuffer.pushRow(pipeline.magnitudeDB)
                }
            }
            do {
                try capture.start()
                pipeline.sampleRate = capture.sampleRate
                isRunning = true
            } catch {}
        }
    }
}

#Preview {
    WaterfallTestView()
}
