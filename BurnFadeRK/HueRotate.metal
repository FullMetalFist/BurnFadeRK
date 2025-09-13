//
//  HueRotate.metal
//  BurnFadeRK
//
//  Created by Michael Vilabrera on 9/10/25.
//

#include <metal_stdlib>
using namespace metal;

inline float3 rotateHue(float3 color, float hueRotation) {
    const float3 k = float3(0.57735, 0.57735, 0.57735);
    float cosAngle = cos(hueRotation);
    return color * cosAngle + cross(k, color) * sin(hueRotation) + k * dot(k, color) * (1.0 - cosAngle);
}
