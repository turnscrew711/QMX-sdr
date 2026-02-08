//
//  SettingsMenuView.swift
//  QMX-SDR
//
//  Settings menu mirroring QMX menu structure. Bluetooth connection in Connection section.
//

import SwiftUI

struct SettingsMenuView: View {
    var transport: BLESerialTransport? = nil
    var client: CATClient? = nil
    var presetsManager: PresetsManager? = nil

    var body: some View {
        List {
            if transport != nil {
                Section("Connection") {
                    NavigationLink("Connect Bluetooth") {
                        BLEConnectView(transport: transport!)
                    }
                }
            }
            if client != nil {
                Section("Tools") {
                    NavigationLink("SWR Meter") {
                        SWRSweepView(client: client!)
                    }
                    Button("Tune") {
                        client?.setTransmit(true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            client?.setTransmit(false)
                        }
                    }
                }
            }
            if presetsManager != nil && client != nil {
                Section("Presets") {
                    NavigationLink("Frequency Presets") {
                        PresetsMenuView(manager: presetsManager!, client: client!)
                    }
                }
            }
            Section("Audio") {
                SettingsRow(title: "Volume", type: .number(value: 80))
                SettingsRow(title: "Mic Gain", type: .number(value: 50))
                SettingsRow(title: "Speaker", type: .toggle(isOn: true))
            }
            Section("Keyer") {
                SettingsRow(title: "Keyer Speed (WPM)", type: .number(value: 20))
                SettingsRow(title: "Keyer Mode", type: .list(options: ["Straight", "Iambic A", "Iambic B"]))
                SettingsRow(title: "Paddle Reverse", type: .toggle(isOn: false))
            }
            Section("CW Decoder") {
                SettingsRow(title: "Decoder Enable", type: .toggle(isOn: false))
                SettingsRow(title: "Decoder Threshold", type: .number(value: 50))
            }
            Section("Digi Interface") {
                SettingsRow(title: "Digi Mode", type: .list(options: ["Off", "RTTY", "FT8", "WSPR"]))
                SettingsRow(title: "PTT Delay (ms)", type: .number(value: 0))
            }
            Section("Beacon") {
                SettingsRow(title: "Beacon Enable", type: .toggle(isOn: false))
                SettingsRow(title: "Beacon Interval (s)", type: .number(value: 60))
            }
            Section("Display / Controls") {
                SettingsRow(title: "Contrast", type: .number(value: 50))
                SettingsRow(title: "Backlight", type: .toggle(isOn: true))
            }
            if client != nil {
                Section("RIT") {
                    NavigationLink("RIT control") {
                        RITMenuView(client: client!)
                    }
                }
            }
            Section("Tests") {
                NavigationLink("Test IQ") { TestIQView() }
                NavigationLink("Test CAT") { TestCATView() }
                NavigationLink("Spectrum") { SpectrumTestView() }
                NavigationLink("CAT Control") { CATControlView() }
                NavigationLink("Waterfall") { WaterfallTestView() }
            }
            Section("Help") {
                NavigationLink("About & limitations") {
                    AboutLimitationsView()
                }
            }
        }
        .navigationTitle("QMX Settings")
    }
}

private enum SettingsRowType {
    case toggle(isOn: Bool)
    case number(value: Int)
    case list(options: [String])
}

