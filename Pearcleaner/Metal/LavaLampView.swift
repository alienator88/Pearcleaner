//
//  Metal.swift
//  Playground
//
//  Created by Alin Lupascu on 3/26/25.
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    func makeCoordinator() -> Renderer { Renderer() }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 60
        view.delegate = context.coordinator
        context.coordinator.mtkView(view, drawableSizeWillChange: view.drawableSize)
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}
}



class Renderer: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!

    var centers: [SIMD2<Float>] = []
    var radii: [Float] = []
    var time: Float = 0

    override init() {
        super.init()
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        setupPipeline()
        setupBlobs()
    }

    func setupPipeline() {
        let library = device.makeDefaultLibrary()
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = library?.makeFunction(name: "vertex_passthrough")
        pipelineDesc.fragmentFunction = library?.makeFunction(name: "lavaLampFrag")
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDesc)
    }

    func setupBlobs() {
        for _ in 0..<6 {
            centers.append(SIMD2<Float>(Float.random(in: 0.2...0.8), Float.random(in: 0.2...0.8)))
            radii.append(Float.random(in: 0.05...0.15))
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor else { return }

        time += 0.016

        let cmdBuffer = commandQueue.makeCommandBuffer()!
        let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: rpd)!
        encoder.setRenderPipelineState(pipelineState)

        encoder.setFragmentBytes(&centers, length: MemoryLayout<SIMD2<Float>>.stride * centers.count, index: 0)
        encoder.setFragmentBytes(&radii, length: MemoryLayout<Float>.stride * radii.count, index: 1)

        var count = UInt32(centers.count)
        encoder.setFragmentBytes(&count, length: MemoryLayout<UInt32>.stride, index: 2)
        encoder.setFragmentBytes(&time, length: MemoryLayout<Float>.stride, index: 3)

        var resolution = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        encoder.setFragmentBytes(&resolution, length: MemoryLayout<SIMD2<Float>>.stride, index: 4)

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        cmdBuffer.present(drawable)
        cmdBuffer.commit()
    }
}
