//
//  WaterfallBuffer.swift
//  QMX-SDR
//
//  2D buffer (time × frequency bins). New FFT row at newest time; scroll. Produces image for display.
//

import CoreGraphics
import Foundation
import UIKit

private enum WaterfallDefaults {
    static let sensitivityKey = "waterfall.sensitivity"
    static let gammaKey = "waterfall.gamma"
    static let paletteKey = "waterfall.palette"
    static let sensitivityDefault: Float = 1.0
    static let gammaDefault: Float = 0.92
}

/// Waterfall color palette.
enum WaterfallPalette: String, CaseIterable, Identifiable {
    case grayscale
    case blueRed
    case cold
    case hot
    var id: String { rawValue }
    var label: String {
        switch self {
        case .grayscale: return "Grayscale"
        case .blueRed: return "Blue–Red"
        case .cold: return "Cold"
        case .hot: return "Hot"
        }
    }
}

/// Holds rolling rows of magnitude (dB or linear). Renders to a grayscale/color image.
@Observable
final class WaterfallBuffer {
    /// Number of frequency bins (columns).
    let binCount: Int
    /// Maximum number of time rows to keep.
    let maxRows: Int
    /// Rows of magnitude values (row-major: row 0 = oldest, last row = newest; scrolls upward).
    private var rows: [[Float]] = []
    /// Min/max for color scale (dB). Updated from data.
    private var minDB: Float = -60
    private var maxDB: Float = 10
    /// Last rendered image for display.
    private(set) var image: CGImage?

    /// Sensitivity 0.5–2.0: higher = more contrast (narrower effective range).
    var sensitivity: Float {
        didSet {
            sensitivity = min(2.0, max(0.5, sensitivity))
            saveSensitivity()
            rerender()
        }
    }

    /// Display gamma 0.5–2.0 (used by Metal shader).
    var gamma: Float {
        didSet {
            gamma = min(2.0, max(0.5, gamma))
            saveGamma()
        }
    }

    /// Color palette for the waterfall.
    var palette: WaterfallPalette {
        didSet {
            savePalette()
            rerender()
        }
    }

    init(binCount: Int, maxRows: Int = 256) {
        self.binCount = binCount
        self.maxRows = maxRows
        let s = UserDefaults.standard.object(forKey: WaterfallDefaults.sensitivityKey) as? NSNumber
        self.sensitivity = s?.floatValue ?? WaterfallDefaults.sensitivityDefault
        let g = UserDefaults.standard.object(forKey: WaterfallDefaults.gammaKey) as? NSNumber
        self.gamma = g?.floatValue ?? WaterfallDefaults.gammaDefault
        let raw = UserDefaults.standard.string(forKey: WaterfallDefaults.paletteKey)
        self.palette = (raw.flatMap { WaterfallPalette(rawValue: $0) }) ?? .blueRed
    }

    private func saveSensitivity() {
        UserDefaults.standard.set(sensitivity, forKey: WaterfallDefaults.sensitivityKey)
    }
    private func saveGamma() {
        UserDefaults.standard.set(gamma, forKey: WaterfallDefaults.gammaKey)
    }
    private func savePalette() {
        UserDefaults.standard.set(palette.rawValue, forKey: WaterfallDefaults.paletteKey)
    }

    private func rerender() {
        let newImage = renderImage()
        if Thread.isMainThread {
            image = newImage
        } else {
            Task { @MainActor in
                image = newImage
            }
        }
    }

    /// Append a new spectrum row (same length as binCount). Newest row at bottom; waterfall scrolls upward.
    func pushRow(_ magnitudes: [Float]) {
        let slice = magnitudes.count >= binCount ? Array(magnitudes.prefix(binCount)) : magnitudes + [Float](repeating: 0, count: binCount - magnitudes.count)
        rows.append(slice)
        if rows.count > maxRows {
            rows.removeFirst()
        }
        updateRange(slice)
        let newImage = renderImage()
        Task { @MainActor in
            image = newImage
        }
    }

