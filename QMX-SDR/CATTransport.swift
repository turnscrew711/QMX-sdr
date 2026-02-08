//
//  CATTransport.swift
//  QMX-SDR
//
//  Protocol for CAT serial transport (BLE, network, etc.). CATClient uses this.
//

import Foundation

/// Transport that sends raw bytes and delivers received lines (complete replies ending with `;`).
protocol CATTransport: AnyObject {
    var isConnected: Bool { get }
    func send(_ string: String)
    var onReplyReceived: ((String) -> Void)? { get set }
    var onConnectionChanged: ((Bool) -> Void)? { get set }
}
