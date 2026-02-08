//
//  IQCaptureService.swift
//  QMX-SDR
//
//  Captures IQ audio from USB input (e.g. QMX) via AVAudioEngine.
//

import AVFoundation
import Foundation

@Observable
final class IQCaptureService {
    private let engine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()
    private var isRunning = false

    /// Sample rate reported by the input (e.g. 48000 for QMX).
    private(set) var sampleRate: Double = 0
    /// Number of channels (expect 2 for I/Q).
    private(set) var channelCount: Int = 0
    /// Whether a USB (or external) input is currently preferred and in use.
    private(set) var hasUSBInput: Bool = false
    /// Last buffer info for UI (frames per buffer, updated ~once per second).
    private(set) var lastBufferFrameCount: Int = 0
    /// Callback for raw IQ buffers (interleaved or deinterleaved as provided by the tap).
    var onSamples: (([Float], AVAudioFormat) -> Void)?

    init() {}

    /// Configures session, selects USB input if available, and prepares the engine.
    func configure() throws {
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
        try session.setActive(true)

        let inputs = session.availableInputs ?? []
        let usbInput = inputs.filter { port in
            let name = port.portName.lowercased()
            return name.contains("usb") || name.contains("qmx")
        }.first
        if let usb = usbInput {
            try session.setPreferredInput(usb)
            hasUSBInput = true
        } else {
            hasUSBInput = false
        }
    }

    /// Starts capture: installs tap on inputNode and runs the engine.
    func start() throws {
        guard !isRunning else { return }
        try configure()

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        sampleRate = format.sampleRate
        channelCount = Int(format.channelCount)

        engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            guard let self else { return }
            let frameCount = Int(buffer.frameLength)
            self.lastBufferFrameCount = frameCount

            let channelCount = Int(buffer.format.channelCount)
            var samples: [Float] = []
            if channelCount >= 2 {
                let channelData = buffer.floatChannelData!
                for frame in 0..<frameCount {
                    samples.append(channelData[0][frame])
                    samples.append(channelData[1][frame])
                }
            } else {
                let channelData = buffer.floatChannelData!
                for frame in 0..<frameCount {
                    samples.append(channelData[0][frame])
                    samples.append(0)
                }
            }
            self.onSamples?(samples, buffer.format)
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        sampleRate = 0
        channelCount = 0
        lastBufferFrameCount = 0
    }
}
