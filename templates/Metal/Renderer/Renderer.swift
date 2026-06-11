//
//  Renderer.swift
//  Metal Template
//
//  The MTKViewDelegate that owns pipeline states and buffers, and encodes
//  each frame.
//
//  Threading model
//  ---------------
//  - MetalKit calls `draw(in:)` and `mtkView(_:drawableSizeWillChange:)` on the
//    main thread by default. We mark those touchpoints `@MainActor`.
//  - The actual GPU work (encoding + submission) is cheap CPU-side; the GPU
//    runs asynchronously. We do NOT block the main thread waiting for the GPU:
//    instead the triple-buffer semaphore (in BufferManager) throttles how far
//    ahead the CPU may run, and we signal it from the command buffer's
//    completion handler (which fires on a background queue).
//  - `runCompute()` shows an independent compute submission that can be called
//    off the render loop (e.g. from a Task) without touching the view.
//

import Metal
import MetalKit
import simd

@MainActor
final class Renderer: NSObject, MTKViewDelegate {

    private let metal: MetalDevice
    private let buffers: BufferManager

    private let renderPipeline: MTLRenderPipelineState
    private let computePipeline: MTLComputePipelineState

    // Static geometry: a single colored triangle. TODO: swap for your mesh.
    private let vertexBuffer: MTLBuffer
    private let vertexCount: Int

    // Backing buffer for the compute demo.
    private let computeBuffer: MTLBuffer
    private let computeElementCount = 1024

    private var aspectRatio: Float = 1.0
    private let startTime = CACurrentMediaTime()

    /// Creates a renderer bound to a view. Throws if Metal setup fails.
    init(view: MTKView) throws {
        self.metal = try MetalDevice()
        self.buffers = BufferManager(device: metal.device)

        view.device = metal.device

        self.renderPipeline = try metal.makeRenderPipelineState(
            vertex: "vertex_main",
            fragment: "fragment_main",
            pixelFormat: view.colorPixelFormat
        )
        self.computePipeline = try metal.makeComputePipelineState(function: "compute_main")

        // Triangle in clip space with per-vertex colors.
        let vertices: [Vertex] = [
            Vertex(position: SIMD2<Float>( 0.0,  0.6), color: SIMD4<Float>(1, 0, 0, 1)),
            Vertex(position: SIMD2<Float>(-0.6, -0.6), color: SIMD4<Float>(0, 1, 0, 1)),
            Vertex(position: SIMD2<Float>( 0.6, -0.6), color: SIMD4<Float>(0, 0, 1, 1)),
        ]
        self.vertexCount = vertices.count
        self.vertexBuffer = buffers.makeBuffer(of: Vertex.self,
                                               count: vertices.count,
                                               initialValues: vertices,
                                               label: "Triangle Vertices")

        let seed = (0..<computeElementCount).map { Float($0) / Float(computeElementCount) }
        self.computeBuffer = buffers.makeBuffer(of: Float.self,
                                                count: computeElementCount,
                                                initialValues: seed,
                                                label: "Compute Data")

        buffers.allocateUniformRing()

        super.init()
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        aspectRatio = size.height > 0 ? Float(size.width / size.height) : 1.0
    }

    func draw(in view: MTKView) {
        // Throttle: never run more than kMaxBuffersInFlight frames ahead.
        _ = buffers.inFlightSemaphore.wait(timeout: .distantFuture)

        guard
            let commandBuffer = metal.commandQueue.makeCommandBuffer(),
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable
        else {
            buffers.inFlightSemaphore.signal()
            return
        }

        // Signal the semaphore once the GPU is done with this frame's buffers.
        let semaphore = buffers.inFlightSemaphore
        commandBuffer.addCompletedHandler { _ in
            semaphore.signal()
        }

        // Rotate to this frame's uniform slot and update it.
        buffers.advanceFrame()
        let time = Float(CACurrentMediaTime() - startTime)
        buffers.update(uniforms: Uniforms(modelViewProjection: projectionMatrix(), time: time))

        // --- Render pass: draw the triangle ---
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            encoder.label = "Triangle Render Pass"
            encoder.setRenderPipelineState(renderPipeline)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(BufferIndex.vertices.rawValue))
            encoder.setVertexBuffer(buffers.currentUniformBuffer, offset: 0, index: Int(BufferIndex.uniforms.rawValue))
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
            encoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Compute

    /// Runs an independent compute dispatch over `computeBuffer`.
    ///
    /// This is intentionally decoupled from the render loop to show how a
    /// compute pipeline is encoded and submitted on its own. Returns when the
    /// GPU has finished (via async completion), without blocking the caller's
    /// thread.
    ///
    /// - Returns: the first element of the transformed buffer, for inspection.
    @discardableResult
    func runCompute() async -> Float {
        let time = Float(CACurrentMediaTime() - startTime)

        // Local uniforms for the compute pass (time-driven transform).
        var uniforms = Uniforms(modelViewProjection: matrix_identity_float4x4, time: time)
        var count = UInt32(computeElementCount)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let commandBuffer = metal.commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeComputeCommandEncoder() else {
                continuation.resume()
                return
            }

            encoder.label = "Parallel Transform"
            encoder.setComputePipelineState(computePipeline)
            encoder.setBuffer(computeBuffer, offset: 0, index: Int(BufferIndex.compute.rawValue))
            encoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndex.uniforms.rawValue))
            encoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: Int(BufferIndex.vertices.rawValue))

            // Choose a threadgroup size, then round the grid up to cover all
            // elements. The kernel guards against the rounded-up overshoot.
            let threadgroupWidth = min(computePipeline.maxTotalThreadsPerThreadgroup, 256)
            let threadsPerThreadgroup = MTLSize(width: threadgroupWidth, height: 1, depth: 1)
            let threadgroups = MTLSize(
                width: (computeElementCount + threadgroupWidth - 1) / threadgroupWidth,
                height: 1, depth: 1
            )
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
            encoder.endEncoding()

            commandBuffer.addCompletedHandler { _ in
                continuation.resume()
            }
            commandBuffer.commit()
        }

        let pointer = computeBuffer.contents().bindMemory(to: Float.self, capacity: computeElementCount)
        return pointer.pointee
    }

    // MARK: - Math

    /// A simple orthographic projection that preserves aspect ratio. For 3D,
    /// build a perspective matrix here instead. TODO: replace with your camera.
    private func projectionMatrix() -> matrix_float4x4 {
        let sx = aspectRatio >= 1 ? 1 / aspectRatio : 1
        let sy = aspectRatio >= 1 ? Float(1) : aspectRatio
        return matrix_float4x4(
            SIMD4<Float>(sx, 0,  0, 0),
            SIMD4<Float>(0,  sy, 0, 0),
            SIMD4<Float>(0,  0,  1, 0),
            SIMD4<Float>(0,  0,  0, 1)
        )
    }
}
