//
//  MainSDRView.swift
//  QMX-SDR
//
//  SDR-style layout: band strip, waterfall + spectrum, meters, frequency, mode/VFO/presets/menu.
//

import SwiftUI

struct MainSDRView: View {
    @State private var capture = IQCaptureService()
    @State private var pipeline = SpectrumPipeline()
    @State private var waterfallBuffer = WaterfallBuffer(binCount: defaultFFTSize, maxRows: 256)
    @State private var transport = BLESerialTransport()
    @State private var client: CATClient?
    @State private var presetsManager = PresetsManager()
    @State private var iqRunning = false
    @State private var showSettings = false
    @State private var selectedBandId: String? = "40"
    @State private var selectedVFO: ActiveVFO = .a
    @State private var meterTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Button(iqRunning ? "Stop" : "Start") {
                    toggleIQ()
                }
                .buttonStyle(Win98ButtonStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Win98.surface)
            vfoPanel(vfo: .a)
                .frame(minHeight: 180)
            vfoPanel(vfo: .b)
                .frame(minHeight: 180)

            metersBar
            frequencyBar
            bottomBar
        }
        .background(Win98.windowBackground)
        .onAppear {
            if client == nil {
                client = CATClient(transport: transport)
            }
            startMeterPolling()
        }
        .onDisappear {
            meterTimer?.invalidate()
        }
        .onChange(of: selectedBandId) { _, _ in
            if displayMode == "SSB" { applySSBForCurrentBand() }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsMenuView(transport: transport, client: client, presetsManager: presetsManager)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
        }
        .onChange(of: showSettings) { _, isShowing in
            if !isShowing {
                let hz = selectedVFO == .a ? (client?.frequencyAHz ?? 0) : (client?.frequencyBHz ?? 0)
                if hz > 0 { selectedBandId = HFBands.band(containing: hz)?.id }
            }
        }
    }

    private var selectedBandLabel: String {
        HFBands.bands.first(where: { $0.id == selectedBandId })?.label ?? "—"
    }

    private func vfoPanel(vfo: ActiveVFO) -> some View {
        let isA = (vfo == .a)
        let centerHz = isA ? (client?.frequencyAHz ?? 7_100_000) : (client?.frequencyBHz ?? 7_100_000)
        let hasWaterfallData = waterfallBuffer.image != nil
        return WaterfallSpectrumView(
            buffer: waterfallBuffer,
            magnitudeDB: pipeline.magnitudeDB,
            centerHz: centerHz,
            selectedBandId: selectedBandId,
            onFrequencySelected: { hz in
                let newVFO: ActiveVFO = isA ? .a : .b
                selectedVFO = newVFO
                if let c = client, c.activeVFO != newVFO { c.switchVFO() }
                if isA {
                    client?.setFrequencyA(hz)
                    client?.requestFrequencyA()
                } else {
                    client?.setFrequencyB(hz)
                    client?.requestFrequencyB()
                }
                selectedBandId = HFBands.band(containing: hz)?.id
            }
        )
        .overlay(alignment: .topLeading) {
            Text(isA ? "VFO A" : "VFO B")
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(selectedVFO == vfo ? .semibold : .regular)
                .foregroundStyle(hasWaterfallData ? .black : .white)
                .padding(8)
        }
        .overlay {
            VFOPanelBorder(isSelected: selectedVFO == vfo)
        }
    }

    private var metersBar: some View {
        HStack(spacing: 16) {
            SMeterView(value: client?.sMeterRaw ?? 0)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Win98.surface)
    }

    private var frequencyBar: some View {
        let freq = selectedVFO == .a ? (client?.frequencyAHz ?? 0) : (client?.frequencyBHz ?? 0)
        return HStack {
            Text(formatFrequency(freq))
                .font(.system(size: 22, weight: .medium, design: .monospaced))
            Text(client?.mode.isEmpty == false ? client!.mode : "—")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Win98.surface)
    }

    private var bottomBar: some View {
        let connected = client?.isConnected == true
        return HStack(spacing: 6) {
            modeMenu
                .disabled(!connected)

            Menu {
                ForEach(HFBands.bands) { band in
                    Button {
                        client?.setActiveFrequency(band.centerHz)
                        selectedBandId = band.id
                    } label: {
                        HStack {
                            Text(band.label)
                            if selectedBandId == band.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Text(selectedBandLabel)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .menuStyle(.borderlessButton)
            .win98Box()
            .disabled(!connected)

            Button("VFO") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedVFO = selectedVFO == .a ? .b : .a
                }
                client?.switchVFO()
            }
            .buttonStyle(Win98ButtonStyle())
            .disabled(!connected)

            Button("Menu") { showSettings = true }
                .buttonStyle(Win98ButtonStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Win98.surface)
    }

    /// Maps CAT mode (LSB/USB/CW/FSK etc.) to display mode: SSB, CW, or DIGI.
    private var displayMode: String {
        guard let m = client?.mode else { return "SSB" }
        switch m.uppercased() {
        case "LSB", "USB": return "SSB"
        case "CW", "CWR": return "CW"
        case "FSK", "PKT": return "DIGI"
        default: return "SSB"
        }
    }

    private var modeMenu: some View {
        Menu {
            Button {
                applySSBForCurrentBand()
            } label: {
                HStack {
                    Text("SSB")
                    if displayMode == "SSB" { Image(systemName: "checkmark") }
                }
            }
            Button {
                client?.setMode(3)
                client?.requestMode()
            } label: {
                HStack {
                    Text("CW")
                    if displayMode == "CW" { Image(systemName: "checkmark") }
                }
            }
            Button {
                client?.setMode(6)
                client?.requestMode()
            } label: {
                HStack {
                    Text("DIGI")
                    if displayMode == "DIGI" { Image(systemName: "checkmark") }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(displayMode)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .frame(minWidth: 52)
        }
        .menuStyle(.borderlessButton)
        .win98Box()
    }

    private func applySSBForCurrentBand() {
        let bandId = selectedBandId ?? HFBands.band(containing: client?.activeFrequencyHz ?? 0)?.id
        let sideband = bandId.flatMap { HFBands.defaultSSBForBand(id: $0) } ?? "USB"
        let code = sideband == "LSB" ? 1 : 2
        client?.setMode(code)
        client?.requestMode()
    }

    private func formatFrequency(_ hz: UInt64) -> String {
        if hz == 0 { return "—" }
        return String(format: "%.3f MHz", Double(hz) / 1_000_000)
    }

    private func startMeterPolling() {
        meterTimer?.invalidate()
        guard let client = client else { return }
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard client.isConnected else { return }
            client.requestSMeter()
            if client.isTransmitting {
                client.requestSWR()
            }
        }
        RunLoop.main.add(meterTimer!, forMode: .common)
    }

    private func toggleIQ() {
        if iqRunning {
            capture.stop()
            iqRunning = false
        } else {
            capture.onSamples = { [pipeline, waterfallBuffer] samples, _ in
                pipeline.push(samples: samples)
                if !pipeline.magnitudeDB.isEmpty {
                    waterfallBuffer.pushRow(pipeline.magnitudeDB)
                }
            }
            do {
                try capture.start()
                pipeline.sampleRate = capture.sampleRate
                iqRunning = true
            } catch {}
        }
    }
}

// MARK: - VFO panel border (separate view so SwiftUI tracks selection and updates the outline)
private struct VFOPanelBorder: View {
    let isSelected: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            .allowsHitTesting(false)
    }
}
