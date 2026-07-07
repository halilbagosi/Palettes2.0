//
//  PaletteShaders.metal
//  Palettes
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Flowing pastel field: domain-warped sines through a cosine palette.
// Premultiplied-alpha output; `intensity` scales overall strength.
[[ stitchable ]] half4 liquidGradient(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float intensity
) {
    float2 uv = position / max(size, float2(1.0, 1.0));
    float t = time * 0.35;

    float2 p = uv * 3.0;
    p.x += sin(p.y * 1.7 + t * 1.3) * 0.6;
    p.y += cos(p.x * 1.4 - t) * 0.6;

    float n1 = sin(p.x + t) * cos(p.y - t * 0.7);
    float n2 = sin((p.x + p.y) * 0.8 + t * 1.6);
    float band = 0.5 + 0.5 * sin(n1 * 2.2 + n2 * 1.8 + t);

    float3 phase = float3(0.00, 0.33, 0.67);
    float3 col = 0.72 + 0.28 * cos(6.28318 * (band + phase + n1 * 0.15));

    float a = clamp(intensity * (0.30 + 0.45 * band), 0.0, 1.0);
    return half4(half3(col) * a, a);
}
