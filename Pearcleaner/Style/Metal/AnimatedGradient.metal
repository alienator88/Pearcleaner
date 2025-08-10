//
//  AnimatedGradient.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/3/25.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };

    float2 uvs[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0, 1);
    out.uv = uvs[vertexID];
    return out;
}

struct GradientParams {
    float time;
    float direction;
    uint colorCount;
};

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant GradientParams& params [[buffer(0)]],
                              constant float4* colors [[buffer(1)]]) {
    float t;
    if (params.direction == 0.0) {
        t = sin(params.time + in.uv.y * 3.14) * 0.5 + 0.5;
    } else if (params.direction == 1.0) {
        t = sin(params.time + (1.0 - in.uv.x) * 3.14) * 0.5 + 0.5;
    } else {
        float2 center = float2(0.5, 0.5);
        float dist = distance(in.uv, center);
        t = sin(params.time + dist * 6.28) * 0.5 + 0.5;
    }

    if (params.colorCount == 0) return float4(0, 0, 0, 1);
    if (params.colorCount == 1) return colors[0];

    float segment = 1.0 / float(params.colorCount - 1);
    uint idx = min(uint(t / segment), params.colorCount - 2);
    float localT = (t - float(idx) * segment) / segment;

    return mix(colors[idx], colors[idx + 1], localT);
}
