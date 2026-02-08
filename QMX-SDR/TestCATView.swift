//
//  TestCATView.swift
//  QMX-SDR
//
//  Minimal screen to validate BLE CAT: Scan, Connect, Send FA;, show reply.
//

import SwiftUI

struct TestCATView: View {
    @State private var transport = BLESerialTransport()
    @State private var statusMessage = "Tap Scan to find BLE serial module."
    @State private var replyLog: String = ""

    var body: some View {
        List {
            Section("Status") {
                Text(statusMessage)
            }
            Section("Reply") {
                Text(transport.lastReply.isEmpty ? (replyLog.isEmpty ? "(no reply yet)" : "Waiting...") : transport.lastReply)
                    .font(.system(.caption, design: .monospaced))
            }
            Section("Actions") {
                Button("Scan") {
                    transport.startScanning()
                    statusMessage = "Scanning..."
                    replyLog = ""
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
                    Button("Send FA;") {
                        transport.send("FA;")
                        if replyLog.isEmpty { replyLog = "Sent FA;" }
                    }
                    Button("Disconnect") {
                        transport.disconnect()
                        statusMessage = "Disconnected."
                    }
                }
            }
        }
        .navigationTitle("Test CAT")
        .onAppear {
            transport.onReplyReceived = { reply in
                Task { @MainActor in
                    replyLog = reply + "\n" + replyLog
                }
            }
            transport.onConnectionChanged = { connected in
                Task { @MainActor in
                    statusMessage = connected ? "Connected. Tap Send FA; to query frequency." : "Disconnected."
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TestCATView()
    }
}
