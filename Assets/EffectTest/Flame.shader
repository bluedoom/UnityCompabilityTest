Shader "NOAH/Effect/Variant/Flame"
{
    Properties
	{
		// Settings: Cull Depth
		[Enum(UnityEngine.Rendering.CullMode)][Header(Cull Depth)]_Cull("Cull", Float) = 2
		[Toggle]_ZWrite("ZWrite", Float) = 1
		[Enum(UnityEngine.Rendering.CompareFunction)]_ZTest("ZTest", Float) = 4
		[HideInInspector]_ZOffset("ZOffset", Float) = 0
		
		// Settings: Blend
		[Enum(UnityEngine.Rendering.BlendMode)][Header(Blend)]_BlendSrc("Blend Src", Float) = 5
		[Enum(UnityEngine.Rendering.BlendMode)]_BlendDst("Blend Dst", Float) = 10

		// Main Flame Effect 
		/*
		* Step No.1: Differential flow of coordinate values, which can be used to sample flame textures and thus
		* simulate flame wobble.
		*/
		_MainTexTurbulence("Main Tex Turbulence", Float) = 0
		_ParamA("ParamA(SpeedTiling)", Vector) = (0,-0.3,1,1)
		_ParamB("ParamB(SpeedTilling)", Vector) = (0,-0.15,2,2)  // For differential flow of coordinate values
		_FlameDetail("FlameDetail", 2D) = "white" {}
		
		/*
		* Step No.2: This sampling value, combined with a shape mask with a strong bottom and a weak top, can simulates
		* a grayscale flame state. Where our design is that the flame part has a smaller value.
		*/
		_ShapeMask("ShapeMask", 2D) = "white" {}
		_FlameShapeStrength("FlameShapeStrength", Float) = 0.3
		
		/*
		* Step N0.3: When we have a grayscale flame image, use the grading interval so that the stronger part (lower 
		* grayscale value) is the inner flame, the weaker part is the outer flame, and the weakest part is no flame, 
		* this function is implemented using the following parameters.
		*/
		[HDR]_InnerFlameColor("InnerFlameColor", Color) = (1.864072,0.1561526,0,1)
		[HDR]_OutterFlameColor("OutterFlameColor", Color) = (0.9595147,0.2816587,0,1)
		_OutterFlameSize("OutterFlameSize", Float) = 0.3
		_FlameEdgeSize("FlameEdgeSize", Float) = 0.07
		
		// Turbulence
		[KeywordEnum(Off,A,B,Add,Multi)] _EnableTurbulence("Enable Turbulence", Float) = 0
		_TurbulenceATex("TurbulenceA Tex", 2D) = "white" {}
		_TurbulenceAParam("TurbulenceA Param", Vector) = (0,0,1,1)
		_TurbulenceBTex("TurbulenceB Tex", 2D) = "white" {}
		_TurbulenceBParam("TurbulenceB Param", Vector) = (0,0,1,1)
		
		// SubTexture
		_SubTexTurbulence("Sub Tex1 Turbulence", Float) = 0
		_SubTex("Sub Tex1", 2D) = "white" {}
		[KeywordEnum(Off,Add,Multi)] _EnableSubTex("Enable Sub Tex1", Float) = 0

		[KeywordEnum(Off,Add,Multi)] _EnableSubTex2("Enable Sub Tex2", Float) = 0
		_SubTex2Turbulence("Sub Tex2 Turbulence", Float) = 0
		_SubTex2("Sub Tex2", 2D) = "white" {}
		[HDR]_SubTex2TintColor("Sub Tex2 Tint Color", Color) = (1,1,1,1)

		[HDR]_SubTexTintColor("Sub Tex1 Tint Color", Color) = (1,1,1,1)
		
		// Global Mask (Note that this is not the same as the shape mask used by the flame).
		_MaskTexTurbulence("Mask Tex Turbulence", Float) = 0
		[Toggle(_ENABLEMASK_ON)] _EnableMask("Enable Mask", Float) = 0
		_MaskTex("Mask Tex", 2D) = "white" {}
		
		// Dissolve
		/*
		* Similar to the classification of inner and outer flames, here we use three stages of dissolution, dissolved,
		* dissolved, and undissolved, in which we use the dissolved color to mix and interpolate with it to achieve a 
		* gradual dissolution process.
		*/
		_DissolveTexTurbulence("Dissolve Tex Turbulence", Float) = 0
		_DissolveOffset("Dissolve Offset", Vector) = (0,0,0,0)
		_DissolveTex("Dissolve Tex", 2D) = "white" {}
		[Toggle(_ENABLEDISSOLVE_ON)] _EnableDissolve("Enable Dissolve", Float) = 0
		_DissolveRange("Dissolve Range", Range( 0 , 1)) = 0.5294118
		[HDR]_DissolveColor("Dissolve Color", Color) = (0,0,0,0)
		
		// Parameter Control
		[KeywordEnum(Off,A,B,Add,Multi)] _EnableBump1("Enable Bump", Float) = 0
		_BumpATex1("BumpA Tex", 2D) = "white" {}
		_BumpAParam1("BumpA Param", Vector) = (0,0,1,1)
		_BumpBTex1("BumpB Tex", 2D) = "white" {}
		_BumpBParam1("BumpB Param", Vector) = (0,0,1,1)

        [Toggle(_ENABLEMESHPARAM_ON)] _EnableMeshParam("Enable Mesh Param", Float) = 0
		_MeshParamA("Mesh Param A", Vector) = (0,0,0,0)
		_MeshParamB("Mesh Param B", Vector) = (0,0,0,0)

		_Test("Test", Vector) = (0,0,0,0)

	}
    
    SubShader
    {
        LOD 100
		
		Tags { "RenderType"="Transparent" }
		
		Pass
		{

			Blend [_BlendSrc] [_BlendDst]
			AlphaToMask Off
			Cull [_Cull]
			ColorMask RGBA
			ZWrite [_ZWrite]
			ZTest [_ZTest]
			Offset 0 , 0
			

			Name "VFXFlameTransparent"
            HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			
			#pragma multi_compile_instancing
			#pragma multi_compile_local __ _ENABLEMESHPARAM_ON
			// #pragma multi_compile_local _ENABLEBUMP1_OFF _ENABLEBUMP1_A _ENABLEBUMP1_B _ENABLEBUMP1_ADD _ENABLEBUMP1_MULTI

			#pragma multi_compile_local __ _ENABLEDISSOLVE_ON
			// #pragma multi_compile_local _ENABLESUBTEX_OFF _ENABLESUBTEX_ADD _ENABLESUBTEX_MULTI
			// #pragma multi_compile_local _ENABLESUBTEX2_OFF _ENABLESUBTEX2_ADD _ENABLESUBTEX2_MULTI
			#pragma multi_compile_local __ _ENABLEMASK_ON
			// #pragma multi_compile_local _ENABLETURBULENCE_OFF _ENABLETURBULENCE_A _ENABLETURBULENCE_B _ENABLETURBULENCE_ADD _ENABLETURBULENCE_MULTI

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			// #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			CBUFFER_START(UnityPerMaterial)
			float4 _Test;
			// Main Flame Effect
			half4 _BumpATex1_ST;
			half4 _BumpBTex1_ST;
			half4 _BumpAParam1;
			half4 _BumpBParam1;
			half4 _MeshParamA;
			half4 _MeshParamB;
			half4 _ParamA;
			half4 _ParamB;
			half4 _FlameDetail_ST;
			half4 _ShapeMask_ST;
			half4 _DissolveTex_ST;
			half4 _DissolveColor;
			half4 _InnerFlameColor;
			half4 _OutterFlameColor;
			half4 _MaskTex_ST;
			half4 _TurbulenceATex_ST;
			half4 _TurbulenceBTex_ST;
			half4 _TurbulenceAParam;
			half4 _TurbulenceBParam;
			half4 _SubTex_ST;
			half4 _SubTexTintColor;
			half4 _SubTex2_ST;
			half4 _SubTex2TintColor;
			half2 _DissolveOffset;
			half _SubTexTurbulence;
			half _SubTex2Turbulence;
			half _MaskTexTurbulence;			
			half _OutterFlameSize;
			half _FlameEdgeSize;
			half _DissolveRange;
			half _DissolveTexTurbulence;
			half _FlameShapeStrength;
			half _MainTexTurbulence;
			CBUFFER_END

			#include "VFX_Lib.hlsl"

			struct Attributes
			{
				float4 positionOS : POSITION;
				half4 color : COLOR;
				float4 uv1 : TEXCOORD0;
				float4 uv2 : TEXCOORD1;
				half3 normal : NORMAL;
				float4 uv3 : TEXCOORD2;
				float4 uv4 : TEXCOORD3;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float4 color : COLOR;
				
				float4 uv1 : TEXCOORD0;
				float4 uv2 : TEXCOORD1;
				float4 uv3 : TEXCOORD2;
				float4 uv4 : TEXCOORD3;
				float4 uvShapeMask : TEXCOORD4;
				// mask this part
				#ifndef _ENABLETURBULENCE_OFF
				float4 uvTurbulence : TEXCOORD5;
				#endif
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			TEXTURE2D(_MaskTex);			SAMPLER(sampler_MaskTex);
			TEXTURE2D (_TurbulenceATex);	SAMPLER(sampler_TurbulenceATex);
			TEXTURE2D (_TurbulenceBTex);	SAMPLER(sampler_TurbulenceBTex);
			TEXTURE2D (_SubTex);			SAMPLER(sampler_SubTex);
			TEXTURE2D (_SubTex2);			SAMPLER(sampler_SubTex2);
			TEXTURE2D (_DissolveTex);		SAMPLER(sampler_DissolveTex);
			TEXTURE2D (_FlameDetail);		SAMPLER(sampler_FlameDetail);
			TEXTURE2D (_ShapeMask);			SAMPLER(sampler_ShapeMask);
			TEXTURE2D (_BumpATex1);         SAMPLER (sampler_BumpATex1);
			TEXTURE2D (_BumpBTex1);         SAMPLER (sampler_BumpBTex1);

			// Utility Function
			half OneDimensionRemapper(half4 remapper, half value)
			{
				return remapper.z + (value - remapper.x) * (remapper.w - remapper.z) / (remapper.y - remapper.x);
			}

			
			// Turbulence effect processing Split No.1 
			float4 GetTurbulenceUV(float2 uv)
			{
			    float4 uvTurbulence;
							
			    float2 uvTurbulenceA = uv + _Tick * _TurbulenceAParam.xy;
			    uvTurbulenceA = TRANSFORM_TEX(uvTurbulenceA, _TurbulenceATex);
			    uvTurbulence.xy = uvTurbulenceA;
							
			    float2 uvTurbulenceB = ( uv + (_Tick * (_TurbulenceBParam).xy) );
			    uvTurbulenceB = TRANSFORM_TEX(uvTurbulenceB, _TurbulenceBTex);
			    uvTurbulence.zw = uvTurbulenceB;
							
			    return uvTurbulence;
			}

			Varyings vert(Attributes input)
			{
				Varyings output = (Varyings)0;

				// instance
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);

				// create Utility struct
				UVSet uvset = (UVSet)0;
				uvset.uv1 = input.uv1;
				uvset.uv2 = input.uv2;
				uvset.uv3 = input.uv3;
				uvset.uv4 = input.uv4;
				// uvset.meshParamA = _MeshParamA;
				// uvset.meshParamB = _MeshParamB;

				float2 uv1 = GetRealUV1(uvset);
				float2 uv2 = GetRealUV2(uvset);
				float2 uv3 = GetRealUV3(uvset);
				float2 uv4 = GetRealUV4(uvset);
				float2 curve1 = GetCurve1(uvset);
				float2 curve2 = GetCurve2(uvset);
				float2 curve3 = GetCurve3(uvset);
				float2 curve4 = GetCurve4(uvset);
                // bump
			    float2 bumpUV = uv2 + _ModTick * _BumpAParam1.xy;
                half4 bumpCol = SAMPLE_TEXTURE2D_LOD(_BumpATex1, sampler_BumpATex1, bumpUV * _BumpATex1_ST.xy + _BumpATex1_ST.zw,0);
				float bumpValA = (bumpCol.x * 2 - 1) * _BumpAParam1.z;
                
			    bumpUV = uv2 + _ModTick * _BumpBParam1.xy;
                bumpCol = SAMPLE_TEXTURE2D_LOD(_BumpBTex1, sampler_BumpBTex1,bumpUV * _BumpBTex1_ST.xy + _BumpBTex1_ST.zw, 0);
				float bumpValB = (bumpCol.x * 2 - 1) * _BumpBParam1.z;

				float bumpVal = 0;
			    #if defined(_ENABLEBUMP1_A)
				bumpVal = bumpValA;
				#elif defined(_ENABLEBUMP1_B)
				bumpVal = bumpValB;
				#elif defined(_ENABLEBUMP1_ADD)
				bumpVal = (bumpValA + bumpValB);
				#elif defined(_ENABLEBUMP1_MULTI)
				bumpVal = (bumpValA * bumpValB);
				#endif
                float3 finalBump = curve4.x * bumpVal * input.normal;
				// some data transfer
				float3 positionOS = input.positionOS.xyz + finalBump;
				output.positionCS = TransformObjectToHClip(positionOS);
				output.color = input.color;
				// TexCoord data transfer
				output.uv1 = input.uv1;										// TexCoord0
				output.uv2 = input.uv2;										// TexCoord1
				output.uv3 = input.uv3;										// TexCoord2
				output.uv4 = input.uv4;										// TexCoord3
				#ifndef _ENABLETURBULENCE_OFF
				output.uvTurbulence = GetTurbulenceUV(GetRealUV2(uvset));	// TexCoord4
				#endif
				float2 uvShapeMask = TRANSFORM_TEX(uv1 + curve4, _ShapeMask);
				output.uvShapeMask = float4(uvShapeMask, 0, 0);				// TexCoord5
				return output;
			}
half4 frag(Varyings input) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(input);

				// Setting the uvset
				UVSet uvset = (UVSet)0;
				uvset.uv1 = input.uv1;
				uvset.uv2 = input.uv2;
				uvset.uv3 = input.uv3;
				uvset.uv4 = input.uv4;
				// uvset.meshParamA = _MeshParamA;
				// uvset.meshParamB = _MeshParamB;
				float2 uv1 = GetRealUV1(uvset);
            	float2 uv2 = GetRealUV2(uvset);
            	float2 uv3 = GetRealUV3(uvset);
            	float2 uv4 = GetRealUV4(uvset);
            	float2 curve1 = GetCurve1(uvset);
            	float2 curve2 = GetCurve2(uvset);
            	float2 curve3 = GetCurve3(uvset);
            	float2 curve4 = GetCurve4(uvset);
				
				// bump
				float2 turbulenceValue = float2(1.0, 1.0);
				#ifndef _ENABLETURBULENCE_OFF
					turbulenceValue = Turbulence(
					input.uvTurbulence.xy, input.uvTurbulence.zw,
					TEXTURE2D_ARGS(_TurbulenceATex, sampler_TurbulenceATex),
					TEXTURE2D_ARGS(_TurbulenceBTex, sampler_TurbulenceBTex),
					_TurbulenceAParam, _TurbulenceBParam);
				#endif


				// Get uvMainTexture
				float2 uvMainTex = uv1 + curve1 + _MainTexTurbulence * turbulenceValue;
				// Bug Report: _Tick * 
				float2 uvMainTexA = TRANSFORM_TEX(_Tick * float2(_ParamA.xy) + float2(_ParamA.zw) * uvMainTex, _FlameDetail);
				float2 uvMainTexB = TRANSFORM_TEX(_Tick * float2(_ParamB.xy) + float2(_ParamB.zw) * uvMainTex, _FlameDetail);

				// Main flame logic
				float4 flameDetailColorA = SAMPLE_TEXTURE2D(_FlameDetail, sampler_FlameDetail, uvMainTexA);
				float4 flameDetailColorB = SAMPLE_TEXTURE2D(_FlameDetail, sampler_FlameDetail, uvMainTexB);
				float4 shapeMaskColor = SAMPLE_TEXTURE2D(_ShapeMask, sampler_ShapeMask, input.uvShapeMask.xy);
				float differentialTexture = flameDetailColorA.r * flameDetailColorB.r +
					shapeMaskColor.r * (_FlameShapeStrength + curve3.x) ;
				// When flame value is smaller than outer flame edge, flame is visible, else is invisible
				half flameAlpha = smoothstep(_OutterFlameSize, _OutterFlameSize - 0.01,differentialTexture);
				// When flame value is smaller than inner flame edge, color reference is innerFlameColor, else is outerFlameColor.
				half outerFlameStart = smoothstep(_OutterFlameSize + curve1.y - _FlameEdgeSize,  _OutterFlameSize + curve1.y - _FlameEdgeSize - 0.005, differentialTexture);
				half4 flameColorReference = lerp(_OutterFlameColor, outerFlameStart * _InnerFlameColor, outerFlameStart);

				// Get final color
				half4 finalColor = half4(1.0, 1.0, 1.0, flameAlpha) * input.color * flameColorReference;
				#ifdef _ENABLESPLITALPHA_ON
				finalColor.a =  1 ;
				#endif
				#if _ENABLECLIP_ON
				clip(finalColor.a -  0 );
				#endif
				return finalColor;
			}
			ENDHLSL
		}
    }
	CustomEditor "NOAH.EditorExtends.GroupedShaderGUI"
}
			
			

			


