//
//  BurnFadeVertices.metal
//  BurnFadeRK
//
//  Created by Michael Vilabrera on 9/10/25.
//

#include <metal_stdlib>
using namespace metal;

#include "HueRotate.metal"
#include "NoiseUtilities.metal"
#include "VertexDataWith4ChannelColor.h"
#include "BurnFadeParams.h"

kernel void BurnFadeVertices(device const VertexDataWith4ChannelColor* inputVertices [[buffer(0)]],
                             device VertexDataWith4ChannelColor* outputVertices [[buffer(1)]],
                             constant BurnFadeParams& params [[buffer(2)]],
                             uint vid [[thread_position_in_grid]])
{
    VertexDataWith4ChannelColor inputVertex = inputVertices[vid];
    VertexDataWith4ChannelColor outputVertex = inputVertex;
    
    float3 scaledPosition = inputVertex.position * params.scale;
    
    float primaryNoise = fractalNoise(scaledPosition);
    float secondaryNoise = fractalNoise(scaledPosition * 2.3 + float3(100.0, 50.0, 75.0));
    float detailNoise = noise(scaledPosition * 12.0);
    
    float burnPriority = primaryNoise * 0.6 + secondaryNoise * 0.3 + detailNoise * 0.1;
    
    float effectiveBurnAmount = params.progress;
    
    float burnDistance = burnPriority - effectiveBurnAmount;
    
    float edgeWidth = params.edgeWidth;
    float alpha = smoothstep(-edgeWidth, edgeWidth, burnDistance);
    
    float emberIntensity = 0.0;
    float emberRange = params.emberRange;
    
    if (burnDistance > -emberRange && burnDistance < emberRange) {
        float distanceFromEdge = abs(burnDistance);
        emberIntensity = 1.0 - (distanceFromEdge / emberRange);
        emberIntensity = smoothstep(0.0, 1.0, emberIntensity);
        
        float emberFlicker = noise(scaledPosition * 25.0 + float3(params.progress * 10.0, 0.0, 0.0));
        emberIntensity *= 0.7 + 0.3 * emberFlicker;
    }
    
    float3 originalColor = float3(inputVertex.color.x, inputVertex.color.y, inputVertex.color.z);
    float3 emberColor = float3(1.0, 0.4, 0.1);
    float3 fireColor = float3(1.0, 0.2, 0.0);
    float3 hotColor = float3(1.0, 0.8, 0.2);
    
    float3 burnColor;
    if(emberIntensity < 0.3) {
        burnColor = mix(emberColor, fireColor, emberIntensity / 0.3);
    } else if (emberIntensity < 0.7) {
        burnColor = mix(fireColor, hotColor, (emberIntensity - 0.3) / 0.4);
    } else {
        burnColor = hotColor;
    }
    
    burnColor = rotateHue(burnColor, params.hueRotate);
    
    float3 finalColor = mix(originalColor, burnColor, emberIntensity);
    
    finalColor += emberIntensity * emberIntensity * float3(0.2, 0.2, 0.2);
    
    alpha = clamp(alpha, 0.0, 1.0);
    
    outputVertex.color.rgb = finalColor;
    outputVertex.color.w = alpha;
    outputVertices[vid] = outputVertex;
}
