//
//  NoiseUtilities.metal
//  BurnFadeRK
//
//  Created by Michael Vilabrera on 9/10/25.
//

#include <metal_stdlib>
using namespace metal;

inline float hash(float3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

inline float noise(float3 p) {
    float3 i = floor(p);
    float3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    return mix(mix(mix(hash(i + float3(0,0,0)), hash(i + float3(1,0,0)), f.x),
                   mix(hash(i + float3(0,1,0)), hash(i + float3(1,1,0)), f.x), f.y),
               mix(mix(hash(i + float3(0,0,1)), hash(i + float3(1,0,1)), f.x),
                   mix(hash(i + float3(0,1,1)), hash(i + float3(1,1,1)), f.x), f.y), f.z);
}

inline float fractalNoise(float3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    float maxValue = 0.0;
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        maxValue += amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value / maxValue;
}
