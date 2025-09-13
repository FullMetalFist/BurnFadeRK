//
//  VertexDataWith4ChannelColor.h
//  BurnFadeRK
//
//  Created by Michael Vilabrera on 9/10/25.
//

#include <simd/simd.h>

#ifndef VertexDataWith4ChannelColor_h
#define VertexDataWith4ChannelColor_h

struct VertexDataWith4ChannelColor {
    simd_float3 position;
    simd_float3 normal;
    simd_float2 uv;
    simd_float4 color;
};

#endif /* VertexDataWith4ChannelColor_h */
