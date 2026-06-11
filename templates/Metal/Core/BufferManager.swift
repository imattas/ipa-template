//
//  BufferManager.swift
//  Metal Template
//
//  Typed MTLBuffer allocation plus a triple-buffering ring for per-frame
//  data (uniforms).
//
//  Why triple-buffering?
//  ---------------------
//  The CPU records frame N+1 while the GPU is still reading frame N. If the CPU
//  wrote uniforms into a single shared buffer, it could overwrite data the GPU
//  is mid-read on, causing flicker or corruption. We keep a ring of N buffers
//  (here 3) and rotate through them. A DispatchSemaphore caps the number of
//  frames the CPU may run ahead, so it never laps the GPU and stalls cleanly
//  when the GPU falls behind.
//

import Metal

/// Number of frames the CPU is allowed to be working on concurrently.
/// 3 is the conventional choice: enough to hide latency without excess memory.
let kMaxBuffersInFlight = 3

/// Allocates and vends typed Metal buffers, and manages the per-frame
/// triple-buffer ring used for synchronizing CPU writes with GPU reads.
final class BufferManager {

    private let device: MTLDevice

    /// Caps in-flight frames. Wait before encoding a frame; signal in the
    /// command buffer's completion handler.
    let inFlightSemaphore = DispatchSemaphore(value: kMaxBuffersInFlight)

    /// Ring of uniform buffers, one slot per in-flight frame.
    private(set) var uniformBuffers: [MTLBuffer] = []

    /// Index of the ring slot for the frame currently being encoded.
    private(set) var currentBufferIndex = 0

    init(device: MTLDevice) {
        self.device = device
    }

    // MARK: - Generic Allocation

    /// Allocates a buffer sized for `count` elements of `T`, optionally seeding
    /// it from an array.
    ///
    /// Uses `.storageModeShared` so the CPU can write directly. On discrete
    /// GPUs you may prefer `.storageModeManaged` + `didModifyRange`; on Apple
    /// Silicon, shared memory is the right default.
    func makeBuffer<T>(of type: T.Type,
                       count: Int,
                       initialValues: [T]? = nil,
                       label: String? = nil) -> MTLBuffer {
        let length = MemoryLayout<T>.stride * count
        let buffer: MTLBuffer
        if let initialValues {
            precondition(initialValues.count == count, "initialValues count must equal count")
            buffer = initialValues.withUnsafeBytes { raw in
                device.makeBuffer(bytes: raw.baseAddress!, length: length, options: .storageModeShared)!
            }
        } else {
            buffer = device.makeBuffer(length: length, options: .storageModeShared)!
        }
        buffer.label = label
        return buffer
    }

    // MARK: - Triple-Buffer Ring (Uniforms)

    /// Allocates the uniform ring. Call once during setup.
    func allocateUniformRing(uniformType: Uniforms.Type = Uniforms.self) {
        uniformBuffers = (0..<kMaxBuffersInFlight).map { index in
            makeBuffer(of: Uniforms.self, count: 1, label: "Uniforms[\(index)]")
        }
    }

    /// Advances to the next ring slot. Call once per frame, after the
    /// semaphore wait. Returns the buffer for this frame's uniforms.
    @discardableResult
    func advanceFrame() -> MTLBuffer {
        currentBufferIndex = (currentBufferIndex + 1) % kMaxBuffersInFlight
        return uniformBuffers[currentBufferIndex]
    }

    /// The uniform buffer for the frame currently being encoded.
    var currentUniformBuffer: MTLBuffer {
        uniformBuffers[currentBufferIndex]
    }

    /// Writes `value` into the current frame's uniform buffer.
    func update(uniforms value: Uniforms) {
        let pointer = currentUniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        pointer.pointee = value
    }
}
