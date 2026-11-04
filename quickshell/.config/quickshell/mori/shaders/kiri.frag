#version 440
// Kiri (霧): the lock screen's fog. The screenshot blurs into its own colours
// while soft rounded boxes grow out of it and drift into place. `progress`
// runs 0 → 1 on lock and 1 → 0 on unlock; everything is a function of it.
// Compile: qsb --glsl "300 es,330" --hlsl 50 --msl 12 -o kiri.frag.qsb kiri.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;   // 0 = sharp screenshot, 1 = settled fog
    float seed;       // new box layout per lock
    float aspect;     // width / height
    float maxLod;     // mip levels of the screenshot
    float arcs;       // 1: boxes travel on arcs, 0: straight lines
};
layout(binding = 1) uniform sampler2D source;

const int BOXES = 6;

// PCG-style integer hash → [0, 1)
uint pcg(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}
float rand(uint a, uint b) {
    return float(pcg(a * 9781u + pcg(b + uint(seed * 4096.0)))) / 4294967296.0;
}

// Signed distance to a rounded box centred at the origin.
float roundedBox(vec2 p, vec2 extent, float radius) {
    vec2 q = abs(p) - extent + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float phase(float from, float to) { return smoothstep(from, to, progress); }

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = vec2(uv.x * aspect, uv.y);

    float blurLod = mix(0.0, maxLod - 1.5, phase(0.0, 0.55));
    vec3 photo = textureLod(source, uv, blurLod).rgb;
    vec3 base = textureLod(source, vec2(0.5), maxLod).rgb;
    vec3 colour = mix(photo, base, phase(0.05, 0.7));

    float grow = phase(0.04, 0.5);
    float travel = phase(0.0, 0.9);
    float softness = mix(0.004, 0.09, phase(0.1, 0.7));
    vec3 boxColour = vec3(0.0);
    float weight = 0.0;
    float cover = 0.0;
    for (int i = 0; i < BOXES; ++i) {
        uint id = uint(i);
        vec2 start = vec2(0.12 + 0.76 * rand(id, 1u), 0.12 + 0.76 * rand(id, 2u));
        vec2 goal = vec2(0.1 + 0.8 * rand(id, 3u), 0.1 + 0.8 * rand(id, 4u));
        // Colour of the screen where the box grows from.
        vec3 tint = textureLod(source, start, maxLod - 3.0).rgb;
        vec2 a = vec2(start.x * aspect, start.y), b = vec2(goal.x * aspect, goal.y);
        vec2 mid = (a + b) * 0.5;
        vec2 side = vec2(-(b - a).y, (b - a).x) * (rand(id, 5u) < 0.5 ? 0.5 : -0.5);
        vec2 straight = mix(a, b, travel);
        vec2 curved = mix(mix(a, mid + side, travel), mix(mid + side, b, travel), travel);
        vec2 centre = mix(straight, curved, arcs);
        vec2 extent = mix(vec2(0.012), vec2(0.13 + 0.12 * rand(id, 6u), 0.1 + 0.1 * rand(id, 7u)), grow);
        float d = roundedBox(p - centre, extent, min(extent.x, extent.y) * 0.22);
        float a_i = (1.0 - smoothstep(-softness, softness, d)) * phase(0.04, 0.3);
        boxColour += tint * a_i;
        weight += a_i;
        cover = 1.0 - (1.0 - cover) * (1.0 - a_i * 0.92);
    }
    if (weight > 0.0)
        colour = mix(colour, boxColour / weight, cover);

    // Fine grain, settling in with the fog.
    float grain = float(pcg(uint(gl_FragCoord.x) * 1973u + pcg(uint(gl_FragCoord.y) + 9277u))) / 4294967296.0;
    colour += (grain - 0.5) * 0.06 * phase(0.0, 0.45);

    fragColor = vec4(colour, 1.0) * qt_Opacity;
}
