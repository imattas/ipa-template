# Metal Template

![CI](https://github.com/imattas/ipa-template/actions/workflows/build.yml/badge.svg)

A production-ready scaffolding for a **Swift + Metal** iOS app that demonstrates
the two core Metal pipelines side by side:

- **Render pipeline** — an `MTKViewDelegate` draws an animated, colored triangle
  each frame using vertex + fragment shaders and per-frame uniforms.
- **Compute pipeline** — a kernel performs a parallel transform over a buffer,
  dispatched independently of the render loop.
- **CPU/GPU shared types** — a single `ShaderTypes.h` defines the struct layouts
  and buffer indices used by both Swift and Metal Shading Language.
- **Triple-buffering** — a 3-slot uniform ring + semaphore keeps the CPU from
  overwriting data the GPU is still reading.

## Folder tree

```
Metal/
├── App/
│   ├── AppEntry.swift        @main SwiftUI App, hosts the Metal view
│   └── Info.plist            Requires the `metal` device capability
├── Renderer/
│   ├── MetalView.swift       UIViewRepresentable wrapping MTKView
│   ├── Renderer.swift        MTKViewDelegate: render + compute encoding
│   ├── Shaders.metal         vertex_main / fragment_main / compute_main
│   └── ShaderTypes.h         Shared CPU/GPU structs + buffer-index enums
├── Core/
│   ├── MetalDevice.swift     Device / queue / library + pipeline helpers
│   └── BufferManager.swift   Typed buffers + triple-buffer ring
├── Resources/
│   └── Assets.xcassets/      App icon + accent color
└── docs/
    ├── ARCHITECTURE.md
    └── SETUP.md
```

## Pattern: Renderer + MTKViewDelegate

`MetalView` (a `UIViewRepresentable`) creates an `MTKView`, assigns the GPU
device, and sets a `Renderer` as its delegate. MetalKit calls
`Renderer.draw(in:)` on a display-linked timer; the Renderer encodes a command
buffer (render pass, optionally compute) and submits it asynchronously to the
GPU. `Core/` provides the reusable device/buffer plumbing so the Renderer stays
focused on per-frame work. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for
the full frame lifecycle, shared-types approach, and triple-buffering details.

## Build & run

1. Open the repo in **Xcode 16+** and add these sources to an iOS App target
   (SwiftUI lifecycle). This template ships without an `.xcodeproj` on purpose.
2. Configure an Objective-C **bridging header** that `#import "ShaderTypes.h"`
   so Swift sees the shared types.
3. Select a **real device or a Metal-capable Simulator** and run.

Full step-by-step instructions, including how `.metal` compiles into
`default.metallib`, are in [docs/SETUP.md](docs/SETUP.md).

> Metal requires a real device or a Metal-capable Simulator. The app declares
> the `metal` capability and will not install on unsupported hardware.
