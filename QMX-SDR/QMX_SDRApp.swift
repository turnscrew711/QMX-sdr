//
//  QMX_SDRApp.swift
//  QMX-SDR
//
//  Created by Dylan Zecha on 2/7/26.
//

import SwiftUI
import UIKit

@main
struct QMX_SDRApp: App {
    init() {
        // Remove default toolbar button bubble so custom Win98 Done (and other bar buttons) don’t show a white pill behind them.
        UIBarButtonItem.appearance().setBackgroundImage(UIImage(), for: .normal, barMetrics: .default)
        UIBarButtonItem.appearance().setBackgroundImage(UIImage(), for: .normal, barMetrics: .compact)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
