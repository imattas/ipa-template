# Setup

## Prerequisites

- **Xcode 16 or newer** (Swift 6 toolchain, modern MetalKit).
- **iOS 16+** deployment target.
- A **Metal-capable device**: a physical iPhone/iPad, or a Metal-capable
  Simulator. On Apple Silicon Macs, Xcode 16 Simulators support Metal; on Intel
  Macs you should test on a real device. Metal is unavailable on devices without
  a supported GPU — the app declares the `metal` device capability in
  `Info.plist`, so it will not install on unsupported hardware.
- Command-line Metal tools (bundled with Xcode), available through `xcrun`.

## Clone and open

```bash
git clone https://github.com/imattas/ipa-template.git
cd ipa-template/templates/Metal
```

This template intentionally ships **without** an `.xcodeproj`. Generate or
create a project/target that includes these source files, then:

1. Create a new iOS App target (SwiftUI lifecycle).
2. Add all `App/`, `Renderer/`, and `Core/` sources to the target.
3. Add `Resources/Assets.xcassets` to the target.
4. Set the target's **Info.plist** to `App/Info.plist` (or merge its keys),
   especially `UIRequiredDeviceCapabilities = [metal]`.
5. Create a **bridging header** (or add to the existing one) that imports the
   shared types so Swift can see them:

   ```objc
   // <ProductName>-Bridging-Header.h
   #import "ShaderTypes.h"
   ```

   Set **Build Settings → Objective-C Bridging Header** to point at it. This is
   what makes `Vertex`, `Uniforms`, and `BufferIndex` visible to Swift.
6. Set the bundle identifier to `com.example.metal` (or your own).

## How the `.metal` is compiled

`.metal` files in a target are compiled by Xcode's Metal toolchain and linked
into a single **`default.metallib`** embedded in the app bundle. At runtime,
`device.makeDefaultLibrary()` loads that library and `library.makeFunction(name:)`
looks up `vertex_main`, `fragment_main`, and `compute_main` by name. Keep the
Swift function-name strings in sync with the MSL function names.

To compile shaders manually from the command line (useful for CI lint checks):

```bash
# Compile to an intermediate .air, then archive into a .metallib.
xcrun -sdk iphoneos metal   -c Renderer/Shaders.metal -o Shaders.air
xcrun -sdk iphoneos metallib   Shaders.air            -o default.metallib
```

The include path must let the compiler find `ShaderTypes.h` (it lives alongside
`Shaders.metal`, so the relative `#include "ShaderTypes.h"` resolves; add
`-I Renderer` if compiling from a different directory).

## Configuration knobs

- **Frame rate**: `MetalView.makeUIView` sets `preferredFramesPerSecond`.
- **Clear color / pixel format**: also in `MetalView.makeUIView`. The pixel
  format must match the render pipeline (`bgra8Unorm` by default).
- **Frames in flight**: `kMaxBuffersInFlight` in `BufferManager.swift`.
- **Geometry / compute size**: vertex array and `computeElementCount` in
  `Renderer.swift`.

## Troubleshooting

- *"No Metal device is available"* — running on a non-Metal Simulator or host.
  Use a real device or a Metal-capable Simulator.
- *"Shader function '…' not found"* — the `.metal` file is not in the target, or
  the Swift name string does not match the MSL function name.
- *Garbled struct data* — the bridging header is not configured, so Swift and
  MSL disagree on layout. Confirm `ShaderTypes.h` is imported via the bridging
  header.
