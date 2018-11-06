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
    float4 light;
};

struct ShapeVertex {
    packed_float4 position;
    packed_float4 normal;
    packed_float4 color;
};

struct VertexIn {
    packed_float3 position;
    packed_float2 texCoord;
};

struct VertexOut {
    float4 position [[position]];
    float4 normal;
    float2 texCoord;
    float4 color;
    unsigned int vid;
};

struct FragmentOut {
    float4 texColor [[ color(0) ]];
};

vertex VertexOut shape_vertex(const device ShapeVertex* vertex_array [[ buffer(0) ]],
                              const device State& state [[ buffer(1) ]],
                              unsigned int vid [[ vertex_id ]]) {
    VertexOut vout;

    vout.position = state.projectionMatrix * float4(vertex_array[vid].position);
    vout.normal = state.projectionMatrix * float4(vertex_array[vid].normal);
    vout.color = vertex_array[vid].color;
    
    vout.vid = vid;
    return vout;
}

fragment half4 shape_fragment(VertexOut vert [[ stage_in ]],
                              const device State& state [[ buffer(0) ]]) {
    float4 n = vert.normal;
    float4 c = vert.color;
    float4 light = state.light;
    float intensity = n.x * light.x + n.y * light.y + n.z * light.z;

    return half4(intensity * c + float4(0.2, 0.235, 0.36, 1.0));
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
