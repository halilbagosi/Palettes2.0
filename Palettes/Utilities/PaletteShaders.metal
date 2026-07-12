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

// Glass rim refraction: content under the orb's interior is left untouched
// and bends only in a band near the rim, like the edge of a clear lens.
// The bump returns to zero at the boundary so there is no seam.
[[ stitchable ]] float2 lensWarp(
    float2 position,
    float2 center,
    float radius,
    float strength
) {
    float2 d = position - center;
    float dist = length(d);
    if (dist >= radius || radius <= 0.0) { return position; }
    float q = dist / radius;
    float w = smoothstep(0.95, 1.0, q);
    float mag = 1.0 + strength * w;
    return center + d / mag;
}

// Living orb interior: a flowing fluid blend of the palette colors that have
// arrived so far, over an iridescent "thinking" field. `touch` (normalized)
// and `touchStrength` swirl the fluid around the finger; per-color alpha
// controls how far each color has bloomed into the mix.
[[ stitchable ]] half4 orbFlow(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float2 touch,
    float touchStrength,
    device const half4 *colors,
    int count
) {
    float2 uv = position / max(size, float2(1.0, 1.0));
    float t = time * 0.4;

    // Domain-warped flow field
    float2 p = uv * 3.2;
    p.x += sin(p.y * 1.8 + t * 1.3) * 0.55;
    p.y += cos(p.x * 1.5 - t) * 0.55;

    // Touch swirl: rotate the field around the touch point, falling off with distance
    float2 toTouch = uv - touch;
    float swirl = touchStrength * exp(-dot(toTouch, toTouch) * 7.0);
    p += swirl * 5.0 * float2(-toTouch.y, toTouch.x);

    // Iridescent base field (pre-color "thinking" state)
    float band = 0.5 + 0.5 * sin(sin(p.x + t) * 2.1 + cos(p.y - t * 0.8) * 1.9 + t);
    float3 base = 0.74 + 0.26 * cos(6.28318 * (band + float3(0.0, 0.33, 0.67)));

    // Blend arrived palette colors as drifting soft blobs
    float3 acc = float3(0.0);
    float wsum = 0.0;
    float presence = 0.0;
    for (int i = 0; i < count; i++) {
        float fi = float(i);
        float2 c = 0.5 + 0.36 * float2(
            sin(t * 0.9 + fi * 2.399),
            cos(t * 0.7 + fi * 1.716 + 1.3)
        );
        float d = length(uv - c) + 0.12 * sin(p.x + p.y + fi * 2.0);
        float w = float(colors[i].a) / (0.06 + d * d * 5.0);
        acc += float3(colors[i].rgb) * w;
        wsum += w;
        presence = max(presence, float(colors[i].a));
    }

    float3 col = base;
    if (wsum > 1e-4) {
        col = mix(base, acc / wsum, clamp(presence, 0.0, 1.0));
    }

    // Gentle inner shading so the disc reads as a sphere
    float2 fromCenter = uv - 0.5;
    float r = length(fromCenter) * 2.0;
    col *= 1.0 - 0.22 * smoothstep(0.55, 1.0, r);

    half a = color.a;
    return half4(half3(col) * a, a);
}
