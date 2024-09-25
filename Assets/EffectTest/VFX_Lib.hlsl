#ifndef VFX_LIB_INCLUDED
#define VFX_LIB_INCLUDED

#ifdef _ENABLEDEPTHFADE_ON
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#endif
CBUFFER_START(NOAHGlobal)
float _Tick;
float _ModTick;
CBUFFER_END

struct UVSet
{
    float4 uv1;
    float4 uv2;
    float4 uv3;
    float4 uv4;
    // half4 meshParamA;
    // half4 meshParamB;
};

//_ENABLEMESHPARAM_ON
float2 GetRealUV1(UVSet uvset)
{
    return uvset.uv1.xy;
}
float2 GetRealUV2(UVSet uvset)
{
    #ifdef _ENABLEMESHPARAM_ON
        return uvset.uv2.xy;
    #else
        return uvset.uv1.zw;
    #endif
}
float2 GetRealUV3(UVSet uvset)
{
    #ifdef _ENABLEMESHPARAM_ON
        return uvset.uv3.xy;
    #else
        return uvset.uv2.xy;
    #endif
}
float2 GetRealUV4(UVSet uvset)
{
    #ifdef _ENABLEMESHPARAM_ON
    return uvset.uv4.xy;
    #else
    return uvset.uv2.zw;
    #endif
}
float2 GetCurve1(UVSet uvset)
{
    #ifdef _ENABLEMESHPARAM_ON
        return _MeshParamA.xy;
    #else
        return uvset.uv3.xy;
    #endif
}
float2 GetCurve2(UVSet uvset)
{
    #ifdef _ENABLEMESHPARAM_ON
    return _MeshParamA.zw;
    #else
    return uvset.uv3.zw;
    #endif
}
float2 GetCurve3(UVSet uvset)
{
    #ifdef _ENABLEMESHPARAM_ON
    return _MeshParamB.xy;
    #else
    return uvset.uv4.xy;
    #endif
}
float2 GetCurve4(UVSet uvset)
{
    #ifdef _ENABLEMESHPARAM_ON
    return _MeshParamB.zw;
    #else
    return uvset.uv4.zw;
    #endif
}

//_ENABLEBUMP_A _ENABLEBUMP_B _ENABLEBUMP_ADD _ENABLEBUMP_MULTI
half3 Bump(half2 uv, half intensity, half3 vertexNormal, TEXTURE2D_PARAM(BumpA,samplerBumpA), half4 BumpA_ST, TEXTURE2D_PARAM(BumpB,samplerBumpB), half4 BumpB_ST,
    half4 bumpAParam, half4 bumpBParam, float tick)
{
    half bumpValue = 0;
    float2 uvA = uv + tick * bumpAParam.xy;
    float2 uvB = uv + tick * bumpBParam.xy;
    half bumpValueA = SAMPLE_TEXTURE2D_LOD(BumpA, samplerBumpA, uvA*BumpA_ST.xy + BumpA_ST.zw,0).r;
    half bumpValueB = SAMPLE_TEXTURE2D_LOD(BumpB, samplerBumpB, uvB*BumpB_ST.xy + BumpB_ST.zw,0).r;
    bumpValueA = (bumpValueA * 2 - 1) * bumpAParam.z;
    bumpValueB = (bumpValueB * 2 - 1) * bumpAParam.z;
    #ifdef _ENABLEBUMP_A
    bumpValue = bumpValueA;
    #elif _ENABLEBUMP_B
    bumpValue = bumpValueB;
    #elif _ENABLEBUMP_ADD
    bumpValue = bumpValueA + bumpValueB;
    #elif _ENABLEBUMP_MULTI
    bumpValue = bumpValueA * bumpValueB;
    #endif
    half3 vertexOffset = vertexNormal * bumpValue * intensity;
    return vertexOffset;
}



