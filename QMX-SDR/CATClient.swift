//
//  CATClient.swift
//  QMX-SDR
//
//  Kenwood TS-480 style CAT: send commands, parse replies. QMX compatible.
//  Ref: QMX CAT manual 1.02_006 (AG, RG, KS, FA, FB, MD, RT, RU, RD, RC, SM, RM, TQ, etc.)
//  Implemented: FA, FB, MD, RT, RU, RD, RC, TQ/TX/RX, SM, RM (SWR), AG (volume), RG (RF gain), KS (keyer WPM).
//  Not yet: IF (composite), FR/FT (VFO mode), SP (split), ML/MM (menu discovery/set), SW (SWR hundredths), Q0–QB.
//

import Foundation

/// Active VFO for display and tuning.
enum ActiveVFO {
    case a
    case b
}

/// Kenwood TS-480 / QMX CAT client. Uses a CATTransport for read/write.
@Observable
final class CATClient {
    /// VFO A frequency in Hz. 0 = unknown.
    private(set) var frequencyAHz: UInt64 = 0
    /// VFO B frequency in Hz. 0 = unknown.
    private(set) var frequencyBHz: UInt64 = 0
    /// Mode string (e.g. "LSB", "USB", "CW", "FM"). Empty = unknown.
    private(set) var mode: String = ""
    /// Transmit on (TQ) state.
    private(set) var isTransmitting: Bool = false
    /// S-meter value 0–60 (S-units style) or 0–255 raw. Updated when SM; is supported.
    private(set) var sMeterRaw: Int = 0
    /// SWR value (e.g. 1.0–10). Updated when RM6; is supported (often only in TX).
    private(set) var swr: Double = 1.0
    /// RIT on/off. Updated when RT; is supported.
    private(set) var ritEnabled: Bool = false
    /// AF gain (volume) in dB, 0.25 dB steps. Updated when AG; is supported.
    private(set) var volumeDB: Double = 20.0
    /// RF gain in dB for current band. Updated when RG; is supported.
    private(set) var rfGainDB: Int = 54
    /// Keyer speed in WPM. Updated when KS; is supported.
    private(set) var keyerSpeedWPM: Int = 20
    /// Which VFO is active for display/tuning.
    var activeVFO: ActiveVFO = .a
    /// Last raw reply for debug.
    private(set) var lastReply: String = ""

    private weak var transport: (any CATTransport)?
    private var pendingCommand: String?

    /// Called when transport connection state changes. Set to e.g. sync app state when connected.
    var onConnectionChanged: ((Bool) -> Void)?

    init(transport: any CATTransport) {
        self.transport = transport
        transport.onReplyReceived = { [weak self] reply in
            self?.handleReply(reply)
        }
        transport.onConnectionChanged = { [weak self] connected in
            if !connected {
                Task { @MainActor in
                    self?.frequencyAHz = 0
                    self?.frequencyBHz = 0
                    self?.mode = ""
                }
            }
            self?.onConnectionChanged?(connected)
        }
    }

    /// Request current frequencies, mode, and RIT from the radio (call after connect to sync app).
    func requestFullState() {
        requestFrequencyA()
        requestFrequencyB()
        requestMode()
        requestRITStatus()
        requestVolume()
        requestRFGain()
        requestKeyerSpeed()
    }

    var isConnected: Bool { transport?.isConnected ?? false }

    /// Send a CAT command (e.g. "FA;"). Reply will be parsed in handleReply.
    func send(_ command: String) {
        let cmd = command.hasSuffix(";") ? command : command + ";"
        pendingCommand = String(cmd.prefix(2)).uppercased()
        transport?.send(cmd)
    }

