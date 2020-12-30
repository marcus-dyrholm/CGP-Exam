// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "CGP/Testing"
{
    Properties{
        _Tess ("Tessalation", Range(0,8)) = 4
        _MainTex ("Texture", 2D) = "white"{}
        _MainColor("Color", Color) = (1,1,1,1)
        _EmissionMap ("Emission Map", 2D) = "black" {}
        [HDR] _EmissionColor ("Emission Color", Color) = (0,0,0)
    }

    // no Properties block this time!
    SubShader
    {
        Tags{"Queue"="Transparent"}
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        //  Cull Off
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // include file that contains UnityObjectToWorldNormal helper function
            #include "UnityCG.cginc"

            

            uniform sampler2D _MainTex;
            uniform float4 _MainTex_ST;
            
            float4 _MainColor;

            uniform sampler2D _EmissionMap;
            float4 _EmissionColor;

            struct vertexInput 
            {
                float4 texcoord : TEXCOORD1;
            };

            struct v2f {
                float4 tex : TEXCOORD1;
                // we'll output world space normal as one of regular ("texcoord") interpolators
                half3 worldNormal : TEXCOORD0;
                float4 pos : SV_POSITION;
                half2 uv : TEXCOORD2;
            };

            // vertex shader: takes object space normal as input too
            v2f vert (float4 vertex : POSITION, float3 normal : NORMAL, vertexInput vert)
            {
                
                v2f o;
                o.tex= vert.texcoord;
                o.pos = UnityObjectToClipPos(vertex);
                // UnityCG.cginc file contains function to transform
                // normal from object to world space, use that
                o.worldNormal = UnityObjectToWorldNormal(normal);
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
               //fixed4 c = 0;
                fixed4 albedo = tex2D(_EmissionMap,i.uv) * _MainColor;
                clip(i.worldNormal.y);
                // normal is a 3D vector with xyz components; in -1..1
                // range. To display it as color, bring the range into 0..1
                // and put into red, green, blue components
                //c.rgb = i.worldNormal*0.5+0.5;
                //return c;
                return albedo + tex2D(_MainTex, _MainTex_ST.xy * i.tex.xy + _MainTex_ST.zw) * _EmissionColor;
            }
            ENDCG
        }
    }
}
