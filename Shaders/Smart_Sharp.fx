 ////----------------------//
 ///**Depth Unsharp Mask**///
 //----------------------////

 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 //* Depth Based Unsharp Mask                                      																													*//
 //* For Reshade 3.0+																																								*//
 //* --------------------------																																						*//
 //* This work is licensed under a Creative Commons Attribution 3.0 Unported License.																								*//
 //* So you are free to share, modify and adapt it for your needs, and even use it for commercial use.																				*//
 //* I would also love to hear about a project you are using it with.																												*//
 //* https://creativecommons.org/licenses/by/3.0/us/																																*//
 //*																																												*//
 //* Have fun,																																										*//
 //* Jose Negrete AKA BlueSkyDefender																																				*//
 //*																																												*//
 //* http://reshade.me/forum/shader-presentation/2128-sidebyside-3d-depth-map-based-stereoscopic-shader																				*//	
 //* ---------------------------------																																				*//
 //*                                                                            																									*//
 //*                                                                                                            																	*//
 //*                                                                                                            																	*//
 //* 											Bilateral Filter Made by mrharicot ported over to Reshade by BSD																	*//
 //*											GitHub Link for sorce info github.com/SableRaf/Filters4Processin																	*//
 //* 											Shadertoy Link https://www.shadertoy.com/view/4dfGDH  Thank You.																	*//	 
 //*																																												*//
 //* 																																												*//
 //* Lightly optimized by Marot Satil for the GShade project.
 //*
 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Determines the power of the Bilateral Filter and sharpening quality. Lower the setting the more performance you would get along with lower quality.
// 0 = Low
// 1 = Default 
// 2 = Medium
// 3 = High 
// Default is Low.
#define Quality 1

uniform int Depth_Map <
	ui_type = "combo";
	ui_items = "Raw\0Raw Reverse\0";
	ui_label = "Custom Depth Map";
	ui_tooltip = "Pick your Depth Map.";
> = 0;

uniform float Depth_Map_Adjust <
	ui_type = "slider";
	ui_min = 0.001; ui_max = 500.0; ui_step = 0.001;
	ui_label = "Depth Map Adjustment";
	ui_tooltip = "Adjust the depth map and sharpness.";
> = 5.0;

uniform bool Depth_Map_Flip <
	ui_label = "Depth Map Flip";
	ui_tooltip = "Flip the depth map if it is upside down.";
> = false;

uniform bool No_Depth_Map <
	ui_label = "No Depth Map";
	ui_tooltip = "If you have No Depth Buffer turn this On.";
> = false;

uniform int Sharpen_Type <
	ui_type = "combo";
	ui_items = "Normal\0Bilateral Filter\0";
	ui_label = "Sharpen Type";
	ui_tooltip = "Select Sharpen type.";
> = 0;

uniform int Output_Selection <
	ui_type = "combo";
	ui_items = "Normal\0Color Only\0Greyscale Only\0";
	ui_label = "Output Selection";
	ui_tooltip = "Select Sharpen output type.";
> = 0;

uniform float Sharpen_Power <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 5.0; ui_step = 0.1;
	ui_label = "Sharpen Power";
	ui_tooltip = "Increases or Decreases the Sharpen power.";
> = 0.5;

uniform int Luma_Coefficient <
	ui_type = "combo";
	ui_label = "Luma";
	ui_tooltip = "Changes how color get sharpened by Unsharped Masking\n"
				 "This should only affect Normal & Greyscale output.";
	ui_items = "SD video\0HD video\0HDR video\0";
> = 0;

uniform float Contrast_Aware <
	ui_type = "slider";
	ui_min = 0; ui_max = 4.0; ui_step = 0.25;
	ui_label = "Contrast Aware";
	ui_tooltip = "This is used to adjust contrast awareness or to turn it off.\n"
				 "It will not shapren High Contrast areas in game.";
> = 2.0;

uniform bool Debug_View <
	ui_label = "Debug View";
	ui_tooltip = "Used to see what the shaderis changing in the image.";
> = false;

/////////////////////////////////////////////////////D3D Starts Here/////////////////////////////////////////////////////////////////
#define pix float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)

texture DepthBufferTex : DEPTH;

sampler DepthBuffer 
	{ 
		Texture = DepthBufferTex; 
	};
	
texture BackBufferTex : COLOR;

sampler BackBuffer 
	{ 
		Texture = BackBufferTex;
	};
		
texture texBF { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8;};

