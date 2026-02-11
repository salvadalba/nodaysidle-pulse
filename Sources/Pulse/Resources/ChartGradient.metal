// ChartGradient.metal
// Pulse — animated gradient for chart background (used when built with Xcode).

#include <metal_stdlib>
using namespace metal;

[[ stitchable ]] half4 chartGradient(float2 position, half4 colorA, half4 colorB, float time) {
    float t = 0.5 + 0.5 * sin(time * 0.5);
    return mix(colorA, colorB, half(t));
}