private struct SettingsRow: View {
    let title: String
    let type: SettingsRowType

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            switch type {
            case .toggle(let isOn):
                Toggle("", isOn: .constant(isOn))
                    .labelsHidden()
            case .number(let value):
                Text("\(value)")
                    .foregroundStyle(.secondary)
            case .list(let options):
                Text(options.first ?? "")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Presets screen pushed from Menu (save current, list, recall). Pops on Done or after recall.
struct PresetsMenuView: View {
    @Bindable var manager: PresetsManager
    var client: CATClient?
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""

    var body: some View {
        List {
            Section("Save current") {
                HStack {
                    TextField("Preset name", text: $newName)
                    Button("Save") {
                        guard let c = client, !newName.isEmpty else { return }
                        let hz = c.activeFrequencyHz
                        if hz > 0 {
                            manager.add(name: newName, frequencyHz: hz, mode: c.mode)
                            newName = ""
                        }
                    }
                    .disabled(newName.isEmpty)
                }
            }
            Section("Presets") {
                ForEach(manager.presets) { preset in
                    Button {
                        manager.recall(preset, setFrequency: { hz in
                            client?.setActiveFrequency(hz)
                        }, setMode: { code in
                            client?.setMode(code)
                            client?.requestMode()
                        })
                        client?.clearRIT()
                        client?.setRIT(on: false)
                        client?.requestFrequencyA()
                        client?.requestFrequencyB()
                        dismiss()
                    } label: {
                        HStack {
                            Text(preset.name)
                            Spacer()
                            if !preset.mode.isEmpty {
                                Text(preset.mode)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(String(format: "%.3f MHz", Double(preset.frequencyHz) / 1_000_000))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: manager.remove)
            }
        }
        .navigationTitle("Frequency Presets")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

/// About the app and QMX/CAT limitations (from QRPLabs Groups.io and manual).
struct AboutLimitationsView: View {
    var body: some View {
        List {
            Section("Waterfall & IQ") {
                Text("Enable IQ Mode on the QMX: Menu → System config → IQ Mode → ENABLED. Connect QMX via USB for 48 kHz stereo IQ.")
                Text("IQ mode is receive-only: the waterfall shows RX; transmit is still controlled by the radio and CAT.")
            }
            Section("CAT & status") {
                Text("Real-time SWR and \"SWR protection tripped\" are not available via CAT; the QMX does not report them to the app. Use the radio’s LCD for that.")
                Text("S-meter and SWR (when transmitting) are polled via CAT where supported.")
            }
            Section("RIT") {
                Text("QMX RIT uses absolute offset: RU sets +n Hz, RD sets -n Hz. Use RIT control in the menu to turn RIT on/off, clear to zero, or step ±100 Hz.")
            }
            Section("Tune / CW") {
                Text("CAT does not support full CW keying (e.g. TQ1; for CW). Use the radio’s front panel for tune or CW. Any app Tune control would send carrier only.")
            }
            Section("Compatibility") {
                Text("CAT is based on Kenwood TS-480; QMX accepts variable-length frequency and uses absolute RIT (RU/RD). Compatible with WSJT-X and similar when set to TS-440 or TS-480.")
            }
        }
        .navigationTitle("About & limitations")
    }
}

/// RIT control: on/off, clear, step +/-.
struct RITMenuView: View {
    @Bindable var client: CATClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("RIT") {
                Toggle("RIT on", isOn: Binding(
                    get: { client.ritEnabled },
                    set: { client.setRIT(on: $0); client.requestRITStatus() }
                ))
                .disabled(!client.isConnected)
                Button("Clear RIT (0 Hz)") {
                    client.clearRIT()
                    client.requestRITStatus()
                }
                .disabled(!client.isConnected)
            }
            Section("Step") {
                HStack {
                    Button("−100 Hz") {
                        client.ritDown(100)
                    }
                    .disabled(!client.isConnected)
                    Spacer()
                    Text("RIT offset")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("+100 Hz") {
                        client.ritUp(100)
                    }
                    .disabled(!client.isConnected)
                }
            }
        }
        .navigationTitle("RIT control")
        .onAppear {
            client.requestRITStatus()
        }
    }
}

/// In-menu BLE scan and connect (no sheet dismiss; user navigates back).
struct BLEConnectView: View {
    var transport: BLESerialTransport

    var body: some View {
        List {
            Button("Scan") { transport.startScanning() }
            ForEach(transport.discoveredPeripherals, id: \.identifier) { item in
                Button(item.name ?? item.identifier.uuidString) {
                    transport.connect(to: item.identifier)
                }
            }
        }
        .navigationTitle("Connect Bluetooth")
    }
}

#Preview {
    NavigationStack {
        SettingsMenuView()
    }
}
