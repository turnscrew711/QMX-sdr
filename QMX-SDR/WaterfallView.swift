//
//  WaterfallView.swift
//  QMX-SDR
//
//  Displays the waterfall buffer image. Newest at top. Uses Metal when available for smooth, appealing rendering.
//

import SwiftUI

/// True when the app is running in the Xcode Preview canvas. Metal is unreliable there, so we use a fallback.
private var isRunningForPreviews: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

struct WaterfallView: View {
    var buffer: WaterfallBuffer

    var body: some View {
        GeometryReader { geo in
            if let cgImage = buffer.image {
                if isRunningForPreviews {
                    Image(uiImage: UIImage(cgImage: cgImage))
                        .resizable()
                        .interpolation(.medium)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    WaterfallMetalView(image: cgImage, gamma: buffer.gamma)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            } else {
                Color.black
                    .overlay(Text("No waterfall data").foregroundStyle(.gray))
            }
        }
    }
}
