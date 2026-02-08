//
//  HFBands.swift
//  QMX-SDR
//
//  HF amateur band definitions (10–80 m) for band switching and display span.
//

import Foundation

/// Standard HF band: label and frequency range in Hz.
struct HFBand: Identifiable {
    let id: String
    let label: String
    let startHz: UInt64
    let endHz: UInt64

    var centerHz: UInt64 { (startHz + endHz) / 2 }
    var widthHz: UInt64 { endHz - startHz }
}

/// Predefined HF bands (80, 60, 40, 30, 20, 15, 10 m).
enum HFBands {
    static let bands: [HFBand] = [
        HFBand(id: "80", label: "80m", startHz: 3_500_000, endHz: 4_000_000),
        HFBand(id: "60", label: "60m", startHz: 5_330_500, endHz: 5_366_500),
        HFBand(id: "40", label: "40m", startHz: 7_000_000, endHz: 7_300_000),
        HFBand(id: "30", label: "30m", startHz: 10_100_000, endHz: 10_150_000),
        HFBand(id: "20", label: "20m", startHz: 14_000_000, endHz: 14_350_000),
        HFBand(id: "15", label: "15m", startHz: 21_000_000, endHz: 21_450_000),
        HFBand(id: "10", label: "10m", startHz: 28_000_000, endHz: 29_700_000),
    ]

    static func band(containing hz: UInt64) -> HFBand? {
        bands.first { hz >= $0.startHz && hz <= $0.endHz }
    }

    static func band(id: String) -> HFBand? {
        bands.first { $0.id == id }
    }

    /// Default sideband for SSB on this band (amateur standard: LSB on 80m/40m, USB on 20m and up).
    static func defaultSSBForBand(id: String) -> String {
        switch id {
        case "80", "40": return "LSB"
        default: return "USB"
        }
    }

    /// Default sideband for SSB at the given frequency (uses band containing hz).
    static func defaultSSBForFrequency(hz: UInt64) -> String {
        guard let band = band(containing: hz) else { return "USB" }
        return defaultSSBForBand(id: band.id)
    }
}
