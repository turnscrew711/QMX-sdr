//
//  SpectrumLineView.swift
//  QMX-SDR
//
//  Draws a single spectrum line (frequency vs level). QMX offset ~12 kHz for display.
//

import SwiftUI

struct SpectrumLineView: View {
    /// Magnitude (linear) or dB values; one per bin. Empty = no data.
    var magnitude: [Float]
    /// Use dB scale for Y axis when true.
    var useDB: Bool = true
    /// Optional: center frequency in Hz for axis label (from CAT).
    var centerFrequencyHz: Double = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if magnitude.isEmpty {
                Text("No spectrum data")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Canvas { context, size in
                    let n = magnitude.count
                    guard n > 1 else { return }
                    let values = useDB ? magnitude : magnitude
                    let (minVal, maxVal) = values.minMax() ?? (0, 1)
                    let range = max(maxVal - minVal, 0.001)
                    var path = Path()
                    let stepX = (size.width - 1) / CGFloat(n - 1)
                    for i in 0..<n {
                        let x = CGFloat(i) * stepX
                        let y = size.height - (CGFloat((values[i] - minVal) / range) * size.height)
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    context.stroke(path, with: .color(.green), lineWidth: 1)
                }
                .frame(width: w, height: h)
            }
        }
    }
}

private extension Array where Element == Float {
    func minMax() -> (Float, Float)? {
        guard !isEmpty else { return nil }
        var mn = self[0], mx = self[0]
        for v in self {
            if v < mn { mn = v }
            if v > mx { mx = v }
        }
        return (mn, mx)
    }
}

#Preview {
    SpectrumLineView(magnitude: (0..<256).map { Float(sin(Double($0) * 0.1) * 20 + 10) })
        .frame(height: 120)
}
