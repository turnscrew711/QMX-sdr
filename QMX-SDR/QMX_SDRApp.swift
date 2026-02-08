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
        // Match toolbar button bubble to menu background (Win98.surface) so it blends in.
        let surfaceColor = UIColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1)
        let size = CGSize(width: 1, height: 1)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            surfaceColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysOriginal)
        let resizable = image.resizableImage(withCapInsets: .zero, resizingMode: .stretch)
        let navBarButton = UIBarButtonItem.appearance(whenContainedInInstancesOf: [UINavigationBar.self])
        for state: UIControl.State in [.normal, .highlighted, .focused, .disabled] {
            navBarButton.setBackgroundImage(resizable, for: state, barMetrics: .default)
            navBarButton.setBackgroundImage(resizable, for: state, barMetrics: .compact)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
