//
//  SWRSweepView.swift
//  QMX-SDR
//
//  SWR sweep around current frequency; graph of SWR vs frequency.
//

import SwiftUI

struct SWRSweepView: View {
    @Bindable var client: CATClient

    private let sweepSpanHz: UInt64 = 100_000
    private let sweepSteps = 31
    private let txDelayMs: UInt64 = 350
    private let replyDelayMs: UInt64 = 250

    @State private var points: [(freq: UInt64, swr: Double)] = []
    @State private var isRunning = false
    @State private var errorMessage: String?

    private var centerHz: UInt64 {
        client.activeFrequencyHz > 0 ? client.activeFrequencyHz : client.frequencyAHz
    }

    var body: some View {
        List {
            Section("Current frequency") {
                Text(formatFreq(centerHz))
                    .font(.system(.body, design: .monospaced))
                    .win98ListRow()
            }

            Section {
                Button {
                    runSweep()
                } label: {
                    HStack {
                        Text("Run SWR sweep")
                        Spacer()
                        if isRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .buttonStyle(Win98ButtonStyle())
                .disabled(isRunning || !client.isConnected || centerHz == 0)
                .win98ListRow()

                if let msg = errorMessage {
                    Text(msg)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .win98ListRow()
                }
            } header: {
                Text("Sweep")
            } footer: {
                Text("Sweeps ±\(sweepSpanHz / 2000) kHz around current frequency. Radio will transmit briefly at each step.")
            }

            if !points.isEmpty {
                Section("SWR vs frequency") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SWR")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        swrGraph
                            .frame(height: 220)
                            .background(Win98.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        HStack {
                            Text(formatFreq(sweepStartHz))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatFreq(sweepEndHz))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .win98ListRow()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Win98.windowBackground)
        .listStyle(.insetGrouped)
        .toolbarBackground(Win98.surface, for: .navigationBar)
        .tint(Win98.surface)
        .navigationTitle("SWR Meter")
    }

    private var sweepStartHz: UInt64 {
        let c = centerHz
        return c > sweepSpanHz / 2 ? c - sweepSpanHz / 2 : 0
    }

    private var sweepEndHz: UInt64 {
        centerHz + sweepSpanHz / 2
    }

    @ViewBuilder
    private var swrGraph: some View {
        let yMin = 1.0
        let yMax = max(5.0, (points.map(\.swr).max() ?? 5.0) * 1.05)
        let freqMin = Double(sweepStartHz)
        let freqMax = Double(sweepEndHz)
        let freqRange = max(1, freqMax - freqMin)

        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let paddingLeft: CGFloat = 36
            let paddingBottom: CGFloat = 20
            let plotW = max(0, w - paddingLeft - 8)
            let plotH = max(0, h - paddingBottom - 8)

            ZStack(alignment: .topLeading) {
                // Y axis labels
                ForEach([1.0, 2.0, 3.0, 4.0, 5.0], id: \.self) { val in
                    if val <= yMax {
                        let y = paddingBottom + plotH * (1 - CGFloat((val - yMin) / (yMax - yMin)))
                        Text(String(format: "%.1f", val))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .position(x: paddingLeft / 2, y: y)
                    }
                }

                // Plot area
                Path { path in
                    guard points.count >= 2 else { return }
                    for (i, p) in points.enumerated() {
                        let x = paddingLeft + plotW * CGFloat((Double(p.freq) - freqMin) / freqRange)
                        let swrNorm = (p.swr - yMin) / (yMax - yMin)
                        let y = paddingBottom + plotH * CGFloat(1 - swrNorm)
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 2)

                // 1:1 reference line (optional)
                Path { path in
                    let y1 = paddingBottom + plotH * CGFloat(1 - (1.0 - yMin) / (yMax - yMin))
                    path.move(to: CGPoint(x: paddingLeft, y: y1))
                    path.addLine(to: CGPoint(x: paddingLeft + plotW, y: y1))
                }
                .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
    }

    private func formatFreq(_ hz: UInt64) -> String {
        if hz == 0 { return "—" }
        return String(format: "%.3f MHz", Double(hz) / 1_000_000)
    }

    private func runSweep() {
        guard client.isConnected, centerHz > 0 else {
            errorMessage = "Not connected or no frequency."
            return
        }
        errorMessage = nil
        isRunning = true
        let savedFreq = centerHz
        let activeA = client.activeVFO == .a

        Task { @MainActor in
            defer {
                isRunning = false
                client.setTransmit(false)
                if activeA {
                    client.setFrequencyA(savedFreq)
                    client.requestFrequencyA()
                } else {
                    client.setFrequencyB(savedFreq)
                    client.requestFrequencyB()
                }
            }

            var result: [(freq: UInt64, swr: Double)] = []
            let startFreq = sweepStartHz
            let endFreq = sweepEndHz
            let step = (endFreq - startFreq) / UInt64(max(1, sweepSteps - 1))

            for i in 0..<sweepSteps {
                let f = startFreq + step * UInt64(i)
                if activeA {
                    client.setFrequencyA(f)
                } else {
                    client.setFrequencyB(f)
                }
                try? await Task.sleep(nanoseconds: 50_000_000)

                client.setTransmit(true)
                try? await Task.sleep(nanoseconds: txDelayMs * 1_000_000)
                client.requestSWR()
                try? await Task.sleep(nanoseconds: replyDelayMs * 1_000_000)
                result.append((f, client.swr))
                client.setTransmit(false)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            points = result
        }
    }
}
