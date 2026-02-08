//
//  BLESerialTransport.swift
//  QMX-SDR
//
//  BLE serial transport for CAT: scan, connect, read/write (e.g. HM-10 FFE0/FFE1).
//

import CoreBluetooth
import Foundation

/// BLE serial transport compatible with HM-10 and similar modules (service FFE0, characteristic FFE1).
@Observable
final class BLESerialTransport: NSObject, CATTransport {
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var serialCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?

    /// Discovered peripherals (name or identifier string).
    private(set) var discoveredPeripherals: [(identifier: UUID, name: String?)] = []
    /// Currently connected peripheral identifier, if any.
    private(set) var connectedPeripheralId: UUID?
    /// Incoming data buffer; append on notify/read, consume when parsing CAT replies.
    private(set) var readBuffer = Data()
    /// Last received reply line (up to semicolon) for UI.
    private(set) var lastReply: String = ""

    var isConnected: Bool { connectedPeripheralId != nil }

    /// Called when new data is available (e.g. raw bytes).
    var onDataReceived: ((Data) -> Void)?
    /// Called when a complete CAT reply line (ending with ;) is received.
    var onReplyReceived: ((String) -> Void)?
    /// Called when connection state changes.
    var onConnectionChanged: ((Bool) -> Void)?

    static let serialServiceUUID = CBUUID(string: "FFE0")
    static let serialCharacteristicUUID = CBUUID(string: "FFE1")

    override init() {
        super.init()
    }

    /// Start BLE central and scan for peripherals advertising the serial service.
    func startScanning() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: nil)
        }
        guard let central = central, central.state == .poweredOn else {
            return
        }
        discoveredPeripherals = []
        central.scanForPeripherals(withServices: [Self.serialServiceUUID], options: nil)
    }

    func stopScanning() {
        central?.stopScan()
    }

    /// Connect to a peripheral by identifier (from discoveredPeripherals).
    func connect(to identifier: UUID) {
        guard let central = central else { return }
        guard let peripheral = central.retrievePeripherals(withIdentifiers: [identifier]).first else {
            return
        }
        stopScanning()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let peripheral = peripheral else { return }
        central?.cancelPeripheralConnection(peripheral)
        self.peripheral = nil
        serialCharacteristic = nil
        writeCharacteristic = nil
        connectedPeripheralId = nil
        onConnectionChanged?(false)
    }

    /// Send raw bytes (e.g. CAT command string as ASCII).
    func send(_ data: Data) {
        guard let peripheral = peripheral,
              let characteristic = writeCharacteristic ?? serialCharacteristic,
              (characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse)) else {
            return
        }
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(data, for: characteristic, type: writeType)
    }

    /// Send a string (e.g. "FA;").
    func send(_ string: String) {
        guard let data = string.data(using: .ascii) else { return }
        send(data)
    }

    /// Append received data to buffer and look for a complete reply (ending with `;`).
    func consumeReplyFromBuffer() -> String? {
        guard let idx = readBuffer.firstIndex(of: UInt8(ascii: ";")) else { return nil }
        let chunk = readBuffer.prefix(through: idx)
        readBuffer.removeFirst(chunk.count)
        return String(data: chunk, encoding: .ascii)
    }
}

extension BLESerialTransport: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Caller can call startScanning() again if needed.
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append((peripheral.identifier, peripheral.name))
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.serialServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {}

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.peripheral = nil
        serialCharacteristic = nil
        writeCharacteristic = nil
        connectedPeripheralId = nil
        onConnectionChanged?(false)
    }
}

extension BLESerialTransport: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Self.serialServiceUUID {
            peripheral.discoverCharacteristics([Self.serialCharacteristicUUID], for: service)
            break
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.uuid == Self.serialCharacteristicUUID {
                serialCharacteristic = char
                if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                    writeCharacteristic = char
                }
                if char.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: char)
                }
                break
            }
        }
        if writeCharacteristic == nil { writeCharacteristic = serialCharacteristic }
        connectedPeripheralId = peripheral.identifier
        onConnectionChanged?(true)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, !data.isEmpty else { return }
        readBuffer.append(data)
        onDataReceived?(data)
        while let reply = consumeReplyFromBuffer() {
            lastReply = reply
            onReplyReceived?(reply)
        }
    }
}
