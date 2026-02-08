//
//  MetersView.swift
//  QMX-SDR
//
//  S-meter and SWR meter for main screen.
//

import SwiftUI

/// S-meter: 0–60 S-units style (or 0–255 raw scaled to ~0–60 for display).
struct SMeterView: View {
    var value: Int
    var maxRaw: Int = 255

    private var displayValue: Int { min(60, (value * 60) / max(1, maxRaw)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("S")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: max(4, h * 0.4))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green)
                        .frame(width: max(0, w * CGFloat(displayValue) / 60), height: max(4, h * 0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 16)
            Text("\(displayValue)")
                .font(.system(.caption2, design: .monospaced))
        }
        .frame(minWidth: 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("S meter")
        .accessibilityValue("\(displayValue) S-units")
    }
}

/// SWR meter: 1.0–10+ display.
struct SWRMeterView: View {
    var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("SWR")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let frac = min(1, max(0, (value - 1) / 4))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: max(4, h * 0.4))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(value > 2 ? Color.red : (value > 1.5 ? Color.orange : Color.green))
                        .frame(width: max(0, w * frac), height: max(4, h * 0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 16)
            Text(String(format: "%.2f", value))
                .font(.system(.caption2, design: .monospaced))
        }
        .frame(minWidth: 40)
    }
}

#Preview {
    HStack(spacing: 20) {
        SMeterView(value: 24)
        SWRMeterView(value: 1.2)
    }
    .padding()
}
