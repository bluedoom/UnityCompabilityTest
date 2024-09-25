#include "UnityCG.cginc"
// Pcx - Point cloud importer & renderer for Unity
// https://github.com/keijiro/Pcx

#define PCX_MAX_BRIGHTNESS 16

uint PcxEncodeColor(half3 rgb)
{
    half y = max(max(rgb.r, rgb.g), rgb.b);
    y = clamp(ceil(y * 255 / PCX_MAX_BRIGHTNESS), 1, 255);
    rgb *= 255 * 255 / (y * PCX_MAX_BRIGHTNESS);
    uint4 i = half4(rgb, y);
    return i.x | (i.y << 8) | (i.z << 16) | (i.w << 24);
}

half3 PcxDecodeColor(uint data)
{
    half r = (data) & 0xff;
    half g = (data >> 8) & 0xff;
    half b = (data >> 16) & 0xff;
    half a = (data >> 24) & 0xff;
    return half3(r, g, b) * a * PCX_MAX_BRIGHTNESS / (255 * 255);
}

// #include "Assets/Rendering/Include/Core.hlsl"
sampler2D _NoiseTex;
sampler2D _WaveTex;

float _AnimParam;
float _ModTick;
float _NoiseScale;
float _TimeScale;
float4 _NoiseParam;
float4 _Cliper;
// float _Explode;
float _AudioWaveNoise;
float _AudioWaveStrength;
half4 _Tint;
half4 _FresnelColor;
half _PointSize;
half _FresnelStrength;
half _FresnelBase;
half _BackAlpha;
float4x4 _Transform;
struct AttrRaw
{
    float4 position : POSITION;
    half2 normal: NORMAL;
    half3 color : COLOR;
    uint idx:SV_VertexID;
};

struct Attr
{
    float3 position : POSITION;
    float3 normal: NORMAL;
    half3 color : COLOR;
    uint idx:SV_VertexID;
};

float4 ApplyWave(float4 clipPos)
{
    // half offset = tex2Dlod(_WaveTex, float4(clipPos.x/clipPos.w,0,0,0)).r;
    // clipPos.y += offset * 15;
    return clipPos;
}

Attr VtxOffset(in AttrRaw i)
{
    Attr o;
    float waveNoise = 0;
    float yOffset = 0;
    o.position = i.position.xyz;
    o.idx = i.idx;
    o.color = i.color;
    #if _AUDIO_WAVE
        half wave = tex2Dlod(_WaveTex, float4( (o.position.x + 1)/ 2,0,0,0)).r;
        waveNoise = wave * _AudioWaveNoise;
        yOffset = _AudioWaveStrength * wave;
    #endif
    float3 seed = (o.position) * _NoiseParam;
    float u = (seed.x+seed.y+seed.z) + (_ModTick % 100) * _TimeScale;
    half3 offset = tex2Dlod(_NoiseTex, float4(u, i.idx % 3.14159267, 0, 0)).rgb - (0.5).xxx;
    o.position.y += yOffset;
    o.position += offset *(_NoiseScale + waveNoise);
    o.normal = half3(i.position.w, i.normal.xy);
    return o;
}