sampler SamplerBF
	{
		Texture = texBF;
	};
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
float4 Depth(in float2 texcoord : TEXCOORD0)
{
		if (Depth_Map_Flip)
			texcoord.y =  1 - texcoord.y;
			
		float zBuffer = tex2D(DepthBuffer, texcoord).r; //Depth Buffer

		//Conversions to linear space.....
		//Near & Far Adjustment
		const float DA = Depth_Map_Adjust * 2.0f; //Depth Map Adjust - Near
		//All 1.0f are Far Adjustment
	
		//1. Raw Buffer
		const float Raw = pow(abs(zBuffer),DA);
		
		//2. Raw Buffer Reverse
		const float RawReverse = pow(abs(zBuffer - 1.0f),DA);
		
		if (Depth_Map == 0)
		{
		zBuffer = Raw;
		}
		else
		{
		zBuffer = RawReverse;
		}
	
	return smoothstep(0.0f,1.0f,float4(zBuffer.rrr,1));	
}


#define SIGMA 10
#define BSIGMA 0.1125

#if Quality == 0
	#define MSIZE 3
#endif
#if Quality == 1
	#define MSIZE 5
#endif
#if Quality == 2
	#define MSIZE 7
#endif
#if Quality == 3
	#define MSIZE 9
#endif


float normpdf(in float x, in float sigma)
{
	return 0.39894*exp(-0.5*x*x/(sigma*sigma))/sigma;
}

float normpdf3(in float3 v, in float sigma)
{
	return 0.39894*exp(-0.5*dot(v,v)/(sigma*sigma))/sigma;
}

float4 USM( float2 texcoord )
{
	float2 tex_offset = pix; // Gets texel offset
	float4 result =  tex2D(BackBuffer, float2(texcoord));
	if(Sharpen_Power > 0)
	{				   
		   result += tex2D(BackBuffer, float2(texcoord + float2( 1, 0) * tex_offset));
		   result += tex2D(BackBuffer, float2(texcoord + float2(-1, 0) * tex_offset));
		   result += tex2D(BackBuffer, float2(texcoord + float2( 0, 1) * tex_offset));
		   result += tex2D(BackBuffer, float2(texcoord + float2( 0,-1) * tex_offset));
		   tex_offset *= 0.75;		   
		   result += tex2D(BackBuffer, float2(texcoord + float2( 1, 1) * tex_offset));
		   result += tex2D(BackBuffer, float2(texcoord + float2(-1,-1) * tex_offset));
		   result += tex2D(BackBuffer, float2(texcoord + float2( 1,-1) * tex_offset));
		   result += tex2D(BackBuffer, float2(texcoord + float2(-1, 1) * tex_offset));
   		result /= 9;
	}
	
	return result;
}

float4 BS( float2 texcoord )
{
	if(!Sharpen_Type)
		discard;
	//Bilateral Filter//                                                                                                                                                                   
	const float3 c = tex2D(BackBuffer,texcoord.xy).rgb;
	const int kSize = (MSIZE-1)/2;	
//													1			2			3			4				5			6			7			8				7			6			5				4			3			2			1
//Full Kernal Size would be 15 as shown here (0.031225216, 0.033322271, 0.035206333, 0.036826804, 0.038138565, 0.039104044, 0.039695028, 0.039894000, 0.039695028, 0.039104044, 0.038138565, 0.036826804, 0.035206333, 0.033322271, 0.031225216)
#if Quality == 0
	float weight[MSIZE] = {0.031225216, 0.039894000, 0.031225216}; // by 3
#endif
#if Quality == 1
	float weight[MSIZE] = {0.031225216, 0.036826804, 0.039894000, 0.036826804, 0.031225216};  // by 5
#endif	
#if Quality == 2
	float weight[MSIZE] = {0.031225216, 0.035206333, 0.039104044, 0.039894000, 0.039104044, 0.035206333, 0.031225216};   // by 7
#endif
#if Quality == 3
	float weight[MSIZE] = {0.031225216, 0.035206333, 0.038138565, 0.039695028, 0.039894000, 0.039695028, 0.038138565, 0.035206333, 0.031225216};  // by 9
#endif

		float3 final_colour;
		float Z;
		[loop]
		for (int j = 0; j <= kSize; ++j)
		{
			weight[kSize+j] = normpdf(float(j), SIGMA);
			weight[kSize-j] = normpdf(float(j), SIGMA);
		}
		
		float3 cc;
		float factor;
		const float bZ = 1.0/normpdf(0.0, BSIGMA);
		
		[loop]
		for (int i=-kSize; i <= kSize; ++i)
		{
			for (int j=-kSize; j <= kSize; ++j)
			{
				const float2 XY = float2(float(i),float(j))*pix;
				cc = tex2D(BackBuffer,texcoord.xy+XY).rgb;

				factor = normpdf3(cc-c, BSIGMA)*bZ*weight[kSize+j]*weight[kSize+i];
				Z += factor;
				final_colour += factor*cc;
			}
		}
		
	return float4(final_colour/Z, 1.0);
}

