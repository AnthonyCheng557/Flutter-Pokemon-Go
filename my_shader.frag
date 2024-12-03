#version 460 core
#include <flutter/runtime_effect.glsl>


// Inputs
uniform vec2 uSize;
uniform vec4 uColor;
uniform float uTime;
// Outputs
out vec4 fragColor;

void main() {
    vec2 pixel = FlutterFragCoord() / uSize;
    vec4 white = vec4(1.0);

    float t = sin(uTime * 5);

    float random = mix(pixel.y, pixel.x, step(0.0, t));

    fragColor = mix(uColor, white, random);
}

