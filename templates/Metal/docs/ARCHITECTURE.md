# Architecture

This template demonstrates a complete, idiomatic Metal setup for iOS that
exercises **both** a render pipeline (drawing geometry) and a compute pipeline
(parallel data transform), with **CPU/GPU shared types** and **triple-buffered**
per-frame data.

## Folder structure

```
Metal/
├── App/
│   ├── AppEntry.swift        @main SwiftUI App; hosts MetalView full-screen
│   └── Info.plist            Bundle config; requires the `metal` capability
├── Renderer/
│   ├── MetalView.swift       UIViewRepresentable wrapping MTKView
│   ├── Renderer.swift        MTKViewDelegate: encodes render + compute work
│   ├── Shaders.metal         Vertex, fragment, and compute MSL functions
│   └── ShaderTypes.h         Shared CPU/GPU structs + buffer-index enums
├── Core/
│   ├── MetalDevice.swift     Device/queue/library + pipeline-state helpers
│   └── BufferManager.swift   Typed buffers + triple-buffer ring + semaphore
├── Resources/
│   └── Assets.xcassets/      App icon + accent color
└── docs/                     This documentation
```

**Rationale.** `Core/` holds long-lived, reusable plumbing (device setup,
buffer allocation) that rarely changes. `Renderer/` holds the per-app drawing
logic and shaders that you customize. `App/` is the thin SwiftUI shell. Keeping
shaders next to the Renderer that uses them makes the render/compute story easy
to follow; keeping device/buffer plumbing in `Core/` keeps that story short.

## Frame lifecycle

MetalKit drives the loop via a display-linked timer. Each frame:

```
        ┌──────────────┐
        │   MTKView    │  display-link tick (preferredFramesPerSecond)
        └──────┬───────┘
               │ calls (main thread)
               ▼
   ┌───────────────────────────┐
   │  Renderer.draw(in:)        │
   │  1. semaphore.wait()       │  ── throttle: ≤ 3 frames in flight
   │  2. advance uniform slot   │
   │  3. write Uniforms (time)  │
   └─────────────┬─────────────┘
                 │ makeCommandBuffer()
                 ▼
        ┌──────────────────┐
        │  MTLCommandBuffer │
        └───────┬──────────┘
        ┌───────┴───────────────────────────┐
        ▼                                     ▼
 ┌───────────────────┐              ┌──────────────────────┐
 │ Render encoder    │              │ Compute encoder      │
 │ setPipelineState  │              │ setComputePipeline   │
 │ setVertexBuffer   │              │ setBuffer            │
 │ drawPrimitives    │              │ dispatchThreadgroups │
 └─────────┬─────────┘              └──────────┬───────────┘
           └───────────────┬───────────────────┘
                           ▼
                 commandBuffer.present(drawable)
                 commandBuffer.commit()  ── async to GPU
                           │
                           ▼
                 ┌──────────────────┐
                 │       GPU        │  executes encoded passes
                 └────────┬─────────┘
                          │ addCompletedHandler (background queue)
                          ▼
                 semaphore.signal()  ── frees a ring slot
```

In this template the render pass runs every frame from `draw(in:)`, while the
compute pass is exposed as an independent `runCompute()` async method to show
how compute is encoded and submitted on its own command buffer. You can also
encode both passes into a single command buffer.

## CPU/GPU shared types (`ShaderTypes.h`)

`Renderer/ShaderTypes.h` is the single source of truth for memory layouts shared
across the CPU/GPU boundary. It is included from `Shaders.metal` (where
`__METAL_VERSION__` is defined) and imported into Swift via a bridging header
(where it is not). SIMD types from `<simd/simd.h>` have identical layout on both
sides, so a `Vertex` written by Swift is read correctly by the vertex shader.

- `struct Vertex { vector_float2 position; vector_float4 color; }`
- `struct Uniforms { matrix_float4x4 modelViewProjection; float time; }`
- `enum BufferIndex { Vertices, Uniforms, Compute }` — stable indices used by
  both `setVertexBuffer(_:offset:index:)` and `[[ buffer(n) ]]`.

This eliminates an entire class of bugs where the two sides disagree on struct
field order, size, or buffer slot.

## Triple-buffering pattern

The CPU records frame N+1 while the GPU still reads frame N. A single shared
uniform buffer would let the CPU overwrite data mid-read. Instead
`BufferManager` keeps a ring of `kMaxBuffersInFlight` (3) uniform buffers and
rotates through them each frame. A `DispatchSemaphore(value: 3)` caps how far
ahead the CPU may run: `draw(in:)` waits on it at the top of the frame, and the
command buffer's completion handler signals it when the GPU is done. If the GPU
falls behind, the CPU blocks cleanly on the wait instead of corrupting data.

## Render vs compute pipelines

| | Render pipeline | Compute pipeline |
|---|---|---|
| State type | `MTLRenderPipelineState` | `MTLComputePipelineState` |
| Built from | vertex + fragment functions | one kernel function |
| Encoder | `MTLRenderCommandEncoder` | `MTLComputeCommandEncoder` |
| Output | drawable/attachments | buffers/textures |
| Dispatch | `drawPrimitives(...)` | `dispatchThreadgroups(...)` |

Both are created through `MetalDevice` helpers
(`makeRenderPipelineState`, `makeComputePipelineState`) that centralize error
handling.

## Where to add a new shader / pipeline

1. **Add the MSL function** in `Renderer/Shaders.metal`. For shared data, add or
   reuse structs/enums in `ShaderTypes.h` so both sides agree.
2. **Create the pipeline state** in `Renderer.swift` using the appropriate
   `MetalDevice` helper, storing it as a property.
3. **Allocate buffers** through `BufferManager.makeBuffer(of:count:...)`. If the
   data is per-frame and CPU-written, route it through the triple-buffer ring.
4. **Encode it** — add a new encoder block in `draw(in:)` (render) or a new
   `runX()` method (compute), binding buffers at the `BufferIndex` slots.
5. **Match formats** — a render pipeline's `colorAttachments[0].pixelFormat`
   must equal the `MTKView.colorPixelFormat`.
