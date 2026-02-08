//
//  WaterfallBuffer.swift
//  QMX-SDR
//
//  2D buffer (time × frequency bins). New FFT row at newest time; scroll. Produces image for display.
//

import CoreGraphics
import Foundation
import UIKit

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

    init(binCount: Int, maxRows: Int = 256) {
        self.binCount = binCount
        self.maxRows = maxRows
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
                let v = (row[x] - minDB) / range
                let t = max(0, min(1, v))
                let (r, g, b) = colorMap(t)
                let i = (y * W + x) * 4
                buffer[i] = r
                buffer[i + 1] = g
                buffer[i + 2] = b
                buffer[i + 3] = 255
            }
        }
        return ctx.makeImage()
    }

    /// Simple blue -> cyan -> green -> yellow -> red.
    private func colorMap(_ t: Float) -> (UInt8, UInt8, UInt8) {
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
}
