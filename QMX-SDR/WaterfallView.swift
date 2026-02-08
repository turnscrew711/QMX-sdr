//
//  WaterfallView.swift
//  QMX-SDR
//
//  Displays the waterfall buffer image. Newest at top. Uses Metal when available for smooth, appealing rendering.
//

import SwiftUI

struct WaterfallView: View {
    var buffer: WaterfallBuffer

    var body: some View {
        GeometryReader { geo in
            if let cgImage = buffer.image {
                WaterfallMetalView(image: cgImage)
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                Color.black
                    .overlay(Text("No waterfall data").foregroundStyle(.gray))
            }
        }
    }
}