float2 Turbulence(float2 uvA,float2 uvB,
    TEXTURE2D_PARAM(TurATex,samplerTurATex), TEXTURE2D_PARAM(TurBTex, samplerTurBTex),
    half4 turAParam, half4 turBParam)
{
    half2 turbulenceValue = 0;
    half2 turbulenceValueA = SAMPLE_TEXTURE2D(TurATex, samplerTurATex, uvA).r * turAParam.zw;
    half2 turbulenceValueB = SAMPLE_TEXTURE2D(TurBTex, samplerTurBTex, uvB).r * turBParam.zw;
    #ifdef _ENABLETURBULENCE_A
        turbulenceValue = turbulenceValueA;
    #elif _ENABLETURBULENCE_B
        turbulenceValue = turbulenceValueB;
    #elif _ENABLETURBULENCE_ADD
        turbulenceValue = turbulenceValueA + turbulenceValueB;
    #elif _ENABLETURBULENCE_MULTI
        turbulenceValue = turbulenceValueA * turbulenceValueB;
    #endif
    return turbulenceValue;
}

half3 GetViewDirTS(half3 viewDirWS, half3 normalWS, half4 tangentWS)
{
    half3 bitangentWS = cross( normalWS, tangentWS.xyz ) * tangentWS.w;
    half3 tanToWorld0 = float3( tangentWS.x, bitangentWS.x, normalWS.x );
    half3 tanToWorld1 = float3( tangentWS.y, bitangentWS.y, normalWS.y );
    half3 tanToWorld2 = float3( tangentWS.z, bitangentWS.z, normalWS.z );
    half3 viewDirTS =  tanToWorld0 * viewDirWS.x + tanToWorld1 * viewDirWS.y  + tanToWorld2 * viewDirWS.z;
    viewDirTS = normalize(viewDirTS);
    return viewDirTS;
}

half2 ParallaxUVMapping(half2 uv, half height, half scale, half3 viewDirTS)
{
    return uv + (height-1)* viewDirTS.xy * scale;
}

half4 Dissolve(half dissolveValue, half threshold, half range, half4 dissolveColor)
{
    half value =  saturate((dissolveValue - threshold)/range);
    half4 dissolveResult = half4((1-value) * dissolveColor.rgb,dissolveColor.a * value);
    return dissolveResult;
}


half4 BlendSub2Color(half4 colorA, half4 colorB, half alpha)
{
    half blendAlpha = colorA.a * colorB.a * alpha;
    half4 offResult = half4(colorA.rgb, colorA.a * alpha);
    half4 addResult = half4(colorA.rgb + colorB.rgb, blendAlpha);
    half4 mulResult = half4(colorA.rgb * colorB.rgb, blendAlpha);
    
    #if defined(_ENABLESUBTEX2_OFF)
    half4 result = offResult;
    #elif defined(_ENABLESUBTEX2_ADD)
    half4 result = addResult;
    #elif defined(_ENABLESUBTEX2_MULTI)
    half4 result = mulResult;
    #else
    half4 result = offResult;
    #endif
    
    return result;
}

half4 BlendSubColor(half4 colorA, half4 colorB, half alpha)
{
    half blendAlpha = colorA.a * colorB.a * alpha;
    half4 offResult = half4(colorA.rgb, colorA.a * alpha);
    half4 addResult = half4(colorA.rgb + colorB.rgb, blendAlpha);
    half4 mulResult = half4(colorA.rgb * colorB.rgb, blendAlpha);
    
    #if defined(_ENABLESUBTEX_OFF)
    half4 result = offResult;
    #elif defined(_ENABLESUBTEX_ADD)
    half4 result = addResult;
    #elif defined(_ENABLESUBTEX_MULTI)
    half4 result = mulResult;
    #else
    half4 result = offResult;
    #endif
    
    return result;
}

