float invLerp(float from, float to, float value){
  return (value - from) / (to - from);
}
float remap(float origFrom, float origTo, float targetFrom, float targetTo, float value){
  float rel = invLerp(origFrom, origTo, value);
  return lerp(targetFrom, targetTo, rel);
}
float rand(float2 co, float seed){
    float a = 12.9898;
    float b = 78.233;
    float c = 43758.5453;
    float dt= dot(co.xy,float2(a + seed,b + seed));
    float sn= fmod(dt,3.1415926535);
    return frac(sin(sn) * c);
}
float noise (float2 uv,float seed){
    float2 i = floor(uv);
    float2 f = frac(uv);
    float a = rand(i,seed);
    float b = rand(i + float2(1.0, 0.0),seed);
    float c = rand(i + float2(0.0, 1.0),seed);
    float d = rand(i + float2(1.0, 1.0),seed);
    float2 u = f * f * (3.0 - 2.0 * f);
    return lerp(a, b, u.x) +(c - a)* u.y * (1.0 - u.x) +(d - b) * u.x * u.y;
}
