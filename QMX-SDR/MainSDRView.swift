//
//  MainSDRView.swift
//  QMX-SDR
//
//  SDR-style layout: band strip, waterfall + spectrum, meters, frequency, mode/VFO/presets/menu.
//

import SwiftUI

/// Holds input gain so the IQ callback can read the current value without capturing the view.
private final class IQInputGainRef {
    var gain: Float = 0.4
}

struct MainSDRView: View {
    @State private var capture = IQCaptureService()
    @State private var pipeline = SpectrumPipeline()
    @State private var waterfallBuffer = WaterfallBuffer(binCount: defaultFFTSize, maxRows: 256)
    @State private var transport = BLESerialTransport()
    @State private var client: CATClient?
    @State private var presetsManager = PresetsManager()
    @State private var iqRunning = false
    @State private var showSettings = false
    @State private var showWaterfallSettings = false
    @State private var waterfallSensitivity: Float = 1.0
    @State private var waterfallGamma: Float = 0.92
    @State private var waterfallPalette: WaterfallPalette = .blueRed
    @State private var iqInputGainRef = IQInputGainRef()
    @State private var selectedBandId: String? = "40"
    @State private var selectedVFO: ActiveVFO = .a
    @State private var meterTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            topToolbar
            vfoPanel(vfo: .a)
                .frame(minHeight: 180)
            secondPanel
            metersBar
            frequencyBar
            bottomBar
            ritBar
        }
        .background(Win98.windowBackground)
        .onAppear {
            if client == nil {
                client = CATClient(transport: transport)
                client?.onConnectionChanged = { connected in
                    if connected { self.syncFromRadio() }
                }
            }
            startMeterPolling()
            waterfallSensitivity = waterfallBuffer.sensitivity
            waterfallGamma = waterfallBuffer.gamma
            waterfallPalette = waterfallBuffer.palette
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
                    .toolbarBackground(Win98.surface, for: .navigationBar)
                    .tint(Win98.surface)
            }
            .overlay(alignment: .topTrailing) {
                Win98ToolbarDoneLabel { showSettings = false }
                    .padding(.top, 16)
                    .padding(.trailing, 16)
            }
        }
        .sheet(isPresented: $showWaterfallSettings) {
            WaterfallSettingsView(
                sensitivity: $waterfallSensitivity,
                gamma: $waterfallGamma,
                palette: $waterfallPalette,
                inputGain: Binding(
                    get: { iqInputGainRef.gain },
                    set: { iqInputGainRef.gain = $0 }
                )
            )
        }
        .onChange(of: showWaterfallSettings) { _, isShowing in
            guard !isShowing else { return }
            let sens = waterfallSensitivity
            let gam = waterfallGamma
            let pal = waterfallPalette
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                waterfallBuffer.applyDisplay(sensitivity: sens, gamma: gam, palette: pal)
            }
        }
        .onChange(of: showSettings) { _, isShowing in
            if !isShowing {
                let hz = selectedVFO == .a ? (client?.frequencyAHz ?? 0) : (client?.frequencyBHz ?? 0)
                if hz > 0 { selectedBandId = HFBands.band(containing: hz)?.id }
            }
        }
    }

    /// After Bluetooth connect: read FA, FB, MD, RT from radio and update selectedBandId / selectedVFO.
    private func syncFromRadio() {
        client?.requestFullState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard let c = self.client else { return }
            let bandId = HFBands.band(containing: c.frequencyAHz)?.id
                ?? HFBands.band(containing: c.frequencyBHz)?.id
            if let id = bandId { self.selectedBandId = id }
            self.selectedVFO = .a
        }
    }

    private var selectedBandLabel: String {
        HFBands.bands.first(where: { $0.id == selectedBandId })?.label ?? "—"
    }

    @ViewBuilder
    private var topToolbar: some View {
        HStack {
            if iqRunning {
                Text(capture.hasUSBInput ? "IQ" : "IQ (no USB)")
                    .font(.caption)
                    .foregroundStyle(capture.hasUSBInput ? Color.secondary : Color.orange)
            }
            Spacer(minLength: 0)
            Button("Waterfall") {
                waterfallSensitivity = waterfallBuffer.sensitivity
                waterfallGamma = waterfallBuffer.gamma
                waterfallPalette = waterfallBuffer.palette
                showWaterfallSettings = true
            }
            .buttonStyle(Win98ButtonStyle())
            .accessibilityLabel("Waterfall display settings")
            .accessibilityHint("Display and input level")
            Button(iqRunning ? "Stop" : "Start") {
                toggleIQ()
            }
            .buttonStyle(Win98ButtonStyle())
            .accessibilityLabel(iqRunning ? "Stop IQ capture" : "Start IQ capture")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Win98.surface)
    }

    @ViewBuilder
    private var secondPanel: some View {
        if displayMode == "DIGI" {
            FT8View(client: client)
                .frame(minHeight: 180)
        } else {
            vfoPanel(vfo: .b)
                .frame(minHeight: 180)
        }
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
        .accessibilityLabel(isA ? "VFO A waterfall and spectrum" : "VFO B waterfall and spectrum")
        .accessibilityHint("Tap or drag to set frequency; pinch to zoom")
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
                .accessibilityLabel("Frequency \(formatFrequency(freq))")
            Text(client?.mode.isEmpty == false ? client!.mode : "—")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if client?.ritEnabled == true {
                Text("RIT on")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Win98.surface)
    }

    private var ritBar: some View {
        let connected = client?.isConnected == true
        return HStack(spacing: 6) {
            Spacer(minLength: 0)
            Text("RIT")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("−100") {
                client?.ritDown(100)
            }
            .buttonStyle(Win98ButtonStyle())
            .font(.caption)
            .disabled(!connected)
            .accessibilityLabel("RIT down 100 Hz")
            Button("+100") {
                client?.ritUp(100)
            }
            .buttonStyle(Win98ButtonStyle())
            .font(.caption)
            .disabled(!connected)
            .accessibilityLabel("RIT up 100 Hz")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
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
            .accessibilityLabel("Band selection")

            Button("VFO") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedVFO = selectedVFO == .a ? .b : .a
                }
                client?.switchVFO()
            }
            .buttonStyle(Win98ButtonStyle())
            .disabled(!connected)
            .accessibilityLabel("Switch VFO")

            Button("Menu") { showSettings = true }
                .buttonStyle(Win98ButtonStyle())
                .accessibilityLabel("Settings menu")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Win98.surface.ignoresSafeArea(edges: [.leading, .trailing, .bottom]))
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
        .accessibilityLabel("Mode selection")
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
            client.requestRITStatus()
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
            capture.onSamples = { [pipeline, waterfallBuffer, iqInputGainRef] samples, _ in
                let gain = iqInputGainRef.gain
                let scaled = samples.map { $0 * gain }
                pipeline.push(samples: scaled)
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