void Filters(in float4 position : SV_Position, in float2 texcoord : TEXCOORD0, out float4 color : SV_Target0)                                                                          
{
	if(Sharpen_Type)
		color = BS(texcoord);
	else
		color = USM(texcoord);
}

float4 Out(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float4 Out,RGBA,BB = tex2D(BackBuffer,texcoord);
	float3 Luma,RGB,RGBT,RGBB; //Used in Grayscale calculation I see no diffrence....
	float DB = Depth(texcoord).r, DBBL = Depth(float2(texcoord.x*2,texcoord.y*2-1)).r,SP = Sharpen_Power;
	
	if(Sharpen_Type)
	SP *= 0.5f;
	
	if(No_Depth_Map)
	{
		DB = 0.0;
		DBBL = 1.0;
	}
	
	if (Luma_Coefficient == 0)
	{
		Luma = float3(0.299, 0.587, 0.114); // (SD video)
	}
	else if (Luma_Coefficient == 1)
	{
		Luma = float3(0.2126, 0.7152, 0.0722); // (HD video) https://en.wikipedia.org/wiki/Luma_(video)
	}
	else
	{
		Luma = float3(0.2627, 0.6780, 0.0593); //(HDR video) https://en.wikipedia.org/wiki/Rec._2100
	}
	
	float3 Blur = USM(texcoord).rgb, BackBuff = BB.rgb;
	if (Debug_View)
	{
		Blur = USM(float2(texcoord.x*2,texcoord.y*2-1)).rgb;
		BackBuff = tex2D(BackBuffer,float2(texcoord.x*2,texcoord.y*2-1)).rgb;
	}
	//High Contrast Mask
	float CA = Contrast_Aware * 25.0f, HCM = saturate(dot(( BackBuff - Blur ) , Luma * CA) > 1);
		
	RGB = tex2D(BackBuffer,float2(texcoord.x,texcoord.y)).rgb - tex2D(SamplerBF,float2(texcoord.x,texcoord.y)).rgb;
	
	const float3 Color_Sharp_Control = RGB * SP; 
	const float Grayscale_Sharp_Control = dot(RGB, saturate(Luma * SP));
	
	if (Output_Selection == 0)
	{
		RGBA = saturate(lerp(Grayscale_Sharp_Control,float4(Color_Sharp_Control,1),0.5)) + BB;
	}
	else if (Output_Selection == 1)
	{
		RGBA = saturate(float4(Color_Sharp_Control,1)) + BB;
	}
	else
	{
		RGBA = saturate(Grayscale_Sharp_Control) + BB;
	}

	if (Debug_View == 0)
	{
		Out = lerp(RGBA, BB, DB);
		if(Contrast_Aware > 0)
		Out = lerp(Out, BB, HCM);
	}
	else
	{
		RGBT = tex2D(BackBuffer,float2(texcoord.x*2,texcoord.y*2)).rgb - tex2D(SamplerBF,float2(texcoord.x*2,texcoord.y*2)).rgb;
			
		const float3 CSCT = (RGBT * 5) * SP; 
		const float GSCT = dot(RGBT, saturate((Luma * 5 ) * SP));
		
		if (Output_Selection == 0)
			{
				RGB = saturate(lerp(GSCT,CSCT,0.5));
			}
		else if (Output_Selection == 1)
			{
				RGB = saturate(CSCT);
			}
		else
			{
				RGB = saturate(GSCT);
			}
			
		const float4 BL = lerp(float4(1.0f, 0.0f, 1.0f, 1.0f), tex2D(BackBuffer,float2(texcoord.x*2,texcoord.y*2-1)), DBBL);
		
		if(Contrast_Aware == 0)
			HCM = 0;
		
		const float4 VA_Top = texcoord.x < 0.5 ? float4(RGB,1) : Depth(float2(texcoord.x*2-1,texcoord.y*2));
		const float4 VA_Bottom = texcoord.x < 0.5 ? BL + float4(0,HCM,0,0) : tex2D(SamplerBF,float2(texcoord.x*2-1,texcoord.y*2-1));
		
	Out = texcoord.y < 0.5 ? VA_Top : VA_Bottom;
	
	}

	return Out;
}

///////////////////////////////////////////////////////////ReShade.fxh/////////////////////////////////////////////////////////////

// Vertex shader generating a triangle covering the entire screen
void PostProcessVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

//*Rendering passes*//

technique Smart_Sharp
{			
			pass FilterOut
		{
			VertexShader = PostProcessVS;
			PixelShader = Filters;
			RenderTarget = texBF;
		}
			pass UnsharpMask
		{
			VertexShader = PostProcessVS;
			PixelShader = Out;	
		}
}