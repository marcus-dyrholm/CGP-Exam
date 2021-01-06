Shader "Custom/FlowingHologram" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_EmissionMap ("Emission Map", 2D) = "white"{}
		[HDR] _EmissionColor ("Emission Color", Color) = (0,0,0)
		[NoScaleOffset] _FlowMap ("Flow (RG, A noise)", 2D) = "black" {}
		_UJump ("U jump per phase", Range(-0.25, 0.25)) = 0.25
		_VJump ("V jump per phase", Range(-0.25, 0.25)) = 0.25
		_Tiling ("Tiling", Float) = 1
		_Speed ("Speed", Float) = 1
		_FlowStrength ("Flow Strength", Float) = 1
		_FlowOffset ("Flow Offset", Float) = 0

	}
	SubShader {
		Tags {"Queue"="Transparent"  "RenderType"="Transparent" }

		CGPROGRAM
		#pragma surface surf Standard alpha:fade nolightmap 
		#pragma target 3.0

		#include "Flow.cginc"

		sampler2D _MainTex, _FlowMap, _EmissionMap, _DerivHeightMap;
		float _UJump, _VJump, _Tiling, _Speed, _FlowStrength, _FlowOffset;
		float _HeightScale, _HeightScaleModulated;

		float4 _EmissionColor;


		struct Input {
			float2 uv_MainTex;
			float2 uv_EmissionMap;
			float3 worldNormal;
			float3 viewDir;
			INTERNAL_DATA
		};
		
		fixed4 _Color;

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

			clip(IN.worldNormal.y);
			fixed4 texA = tex2D(_MainTex, uvwA.xy) * uvwA.z;
			fixed4 texB = tex2D(_MainTex, uvwB.xy) * uvwB.z;
			
			fixed4 c = (texA + texB) * _Color;
			o.Albedo = c.rgb + tex2D(_EmissionMap, IN.uv_MainTex) * _EmissionColor;
			o.Alpha = c.a;
			
		}
		ENDCG
	}
	FallBack "Standard"

}