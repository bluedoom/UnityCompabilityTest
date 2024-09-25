// Pcx - Point cloud importer & renderer for Unity
// https://github.com/keijiro/Pcx

Shader "Point Cloud/Point"
{
    Properties
    {
        [HDR]_Tint("Tint", Color) = (0.5, 0.5, 0.5, 1)
        _BackAlpha("Back Alpha", Range(0.05,1)) = 0.05
        [HDR]_FresnelColor("Fresnel Color", Color) = (1, 1, 1, 0.05)
        _FresnelBase("Fresnel Base", Range(0,1)) = 0
        _FresnelStrength("Fresnel Strength", Range(0,4)) = 0
        [KeywordEnum(Transparent, Back, Off)]CULLMODE("Cull Mode",Float)= 0
        _PointSize("Point Size", Range(0.001,1)) = 0.05
        _NoiseTex("Noise", 2D) = "gray"{}
        _NoiseScale("Noise Scale", Range(0,99)) = 0
        _TimeScale("Time Scale", Range(0,3)) = 1
        _NoiseParam("Noise Param",Vector)=(1,1,1,0)
        _Cliper("Cliper",Vector) = (1000,1000,1000,1)
        // _Explode("Explode", Float) = 0
        [Toggle(_AUDIO_WAVE)]_AudioWave("Audio Wave", Float) = 0
        _AudioWaveStrength("Audio Wave Strength", Float) = 1
        _AudioWaveNoise("Audio Wave Noise", Float) = 0

    }


    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent"}

        Pass
        {

            Cull Off
            ColorMask RGBA
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite OFF
            ZTest LEqual
            CGPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma multi_compile_fog
            #pragma multi_compile _ UNITY_COLORSPACE_GAMMA
            #pragma multi_compile _ _COMPUTE_BUFFER
            #pragma multi_compile_local _ ANIM_BOOM
            #pragma multi_compile_local _ CULLMODE_BACK CULLMODE_OFF CULLMODE_TRANSPARENT
            #pragma multi_compile_local _ _AUDIO_WAVE

            #include "PointCloud.hlsl"

            // #if defined(SHADER_API_GLES) || defined(SHADER_API_GLES3) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL)
            //     #pragma require mrt999
            // #else
            #define GEOMETRY_SHADER 1
            #pragma geometry Geometry
            // #endif

            struct v2g
            {
                float4 position : SV_Position;
                half4 color : COLOR;
                float dot: NORMAL;
            };

            struct v2f
            {
                float4 position : SV_Position;
                half4 color : COLOR;
            };
            #define Varyings v2g

            // Geometry phase
            [maxvertexcount(16)]
            void Geometry(point v2g input[1], inout TriangleStream<Varyings> outStream)
            {
                // float3 normal = input[0].normal;
                // Copy the basic information.
                Varyings o = input[0];
                float dirDot = input[0].dot;
                #if CULLMODE_BACK
                    if(dirDot < 0 ) return;
                #endif
                #if !CULLMODE_TRANSPARENT 
                    o.color.a = dirDot;
                #else
                    o.color.a = (dirDot + 1)/2;
                #endif
                o.color.r = dirDot;
                // o.color.a *= (dirDot);
                // o.color = ((o.position / o.position.w) + 1)/ 2;
                // o.color = (input[0].dot.xyzz + 1) /2;
                // o.color.a =1;
                float4 origin = o.position;
                float2 extent = abs(UNITY_MATRIX_P._11_22 * (_PointSize * 0.4));
                // Determine the number of slices based on the radius of the
                // point on the screen.
                float radius = extent.y / origin.w * _ScreenParams.y;
                uint slices = min((radius + 1) / 5, 4) + 2;
                // Slightly enlarge quad points to compensate area reduction.
                // Hopefully this line would be complied without branch.
                if (slices == 2) extent *= 1.2;

                // Top vertex
                o.position.y = origin.y + extent.y;
                o.position.xzw = origin.xzw;
                outStream.Append(o);

                UNITY_LOOP for (uint i = 1; i < slices; i++)
                {
                    float sn, cs;
                    sincos(UNITY_PI / slices * i, sn, cs);

                    // Right side vertex
                    o.position.xy = origin.xy + extent * float2(sn, cs);
                    outStream.Append(o);

                    // Left side vertex
                    o.position.x = origin.x - extent.x * sn;
                    outStream.Append(o);
                }

                // Bottom vertex
                o.position.x = origin.x;
                o.position.y = origin.y - extent.y;
                outStream.Append(o);

                outStream.RestartStrip();
            }

            Varyings Vertex(AttrRaw i)
            {
                Attr input = VtxOffset(i);
                float3 pos = input.position;
                half3 col = input.color;

            #ifdef UNITY_COLORSPACE_GAMMA
                col *= _Tint.rgb;
            #else
                col *= LinearToGammaSpace(_Tint.rgb);
                col = GammaToLinearSpace(col);
            #endif
                Varyings o;
                float4 hcPos = UnityObjectToClipPos(pos);
                o.position = hcPos;
                // Compute screen pos 
                // float4 screenPos = ComputeScreenPos(hcPos);
                // screenPos /= screenPos.w;

                // half offset = tex2Dlod(_WaveTex, float4(screenPos.x,0,0,0)).r;
                // o.position = hcPos - float4(0,offset,0,0) * hcPos.w;

                // float len = length(input.position);
                // float3 n = (input.position)/len;
                // o.position.xyz += n * lerp(len, 5, _Explode * offset) ;

                o.color = half4(col,1);
                float3 worldNormal = UnityObjectToWorldNormal(input.normal);
                float3 normal = mul(worldNormal,(float3x3) UNITY_MATRIX_V);
                float3 vPos = normalize(-UnityObjectToViewPos(pos));
                float dirDot = dot(vPos, normal);
                #if CULLMODE_OFF
                    dirDot = abs(dirDot);
                #endif
                o.dot = dirDot; //float4(normalize(-UnityObjectToViewPos(pos)).xyz, 1);
                // o.dot = dirDot;
                return o;
            }

            half4 Fragment(v2f input) : SV_Target
            {
                half4 c = _Tint;
                c.a = lerp(_BackAlpha , c.a, input.color.a);
                half fresnel = pow(input.color.a,_FresnelStrength);
                c = lerp(_FresnelColor, c, saturate(-_FresnelBase + fresnel));
                // UNITY_APPLY_FOG(input.fogCoord, c);
                return c;
            }

            ENDCG
        }
    }
    SubShader{
         Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline"  }

        Pass
        {
            Tags { "LightMode" = "SRPUnlit" }
            Cull Off
            ColorMask RGBA
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite OFF
            ZTest LEqual
            CGPROGRAM

            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma multi_compile_fog
            #pragma multi_compile _ UNITY_COLORSPACE_GAMMA
            #pragma multi_compile _ _COMPUTE_BUFFER
            #pragma multi_compile_local _ ANIM_BOOM
            #pragma multi_compile_local _ CULLMODE_BACK CULLMODE_OFF CULLMODE_TRANSPARENT
            #pragma multi_compile_local _ _AUDIO_WAVE
            #include "PointCloud.hlsl"

            struct v2f
            {
                float4 position : SV_Position;
                half4 color : COLOR;
                float dot : NORMAL;
                float psize : PSIZE;
            };
            

            v2f Vertex(AttrRaw i)
            {
                Attr input = VtxOffset(i);
                float3 pos = input.position;
                half3 col = input.color;

                #ifdef UNITY_COLORSPACE_GAMMA
                    col *= _Tint.rgb;
                #else
                    col *= LinearToGammaSpace(_Tint.rgb);
                    col = GammaToLinearSpace(col);
                #endif
                v2f o;
                float4 hcPos = UnityObjectToClipPos(pos);
                o.position = hcPos;

                float3 worldNormal = UnityObjectToWorldNormal(input.normal);
                float3 normal = mul(worldNormal,(float3x3) UNITY_MATRIX_V);
                float3 vPos = normalize(-UnityObjectToViewPos(pos));
                float dirDot = dot(vPos, normal);
                #if CULLMODE_OFF
                    dirDot = abs(dirDot);
                #endif
                o.dot = dirDot;
                o.psize = _PointSize / o.position.w * _ScreenParams.y;
                o.color = half4(col,1);
                #if CULLMODE_BACK
                    if(dirDot < 0 ) o.color.a = 0;
                #endif
                #if !CULLMODE_TRANSPARENT 
                    o.color.a = dirDot;
                #else
                    o.color.a = (dirDot + 1)/2;
                #endif
                o.color.a = o.color.a * saturate(o.psize);
                return o;
            }

            half4 Fragment(v2f input) : SV_Target
            {
                if(input.color.a <= 0) discard;
                half4 c = _Tint;
                c.a = lerp(_BackAlpha , c.a, input.color.a);
                half fresnel = pow(input.color.a,_FresnelStrength);
                c = lerp(_FresnelColor, c, saturate(-_FresnelBase + fresnel));
                return c;
            }

            ENDCG
        }
    }
}
