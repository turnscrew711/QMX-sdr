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
            Section("Tests") {
                NavigationLink("Test IQ") { TestIQView() }
                NavigationLink("Test CAT") { TestCATView() }
                NavigationLink("Spectrum") { SpectrumTestView() }
                NavigationLink("CAT Control") { CATControlView() }
                NavigationLink("Waterfall") { WaterfallTestView() }
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
                        client?.requestFrequencyA()
                        client?.requestFrequencyB()
                        dismiss()
                    } label: {
                        HStack {
                            Text(preset.name)
                            Spacer()
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
