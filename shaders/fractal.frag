#version 460 core
#include <flutter/runtime_effect.glsl>

// Fractal colour pipeline: log transform -> palette lookup -> brightness
// falloff, all on the GPU. The Rust core supplies only the raw escape-count
// buffer (uploaded as uCounts); this shader turns counts into pixels.
//
// Locked by great-wall-docs/great-wall-ux/TECH_STACK.md
// (Colour pipeline + Brightness modulation). Brightness offset (uBeo) and
// the palette (uPalette) are uniforms, so live adjustment costs nothing per
// frame and never re-runs escape_count.

precision highp float;

uniform vec2 uResolution;    // canvas size in physical px
uniform float uMaxIter;      // iteration cap (matches the core request)
uniform float uFalloffBase;  // brightness falloff base B (= 16)
uniform float uBeo;          // brightness exponent offset (live, tacit)
uniform float uZoom;         // zoom factor (reference / halfExtent)
uniform sampler2D uCounts;   // escape counts, normalised n/maxIter in .r
uniform sampler2D uPalette;  // 256x1 RGBA palette LUT

out vec4 fragColor;

const float kPaletteSize = 256.0;

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float n = texture(uCounts, uv).r * uMaxIter;

    // Fixed log transform -> palette index. Inside-the-set points
    // (n == maxIter) take the last LUT entry; escaping points map
    // log2(1+n)/log2(1+maxIter) across [0, size-2].
    float index;
    if (n >= uMaxIter - 0.5) {
        index = kPaletteSize - 1.0;
    } else {
        float denom = log2(1.0 + uMaxIter);
        float t = denom > 0.0 ? log2(1.0 + n) / denom : 0.0;
        index = floor(clamp(t, 0.0, 1.0) * (kPaletteSize - 2.0) + 0.5);
    }
    vec4 color = texture(uPalette, vec2((index + 0.5) / kPaletteSize, 0.5));

    // Sigmoid "cave-exploration" falloff inherited from great-wall-core:
    //   factor = B / (B + 2^(n - beo) / z^2)
    float factor = uFalloffBase / (uFalloffBase + exp2(n - uBeo) / (uZoom * uZoom));
    color.rgb *= factor;

    fragColor = color;
}