half Fresnel(half3 normalWS, half3 viweDirWS, half scale, half power )
{
    half fresnelNdotV = saturate(dot( normalWS, viweDirWS ));
    half fresnel = scale * pow( 1.0 - fresnelNdotV, power ) ;
    #ifdef _FRESNELINVERT_ON
        return saturate(1-fresnel); 
    #else
        return fresnel;
    #endif
}
#if _ENABLEDEPTHFADE_ON
half DepthFade(half4 positionSS, half distance, half power)
{
    float4 normalizedSS = positionSS / positionSS.w;
    normalizedSS.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? normalizedSS.z : normalizedSS.z * 0.5 + 0.5;
    float screenDepth = LinearEyeDepth(SampleSceneDepth( normalizedSS.xy ),_ZBufferParams);
    float distanceDepth = abs( ( screenDepth - LinearEyeDepth( normalizedSS.z,_ZBufferParams ) ) /  distance  );
    distanceDepth = saturate( distanceDepth );
    #ifdef _DEPTHFADEINVERT_ON
        distanceDepth =  ( 1.0 - distanceDepth );
    #endif
    return pow( distanceDepth , power);
}
#endif
inline half UnityGet2DClipping (in float2 position, in float4 clipRect)
{
    half2 inside = step(clipRect.xy, position.xy) * step(position.xy, clipRect.zw);
    return inside.x * inside.y;
}

float2 POM(TEXTURE2D(_ParallaxTex),SAMPLER(sampler_ParallaxTex),
	float2 uvs, float2 dx, float2 dy, float3 normalWorld, float3 viewWorld,
	float3 viewDirTan, int minSamples, int maxSamples, float parallax, float refPlane)
{
	float3 result = 0;
	int stepIndex = 0;
	int numSteps = ( int )lerp( (float)maxSamples, (float)minSamples, saturate( dot( normalWorld, viewWorld ) ) );
	float layerHeight = 1.0 / numSteps;
	float2 plane = parallax * ( viewDirTan.xy / viewDirTan.z );
	uvs.xy += refPlane * plane;
	float2 deltaTex = -plane * layerHeight;
	float2 prevTexOffset = 0;
	float prevRayZ = 1.0f;
	float prevHeight = 0.0f;
	float2 currTexOffset = deltaTex;
	float currRayZ = 1.0f - layerHeight;
	float currHeight = 0.0f;
	float intersection = 0;
	float2 finalTexOffset = 0;
	while ( stepIndex < numSteps + 1 )
	{
		currHeight = SAMPLE_TEXTURE2D_GRAD( _ParallaxTex, sampler_ParallaxTex, uvs + currTexOffset, dx, dy ).r;
		if ( currHeight > currRayZ )
		{
			stepIndex = numSteps + 1;
		}
		else
		{
			stepIndex++;
			prevTexOffset = currTexOffset;
			prevRayZ = currRayZ;
			prevHeight = currHeight;
			currTexOffset += deltaTex;
			currRayZ -= layerHeight;
		}
	}
	int sectionSteps = 8;
	int sectionIndex = 0;
	float newZ = 0;
	float newHeight = 0;
	
	intersection = ( prevHeight - prevRayZ ) / ( prevHeight - currHeight + currRayZ - prevRayZ );
	finalTexOffset = prevTexOffset + intersection * deltaTex;
	
	while ( sectionIndex < sectionSteps )
	{
		intersection = ( prevHeight - prevRayZ ) / ( prevHeight - currHeight + currRayZ - prevRayZ );
		finalTexOffset = prevTexOffset + intersection * deltaTex;
		newZ = prevRayZ - intersection * layerHeight;
		newHeight = SAMPLE_TEXTURE2D_GRAD( _ParallaxTex, sampler_ParallaxTex, uvs + currTexOffset, dx, dy ).r;
		if ( newHeight > newZ )
		{
			currTexOffset = finalTexOffset;
			currHeight = newHeight;
			currRayZ = newZ;
			deltaTex = intersection * deltaTex;
			layerHeight = intersection * layerHeight;
		}
		else
		{
			prevTexOffset = finalTexOffset;
			prevHeight = newHeight;
			prevRayZ = newZ;
			deltaTex = ( 1 - intersection ) * deltaTex;
			layerHeight = ( 1 - intersection ) * layerHeight;
		}
		sectionIndex++;
	}
	return uvs.xy + finalTexOffset;
}
#endif

