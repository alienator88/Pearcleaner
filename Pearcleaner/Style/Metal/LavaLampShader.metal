//
//  LavaLampShader.metal
//  Playground
//
//  Created by Alin Lupascu on 3/26/25.
//

#include <metal_stdlib>
using namespace metal;

float metaball(float2 p, float2 center, float radius) {
    float2 diff = p - center;
    return radius * radius / dot(diff, diff);
}

vertex float4 vertex_passthrough(uint vertexID [[vertex_id]]) {
    float2 positions[6] = {
        {-1.0, -1.0}, {1.0, -1.0}, {-1.0, 1.0},
        {-1.0, 1.0}, {1.0, -1.0}, {1.0, 1.0}
    };
    return float4(positions[vertexID], 0.0, 1.0);
}

fragment float4 lavaLampFrag(float4 fragCoord [[position]],
                             constant float2 *centers [[buffer(0)]],
                             constant float *radii [[buffer(1)]],
                             constant uint &count [[buffer(2)]],
                             constant float &time [[buffer(3)]],
                             constant float2 &resolution [[buffer(4)]]) {
    float2 uv = fragCoord.xy / resolution;
    float intensity = 0.0;
    float3 color = float3(0.0);

    for (uint i = 0; i < count; ++i) {
        float2 animated = centers[i] + 0.25 * float2(sin(time * 0.6 + float(i) * 1.7), cos(time * 0.4 + float(i) * 1.3));
        float radius = radii[i] * (2.0 + 0.5 * sin(time + float(i) * 2.17)); // larger size
        float contrib = metaball(uv, animated, radius);
        if (i % 3 == 0) {
            color += contrib * float3(1.0, 0.4, 0.7) * 0.5; // pink (dimmed)
        } else if (i % 3 == 1) {
            color += contrib * float3(1.0, 0.6, 0.2) * 0.5; // orange (dimmed)
        } else {
            color += contrib * float3(0.4, 0.5, 1.0) * 0.5; // purple-blue (dimmed)
        }
        intensity += contrib;
    }

    float threshold = 1.0;
    return float4(smoothstep(threshold - 0.3, threshold + 0.3, intensity) * color, 1.0);
}
