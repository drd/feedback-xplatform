#include <metal_stdlib>
using namespace metal;

struct State {
    packed_float2 outputSize;
    packed_float2 position;
    float zoom;
    float rotation;
    float time;
    float aspectRatio;
    float colorOffset;
    float nonlinearity;
    float4x4 projectionMatrix;
    //    Light light;
};

struct ShapeVertex {
    packed_float3 position;
};

struct VertexIn {
    packed_float3 position;
    packed_float2 texCoord;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    half4 color;
    unsigned int vid;
};

struct FragmentOut {
    float4 texColor [[ color(0) ]];
};

vertex VertexOut shape_vertex(const device ShapeVertex* vertex_array [[ buffer(0) ]],
                              const device State& state [[ buffer(1) ]],
                              unsigned int vid [[ vertex_id ]]) {
    float time = state.time;
    VertexOut vout;
//    float3 anchor = vertex_array[vid - vid % 3].position;
//    float3 vert = vertex_array[vid].position - anchor;
//
//    float rotation = state.rotation;
//    float x = vert.x * cos(rotation) - vert.y * sin(rotation);
//    float y = vert.x * sin(rotation) + vert.y * cos(rotation);
//    vert = float3(x, y, vert.z) + anchor;
//
//    float scale = cos(sin(time * 1.13)) * 0.9 + 1.1;
//    float3 offset = float3(0, 0, 0);
//    vout.position = state.projectionMatrix * float4(vert * scale + offset, 1.0);

    time = state.time + vid / 13.0 + state.colorOffset;
    //    float4 pos = vert.position;
    
    float r = .4 * (sin(time/1.3 - 1.2) + 1) / 2 + (sin(time / 317 ) - cos(time / 3 / 153) / 2) / 2.7;
    float g = .6 * (sin(time/1.7 + 2.3) + 1) / 2 + abs(cos(sin(time) / 209 + cos(time / 2 ))) / 2.9;
    float b = .7 * (sin(time/2.1 + 1.1) + 1) / 2 + + (cos(time / 100 - time / 31 + sin(time  * 17))) / 2.3;
    float a = (1 - cos(time / 69 + sin(time / 29))) / 3 + .3;

    vout.color = half4(half3(r, g, b) + (sin(time * 3.12) + 0.7) * 0.4, a);
    
    vout.position = float4(vertex_array[vid].position, 1);
    vout.vid = vid;
    return vout;
}

fragment half4 shape_fragment(VertexOut vert [[ stage_in ]],
                              const device State& state [[ buffer(0) ]]) {
//    float time = state.time + vert.vid / 13.0 + state.colorOffset;
    //    float4 pos = vert.position;
//
//    float r = .4 * (sin(time/1.3 - 1.2) + 1) / 2 + (sin(time / 317 ) - cos(time / 3 / 153) / 2) / 2.7;
//    float g = .6 * (sin(time/1.7 + 2.3) + 1) / 2 + abs(cos(sin(time) / 209 + cos(time / 2 ))) / 2.9;
//    float b = .7 * (sin(time/2.1 + 1.1) + 1) / 2 + + (cos(time / 100 - time / 31 + sin(time  * 17))) / 2.3;
//    float a = (1 - cos(time / 69 + sin(time / 29))) / 3 + .3;
//    return half4(half3(r, g, b) + (sin(time * 3.12) + 0.7) * 0.4, a);
    return vert.color;
}

vertex VertexOut texture_vertex(const device VertexIn* vertex_array [[ buffer(0) ]],
                                const device State& state [[ buffer(1) ]],
                                unsigned int vid [[ vertex_id ]]) {
    VertexOut out;
    VertexIn vert = vertex_array[vid];
    float3 pos = vert.position;
    out.position = float4(pos, 1.0);
    
    float2 tc = (vert.texCoord - float2(0.5, 0.5)) * state.zoom;
    float rotation = state.rotation;
    float x = tc.x * cos(rotation) - tc.y * sin(rotation);
    float y = tc.x * sin(rotation) + tc.y * cos(rotation);
    
    out.texCoord = float2(x, y) + state.position + float2(0.5, 0.5);
    return out;
}

fragment FragmentOut texture_fragment(VertexOut          interpolated   [[ stage_in ]],
                                      const device       State& state   [[ buffer(0) ]],
                                      texture2d<float>   tex2d          [[ texture(0) ]],
                                      sampler            sampler2d      [[ sampler(0) ]]) {
    FragmentOut out;
    float t = state.time;
    float2 tc = interpolated.texCoord; // - 0.5;
    //    float2 modifier = state.nonlinearity * float2(
    //         (sin((tc.y - .5) * 8.1 + t/1.7 - state.rotation / 3.9) * .31 + .23 *  cos((tc.x - .5) * 4.9 - t/1.3 + state.rotation / 2.9 )) / 31,
    //         (sin((tc.x - .5) * 7.3 - t/1.3 - state.rotation / 2.7) + cos((tc.y -.5) * 5.3 + t/1.7 + state.rotation / 2.9)) / 31);
    
    float2 modifier = state.nonlinearity * float2(tc.x * tc.x,
                                                  (tc.y * tc.y));
    
    out.texColor = tex2d.sample(sampler2d, tc);
    return out;
}

vertex VertexOut feedback_vertex(const device VertexIn* vertex_array [[ buffer(0) ]],
                                 const device State& state [[ buffer(1) ]],
                                 unsigned int vid [[ vertex_id ]]) {
    VertexOut out;
    VertexIn vert = vertex_array[vid];
    float3 pos = vert.position;
    float2 tc = vert.texCoord;
    out.position = float4(pos, 1.0);
    out.texCoord = tc;
    return out;
}

vertex VertexOut final_vertex(const device VertexIn* vertex_array [[ buffer(0) ]],
                              const device State& state [[ buffer(1) ]],
                              unsigned int vid [[ vertex_id ]]) {
    VertexOut out;
    VertexIn vert = vertex_array[vid];
    float3 pos = vert.position;
    float2 tc = vert.texCoord;
    if (state.aspectRatio > 1) {
        tc.y = (tc.y - .5) / state.aspectRatio + 0.5;
    } else if (state.aspectRatio < 1) {
        tc.x = (tc.x - .5) * state.aspectRatio + 0.5;
    }
    out.position = float4(pos, 1.0);
    out.texCoord = tc;
    return out;
}

fragment FragmentOut final_fragment(VertexOut          interpolated   [[ stage_in ]],
                                    texture2d<float>   tex2d          [[ texture(0) ]],
                                    sampler            sampler2d      [[ sampler(0) ]]) {
    FragmentOut out;
    out.texColor = tex2d.sample(sampler2d, interpolated.texCoord);
    return out;
}
