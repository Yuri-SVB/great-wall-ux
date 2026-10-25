#version 460 core
#include <flutter/runtime_effect.glsl>

// Fractal colour pipeline: palette lookup (the hue, or black inside the set)
// -> brightness falloff, all on the GPU. The Rust core supplies only the raw
// escape-count buffer (uploaded as uCounts); this shader turns counts into
// pixels.
//
// Locked by great-wall-docs/great-wall-ux/TECH_STACK.md
// (Colour pipeline + Brightness modulation). Brightness offset (uBeo), slope
// (uSlope) and the palette (uPalette) are uniforms, so live adjustment costs
// nothing per frame and never re-runs escape_count.

precision highp float;

uniform vec2 uResolution;    // canvas size in physical px
uniform float uMaxIter;      // iteration cap (matches the core request)
uniform float uFalloffBase;  // brightness falloff base B (= 16)
uniform float uBeo;          // brightness exponent offset (live, tacit)
uniform float uZoom;         // zoom factor (reference / halfExtent)
uniform float uSlope;        // brightness falloff slope s (live, tacit; 1 = original)
uniform sampler2D uCounts;   // exact escape counts: high byte in .r, low in .g
uniform sampler2D uPalette;  // 256x1 RGBA palette LUT

out vec4 fragColor;

const float kPaletteSize = 256.0;
const float kChannelMax = 255.0;   // a channel's largest byte
const float kHighByteWeight = 256.0;

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    // 16-bit count, sampled nearest (interpolating the bytes separately would
    // not interpolate the count). Rounded: r and g are bytes / 255.
    vec4 texel = texture(uCounts, uv);
    float n = floor(kChannelMax * (kHighByteWeight * texel.r + texel.g) + 0.5);

    // Palette: inside-the-set points (n == maxIter) take the last LUT entry
    // (black); every escaping point takes the hue at full brightness (entry 0;
    // all escaping entries are equal). Brightness is the falloff's alone, so a
    // higher count is never brighter.
    float index = n >= uMaxIter - 0.5 ? kPaletteSize - 1.0 : 0.0;
    vec4 color = texture(uPalette, vec2((index + 0.5) / kPaletteSize, 0.5));

    // Sigmoid "cave-exploration" falloff inherited from great-wall-core,
    //   factor = B / (B + 2^(n - beo) / z^2) = 1 / (1 + 2^(n - h)),
    // half brightness at h = beo + log2(B) + 2 log2(z), with a slope s:
    //   factor = 1 / (1 + 2^((n - h) / s)).
    // s = 1 is the original curve; a larger s spreads the falloff over more
    // escape counts (more intermediate shades), a smaller one sharpens it.
    // h does not depend on s, so the half-brightness point stays put.
    float h = uBeo + log2(uFalloffBase) + 2.0 * log2(uZoom);
    float factor = 1.0 / (1.0 + exp2((n - h) / uSlope));
    color.rgb *= factor;

    fragColor = color;
}
