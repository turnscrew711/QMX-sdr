//
//  FT8View.swift
//  QMX-SDR
//
//  FT8 interface shown when Digi mode is selected. Replaces VFO B waterfall/spectrum.
//  Decode log and message composition; full decode/encode pipeline is future work.
//

import SwiftUI

struct FT8View: View {
    var client: CATClient?
    @State private var decodeLog: [String] = []
    @State private var messageText: String = "CQ CALLSIGN GRID"

    private var frequencyDisplay: String {
        guard let c = client, c.isConnected else { return "—" }
        let hz = c.activeFrequencyHz
        if hz == 0 { return "—" }
        return String(format: "%.3f MHz", Double(hz) / 1_000_000)
    }

    var body: some View {
        VStack(spacing: 0) {
            ft8Header
            ft8DecodeScroll
            Divider()
                .background(Win98.buttonShadow)
            ft8MessageBar
        }
        .overlay { ft8Border }
        .accessibilityLabel("FT8 interface")
        .accessibilityHint("Decode log and message entry; TX keys the radio for 15 seconds when connected")
    }

    private var ft8Header: some View {
        HStack {
            Text("FT8")
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.semibold)
            Text(frequencyDisplay)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(8)
        .background(Win98.surface.opacity(0.9))
    }

    private var ft8DecodeScroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if decodeLog.isEmpty {
                    Text("Decodes will appear here when FT8 decode from IQ is implemented.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                } else {
                    ForEach(Array(decodeLog.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .background(Win98.windowBackground)
    }

    private var ft8MessageBar: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $messageText)
                .textFieldStyle(.plain)
                .font(.system(.caption, design: .monospaced))
                .padding(6)
                .background(Win98.surface)
            Button("TX") {
                client?.setTransmit(true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                    client?.setTransmit(false)
                }
            }
            .buttonStyle(Win98ButtonStyle())
            .disabled(client?.isConnected != true)
        }
        .padding(8)
        .background(Win98.surface)
    }

    private var ft8Border: some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(Color.blue.opacity(0.6), lineWidth: 2)
            .allowsHitTesting(false)
    }
}

#Preview {
    FT8View(client: nil)
        .frame(height: 220)
}
