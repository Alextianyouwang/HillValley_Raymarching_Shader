#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/Utility.hlsl"
#define MIN 0.0000001
#define NORMAL_EPSILON 0.005
#define RAY_MARCH_MAX_STEP 400
#define RAY_MARCH_SURFACE_HIT 0.001
#define RAY_MARCH_MAX_DISTANCE 4

float4 _ColorMap_ST,_ColorTint,_GridChunkColorLow,_GridChunkColorHigh,_GridColor,_GraphColor,_AOColor ;
float _GridFrequency,_GridWidth,_GridSmooth,_GridDepth,_GridSeed,_GridChunkHeightInfluence,_GridOffset,
_GraphFrequency,_GraphAmplitute,_GraphXOffset,_GraphYOffset,_GraphSmooth,_GraphWidth,_GraphDepth,
_Blend,_Speed,
_Smoothness,_Metallic,_ShadowIntensity,_EmissionWeight,
_AOStepNumbers,_AODistance,_SDFMultiplier,_AOIntensity;

//Main graph of the scenery, given a position in Object Space will return 0-1.
float Graph(float3 posOS){
    //Make sure this value not fall equal to 0 preventing artifact.
    _GraphSmooth=_GraphSmooth == 0?MIN:_GraphSmooth;
    _GraphAmplitute=_GraphAmplitute == 0?MIN:_GraphAmplitute;
    //The repeating grayscale goes alone X axis in the form of sin wave. Amplitute, frequency and offset are implemented here.
    float grayscale = sin(((posOS.x+_Time.y*_Speed)*_GraphFrequency*PI+_GraphXOffset*PI));
    //Object space Y should reach infinity to introduce a virtually straight line that goes along X, thus inverse relation.
    float inversedAmplitute = 2/_GraphAmplitute;
    //Storing some info for Y to be reused later, offsets are applied.
    float thresholdUp = (posOS.y+_GraphYOffset/2-_GraphWidth/2);
    float thresholdLow = (posOS.y+_GraphYOffset/2+_GraphWidth/2);
    //Apply the smooth edge offset before multiply with the amplitute to make sure the smooth edge value does not scale.
    //Reverse smooth edge to make sure it work with both positive and negative value.
    half graphUpperEdge=smoothstep(thresholdUp*inversedAmplitute,(thresholdUp-_GraphSmooth)*inversedAmplitute,grayscale);
    graphUpperEdge = _GraphSmooth>0?1-graphUpperEdge:graphUpperEdge;
    half graphLowerEdge=smoothstep(thresholdLow*inversedAmplitute,(thresholdLow+_GraphSmooth)*inversedAmplitute,grayscale);
    graphLowerEdge = _GraphSmooth>0?1-graphLowerEdge:graphLowerEdge;
    float remaped = remap(0,1,0,_GraphDepth, (graphUpperEdge * graphLowerEdge) );
    return remaped;
}
//Parts assembling the main grid of the scenery, given a position in Object Space will return 0-1.
float Stripe(float dimension){
    //Multiply the object position by several factor and keep only the decimal to create a patterned UV.
    float edgeOne = smoothstep (_GridSmooth,_GridWidth/2, frac((dimension*_GridFrequency)));
    float edgeTwo = smoothstep (_GridSmooth,_GridWidth/2,1-frac((dimension*_GridFrequency)));
    return 1 - edgeOne * edgeTwo;
}
float Chunk(float3 posOS){
   //Have a scaled position map subtract the decimal generated a low resolution UV pattern for noise implementation.
   float3 pieces = (posOS * _GridFrequency- frac(posOS * _GridFrequency))/_GridFrequency;    
   //Sample the noise with this large UV chunk will provide a randomized greyscale checker map.
   float randPieces = noise((pieces.xy+10)*10+float2 (_Time.y*_Speed,0),_GridSeed*10000);
   randPieces = lerp(0,randPieces,_GridChunkHeightInfluence);
   return randPieces;
}
float Grid(float3 posOS){
    //Combine the grid in both X and Y axis to generate a grid. Z is omitted for now.
    float gridX = Stripe(posOS.x);
    float gridY = Stripe(posOS.y);
    float gridZ = Stripe(posOS.z);
    float grid = max(gridX, gridY);
    float remaped = remap(0,1,0,_GridDepth, grid + Chunk(posOS));
    return remaped;
}
//Scenery SDFs, the multiplier for distance is needed to boost precision when rendering objects with steep slope.
//Height map generated from pervious functions may have abrupt value change. Have to use tiny steps to achieve good results.
//This is the middle place between a fixed-steped raymarch and SDF-steped raymarch.
float GridSDF(float3 pos){
    //This "1" is an arbitrary offset since different ray marching steps will generate different depth in this situation.
    float distance = pos.z + _GridOffset- Grid(pos)-1;
    return -distance;//multiplier
}
float GraphSDF(float3 pos){
    float distance = pos.z - Graph(pos);
    return -distance;
}
float CombinedSDF(float3 pos){
    //Lerping the distance value between the two SDFs, have tried smoothedMin for some morphing but it does not work well with height maps.
    float distance = lerp(GridSDF(pos),GraphSDF(pos),_Blend);
    return distance *_SDFMultiplier;
}
//Return the normal of a fragment given its sampled position.
half3 GetNormal(float3 pos, int world){
	float changeX = CombinedSDF(pos + float3(NORMAL_EPSILON, 0, 0)) - CombinedSDF(pos - float3(NORMAL_EPSILON, 0, 0));
	float changeY = CombinedSDF(pos + float3(0, NORMAL_EPSILON, 0)) - CombinedSDF(pos - float3(0, NORMAL_EPSILON, 0));
	float changeZ = CombinedSDF(pos + float3(0, 0, NORMAL_EPSILON)) - CombinedSDF(pos - float3(0, 0, NORMAL_EPSILON));
	float3 surfaceNormal = float3(changeX, changeY, changeZ);
	float3 worldNormal = mul(unity_ObjectToWorld, float4(surfaceNormal, 0)).xyz;
    //URP lighting input needs world space normal, object space normal is also useful for creating offsets, so keep both of them.
	return world == 1? normalize(worldNormal):normalize(surfaceNormal);
}
//Return the position of SDF hit by a ray cast from a start position and direction foreach fragment.
//It is later reused to calculate shadow, as a ray shooted from a point of the scene to the direction of light,
//a target hit indicates it is inside shadow, the returned vector3 subtract its original position will be reletively short, and vise versa.
//So use the invert of the length of this value clamped from 0-1 could be a decent represenation of a shadowmask.
float3 Raymarch(float3 rayOrigin, float3 rayDirection) 
{
    float marchDistanceCombined = 0;
    float3 samplePointCombined = 0;
    for (int i = 0; i< RAY_MARCH_MAX_STEP; i++)
    {
        float pos = CombinedSDF(samplePointCombined);
        samplePointCombined = rayOrigin + rayDirection*marchDistanceCombined;
        marchDistanceCombined += pos;
        if (pos <= RAY_MARCH_SURFACE_HIT || marchDistanceCombined > RAY_MARCH_MAX_DISTANCE)
        {
            return samplePointCombined;
        }
    }
    return samplePointCombined;
}
half AO(float3 rayOrigin, float3 rayDirection) 
{
    float marchDistanceCombined = 0;
    for (int i = 0; i< _AOStepNumbers; i++)
    {
        float pos = CombinedSDF(rayOrigin + rayDirection * marchDistanceCombined * _AODistance);
         if (pos <= RAY_MARCH_SURFACE_HIT || marchDistanceCombined > RAY_MARCH_MAX_DISTANCE)
        {
            break;
        }
        marchDistanceCombined += pos;
    }
    return lerp(1,clamp(0,1,marchDistanceCombined), _AOIntensity) ;
}
half4 GetColor (float3 samplePoint) {
    half4 gridRamp = lerp(_GridChunkColorLow,_GridChunkColorHigh,1- Grid( samplePoint));
    half4 coloredGrid =  gridRamp;
    half4 coloredGraph = abs(Graph(samplePoint))* _GraphColor ;
    half4 proceduralColor = coloredGraph + coloredGrid;
    return proceduralColor;
}
struct Attributes{
    float3 positionOS : POSITION;     
    float2 uv : TEXCOORD0;
};

