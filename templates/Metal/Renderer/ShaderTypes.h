//
//  ShaderTypes.h
//  Metal Template
//
//  Shared CPU/GPU type definitions.
//
//  This header is imported from BOTH:
//    - Metal Shading Language (.metal files), where __METAL_VERSION__ is defined.
//    - Swift, via a bridging header (or C interop), where it is NOT defined.
//
//  Keeping a single source of truth for vertex/uniform layouts and buffer
//  indices guarantees the CPU and GPU agree on memory layout. All shared
//  structs use SIMD types from <simd/simd.h>, which have identical layout on
//  both sides.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
// Metal side: the metal namespace already provides vector/matrix aliases.
// Map the simd vector aliases onto Metal's native types.
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
typedef metal::int32_t EnumBackingType;
#else
// CPU side (Swift / Objective-C / C).
#import <Foundation/Foundation.h>
#import <simd/simd.h>
typedef NSInteger EnumBackingType;
#endif

#include <simd/simd.h>

// MARK: - Buffer Indices
//
// Stable indices used by `setVertexBuffer(_:offset:index:)` on the CPU and
// `[[ buffer(n) ]]` attributes on the GPU. Using a shared enum prevents the
// two sides from drifting out of sync.
typedef NS_ENUM(EnumBackingType, BufferIndex)
{
    BufferIndexVertices = 0,
    BufferIndexUniforms = 1,
    BufferIndexCompute  = 2,
};

// MARK: - Vertex Attribute Indices
//
// Optional: useful if you adopt an MTLVertexDescriptor. Provided here so new
// pipelines have a stable place to add attributes.
typedef NS_ENUM(EnumBackingType, VertexAttribute)
{
    VertexAttributePosition = 0,
    VertexAttributeColor    = 1,
};

// MARK: - Shared Structs

// A single vertex: 2D position in clip space plus an RGBA color.
typedef struct
{
    vector_float2 position;
    vector_float4 color;
} Vertex;

// Per-frame uniforms shared by every draw of a frame.
typedef struct
{
    matrix_float4x4 modelViewProjection;
    float           time;
    // NOTE: keep this struct 16-byte aligned for the GPU. `float time` after a
    // matrix is fine; add padding explicitly if you append more scalars.
} Uniforms;

#endif /* ShaderTypes_h */
