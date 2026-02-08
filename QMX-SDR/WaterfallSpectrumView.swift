//
//  WaterfallSpectrumView.swift
//  QMX-SDR
//
//  Waterfall + spectrum with frequency scale. Pan to tune, pinch to zoom.
//

import SwiftUI

/// Max display span (IQ bandwidth). Min span for zoom.
private let kMaxSpanHz: Double = 48_000
private let kMinSpanHz: Double = 2_000

struct WaterfallSpectrumView: View {
    var buffer: WaterfallBuffer
    var magnitudeDB: [Float]
    /// Center frequency in Hz (currently tuned).
    var centerHz: UInt64
    /// Band id for limits (e.g. "40"). Nil = use full range.
    var selectedBandId: String?
    /// Called when user commits a new frequency (pan end, or tap).
    var onFrequencySelected: (UInt64) -> Void

    @State private var spanHz: Double = 24_000
    @State private var panOffsetHz: Double = 0
    @State private var spanHzAtPinchStart: Double?

    private var band: HFBand? {
        selectedBandId.flatMap { HFBands.band(id: $0) }
    }

    private var bandStart: UInt64 {
        band?.startHz ?? 0
    }

    private var bandEnd: UInt64 {
        band?.endHz ?? 50_000_000
    }

    /// Effective center during drag (centerHz + panOffsetHz), clamped to band.
    private var effectiveCenterHz: Double {
        let c = Double(centerHz) + panOffsetHz
        return min(max(c, Double(bandStart)), Double(bandEnd))
    }

    private var clampedSpanHz: Double {
        let bandW = Double(band?.widthHz ?? 500_000)
        return min(max(spanHz, kMinSpanHz), min(kMaxSpanHz, bandW))
    }

    private var lowHz: Double { effectiveCenterHz - clampedSpanHz / 2 }
    private var highHz: Double { effectiveCenterHz + clampedSpanHz / 2 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let scaleHeight: CGFloat = 22
            let waterfallHeight = h * 0.65
            let spectrumHeight = h * 0.23

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    WaterfallView(buffer: buffer)
                        .frame(height: waterfallHeight)
                    gestureOverlay(width: w, height: waterfallHeight)
                }
                ZStack(alignment: .topLeading) {
                    SpectrumLineView(magnitude: magnitudeDB, useDB: true)
                        .frame(height: spectrumHeight)
                    gestureOverlay(width: w, height: spectrumHeight)
                }
                frequencyScaleView(width: w, height: scaleHeight)
            }
        }
        .onAppear {
            if spanHz == 24_000, let b = band {
                spanHz = min(kMaxSpanHz, Double(b.widthHz))
            }
        }
        .onChange(of: selectedBandId) { _, _ in
            if let b = band {
                spanHz = min(spanHz, min(kMaxSpanHz, Double(b.widthHz)))
            }
        }
    }

    private func gestureOverlay(width: CGFloat, height: CGFloat) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: width, height: height)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let freqFromDrag = -Double(value.translation.width) / Double(max(1, width)) * clampedSpanHz
                        panOffsetHz = min(max(freqFromDrag, Double(bandStart) - Double(centerHz)), Double(bandEnd) - Double(centerHz))
                    }
                    .onEnded { value in
                        let freqFromDrag = -Double(value.translation.width) / Double(max(1, width)) * clampedSpanHz
                        let newCenter = Double(centerHz) + freqFromDrag
                        let clamped = UInt64(min(max(newCenter, Double(bandStart)), Double(bandEnd)))
                        onFrequencySelected(clamped)
                        panOffsetHz = 0
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        if spanHzAtPinchStart == nil { spanHzAtPinchStart = spanHz }
                        let base = spanHzAtPinchStart ?? spanHz
                        let newSpan = base / Double(value)
                        spanHz = min(max(newSpan, kMinSpanHz), min(kMaxSpanHz, Double(band?.widthHz ?? 500_000)))
                    }
                    .onEnded { _ in
                        spanHzAtPinchStart = nil
                    }
            )
            .onTapGesture { location in
                commitFrequency(at: location.x, width: width)
            }
    }

    private func commitFrequency(at x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let frac = Double(x / width)
        let hz = lowHz + frac * clampedSpanHz
        let clamped = UInt64(min(max(hz, Double(bandStart)), Double(bandEnd)))
        onFrequencySelected(clamped)
        panOffsetHz = 0
    }

    private func frequencyScaleView(width: CGFloat, height: CGFloat) -> some View {
        let low = lowHz
        let high = highHz
        let center = effectiveCenterHz
        func fmt(_ hz: Double) -> String {
            if hz >= 1_000_000 {
                return String(format: "%.3f", hz / 1_000_000) + " M"
            }
            return String(format: "%.0f", hz / 1_000) + " k"
        }
        return HStack(alignment: .center, spacing: 0) {
            Text(fmt(low))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(fmt(center))
                .font(.system(size: 10, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            Spacer(minLength: 4)
            Text(fmt(high))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(width: width, height: height)
        .padding(.horizontal, 6)
    }
}
