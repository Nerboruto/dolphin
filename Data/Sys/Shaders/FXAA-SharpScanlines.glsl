//			DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
//					Version 2, December 2004

// Copyright (C) 2013 mudlord

// Everyone is permitted to copy and distribute verbatim or modified
// copies of this license document, and changing it is allowed as long
// as the name is changed.

//			DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
//	TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

// 0. You just DO WHAT THE FUCK YOU WANT TO.

//scanlines mod by Nerboruto

#define FXAA_REDUCE_MIN		(1.0/ 128.0)
#define FXAA_REDUCE_MUL		(1.0 / 8.0)
#define FXAA_SPAN_MAX		1.5

#define SCAN_LINES		0.10 //scanline intensity

#define C_LUMA float3(0.2126, 0.7152, 0.0722) //luma coefficient

float4 applyFXAA(float2 fragCoord)
{
	float4 color;
	float2 inverseVP = GetInvResolution();
	float3 rgbNW = SampleLocation((fragCoord + float2(-1.0, -1.0)) * inverseVP).xyz;
	float3 rgbNE = SampleLocation((fragCoord + float2(1.0, -1.0)) * inverseVP).xyz;
	float3 rgbSW = SampleLocation((fragCoord + float2(-1.0, 1.0)) * inverseVP).xyz;
	float3 rgbSE = SampleLocation((fragCoord + float2(1.0, 1.0)) * inverseVP).xyz;
	float3 rgbM  = SampleLocation(fragCoord  * inverseVP).xyz;
	float3 luma = float3(0.299, 0.587, 0.114);
	float lumaNW = dot(rgbNW, luma);
	float lumaNE = dot(rgbNE, luma);
	float lumaSW = dot(rgbSW, luma);
	float lumaSE = dot(rgbSE, luma);
	float lumaM  = dot(rgbM,  luma);
	float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
	float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));

	float2 dir;
	dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
	dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));

	float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) *
						(0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN);

	float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
	dir = min(float2(FXAA_SPAN_MAX, FXAA_SPAN_MAX),
			max(float2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),
			dir * rcpDirMin)) * inverseVP;

	float3 rgbA = 0.5 * (
		SampleLocation(fragCoord * inverseVP + dir * (1.0 / 3.0 - 0.5)).xyz +
		SampleLocation(fragCoord * inverseVP + dir * (2.0 / 3.0 - 0.5)).xyz);
	float3 rgbB = rgbA * 0.5 + 0.25 * (
		SampleLocation(fragCoord * inverseVP + dir * -0.5).xyz +
		SampleLocation(fragCoord * inverseVP + dir * 0.5).xyz);

	float lumaB = dot(rgbB, luma);
	if ((lumaB < lumaMin) || (lumaB > lumaMax))
		color = float4(rgbA, 1.0);
	else
		color = float4(rgbB, 1.0);
	return color;
}

void main()
{
	// fxaa pass
	float3 c1 = applyFXAA(GetCoordinates() * GetResolution()).rgb;
	// sharp pass
	float3 blur = SampleLocation(GetCoordinates() + 0.75 / GetResolution()).rgb; // North West
	blur += SampleLocation(GetCoordinates() - 0.75 / GetResolution()).rgb; // South East
	blur /= 2;
	float3 sharp = c1 - blur;
	float sharp_luma = dot(sharp, C_LUMA * 0.5);
	sharp_luma = clamp(sharp_luma, -0.035, 0.035);
	c1 = c1 + sharp_luma;
	// scanlines generator
	float3 c2;
	float Vpos = floor(GetCoordinates().y * GetWindowResolution().y);
	float horzline = mod(Vpos, 2.0);
	if (horzline == 0.0) c2 = float3(1.0, 1.0, 1.0);
	else c2 = float3(0.0, 0.0, 0.0);
	//merge scanlines
	c1 = lerp(c1, c1 * c2 * 2.0, SCAN_LINES);
	SetOutput(float4(c1,0.0));
}