    /// Request VFO A frequency (FA;).
    func requestFrequencyA() { send("FA;") }
    /// Request VFO B frequency (FB;).
    func requestFrequencyB() { send("FB;") }
    /// Request mode (MD;).
    func requestMode() { send("MD;") }
    /// Set VFO A frequency in Hz. QMX accepts variable-length digits.
    func setFrequencyA(_ hz: UInt64) { send("FA\(hz);") }
    /// Set VFO B frequency in Hz.
    func setFrequencyB(_ hz: UInt64) { send("FB\(hz);") }
    /// Toggle PTT (TQ). 1 = TX, 0 = RX.
    func setTransmit(_ on: Bool) { send(on ? "TX;" : "RX;") }
    /// RIT up: set absolute positive RIT offset (QMX RU = absolute +n Hz). Variable-length digits.
    func ritUp(_ hz: Int = 100) { send("RU\(min(99999, max(0, hz)));") }
    /// RIT down: set absolute negative RIT offset (QMX RD = absolute -n Hz). Variable-length digits.
    func ritDown(_ hz: Int = 100) { send("RD\(min(99999, max(0, hz)));") }
    /// Clear RIT to zero (RC;). Does not turn RIT off.
    func clearRIT() { send("RC;") }
    /// Set RIT on (RT1;) or off (RT0;).
    func setRIT(on: Bool) { send(on ? "RT1;" : "RT0;") }
    /// Request RIT status (RT;). Reply updates ritEnabled.
    func requestRITStatus() { send("RT;") }
    /// Set mode: 1=LSB, 2=USB, 3=CW, 4=FM, 5=AM, 6=FSK, 7=CWR, 8=PKT.
    func setMode(_ code: Int) { send("MD\(code);") }
    /// Request S-meter (SM;). Not all rigs support.
    func requestSMeter() { send("SM;") }
    /// Request SWR (RM6;). Often valid only when transmitting.
    func requestSWR() { send("RM6;") }
    /// Request AF gain / volume (AG;). Reply format AG0091 = 22.75 dB (0.25 dB steps).
    func requestVolume() { send("AG;") }
    /// Set AF gain: value in dB (0.25 dB steps). Send AG0nnn; e.g. AG091; = 22.75 dB.
    func setVolume(_ dB: Double) {
        let steps = Int(round(dB / 0.25))
        let clamped = min(255, max(0, steps))
        send("AG\(String(format: "%03d", clamped));")
    }
    /// Request RF gain (RG;). Reply RG063 = 63 dB.
    func requestRFGain() { send("RG;") }
    /// Set RF gain in dB (e.g. RG63;).
    func setRFGain(_ dB: Int) {
        let clamped = min(99, max(0, dB))
        send("RG\(clamped);")
    }
    /// Request keyer speed (KS;). Reply in WPM.
    func requestKeyerSpeed() { send("KS;") }
    /// Set keyer speed in WPM (e.g. KS20;).
    func setKeyerSpeed(_ wpm: Int) {
        let clamped = min(99, max(5, wpm))
        send("KS\(clamped);")
    }
    /// Swap active VFO (VFO A/B). Some rigs use VS; or similar; we only switch local state and sync displayed freq.
    func switchVFO() {
        activeVFO = activeVFO == .a ? .b : .a
        if activeVFO == .a { requestFrequencyA() } else { requestFrequencyB() }
    }
    /// Current frequency of the active VFO.
    var activeFrequencyHz: UInt64 { activeVFO == .a ? frequencyAHz : frequencyBHz }
    /// Set frequency on the active VFO.
    func setActiveFrequency(_ hz: UInt64) {
        if activeVFO == .a { setFrequencyA(hz); requestFrequencyA() }
        else { setFrequencyB(hz); requestFrequencyB() }
    }

    private func handleReply(_ reply: String) {
        Task { @MainActor in
            lastReply = reply
            let cmd = String(reply.prefix(2)).uppercased()
            let rest = String(reply.dropFirst(2)).replacingOccurrences(of: ";", with: "")
            switch cmd {
            case "FA":
                if let hz = parseFrequency(rest) { frequencyAHz = hz }
            case "FB":
                if let hz = parseFrequency(rest) { frequencyBHz = hz }
            case "MD":
                mode = parseMode(rest)
            case "SM":
                if let v = Int(rest.filter { $0.isNumber }), v >= 0 { sMeterRaw = min(255, v) }
            case "RM":
                let digits = rest.filter { $0.isNumber }
                if let v = Int(String(digits)) {
                    swr = swrFromRMByte(v)
                }
            case "RT":
                if let v = Int(rest.filter { $0.isNumber }.prefix(1)), v == 0 || v == 1 {
                    ritEnabled = (v == 1)
                }
            case "AG":
                let digits = rest.filter { $0.isNumber }
                if let steps = Int(digits), steps >= 0 {
                    volumeDB = Double(min(255, steps)) * 0.25
                }
            case "RG":
                if let v = Int(rest.filter { $0.isNumber }), v >= 0 {
                    rfGainDB = min(99, v)
                }
            case "KS":
                if let v = Int(rest.filter { $0.isNumber }), v >= 0 {
                    keyerSpeedWPM = min(99, max(5, v))
                }
            default:
                break
            }
        }
    }

    private func swrFromRMByte(_ b: Int) -> Double {
        let v = min(255, max(0, b))
        if v <= 0 { return 1.0 }
        if v <= 26 { return 1.0 + Double(v) / 26.0 * 0.2 }
        return 1.2 + Double(v - 26) / 229.0 * 8.8
    }

    private func parseFrequency(_ s: String) -> UInt64? {
        let digits = s.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        return UInt64(digits)
    }

    private func parseMode(_ s: String) -> String {
        let code = s.prefix(1)
        switch code {
        case "1": return "LSB"
        case "2": return "USB"
        case "3": return "CW"
        case "4": return "FM"
        case "5": return "AM"
        case "6": return "FSK"
        case "7": return "CWR"
        case "8": return "PKT"
        default: return String(s.prefix(3))
        }
    }
}