    private func updateRange(_ row: [Float]) {
        let r = row.min() ?? 0, R = row.max() ?? 0
        if rows.count == 1 {
            minDB = r
            maxDB = R
        } else {
            minDB = min(minDB, r)
            maxDB = max(maxDB, R)
        }
    }

    /// Render to CGImage. Row 0 (oldest) at top, last row (newest) at bottom; scrolls upward. Each pixel = one bin, one time row.
    func renderImage() -> CGImage? {
        let H = rows.count
        guard H > 0, binCount > 0 else { return nil }
        let W = binCount
        let range = max(maxDB - minDB, 1)
        guard let ctx = CGContext(
                  data: nil,
                  width: W,
                  height: H,
                  bitsPerComponent: 8,
                  bytesPerRow: W * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        let buffer = ctx.data!.assumingMemoryBound(to: UInt8.self)
        for y in 0..<H {
            let row = rows[y]
            for x in 0..<min(W, row.count) {
                var v = (row[x] - minDB) / range
                v = max(0, min(1, v))
                let t = (v - 0.5) * sensitivity + 0.5
                let tClamped = max(0, min(1, t))
                let (r, g, b) = colorMap(tClamped)
                let i = (y * W + x) * 4
                buffer[i] = r
                buffer[i + 1] = g
                buffer[i + 2] = b
                buffer[i + 3] = 255
            }
        }
        return ctx.makeImage()
    }

    private func colorMap(_ t: Float) -> (UInt8, UInt8, UInt8) {
        switch palette {
        case .grayscale: return colorMapGrayscale(t)
        case .blueRed: return colorMapBlueRed(t)
        case .cold: return colorMapCold(t)
        case .hot: return colorMapHot(t)
        }
    }

    /// Grayscale: black -> white.
    private func colorMapGrayscale(_ t: Float) -> (UInt8, UInt8, UInt8) {
        let v = UInt8(max(0, min(255, t * 255)))
        return (v, v, v)
    }

    /// Blue -> cyan -> green -> yellow -> red.
    private func colorMapBlueRed(_ t: Float) -> (UInt8, UInt8, UInt8) {
        let T = Double(t)
        let r: UInt8
        let g: UInt8
        let b: UInt8
        if T < 0.25 {
            let u = T / 0.25
            r = 0
            g = UInt8(u * 255)
            b = 255
        } else if T < 0.5 {
            let u = (T - 0.25) / 0.25
            r = 0
            g = 255
            b = UInt8((1 - u) * 255)
        } else if T < 0.75 {
            let u = (T - 0.5) / 0.25
            r = UInt8(u * 255)
            g = 255
            b = 0
        } else {
            let u = (T - 0.75) / 0.25
            r = 255
            g = UInt8((1 - u) * 255)
            b = 0
        }
        return (r, g, b)
    }

    /// Cold: black -> blue -> cyan.
    private func colorMapCold(_ t: Float) -> (UInt8, UInt8, UInt8) {
        let T = Double(t)
        let r: UInt8 = 0
        let g = UInt8(min(255, T * 255))
        let b = UInt8(min(255, T * 255))
        return (r, g, b)
    }

    /// Hot: black -> red -> yellow -> white.
    private func colorMapHot(_ t: Float) -> (UInt8, UInt8, UInt8) {
        let T = Double(t)
        let r: UInt8
        let g: UInt8
        let b: UInt8
        if T < 1.0 / 3 {
            let u = T * 3
            r = UInt8(u * 255)
            g = 0
            b = 0
        } else if T < 2.0 / 3 {
            let u = (T - 1.0 / 3) * 3
            r = 255
            g = UInt8(u * 255)
            b = 0
        } else {
            let u = (T - 2.0 / 3) * 3
            r = 255
            g = 255
            b = UInt8(u * 255)
        }
        return (r, g, b)
    }
}
