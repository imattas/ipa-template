//
//  MetalDevice.swift
//  Metal Template
//
//  Owns the long-lived Metal objects: the GPU `MTLDevice`, a shared
//  `MTLCommandQueue`, and the default shader library (compiled from the
//  project's .metal files into `default.metallib`).
//
//  Also provides typed helpers for creating render and compute pipeline
//  states, which centralizes error handling and keeps the Renderer focused on
//  per-frame encoding.
//

import Metal
import MetalKit

/// Errors thrown while setting up Metal.
enum MetalError: Error, CustomStringConvertible {
    case deviceUnavailable
    case commandQueueCreationFailed
    case libraryUnavailable
    case functionNotFound(String)
    case pipelineCreationFailed(underlying: Error)

    var description: String {
        switch self {
        case .deviceUnavailable:
            return "No Metal device is available. Metal requires a real device or a Metal-capable simulator."
        case .commandQueueCreationFailed:
            return "Failed to create a Metal command queue."
        case .libraryUnavailable:
            return "Failed to load the default Metal library (default.metallib). Ensure at least one .metal file is in the target."
        case .functionNotFound(let name):
            return "Shader function '\(name)' was not found in the default library."
        case .pipelineCreationFailed(let underlying):
            return "Failed to create a pipeline state: \(underlying)"
        }
    }
}

/// Wraps the device-level Metal objects and pipeline-creation helpers.
///
/// Thread-safety: `MTLDevice`, `MTLCommandQueue`, and `MTLLibrary` are all
/// thread-safe to use from multiple threads. Instances of this type can be
/// shared freely.
final class MetalDevice {

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary

    /// Creates the Metal stack, throwing a typed `MetalError` on any failure.
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalError.deviceUnavailable
        }
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            throw MetalError.commandQueueCreationFailed
        }
        self.commandQueue = queue

        guard let library = device.makeDefaultLibrary() else {
            throw MetalError.libraryUnavailable
        }
        self.library = library
    }

    // MARK: - Pipeline Creation

    /// Builds a render pipeline state from named vertex and fragment functions.
    ///
    /// - Parameters:
    ///   - vertex: Name of the vertex function in the default library.
    ///   - fragment: Name of the fragment function in the default library.
    ///   - pixelFormat: The color attachment pixel format (match the MTKView).
    func makeRenderPipelineState(vertex: String,
                                 fragment: String,
                                 pixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState {
        guard let vertexFunction = library.makeFunction(name: vertex) else {
            throw MetalError.functionNotFound(vertex)
        }
        guard let fragmentFunction = library.makeFunction(name: fragment) else {
            throw MetalError.functionNotFound(fragment)
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "\(vertex) + \(fragment)"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = pixelFormat

        // TODO: configure blending / depth-stencil formats here if needed.

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw MetalError.pipelineCreationFailed(underlying: error)
        }
    }

    /// Builds a compute pipeline state from a named kernel function.
    func makeComputePipelineState(function name: String) throws -> MTLComputePipelineState {
        guard let function = library.makeFunction(name: name) else {
            throw MetalError.functionNotFound(name)
        }
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            throw MetalError.pipelineCreationFailed(underlying: error)
        }
    }
}
