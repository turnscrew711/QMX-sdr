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
                if client?.isConnected == true {
                    Text("Connected")
                        .foregroundStyle(.green)
                }
            }
            Section("Radio") {
                if let client = client {
                    Text("VFO A: \(formatFrequency(client.frequencyAHz))")
                    Text("VFO B: \(formatFrequency(client.frequencyBHz))")
                    Text("Mode: \(client.mode.isEmpty ? "—" : client.mode)")
                    Button("Refresh") {
                        client.requestFrequencyA()
                        client.requestFrequencyB()
                        client.requestMode()
                    }
                    Button(client.isTransmitting ? "RX" : "TX") {
                        client.setTransmit(!client.isTransmitting)
                    }
                    .foregroundStyle(client.isTransmitting ? .red : .primary)
                }
            }
            Section("BLE") {
                Button("Scan") {
                    transport.startScanning()
                    statusMessage = "Scanning..."
                }
                if !transport.discoveredPeripherals.isEmpty {
                    ForEach(transport.discoveredPeripherals, id: \.identifier) { item in
                        Button(item.name ?? item.identifier.uuidString) {
                            transport.connect(to: item.identifier)
                            statusMessage = "Connecting..."
                        }
                    }
                }
                if transport.connectedPeripheralId != nil {
                    Button("Disconnect") {
                        transport.disconnect()
                        statusMessage = "Disconnected."
                    }
                }
            }
        }
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
