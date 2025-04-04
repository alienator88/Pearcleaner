//
//  AnimatedGradientView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/3/25.
//

import SwiftUI
import MetalKit

enum GradientDirection {
    case vertical
    case horizontal
    case circular
}

struct AnimatedGradientView: NSViewRepresentable {
    var colors: [Color]
    var direction: GradientDirection
    
    func makeCoordinator() -> Coordinator {
        Coordinator(colors: colors.map { $0.toSIMD() }, direction: direction)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.colors = colors.map { $0.toSIMD() }
        context.coordinator.direction = direction
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var commandQueue: MTLCommandQueue!
        var pipelineState: MTLRenderPipelineState!
        var startTime = CACurrentMediaTime()
        
        var colors: [SIMD4<Float>]
        var direction: GradientDirection
        
        init(device: MTLDevice = MTLCreateSystemDefaultDevice()!, colors: [SIMD4<Float>], direction: GradientDirection) {
            self.colors = colors
            self.direction = direction
            super.init()
            let lib = device.makeDefaultLibrary()!
            let pipelineDesc = MTLRenderPipelineDescriptor()
            pipelineDesc.vertexFunction = lib.makeFunction(name: "vertex_main")
            pipelineDesc.fragmentFunction = lib.makeFunction(name: "fragment_main")
            pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDesc)
            commandQueue = device.makeCommandQueue()
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let rpd = view.currentRenderPassDescriptor,
                  let cmdBuf = commandQueue.makeCommandBuffer(),
                  let enc = cmdBuf.makeRenderCommandEncoder(descriptor: rpd) else { return }
            
            let time = Float(CACurrentMediaTime() - startTime)
            let directionValue: Float
            switch direction {
            case .vertical: directionValue = 0
            case .horizontal: directionValue = 1
            case .circular: directionValue = 2
            }
            
            struct GradientParams {
                var time: Float
                var direction: Float
                var colorCount: UInt32
            }
            
            var params = GradientParams(time: time, direction: directionValue, colorCount: UInt32(colors.count))
            enc.setRenderPipelineState(pipelineState)
            enc.setVertexBytes(&params, length: MemoryLayout<GradientParams>.stride, index: 0)
            enc.setFragmentBytes(&params, length: MemoryLayout<GradientParams>.stride, index: 0)
            enc.setFragmentBytes(colors, length: MemoryLayout<SIMD4<Float>>.stride * colors.count, index: 1)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            enc.endEncoding()
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    }
}

extension Color {
    func toSIMD() -> SIMD4<Float> {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? .black
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return SIMD4(Float(red), Float(green), Float(blue), Float(alpha))
    }
}
