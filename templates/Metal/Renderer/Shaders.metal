//
//  Shaders.metal
//  Metal Template
//
//  Real Metal Shading Language (MSL) for this template:
//    - vertex_main / fragment_main: a render pipeline that draws colored
//      geometry with animated uniforms.
//    - compute_main: a compute pipeline that performs a simple parallel
//      transform over a buffer of values.
//
//  These functions are compiled into `default.metallib` and looked up by name
//  at runtime via `device.makeDefaultLibrary()` + `library.makeFunction(name:)`.
//

#include <metal_stdlib>
#include "ShaderTypes.h"

using namespace metal;

// MARK: - Render Pipeline

// Output of the vertex stage / input to the rasterizer.
struct RasterizerData
{
    // [[position]] is required: clip-space position consumed by the rasterizer.
    float4 position [[position]];
    // Interpolated per-fragment color.
    float4 color;
};

// Vertex shader.
//
// Reads from the shared `Vertex` layout (BufferIndexVertices) and per-frame
// `Uniforms` (BufferIndexUniforms). Applies the model-view-projection matrix
// and a small time-based wobble so the template visibly animates.
vertex RasterizerData vertex_main(uint                 vertexID  [[vertex_id]],
                                  constant Vertex     *vertices  [[buffer(BufferIndexVertices)]],
                                  constant Uniforms   &uniforms  [[buffer(BufferIndexUniforms)]])
{
    RasterizerData out;

    Vertex v = vertices[vertexID];

    // Animate the position slightly using uniforms.time. TODO: replace this
    // demo wobble with your own vertex transform.
    float2 animated = v.position;
    animated.x += 0.05 * sin(uniforms.time + v.position.y * 3.0);

    float4 worldPos = float4(animated, 0.0, 1.0);
    out.position = uniforms.modelViewProjection * worldPos;
    out.color    = v.color;

    return out;
}

// Fragment shader.
//
// Outputs the interpolated vertex color. TODO: sample textures, apply lighting,
// or add post effects here.
fragment float4 fragment_main(RasterizerData in [[stage_in]])
{
    return in.color;
}

// MARK: - Compute Pipeline

// A simple parallel transform.
//
// Each thread processes one element of `data`, scaling it by a time factor.
// This demonstrates the compute path (separate from rendering): dispatch a grid
// of threads, each indexed by `thread_position_in_grid`.
//
// TODO: replace with a real workload (image filter, physics step, particle
// update, etc.). Remember to guard against out-of-bounds when the grid size is
// rounded up beyond the buffer length.
kernel void compute_main(device float             *data     [[buffer(BufferIndexCompute)]],
                         constant Uniforms        &uniforms [[buffer(BufferIndexUniforms)]],
                         constant uint            &count    [[buffer(BufferIndexVertices)]],
                         uint                      gid      [[thread_position_in_grid]])
{
    if (gid >= count) {
        return; // Grid was rounded up past the buffer; do nothing.
    }

    float value = data[gid];
    // Example transform: phase-shifted sine modulation per element.
    data[gid] = value * (0.5 + 0.5 * sin(uniforms.time + float(gid)));
}
