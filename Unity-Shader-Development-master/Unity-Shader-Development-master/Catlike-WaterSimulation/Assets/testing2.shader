Shader "Custom/DistortionFlow" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_EmissionMap ("Emission Map", 2D) = "white"{}
		[HDR] _EmissionColor ("Emission Color", Color) = (0,0,0)
		[NoScaleOffset] _FlowMap ("Flow (RG, A noise)", 2D) = "black" {}
		[NoScaleOffset] _DerivHeightMap ("Deriv (AG) Height (B)", 2D) = "black" {}
		_UJump ("U jump per phase", Range(-0.25, 0.25)) = 0.25
		_VJump ("V jump per phase", Range(-0.25, 0.25)) = 0.25
		_Tiling ("Tiling", Float) = 1
		_Speed ("Speed", Float) = 1
		_FlowStrength ("Flow Strength", Float) = 1
		_FlowOffset ("Flow Offset", Float) = 0

		_DissolveScale ("Dissolve Progression", Range(0.0, 1.0)) = 0.0
		_DissolveTex("Dissolve Texture", 2D) = "white" {}
		_GlowIntensity("Glow Intensity", Range(0.0, 5.0)) = 0.05
		_GlowScale("Glow Size", Range(0.0, 5.0)) = 1.0
		_Glow("Glow Color", Color) = (1, 1, 1, 1)
		_GlowEnd("Glow End Color", Color) = (1, 1, 1, 1)
		_GlowColFac("Glow Colorshift", Range(0.01, 2.0)) = 0.75
		_DissolveStart("Dissolve Start Point", Vector) = (1, 1, 1, 1)
		_DissolveEnd("Dissolve End Point", Vector) = (0, 0, 0, 1)
		_DissolveBand("Dissolve Band Size", Float) = 0.25
	}
	SubShader {
		Tags {"Queue"="Transparent"  "RenderType"="Transparent" }
		//LOD 200
		
		ZWrite Off
		//Blend SrcAlpha OneMinusSrcAlpha
		//Cull Off

		CGPROGRAM
		#pragma surface surf Standard alpha:fade vertex:vert nolightmap //noambient nodirlightmap novertexlights
		#pragma target 3.0

		#include "Flow.cginc"

		struct Input {
			float2 uv_MainTex;
			float2 uv_EmissionMap;
			float3 worldNormal;
			float dGeometry;
		};

		sampler2D _MainTex, _FlowMap, _DerivHeightMap;
		float _UJump, _VJump, _Tiling, _Speed, _FlowStrength, _FlowOffset;
		float _HeightScale, _HeightScaleModulated;

		uniform sampler2D _EmissionMap;
		float4 _EmissionColor;

		half _DissolveScale;
		sampler2D _DissolveTex;
		half _GlowIntensity;
		half _GlowScale;
		fixed4 _Glow;
		fixed4 _GlowEnd;
		half _GlowColFac;
		float3 _DissolveStart;
		float3 _DissolveEnd;
		half _DissolveBand;

		

		static float3 dDir = normalize(_DissolveEnd - _DissolveStart);
		static float dMag = length(_DissolveEnd - _DissolveStart);
		static float dAdjust = ( _DissolveBand * clamp(_GlowScale, 1.0, 100.0) - _DissolveBand) / dMag;

		//Convert dissolve progression to new space accounting for band size and glow prediction.
		static half dConverted = _DissolveScale * (1.0f + dAdjust) - dAdjust;

		//Precompute gradient start position.
		static float3 dissolveStartConverted = _DissolveStart - _DissolveBand * dDir;
		static float dBandFactor = 1.0f / _DissolveBand;



		void vert (inout appdata_full v, out Input o) 
		{
			UNITY_INITIALIZE_OUTPUT(Input,o);

			//Calculate geometry-based dissolve coefficient.
			//Compute top of dissolution gradient according to dissolve progression.
			float3 dPoint = lerp(dissolveStartConverted, _DissolveEnd, dConverted);

			//Project vector between current vertex and top of gradient onto dissolve direction.
			//Scale coefficient by band (gradient) size.
			o.dGeometry = dot(v.vertex - dPoint, dDir) * dBandFactor;		
		}
		
		

		//half _Glossiness;
		//half _Metallic;
		fixed4 _Color;
/*
		float3 UnpackDerivativeHeight (float4 textureData) {
			float3 dh = textureData.agb;
			dh.xy = dh.xy * 2 - 1;
			return dh;
		}
*/

		void surf (Input IN, inout SurfaceOutputStandard o) {


						float3 flow = tex2D(_FlowMap, IN.uv_MainTex).rgb;
			flow.xy = flow.xy * 2 - 1;
			flow *= _FlowStrength;
			float noise = tex2D(_FlowMap, IN.uv_MainTex).a;
			float time = _Time.y * _Speed + noise;
			float2 jump = float2(_UJump, _VJump);

			float3 uvwA = FlowUVW(
				IN.uv_MainTex, flow.xy, jump,
				_FlowOffset, _Tiling, time, false
			);
			float3 uvwB = FlowUVW(
				IN.uv_MainTex, flow.xy, jump,
				_FlowOffset, _Tiling, time, true
			);
/*
			float finalHeightScale =
				flow.z * _HeightScaleModulated + _HeightScale;

			float3 dhA =
				UnpackDerivativeHeight(tex2D(_DerivHeightMap, uvwA.xy)) *
				(uvwA.z * finalHeightScale);
			float3 dhB =
				UnpackDerivativeHeight(tex2D(_DerivHeightMap, uvwB.xy)) *
				(uvwB.z * finalHeightScale);
			o.Normal = normalize(float3(-(dhA.xy + dhB.xy), 1));
*/		
			clip(IN.worldNormal.y);
			fixed4 texA = tex2D(_MainTex, uvwA.xy) * uvwA.z;
			fixed4 texB = tex2D(_MainTex, uvwB.xy) * uvwB.z;
			



			//Convert dissolve progression to -1 to 1 scale.
			half dBase = -2.0f * dConverted + 1.0f;

			//fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			fixed4 dTex = tex2D(_DissolveTex, IN.uv_MainTex);

			//Convert dissolve texture sample based on dissolve progression.
			//(Black dissolves first).
			half dTexRead = dTex.r + dBase;

			//Combine texture factor with geometry coefficient from vertex shader.
			half dFinal = dTexRead + IN.dGeometry;

			//Glow is based on "predicting" what will dissolve next.
			//Shift the computed value based on the scale factor of the glow.
			//Scale the shifted value based on effect intensity.
			half dPredict = (_GlowScale - dFinal) * _GlowIntensity;
			//Change colour interpolation by adding in another factor controlling the gradient.
			half dPredictCol = (_GlowScale * _GlowColFac - dFinal) * _GlowIntensity;

			//Calculate and clamp glow colour.
			fixed4 glowCol = dPredict * lerp(_Glow, _GlowEnd, clamp(dPredictCol, 0.0f, 1.0f));
			glowCol = clamp(glowCol, 0.0f, 1.0f);

			//Clamp alpha.
			



						fixed4 c = (texA + texB) * _Color + tex2D(_MainTex, IN.uv_MainTex);
			c.a = c.a + clamp(dFinal, 0.0f, 1.0f);

			o.Albedo = c.rgb + tex2D(_EmissionMap, IN.uv_MainTex) * _EmissionColor + clamp(lerp(c.rgb, glowCol, clamp(dPredict, 0.0f, 1.0f)), 0.0f, 1.0f);
			// o.Albedo = c.rgb 
			//o.Metallic = _Metallic;
			//o.Smoothness = _Glossiness;
			o.Alpha = c.a;
			
		}
		ENDCG
	}
	FallBack "Standard"

}