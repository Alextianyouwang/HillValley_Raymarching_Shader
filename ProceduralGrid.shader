//This shader uses procedural height maps to achieve an raymarched parallex effect and physics based rendering.
//Basic functionality inclued fine tweak the shape of the grid and the graph, procedural color, volume PBR render and raymarch shadows.
//Compatible with Unity 2020 onwards. The shader work best with Unity Defaut Quad. The Displaying screen is XY axis, Depth is Z axis going positive direction.

Shader "AlexWang/ProceduralGrid"{
	Properties {
		[Header(Grid Parameters)]
		[Space][Space]
		_GridChunkColorLow("Grid Chunk Colorramp Low",Color) = (0,0,0,0)
		_GridChunkColorHigh("Grid Chunk Colorramp High",Color) = (0,0,0,0)
		_GridWidth ("Grid Line Width",Range(0,1)) = 0.1
		_GridFrequency("Grid Frequency",Range(1,30)) = 3
		_GridSmooth("Grid Smooth",Range (0,1)) = 0.3
		_GridSeed("Grid Seed",Range (0,1)) =0
		_GridChunkHeightInfluence("Grid Chunk Height Influence",Range(0,1)) = 0.5
		_GridDepth("Grid Depth Multiplier",Range(0,1)) = 0
		_GridOffset("Grid Depth Offset",Range(-1,1)) = 0
		[Header(Graph Parameters)]
		[Space][Space]
		_GraphColor("Graph Color",Color) = (1,1,1,1)
		_GraphFrequency("Grid Frequency",Range(1,10)) = 3
		_GraphAmplitute("Graph Amplitute",Range(0,1)) = 0.5
		_GraphSmooth("Graph Smooth",Range(-3,3)) = 0.5
		_GraphWidth("Graph Width",Range(0,1)) = 0.5
		_GraphXOffset("Graph X Offset",Range(-1,1)) = 0
		_GraphYOffset("Graph Y Offset",Range(-1,1)) = 0
		_GraphDepth("Graph Depth Multiplier",Range(-0.5,1)) = 0
		[Header(Blend Between Grid and Graph)]
		[Space][Space]
		_Blend("Blend Value",Range(0,1)) = 0
		[Header(Animation)]
		[Space][Space]
		_Speed("Animation Speed",Range(0,1)) = 0
		[Header(Surface Options)]
		[Space][Space]
		_Metallic("Metallicness",Range(0,1)) = 0
		_Smoothness("Specular Smoothness",Range(0,1)) = 0
		_EmissionWeight("Emission Weight",Range(0,1)) = 0.3
		_ShadowIntensity("Shadow Intensity",Range(0,1)) = 0
		
		_AOIntensity("AO Intensity",Range(0,1)) = 0
		//_AOColor("AO Color",Color) = (1,1,1,1)

		[Header(Raymarching Options)]
		[Space][Space]
		_SDFMultiplier("SDF Multiplier",Range(0,0.01)) = 0.007
		_AODistance("AO Step Distance Multiplier",Range(0,3)) = 0
		_AOStepNumbers("AO Step Number",Range(1,300)) = 0

		
	}
	SubShader 
	{
		Tags{"RenderPipeline" = "UniversalPipeline"}

		Pass {
			Name "ForwardLit"
			Tags{"LightMode" = "UniversalForward"}

			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag
			#include "Assets/ProceduralGrid.hlsl"
			ENDHLSL
		}
	}
}