struct Interpolators{
    float4 positionCS : SV_POSITION;
    float3 positionOS : TEXCOORD1;
    float3 positionWS : TEXCOORD2;
    float3 viewDirectionOS :TEXCOORD5;
    float3 cameraDirectionWS :TEXCOORD6;
    float2 uv : TEXCOORD0;  
};

Interpolators Vert(Attributes input){
    Interpolators output;
    VertexPositionInputs posInputs = GetVertexPositionInputs (input.positionOS);
    output.positionOS = input.positionOS;
    output.positionCS = posInputs.positionCS;
    output.positionWS = posInputs.positionWS;
    output.uv = TRANSFORM_TEX(input.uv,_ColorMap);
    output.cameraDirectionWS =_WorldSpaceCameraPos - output.positionWS ;
    float3 objectSpaceCameraPos = mul (unity_WorldToObject,float4 (_WorldSpaceCameraPos,1)).xyz;
    output.viewDirectionOS = output.positionOS - objectSpaceCameraPos;
    return output;
};

half4 Frag(Interpolators input): SV_TARGET {
    float2 uv = input.uv;
    float3 posOS = input.positionOS;
    float4 posCS = input.positionCS;
    float3 posWS = input.positionWS;
    float3 viewDirectionOS = normalize (input.viewDirectionOS);
    float3 viewDirectionWS = normalize (input.cameraDirectionWS);
    _GridSmooth = remap(0,1,0,_GridWidth/2,1-_GridSmooth);

    // Calculate and dispatch procedural colors based on sampled SDF positions and color ramps.
    float3 samplePoint = Raymarch(posOS,viewDirectionOS);
   

    // Get Main Light source for its direction to calculate shadow.
    Light mainLight = GetMainLight();
    float3 mainLightDirection = mainLight.direction;
    // Set a skin offset of the shadow marcher start position, as its previous value would instantly hit the surface and kick out of the loop.
    // Translate the mainLight direction from world space to object space as its march direction.

    half3 shadow = 1;
    if (_ShadowIntensity != 0)
    {
        shadow = Raymarch(samplePoint+ GetNormal(samplePoint,0)*0.005,mul(unity_WorldToObject, float4(mainLightDirection, 0)).xyz);
        shadow -= samplePoint;
        shadow = clamp (remap(0, 1, 1 - _ShadowIntensity, 1, length(shadow)),0,1);
    }

    half ambientOcclusion = 1;
    if (_AOIntensity != 0)
        ambientOcclusion = AO(samplePoint+ GetNormal(samplePoint,0)*0.005 ,GetNormal(samplePoint,0));

    float3 reflectionPoint = Raymarch (samplePoint+ GetNormal(samplePoint,0)*0.002 ,GetNormal(samplePoint,0));
    half4 reflectionColor = GetColor(reflectionPoint);

    // Use build-in fragment PBR function to render specular and metallic.
    InputData lightingInput = (InputData)0;
    SurfaceData surfaceInput = (SurfaceData)0;
    lightingInput.normalWS = GetNormal(samplePoint,1);
    lightingInput.viewDirectionWS = viewDirectionWS;
    surfaceInput.smoothness = _Smoothness ;
    surfaceInput.metallic = _Metallic;
    surfaceInput.albedo = GetColor(samplePoint).xyz;
    surfaceInput.emission = GetColor(samplePoint).xyz * _EmissionWeight; 

    half4 surface =  UniversalFragmentPBR(lightingInput,surfaceInput);
    return ambientOcclusion * surface * shadow.xxxx;    
   //return samplePoint.zzzz;
};

