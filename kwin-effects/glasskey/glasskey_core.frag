#version 140
#include "colormanagement.glsl"
// Glass Key. Works on the window's own (sRGB-encoded) pixels, before colour management.
// ONE key colour (uniform keyContent; keyChrome is unused since v2). The app's theme paints
//   the window (chrome)  = the bare key                      -> alphaChrome, tintChrome
//   panels (content)     = the key + PANEL of the text colour -> alphaContent, tintContent
//   controls, text       = more of the text colour on top     -> towards solid
// Everything on the straight line key -> text is therefore "surface with some ink on it", and alpha and tint are CONTINUOUS
// functions of the position t on that line. (v1 had a second exact key for the chrome. It sat on the content's line, so a
// gradient on a panel passed through it: horizontal lines across large panels.) Pixels off the line (pictures, coloured
// controls) stay opaque.
uniform sampler2D sampler;
uniform vec4 modulation;
uniform vec3 keyContent, keyChrome, keyText, tintContent, tintChrome;
uniform float alphaContent, alphaChrome;
// own shadow for windows without a decoration (see GlassKeyEffect::drawWindow): where the contents sit in this texture
uniform float shadowStrength, contentRadius;
uniform vec2 texSizePx;
uniform vec4 contentPx;
in vec2 texcoord0;
out vec4 fragColor;

const float PANEL = 0.04;

void main()
{
    vec4 tex = texture(sampler, texcoord0);
    vec3 p = tex.a > 0.0 ? tex.rgb / tex.a : tex.rgb;
    vec3 d = keyText - keyContent;
    // HOLE: pure magenta is "nothing here" (an undecorated widget rounds its own corners: magenta page, rounded root on top).
    // The anti-aliased corner pixels are magenta MIXED with the surface. Only scaling their alpha left the magenta in them:
    // a red fringe on every corner. So: estimate the magenta share h, take it out of the colour, and accept that only when
    // what remains is surface (on the key line): a pink pixel of a picture has no surface under it and is left alone.
    const vec3 M = vec3(1.0, 0.0, 1.0);
    float h = clamp((p.r + p.b) * 0.5 - p.g, 0.0, 1.0);
    vec3 pc = (p - h * M) / max(1.0 - h, 0.02);
    float tc = clamp(dot(pc - keyContent, d) / dot(d, d), -0.10, 1.0);
    float tolc = 2.6 / 255.0 + 0.07 * abs(tc) + 0.16 * h;             // the un-mix gets noisier the less surface is left
    float surfaceUnder = 1.0 - smoothstep(tolc, tolc * 2.5 + 0.004, length(pc - (keyContent + tc * d)));
    float holeMix = smoothstep(0.02, 0.06, h) * surfaceUnder;
    float holePure = 1.0 - smoothstep(0.02, 0.12, length(p - M));
    p = mix(p, pc, holeMix);
    float t = clamp(dot(p - keyContent, d) / dot(d, d), -0.10, 1.0);
    float residual = length(p - (keyContent + t * d));
    // a cone: soft shadows (key * (1 - a)) drift off the line as they darken; a tube made contour rings of their 8-bit steps
    float tol = 2.6 / 255.0 + 0.07 * abs(t);
    float onLine = 1.0 - smoothstep(tol, tol * 2.5 + 0.004, residual);

    float panel = smoothstep(0.0, PANEL, t);                          // 0 chrome .. 1 panel
    float ink = smoothstep(PANEL + 0.02, 0.55, t);                    // control fills .. text
    float beyond = clamp(-t * 2.0, 0.0, 0.3);                         // the other side of the key (a shadow in dark, a highlight in light)
    float a = mix(alphaChrome, alphaContent, panel);
    a = mix(a, 1.0, max(ink, beyond));
    vec3 tint = mix(tintChrome, tintContent, panel);
    float tt = clamp((t - PANEL) / (1.0 - PANEL), -0.1, 1.0);
    vec3 col = tint + (keyText - tint) * tt;                          // the surface takes the neutral glass tint, ink keeps its weight

    a = mix(1.0, a, onLine);
    float hole = max(holePure, h * holeMix);
    col = mix(p, col, onLine);
    a *= 1.0 - hole;
    vec4 outc = vec4(col, 1.0) * (a * tex.a);                         // premultiplied, which is what KWin's colour functions expect
    if (shadowStrength > 0.0) {
        // distance to the contents' rounded rectangle, a few pixels lower (light from above); soft, and only what the
        // window itself does not cover
        vec2 px = texcoord0 * texSizePx, half_ = contentPx.zw * 0.5;
        vec2 q = abs(px - (contentPx.xy + half_) - vec2(0.0, 5.0)) - half_ + vec2(contentRadius);
        float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - contentRadius;
        float s = shadowStrength * pow(1.0 - smoothstep(-2.0, 26.0, dist), 2.0);
        outc += vec4(0.0, 0.0, 0.0, s) * (1.0 - outc.a);
    }
    outc = sourceEncodingToNitsInDestinationColorspace(outc);
    outc *= modulation;
    fragColor = nitsToDestinationEncoding(outc);
}
