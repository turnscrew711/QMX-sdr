//
//  WaterfallMetalView.swift
//  QMX-SDR
//
//  Metal-backed display of the waterfall texture: smooth sampling + subtle gamma.
//  Shaders are compiled at runtime so the Metal build toolchain is not required.
//

import MetalKit
import SwiftUI
import UIKit

private let kWaterfallMetalSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut waterfall_vertex(uint vid [[vertex_id]],
                                   constant float4 *vertices [[buffer(0)]]) {
    float4 v = vertices[vid];
    VertexOut out;
    out.position = float4(v.x, v.y, 0.0, 1.0);
    out.texCoord = v.zw;
    return out;
}

fragment float4 waterfall_fragment(VertexOut in [[stage_in]],
                                   texture2d<float, access::sample> tex [[texture(0)]]) {
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge);
    float4 c = tex.sample(s, in.texCoord);
    float gamma = 0.92;
    c.rgb = pow(max(c.rgb, 0.0), gamma);
    return c;
}
"""

/// Metal view that draws the waterfall CGImage with linear filtering and a slight gamma.
struct WaterfallMetalView: UIViewRepresentable {
    var image: CGImage?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = true
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = true
        context.coordinator.setup(mtkView: mtkView, image: image)
        return mtkView
    }

    func updateUIView(_ mtkView: MTKView, context: Context) {
        context.coordinator.updateTexture(from: image, view: mtkView)
        mtkView.setNeedsDisplay()
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        private var pipelineState: MTLRenderPipelineState?
        private var vertexBuffer: MTLBuffer?
        private var texture: MTLTexture?
        private let queue = DispatchQueue(label: "waterfall.metal")

        private static let quadVertices: [Float] = [
            -1, -1, 0, 1,   // position xy, texCoord zw
             1, -1, 1, 1,
            -1,  1, 0, 0,
             1,  1, 1, 0
        ]

        func setup(mtkView: MTKView, image: CGImage?) {
            guard let device = mtkView.device else { return }
            let lib = try? device.makeLibrary(source: kWaterfallMetalSource, options: nil)
            let vertexFn = lib?.makeFunction(name: "waterfall_vertex")
            let fragmentFn = lib?.makeFunction(name: "waterfall_fragment")
            guard let vertexFn = vertexFn, let fragmentFn = fragmentFn else { return }

            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vertexFn
            desc.fragmentFunction = fragmentFn
            desc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
            desc.colorAttachments[0].isBlendingEnabled = false
            pipelineState = try? device.makeRenderPipelineState(descriptor: desc)

            vertexBuffer = device.makeBuffer(
                bytes: Self.quadVertices,
                length: Self.quadVertices.count * MemoryLayout<Float>.stride,
                options: .storageModeShared
            )

            updateTexture(from: image, view: mtkView)
        }

        func updateTexture(from cgImage: CGImage?, view: MTKView) {
            guard let device = view.device, let cgImage = cgImage else {
                texture = nil
                return
            }
            queue.async { [weak self] in
                let loader = MTKTextureLoader(device: device)
                let options: [MTKTextureLoader.Option: Any] = [
                    .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                    .textureStorageMode: NSNumber(value: MTLStorageMode.shared.rawValue)
                ]
                do {
                    let tex = try loader.newTexture(cgImage: cgImage, options: options)
                    DispatchQueue.main.async {
                        self?.texture = tex
                        view.setNeedsDisplay()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.texture = nil
                    }
                }
            }
        }

        func draw(in view: MTKView) {
            guard let descriptor = view.currentRenderPassDescriptor,
                  let commandQueue = view.device?.makeCommandQueue(),
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
                  let pipelineState = pipelineState,
                  let vertexBuffer = vertexBuffer else { return }

            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            if let texture = texture {
                encoder.setFragmentTexture(texture, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
            encoder.endEncoding()

            if let drawable = view.currentDrawable {
                commandBuffer.present(drawable)
            }
            commandBuffer.commit()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    }
}
