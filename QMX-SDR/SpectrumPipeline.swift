//
//  SpectrumPipeline.swift
//  QMX-SDR
//
//  Consumes IQ samples, runs FFT (Accelerate), produces magnitude/dB spectrum.
//

import Accelerate
import Foundation

/// FFT size (number of complex bins). Power of 2.
let defaultFFTSize = 2048

@Observable
final class SpectrumPipeline {
    /// Magnitude spectrum (linear), one value per frequency bin. Updated on main thread.
    private(set) var magnitude: [Float] = []
    /// Optional dB spectrum (e.g. 20*log10(magnitude + 1e-12)). Updated when magnitude is.
    private(set) var magnitudeDB: [Float] = []
    /// Sample rate (from IQ source) for frequency axis.
    var sampleRate: Double = 48000
    /// FFT size (complex bins).
    var fftSize: Int = defaultFFTSize { didSet { setupFFT() } }

    private var inputBuffer: [Float] = []
    private var dftSetup: vDSP_DFT_Setup?
    private var realIn: [Float] = []
    private var imagIn: [Float] = []
    private var realOut: [Float] = []
    private var imagOut: [Float] = []

    init() {
        setupFFT()
    }

    private func setupFFT() {
        dftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        realIn = [Float](repeating: 0, count: fftSize)
        imagIn = [Float](repeating: 0, count: fftSize)
        realOut = [Float](repeating: 0, count: fftSize)
        imagOut = [Float](repeating: 0, count: fftSize)
    }

    deinit {
        if let setup = dftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    /// Push interleaved IQ floats [I,Q,I,Q,...]. When we have fftSize*2, run FFT and update magnitude.
    func push(samples: [Float]) {
        inputBuffer.append(contentsOf: samples)
        let needed = fftSize * 2
        while inputBuffer.count >= needed {
            let chunk = Array(inputBuffer.prefix(needed))
            inputBuffer.removeFirst(needed)
            for i in 0..<fftSize {
                realIn[i] = chunk[i * 2]
                imagIn[i] = chunk[i * 2 + 1]
            }
            processFFT()
        }
    }

    private func processFFT() {
        guard let setup = dftSetup else { return }
        realIn.withUnsafeMutableBufferPointer { rIn in
            imagIn.withUnsafeMutableBufferPointer { iIn in
                realOut.withUnsafeMutableBufferPointer { rOut in
                    imagOut.withUnsafeMutableBufferPointer { iOut in
                        guard let rInBase = rIn.baseAddress,
                              let iInBase = iIn.baseAddress,
                              let rOutBase = rOut.baseAddress,
                              let iOutBase = iOut.baseAddress else { return }
                        vDSP_DFT_Execute(setup, rInBase, iInBase, rOutBase, iOutBase)
                    }
                }
            }
        }
        var mag = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            let r = realOut[i], im = imagOut[i]
            mag[i] = sqrt(r * r + im * im)
        }
        // Center the spectrum: raw DFT order is [0, +freq, ..., Nyquist, -freq, ...].
        // Reorder so left = negative freqs, center = DC, right = positive freqs.
        let half = fftSize / 2
        var centered = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            centered[i] = mag[(i + half) % fftSize]
        }
        let dbEpsilon: Float = 1e-12
        let db = centered.map { 20 * log10(max($0, dbEpsilon)) }
        Task { @MainActor in
            magnitude = centered
            magnitudeDB = db
        }
    }
}
