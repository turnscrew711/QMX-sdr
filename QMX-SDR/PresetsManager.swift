//
//  PresetsManager.swift
//  QMX-SDR
//
//  Frequency presets (memories) stored locally. Recall sets VFO via CAT.
//

import Foundation

struct FrequencyPreset: Identifiable, Codable {
    var id: UUID
    var name: String
    var frequencyHz: UInt64
    var mode: String

    init(id: UUID = UUID(), name: String, frequencyHz: UInt64, mode: String = "") {
        self.id = id
        self.name = name
        self.frequencyHz = frequencyHz
        self.mode = mode
    }
}

@Observable
final class PresetsManager {
    private let key = "qmx_frequency_presets"
    private(set) var presets: [FrequencyPreset] = []

    init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([FrequencyPreset].self, from: data) else {
            presets = []
            return
        }
        presets = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func add(name: String, frequencyHz: UInt64, mode: String) {
        presets.append(FrequencyPreset(name: name, frequencyHz: frequencyHz, mode: mode))
        save()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            presets.remove(at: index)
        }
        save()
    }

    func recall(_ preset: FrequencyPreset, setFrequency: (UInt64) -> Void, setMode: ((Int) -> Void)?) {
        setFrequency(preset.frequencyHz)
        if !preset.mode.isEmpty, let setMode = setMode {
            let code = modeToCode(preset.mode)
            if code > 0 { setMode(code) }
        }
    }

    private func modeToCode(_ mode: String) -> Int {
        switch mode.uppercased() {
        case "LSB": return 1
        case "USB": return 2
        case "CW": return 3
        case "FM": return 4
        case "AM": return 5
        case "FSK", "DIGI": return 6
        case "CWR": return 7
        case "PKT": return 8
        default: return 0
        }
    }
}
