//
//  CATControlView.swift
//  QMX-SDR
//
//  Minimal CAT UI: connect via BLE, show frequency/mode, request/set frequency, PTT.
//

import SwiftUI

struct CATControlView: View {
    @State private var transport = BLESerialTransport()
    @State private var client: CATClient?
    @State private var statusMessage = "Scan to connect BLE serial module."

    var body: some View {
        List {
            Section("Status") {
                Text(statusMessage)
                    .win98ListRow()
                if client?.isConnected == true {
                    Text("Connected")
                        .foregroundStyle(.green)
                        .win98ListRow()
                }
            }
            Section("Radio") {
                if let client = client {
                    Text("VFO A: \(formatFrequency(client.frequencyAHz))")
                        .win98ListRow()
                    Text("VFO B: \(formatFrequency(client.frequencyBHz))")
                        .win98ListRow()
                    Text("Mode: \(client.mode.isEmpty ? "—" : client.mode)")
                        .win98ListRow()
                    Button("Refresh") {
                        client.requestFrequencyA()
                        client.requestFrequencyB()
                        client.requestMode()
                    }
                    .buttonStyle(Win98ButtonStyle())
                    .win98ListRow()
                    Button(client.isTransmitting ? "RX" : "TX") {
                        client.setTransmit(!client.isTransmitting)
                    }
                    .buttonStyle(Win98ButtonStyle())
                    .foregroundStyle(client.isTransmitting ? .red : .primary)
                    .win98ListRow()
                }
            }
            Section("BLE") {
                Button("Scan") {
                    transport.startScanning()
                    statusMessage = "Scanning..."
                }
                .buttonStyle(Win98ButtonStyle())
                .win98ListRow()
                if !transport.discoveredPeripherals.isEmpty {
                    ForEach(transport.discoveredPeripherals, id: \.identifier) { item in
                        Button(item.name ?? item.identifier.uuidString) {
                            transport.connect(to: item.identifier)
                            statusMessage = "Connecting..."
                        }
                        .buttonStyle(Win98ButtonStyle())
                        .win98ListRow()
                    }
                }
                if transport.connectedPeripheralId != nil {
                    Button("Disconnect") {
                        transport.disconnect()
                        statusMessage = "Disconnected."
                    }
                    .buttonStyle(Win98ButtonStyle())
                    .win98ListRow()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Win98.windowBackground)
        .listStyle(.insetGrouped)
        .toolbarBackground(Win98.surface, for: .navigationBar)
        .tint(Win98.surface)
        .navigationTitle("CAT Control")
        .onAppear {
            if client == nil {
                client = CATClient(transport: transport)
            }
            transport.onConnectionChanged = { connected in
                Task { @MainActor in
                    statusMessage = connected ? "Connected." : "Disconnected."
                }
            }
        }
    }

    private func formatFrequency(_ hz: UInt64) -> String {
        if hz == 0 { return "—" }
        if hz >= 1_000_000 {
            return String(format: "%.3f MHz", Double(hz) / 1_000_000)
        }
        return "\(hz) Hz"
    }
}

#Preview {
    NavigationStack {
        CATControlView()
    }
}
