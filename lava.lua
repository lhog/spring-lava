function gadget:GetInfo()
  return {
    name      = "Lava Gadget 2.3",
    desc      = "lava",
    author    = "knorke, Beherith, The_Yak, Anarchid, Kloot, Gajop, ivand",
    date      = "Feb 2011, Nov 2013",
    license   = "GNU GPL, v2 or later",
    layer     = -3,
    enabled   = true
  }
end
-----------------


if (gadgetHandler:IsSyncedCode()) then

else --- UNSYCNED:

--local GL_LUMINANCE32F_ARB = 0x8818

--reconsider size
local lavaHeightMapTexX, lavaHeightMapTexY = 5 * Game.mapX * 64, 5 * Game.mapY * 64

local lavaHeightMapTex
local lavaHeightMapFBO

local lavaHeightMapSrc = VFS.LoadFile("LuaRules\\Gadgets\\Shaders\\lavaHeightMap.glsl", VFS.ZIP)

local lavaHeightMapShader
local lavaHeightMapShaderTimeLoc

local lavaDrawShader
local lavaDrawShaderTimeLoc

local lavaSurfaceDrawList

local gf = 0

local function InitLavaHeightMap()
	lavaHeightMapTex = gl.CreateTexture(lavaHeightMapTexX, lavaHeightMapTexY, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		})

	lavaHeightMapFBO = gl.CreateFBO({color0 = lavaHeightMapTex})

	lavaHeightMapShader = gl.CreateShader({
		uniform = {
			lavaHeightMapTexX = lavaHeightMapTexX,
			lavaHeightMapTexY = lavaHeightMapTexY,
		},
		fragment = lavaHeightMapSrc
	})

	Spring.Echo(lavaHeightMapTexX, lavaHeightMapTexY, lavaHeightMapTex, lavaHeightMapFBO, lavaHeightMapShader)
	Spring.Echo("GL_ARB_tessellation_shader", gl.HasExtension("GL_ARB_tessellation_shader"))
	Spring.Echo("SunDir", gl.GetSun("pos"))
	Spring.Echo("ambient",gl.GetSun("ambient" ,"unit"))
	Spring.Echo("diffuse",gl.GetSun("diffuse" ,"unit"))
	Spring.Echo("specular",gl.GetSun("specular" ,"unit"))

	local shLog = gl.GetShaderLog() or ""
	if shLog ~= "" then
		Spring.Echo("lavaHeightMapShader warnings/errors\n"..shLog)
	end

	if lavaHeightMapShader then
		lavaHeightMapShaderTimeLoc = gl.GetUniformLocation(lavaHeightMapShader, "time")
	end

	-- TODO, read sun params from mapinfo.lua!

	local sdx, sdy, sdz = gl.GetSun("pos")

	Spring.Echo("About to create lavaDrawShader")

	lavaDrawShader = gl.CreateShader({
		uniform = {
			lavaHeightMapTexX = lavaHeightMapTexX,
			lavaHeightMapTexY = lavaHeightMapTexY,
			["lightInfo.DirPos"] = { sdx, sdy, sdz, 0.0 },

			--[[
			["lightInfo.La"] = { gl.GetSun("ambient", "unit") },
			["lightInfo.Ld"] = { gl.GetSun("diffuse", "unit") },
			["lightInfo.Ls"] = { gl.GetSun("specular", "unit") },
			--]]
			["lightInfo.La"] = { 0.1, 0.1, 0.1 },
			["lightInfo.Ld"] = { 0.8, 0.8, 0.8 },
			["lightInfo.Ls"] = { 0.3, 0.3, 0.3 },

			--[[
			--["materialInfo.Emmission"] = {0.015, 0.017, 0.024},
			["materialInfo.Emmission"] = {0.0, 0.0, 0.0},
			--["materialInfo.Ka"] = {0.0, 0.0, 0.0},
			["materialInfo.Ka"] = {0.1, 0.1, 0.1},
			--["materialInfo.Ka"] = {0.015, 0.017, 0.024},
			--["materialInfo.Kd"] = {1.0, 1.0, 1.0},
			--["materialInfo.Kd"] = {0.15, 0.17, 0.24},
			["materialInfo.Kd"] = {0.8, 0.8, 0.8},
			["materialInfo.Ks"] = {10.0, 10.0, 10.0},
			["materialInfo.Shininess"] = 128.0,
			]]--
			--[[
			["materialInfo.Ka"] = {0.25, 0.148, 0.06475},
			["materialInfo.Kd"] = {0.4, 0.2368, 0.1036},
			["materialInfo.Ks"] = {0.774597, 0.458561, 0.200621},
			["materialInfo.Shininess"] = 76.8,
			]]--
			--[[
			["materialInfo.Ka"] = {0.24725, 0.2245, 0.0645},
			["materialInfo.Kd"] = {0.34615, 0.3143, 0.0903},
			["materialInfo.Ks"] = {0.797357, 0.723991, 0.208006},
			["materialInfo.Shininess"] = 8.32,
			]]--
			["materialInfo.Ka"] = {0.1, 0.02, 0.02},
			["materialInfo.Kd"] = {0.12, 0.08, 0.08},
			["materialInfo.Ks"] = {0.3, 0.15, 0.18},
			--["materialInfo.Ks"] = {0.3125, 0.185, 0.0809375},
			["materialInfo.Shininess"] = 60,

		},
		uniformInt = {
			lavaHeightMapTex = 0,
		},
		vertex = [[
			#version 150 compatibility

			uniform vec3 CameraPos;

			out Data
			{
				//vec4 eyeFragPos;
				//vec4 worldFragPos;
				//vec3 surfaceToCamera;
				vec2 uv;
				//float cameraDist;
			};

			void main()
			{
				uv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
				//worldFragPos = vec4(gl_Vertex.x, gl_Vertex.y, gl_Vertex.z, 1.0);
				//vec4 eyeFragPos = gl_ModelViewMatrix * worldFragPos;
				//cameraDist = length(eyeFragPos.xyz);

				//surfaceToCamera = normalize(CameraPos - worldFragPos.xyz); //worldspace

				gl_Position = vec4(gl_Vertex.xyz, 1.0);
			}
		]],
		tcs = [[
			#version 150 compatibility
			#extension GL_ARB_tessellation_shader : enable

			layout( vertices = 4 ) out;

			in Data
			{
				//vec4 eyeFragPos;
				//vec4 worldFragPos;
				//vec3 surfaceToCamera;
				vec2 uv;
				//float cameraDist;
			} tcs_in[];

			out Data
			{
				//vec4 eyeFragPos;
				//vec4 worldFragPos;
				//vec3 surfaceToCamera;
				vec2 uv;
				//float cameraDist;
			} tcs_out[];

			void main()
			{
				// Pass along the vertex position unmodified
				gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;

				// Pass in-outs
				//tcs_out[gl_InvocationID].eyeFragPos = tcs_in[gl_InvocationID].eyeFragPos;
				//tcs_out[gl_InvocationID].worldFragPos = tcs_in[gl_InvocationID].worldFragPos;
				//tcs_out[gl_InvocationID].surfaceToCamera = tcs_in[gl_InvocationID].surfaceToCamera;
				tcs_out[gl_InvocationID].uv = tcs_in[gl_InvocationID].uv;
				//tcs_out[gl_InvocationID].cameraDist = tcs_in[gl_InvocationID].cameraDist;

				gl_TessLevelOuter[0] = 8.0;
				gl_TessLevelOuter[1] = 8.0;
				gl_TessLevelOuter[2] = 8.0;
				gl_TessLevelOuter[3] = 8.0;

				gl_TessLevelInner[0] = 8.0;
				gl_TessLevelInner[1] = 8.0;
			}
		]],
		tes = [[
			#version 150 compatibility
			#extension GL_ARB_tessellation_shader : enable

			layout( quads, equal_spacing, ccw ) in;

			uniform vec3 CameraPos;
			uniform float time;

			in Data
			{
				//vec4 eyeFragPos;
				//vec4 worldFragPos;
				//vec3 surfaceToCamera;
				vec2 uv;
				//float cameraDist;
			} tes_in[];

			out Data
			{
				//vec4 eyeFragPos;
				vec4 worldFragPos;
				vec3 surfaceToCamera;
				vec2 uv;
				float cameraDist;
			};



			//---------------------------------------------------------------
			// value noise, and nothing else
			//---------------------------------------------------------------
			float hash( float n ) { return fract(sin(n)*753.5453123); }
			float noisev( in vec3 x )
			{
				vec3 p = floor(x);
				vec3 w = fract(x);
				vec3 u = w*w*(3.0-2.0*w);

				float n = p.x + p.y*157.0 + 113.0*p.z;

				float a = hash(n+  0.0);
				float b = hash(n+  1.0);
				float c = hash(n+157.0);
				float d = hash(n+158.0);
				float e = hash(n+113.0);
				float f = hash(n+114.0);
				float g = hash(n+270.0);
				float h = hash(n+271.0);

				float k0 =   a;
				float k1 =   b - a;
				float k2 =   c - a;
				float k3 =   e - a;
				float k4 =   a - b - c + d;
				float k5 =   a - c - e + g;
				float k6 =   a - b - e + f;
				float k7 = - a + b + c - d + e - f - g + h;

				float val = k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z;

				return val;
			}

			#if 1
				#define mytime time
			#else
				#define mytime 0.0
			#endif

			#define noise(uvHm)  noisev( vec3(uvHm, 0.05 * mytime) )


			float bilerp(in vec2 uv, in float p00, in float p10, in float p11, in float p01)
			{
				float u = uv.x,	v = uv.y;
				#define a mix(p00, p10, u)
				#define b mix(p01, p11, u)
				return mix(a, b, v);
			}

			vec2 bilerp(in vec2 uv, in vec2 p00, in vec2 p10, in vec2 p11, in vec2 p01)
			{
				float u = uv.x,	v = uv.y;
				#define a mix(p00, p10, u)
				#define b mix(p01, p11, u)
				return mix(a, b, v);
			}

			vec3 bilerp(in vec2 uv, in vec3 p00, in vec3 p10, in vec3 p11, in vec3 p01)
			{
				float u = uv.x,	v = uv.y;
				#define a mix(p00, p10, u)
				#define b mix(p01, p11, u)
				return mix(a, b, v);
			}

			vec4 bilerp(in vec2 uv, in vec4 p00, in vec4 p10, in vec4 p11, in vec4 p01)
			{
				float u = uv.x,	v = uv.y;
				#define a mix(p00, p10, u)
				#define b mix(p01, p11, u)
				return mix(a, b, v);
			}

			#define bilerpQuadArgs(inArray, inName) bilerp(gl_TessCoord.xy, inArray[0].inName, inArray[1].inName, inArray[2].inName, inArray[3].inName)

			void main()
			{
				// Pass in-outs
				uv = bilerpQuadArgs(tes_in, uv);
				vec2 uvHm = uv * vec2(128.0);
				//float pn = noise(uvHm);

				// Apply heightmap
				worldFragPos = bilerpQuadArgs(gl_in, gl_Position);
				//worldFragPos.y += pn * 150.0;
				
				surfaceToCamera = normalize(CameraPos - worldFragPos.xyz); //worldspace
				vec4 eyeFragPos = gl_ModelViewMatrix * worldFragPos;
				cameraDist = length(eyeFragPos.xyz);				
				

				// eye space --> NDC space
				gl_Position = gl_ProjectionMatrix * eyeFragPos;
			}
		]],
		fragment = [[
			#version 150 compatibility

			uniform sampler2D lavaHeightMapTex;
			uniform vec3 CameraPos;
			uniform float time;

			struct LightInfo {
				vec4 DirPos; //support both Directional (vec3 direction vector, w == 0.0) and Point light (vec3 position vector, w != 0.0). World Space
				vec3 La;
				vec3 Ld;
				vec3 Ls;
			};
			uniform LightInfo lightInfo;

			struct MaterialInfo {
				vec3 Ka;
				vec3 Kd;
				vec3 Ks;
				float Shininess;
			};
			uniform MaterialInfo materialInfo;

			in Data
			{
				//vec4 eyeFragPos;
				vec4 worldFragPos;
				vec3 surfaceToCamera;
				vec2 uv;
				float cameraDist;
			};

			/////////////////////////////
			vec4 Perlin3D_Deriv( vec3 P )
			{
				//  https://github.com/BrianSharpe/Wombat/blob/master/Perlin3D_Deriv.glsl

				// establish our grid cell and unit position
				vec3 Pi = floor(P);
				vec3 Pf = P - Pi;
				vec3 Pf_min1 = Pf - 1.0;

				// clamp the domain
				Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
				vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

				// calculate the hash
				vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
				Pt *= Pt;
				Pt = Pt.xzxz * Pt.yyww;
				const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
				const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
				vec3 lowz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi.zzz * ZINC ) );
				vec3 highz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi_inc1.zzz * ZINC ) );
				vec4 hashx0 = fract( Pt * lowz_mod.xxxx );
				vec4 hashx1 = fract( Pt * highz_mod.xxxx );
				vec4 hashy0 = fract( Pt * lowz_mod.yyyy );
				vec4 hashy1 = fract( Pt * highz_mod.yyyy );
				vec4 hashz0 = fract( Pt * lowz_mod.zzzz );
				vec4 hashz1 = fract( Pt * highz_mod.zzzz );

				//	calculate the gradients
				vec4 grad_x0 = hashx0 - 0.49999;
				vec4 grad_y0 = hashy0 - 0.49999;
				vec4 grad_z0 = hashz0 - 0.49999;
				vec4 grad_x1 = hashx1 - 0.49999;
				vec4 grad_y1 = hashy1 - 0.49999;
				vec4 grad_z1 = hashz1 - 0.49999;
				vec4 norm_0 = inversesqrt( grad_x0 * grad_x0 + grad_y0 * grad_y0 + grad_z0 * grad_z0 );
				vec4 norm_1 = inversesqrt( grad_x1 * grad_x1 + grad_y1 * grad_y1 + grad_z1 * grad_z1 );
				grad_x0 *= norm_0;
				grad_y0 *= norm_0;
				grad_z0 *= norm_0;
				grad_x1 *= norm_1;
				grad_y1 *= norm_1;
				grad_z1 *= norm_1;

				//	calculate the dot products
				vec4 dotval_0 = vec2( Pf.x, Pf_min1.x ).xyxy * grad_x0 + vec2( Pf.y, Pf_min1.y ).xxyy * grad_y0 + Pf.zzzz * grad_z0;
				vec4 dotval_1 = vec2( Pf.x, Pf_min1.x ).xyxy * grad_x1 + vec2( Pf.y, Pf_min1.y ).xxyy * grad_y1 + Pf_min1.zzzz * grad_z1;

				//	C2 Interpolation
				vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
				vec3 blendDeriv = Pf * Pf * (Pf * (Pf * 30.0 - 60.0) + 30.0);

				//  the following is based off Milo Yips derivation, but modified for parallel execution
				//  http://stackoverflow.com/a/14141774

				//	Convert our data to a more parallel format
				vec4 dotval0_grad0 = vec4( dotval_0.x, grad_x0.x, grad_y0.x, grad_z0.x );
				vec4 dotval1_grad1 = vec4( dotval_0.y, grad_x0.y, grad_y0.y, grad_z0.y );
				vec4 dotval2_grad2 = vec4( dotval_0.z, grad_x0.z, grad_y0.z, grad_z0.z );
				vec4 dotval3_grad3 = vec4( dotval_0.w, grad_x0.w, grad_y0.w, grad_z0.w );
				vec4 dotval4_grad4 = vec4( dotval_1.x, grad_x1.x, grad_y1.x, grad_z1.x );
				vec4 dotval5_grad5 = vec4( dotval_1.y, grad_x1.y, grad_y1.y, grad_z1.y );
				vec4 dotval6_grad6 = vec4( dotval_1.z, grad_x1.z, grad_y1.z, grad_z1.z );
				vec4 dotval7_grad7 = vec4( dotval_1.w, grad_x1.w, grad_y1.w, grad_z1.w );

				//	evaluate common constants
				vec4 k0_gk0 = dotval1_grad1 - dotval0_grad0;
				vec4 k1_gk1 = dotval2_grad2 - dotval0_grad0;
				vec4 k2_gk2 = dotval4_grad4 - dotval0_grad0;
				vec4 k3_gk3 = dotval3_grad3 - dotval2_grad2 - k0_gk0;
				vec4 k4_gk4 = dotval5_grad5 - dotval4_grad4 - k0_gk0;
				vec4 k5_gk5 = dotval6_grad6 - dotval4_grad4 - k1_gk1;
				vec4 k6_gk6 = (dotval7_grad7 - dotval6_grad6) - (dotval5_grad5 - dotval4_grad4) - k3_gk3;

				//	calculate final noise + deriv
				float u = blend.x;
				float v = blend.y;
				float w = blend.z;
				vec4 result = dotval0_grad0
					+ u * ( k0_gk0 + v * k3_gk3 )
					+ v * ( k1_gk1 + w * k5_gk5 )
					+ w * ( k2_gk2 + u * ( k4_gk4 + v * k6_gk6 ) );
				result.y += dot( vec4( k0_gk0.x, k3_gk3.x * v, vec2( k4_gk4.x, k6_gk6.x * v ) * w ), vec4( blendDeriv.x ) );
				result.z += dot( vec4( k1_gk1.x, k3_gk3.x * u, vec2( k5_gk5.x, k6_gk6.x * u ) * w ), vec4( blendDeriv.y ) );
				result.w += dot( vec4( k2_gk2.x, k4_gk4.x * u, vec2( k5_gk5.x, k6_gk6.x * u ) * v ), vec4( blendDeriv.z ) );
				return result * 1.1547005383792515290182975610039;  // scale things to a strict -1.0->1.0 range  *= 1.0/sqrt(0.75)
			}

			vec4 SimplexPerlin3D_Deriv(vec3 P)
			{
				//  https://github.com/BrianSharpe/Wombat/blob/master/SimplexPerlin3D_Deriv.glsl

				//  simplex math constants
				const float SKEWFACTOR = 1.0/3.0;
				const float UNSKEWFACTOR = 1.0/6.0;
				const float SIMPLEX_CORNER_POS = 0.5;
				const float SIMPLEX_TETRAHADRON_HEIGHT = 0.70710678118654752440084436210485;    // sqrt( 0.5 )

				//  establish our grid cell.
				P *= SIMPLEX_TETRAHADRON_HEIGHT;    // scale space so we can have an approx feature size of 1.0
				vec3 Pi = floor( P + dot( P, vec3( SKEWFACTOR) ) );

				//  Find the vectors to the corners of our simplex tetrahedron
				vec3 x0 = P - Pi + dot(Pi, vec3( UNSKEWFACTOR ) );
				vec3 g = step(x0.yzx, x0.xyz);
				vec3 l = 1.0 - g;
				vec3 Pi_1 = min( g.xyz, l.zxy );
				vec3 Pi_2 = max( g.xyz, l.zxy );
				vec3 x1 = x0 - Pi_1 + UNSKEWFACTOR;
				vec3 x2 = x0 - Pi_2 + SKEWFACTOR;
				vec3 x3 = x0 - SIMPLEX_CORNER_POS;

				//  pack them into a parallel-friendly arrangement
				vec4 v1234_x = vec4( x0.x, x1.x, x2.x, x3.x );
				vec4 v1234_y = vec4( x0.y, x1.y, x2.y, x3.y );
				vec4 v1234_z = vec4( x0.z, x1.z, x2.z, x3.z );

				// clamp the domain of our grid cell
				Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
				vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

				//	generate the random vectors
				vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
				Pt *= Pt;
				vec4 V1xy_V2xy = mix( Pt.xyxy, Pt.zwzw, vec4( Pi_1.xy, Pi_2.xy ) );
				Pt = vec4( Pt.x, V1xy_V2xy.xz, Pt.z ) * vec4( Pt.y, V1xy_V2xy.yw, Pt.w );
				const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
				const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
				vec3 lowz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi.zzz * ZINC.xyz ) );
				vec3 highz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi_inc1.zzz * ZINC.xyz ) );
				Pi_1 = ( Pi_1.z < 0.5 ) ? lowz_mods : highz_mods;
				Pi_2 = ( Pi_2.z < 0.5 ) ? lowz_mods : highz_mods;
				vec4 hash_0 = fract( Pt * vec4( lowz_mods.x, Pi_1.x, Pi_2.x, highz_mods.x ) ) - 0.49999;
				vec4 hash_1 = fract( Pt * vec4( lowz_mods.y, Pi_1.y, Pi_2.y, highz_mods.y ) ) - 0.49999;
				vec4 hash_2 = fract( Pt * vec4( lowz_mods.z, Pi_1.z, Pi_2.z, highz_mods.z ) ) - 0.49999;

				//	normalize random gradient vectors
				vec4 norm = inversesqrt( hash_0 * hash_0 + hash_1 * hash_1 + hash_2 * hash_2 );
				hash_0 *= norm;
				hash_1 *= norm;
				hash_2 *= norm;

				//	evaluate gradients
				vec4 grad_results = hash_0 * v1234_x + hash_1 * v1234_y + hash_2 * v1234_z;

				//  evaulate the kernel weights ( use (0.5-x*x)^3 instead of (0.6-x*x)^4 to fix discontinuities )
				vec4 m = v1234_x * v1234_x + v1234_y * v1234_y + v1234_z * v1234_z;
				m = max(0.5 - m, 0.0);
				vec4 m2 = m*m;
				vec4 m3 = m*m2;

				//  calc the derivatives
				vec4 temp = -6.0 * m2 * grad_results;
				float xderiv = dot( temp, v1234_x ) + dot( m3, hash_0 );
				float yderiv = dot( temp, v1234_y ) + dot( m3, hash_1 );
				float zderiv = dot( temp, v1234_z ) + dot( m3, hash_2 );

				//	Normalization factor to scale the final result to a strict 1.0->-1.0 range
				//	http://briansharpe.wordpress.com/2012/01/13/simplex-noise/#comment-36
				const float FINAL_NORMALIZATION = 37.837227241611314102871574478976;

				//  sum and return all results as a vec3
				return vec4( dot( m3, grad_results ), xderiv, yderiv, zderiv ) * FINAL_NORMALIZATION;
			}

			#define HASHSCALE1 .1031
			float hash12(vec2 p)
			{
				vec3 p3  = fract(vec3(p.xyx) * HASHSCALE1);
				p3 += dot(p3, p3.yzx + 19.19);
				return fract((p3.x + p3.y) * p3.z);
			}
			#define rand(p) hash12(p)

			#define M_PI 3.1415926535897932384626433832795
			float noise21(in vec2 n)
			{
				const vec2 d = vec2(0.0, 1.0);
				vec2 b = floor(n);
				vec2 f = 0.5 * (1.0 - cos(M_PI * fract(n)));
				return mix(mix(rand(b), rand(b + d.yx), f.x), mix(rand(b + d.xy), rand(b + d.yy), f.x), f.y);
			}

			mat2 makem2(in float theta){float c = cos(theta);float s = sin(theta);return mat2(c,-s,s,c);}

			vec2 gradn(vec2 p)
			{
				float ep = 0.1;
				float gradx = noise21(vec2(p.x+ep,p.y))-noise21(vec2(p.x-ep,p.y));
				float grady = noise21(vec2(p.x,p.y+ep))-noise21(vec2(p.x,p.y-ep));
				return vec2(gradx,grady);
			}

			#define MAX_OCTAVES 10
			#define MIN_OCTAVES 5


			float flow(in vec2 p, float time2, int octaves)
			{
				float z= 2.0;
				float rz = 0.;
				vec2 bp = p;
				for (int i = 0; i < MAX_OCTAVES; ++i) {
					if (i < octaves) {
						//primary flow speed
						p += time2 * -0.3;

						//secondary flow speed (speed of the perceived flow)
						bp += time2 * 0.3;

						//displacement field (try changing time multiplier)
						vec2 gr = gradn(1 * i * p * 0.34 + time2 * 1.0);

						//rotation of the displacement field
						gr *= makem2(time2 * 6.0 - (0.05 * p.x + 0.03 * p.y) * 40.0);

						//displace the system
						p += gr*.5;

						//add noise octave
						rz += (sin(noise21(p)*5.0)*0.5+0.5)/z;

						//blend factor (blending displaced system with base system)
						//you could call this advection factor (.5 being low, .95 being high)
						p = mix(bp, p, 0.77);

						//intensity scaling
						z *= 1.4;

						//octave scaling
						p *= 2.5;
						bp *= 1.9;
					}
				}
				return rz;
			}


			float hash( float n ) { return fract(sin(n)*753.5453123); }


			//---------------------------------------------------------------
			// value noise, and its analytical derivatives
			//---------------------------------------------------------------

			vec4 noised( in vec3 x )
			{
				vec3 p = floor(x);
				vec3 w = fract(x);
				vec3 u = w*w*(3.0-2.0*w);
				vec3 du = 6.0*w*(1.0-w);

				float n = p.x + p.y*157.0 + 113.0*p.z;

				float a = hash(n+  0.0);
				float b = hash(n+  1.0);
				float c = hash(n+157.0);
				float d = hash(n+158.0);
				float e = hash(n+113.0);
				float f = hash(n+114.0);
				float g = hash(n+270.0);
				float h = hash(n+271.0);

				float k0 =   a;
				float k1 =   b - a;
				float k2 =   c - a;
				float k3 =   e - a;
				float k4 =   a - b - c + d;
				float k5 =   a - c - e + g;
				float k6 =   a - b - e + f;
				float k7 = - a + b + c - d + e - f - g + h;

				float val = k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z;

				return vec4( val,
							 du * (vec3(k1,k2,k3) + u.yzx*vec3(k4,k5,k6) + u.zxy*vec3(k6,k4,k5) + k7*u.yzx*u.zxy ));
			}

			vec4 fbmd( in vec3 x, int octaves )
			{
				float a = 0.0;
				float b = 0.5;
				float f = 1.0;
				vec3  d = vec3(0.0);
				for( int i = 0; i < octaves; i++ )
				{
					vec4 n = noised(f * x);
					a += b * n.x;           	// accumulate values
					d += b * n.yzw * f; 		// accumulate derivatives
					b *= 0.5;             		// amplitude decrease
					f *= 1.9;             		// frequency increase
				}

				return vec4( a, d );
			}
			
			//	Classic Perlin 3D Noise 
			//	by Stefan Gustavson
			//
			vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
			vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}
			vec3 fade(vec3 t) {return t*t*t*(t*(t*6.0-15.0)+10.0);}

			float cnoise(vec3 P){
			  vec3 Pi0 = floor(P); // Integer part for indexing
			  vec3 Pi1 = Pi0 + vec3(1.0); // Integer part + 1
			  Pi0 = mod(Pi0, 289.0);
			  Pi1 = mod(Pi1, 289.0);
			  vec3 Pf0 = fract(P); // Fractional part for interpolation
			  vec3 Pf1 = Pf0 - vec3(1.0); // Fractional part - 1.0
			  vec4 ix = vec4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
			  vec4 iy = vec4(Pi0.yy, Pi1.yy);
			  vec4 iz0 = Pi0.zzzz;
			  vec4 iz1 = Pi1.zzzz;

			  vec4 ixy = permute(permute(ix) + iy);
			  vec4 ixy0 = permute(ixy + iz0);
			  vec4 ixy1 = permute(ixy + iz1);

			  vec4 gx0 = ixy0 / 7.0;
			  vec4 gy0 = fract(floor(gx0) / 7.0) - 0.5;
			  gx0 = fract(gx0);
			  vec4 gz0 = vec4(0.5) - abs(gx0) - abs(gy0);
			  vec4 sz0 = step(gz0, vec4(0.0));
			  gx0 -= sz0 * (step(0.0, gx0) - 0.5);
			  gy0 -= sz0 * (step(0.0, gy0) - 0.5);

			  vec4 gx1 = ixy1 / 7.0;
			  vec4 gy1 = fract(floor(gx1) / 7.0) - 0.5;
			  gx1 = fract(gx1);
			  vec4 gz1 = vec4(0.5) - abs(gx1) - abs(gy1);
			  vec4 sz1 = step(gz1, vec4(0.0));
			  gx1 -= sz1 * (step(0.0, gx1) - 0.5);
			  gy1 -= sz1 * (step(0.0, gy1) - 0.5);

			  vec3 g000 = vec3(gx0.x,gy0.x,gz0.x);
			  vec3 g100 = vec3(gx0.y,gy0.y,gz0.y);
			  vec3 g010 = vec3(gx0.z,gy0.z,gz0.z);
			  vec3 g110 = vec3(gx0.w,gy0.w,gz0.w);
			  vec3 g001 = vec3(gx1.x,gy1.x,gz1.x);
			  vec3 g101 = vec3(gx1.y,gy1.y,gz1.y);
			  vec3 g011 = vec3(gx1.z,gy1.z,gz1.z);
			  vec3 g111 = vec3(gx1.w,gy1.w,gz1.w);

			  vec4 norm0 = taylorInvSqrt(vec4(dot(g000, g000), dot(g010, g010), dot(g100, g100), dot(g110, g110)));
			  g000 *= norm0.x;
			  g010 *= norm0.y;
			  g100 *= norm0.z;
			  g110 *= norm0.w;
			  vec4 norm1 = taylorInvSqrt(vec4(dot(g001, g001), dot(g011, g011), dot(g101, g101), dot(g111, g111)));
			  g001 *= norm1.x;
			  g011 *= norm1.y;
			  g101 *= norm1.z;
			  g111 *= norm1.w;

			  float n000 = dot(g000, Pf0);
			  float n100 = dot(g100, vec3(Pf1.x, Pf0.yz));
			  float n010 = dot(g010, vec3(Pf0.x, Pf1.y, Pf0.z));
			  float n110 = dot(g110, vec3(Pf1.xy, Pf0.z));
			  float n001 = dot(g001, vec3(Pf0.xy, Pf1.z));
			  float n101 = dot(g101, vec3(Pf1.x, Pf0.y, Pf1.z));
			  float n011 = dot(g011, vec3(Pf0.x, Pf1.yz));
			  float n111 = dot(g111, Pf1);

			  vec3 fade_xyz = fade(Pf0);
			  vec4 n_z = mix(vec4(n000, n100, n010, n110), vec4(n001, n101, n011, n111), fade_xyz.z);
			  vec2 n_yz = mix(n_z.xy, n_z.zw, fade_xyz.y);
			  float n_xyz = mix(n_yz.x, n_yz.y, fade_xyz.x); 
			  return 2.2 * n_xyz;
			}			

			/////////////////////////////

			vec3 CalcADS(vec3 nnorm) //nnorm must be a unit vector
			{
				vec3 surfaceToLight;

				if( lightInfo.DirPos.w == 0.0 )
					surfaceToLight = normalize(lightInfo.DirPos.xyz);
				else
					surfaceToLight = normalize(lightInfo.DirPos.xyz - worldFragPos.xyz);

				float sDotN = max( dot(nnorm, surfaceToLight), 0.0 );


				vec3 Ia = lightInfo.La * materialInfo.Ka;
				vec3 Id = lightInfo.Ld * materialInfo.Kd * sDotN;

				vec3 Is = vec3(0.0);
				if( sDotN > 0.0 ) {
					vec3 incidenceVector = -surfaceToLight;
					vec3 reflectionVector = reflect(incidenceVector, nnorm);
					#if 0
						vec3 surfaceToCamera = normalize(CameraPos - worldFragPos.xyz);
					#endif
					Is = lightInfo.Ls * materialInfo.Ks * pow( max( dot(surfaceToCamera, reflectionVector), 0.0 ), materialInfo.Shininess );
				}

				return Ia + Id + Is;
			}

			vec4 notanoise(in vec3 x )
			{
				vec3 f = fract(x);
				float v = (f.x * f.x + f.y * f.y) / 2.0;
				vec3 dV = vec3(f.x, f.y, 0.0);
				return vec4(v, dV);
			}

			#if 0
				#define mytime time * 0.1
			#else
				#define mytime 0.0
			#endif

			#define INIGO

			#if defined (INIGO)
				// see https://gist.github.com/lhog/7c6c019e536131387cf855b032eaac92
				int GetNumberOfOctaves() {
					const vec2 CAM_MINMAX = vec2(100.0, 7000.0);
					#define INIGO_OCTAVES_COUNT 20
					#define INIGO_MIN_OCTAVES  5

					const float RATES[INIGO_OCTAVES_COUNT] = float[](0.0, 0.1571667155245, 0.29075842372032, 0.40431137568677, 0.50083138485825, 0.58287339265401, 0.65260909928041,
																	0.71188444991284, 0.76226849795041, 0.80509493878235, 0.84149741348949, 0.87243951699057, 0.89874030496648, 0.92109597474601,
																	0.9400982940586, 0.95625026547431, 0.96997944117766, 0.98164924052551, 0.99156856997118, 1.0);

					float cdc = clamp(cameraDist, CAM_MINMAX.x, CAM_MINMAX.y);
					float cdcNorm = (CAM_MINMAX.y - cdc) / (CAM_MINMAX.y - CAM_MINMAX.x);
					int octIdx = 0;
					for (int i = 1; i < INIGO_OCTAVES_COUNT; i++)
					{
						if ((RATES[i-1] < cdcNorm) && (cdcNorm <= RATES[i])) {
							octIdx = i;
							break;
						}
					}

					return octIdx + INIGO_MIN_OCTAVES;
					//return INIGO_MIN_OCTAVES;
				}
			#endif

			#if defined(PERLIN)
				#define noise(uvHm)  Perlin3D_Deriv(vec3(uvHm, mytime))
			#elif defined(SIMPLEX)
				#define noise(uvHm)  SimplexPerlin3D_Deriv(vec3(uvHm, mytime))
			#elif defined(FLOW)
				#define noise(uvHm)  vec4(flow(uvHm, 0.01 * mytime, 8))
			#elif defined(INIGO)
				#define noise(uvHm)  fbmd( vec3(uvHm, 0.05 * mytime), GetNumberOfOctaves() )
			#elif defined(NOTANOISE)
				#define noise(uvHm)  notanoise( vec3(uvHm, 0.05 * mytime) )
			#endif
			
			vec3 firePalette(float i, float exposure){

				float T = 1400. + 1300.*i; // Temperature range (in Kelvin).
				vec3 L = vec3(7.4, 5.6, 4.4); // Red, green, blue wavelengths (in hundreds of nanometers).
				L = pow(L,vec3(5.0)) * (exp(1.43876719683e5/(T*L))-1.0);
				return 1.0-exp(- exposure * 1e8/L); // Exposure level. Set to "50." For "70," change the "5" to a "7," etc.
			}			


			void main()
			{
				//vec4 val;
				//val = texture(lavaHeightMapTex, uv);
				#if defined(PERLIN) | defined(SIMPLEX)
					vec2 uvHm = uv * vec2(512.0);
					//vec2 uvHm = uv * vec2(16.0);
				#else
					vec2 uvHm = uv * vec2(128.0);
				#endif

				//vec4 pn = noise(uvHm) + 0.2 * noise(uvHm * 256.0) +  0.1 * noise(uvHm * 512.0);
				vec4 pn;
				pn = noise(uvHm);
				//pn.x = 2.0 * pn.x - 1.0;

				#if defined(INIGO)
					pn.x = 2.0 * pn.x - 1.2;
				#endif

				pn += Perlin3D_Deriv(vec3(uvHm, mytime));

				#define ANALYTICAL_DERIVATIVES

				#if defined(ANALYTICAL_DERIVATIVES)
					vec3 va = vec3(1.0, pn.y, 0.0);
					vec3 vb = vec3(0.0, pn.z, -1.0);  //no idea why minus
				#else //numerical derivatives
					const float off = 0.01;
					const float off2 = 2.0 * off;

					float s01 = noise( uvHm - vec2( off, 0.0 ) ).x;
					float s21 = noise( uvHm + vec2( off, 0.0 ) ).x;
					float s10 = noise( uvHm - vec2( 0.0, off ) ).x;
					float s12 = noise( uvHm + vec2( 0.0, off ) ).x;
					vec3 va = vec3(off2, s21 - s01,  0.0);
					vec3 vb = vec3(0.0 , s12 - s10, -off2); //no idea why minus
				#endif

				pn.yzw = normalize( cross(va, vb) );


				vec3 surfaceColor = CalcADS(pn.yzw);

				const vec3 FANCYLAVA_COLOR = vec3(0.45, 0.1, 0.02);
				const float CONSTRAST_POW = 1.6;

				float rz = flow(uvHm, time * 0.1, 8);
				//float rz = 1.0;
				//vec3 lavaColor = FANCYLAVA_COLOR / rz;
				

				//lavaColor = pow(lavaColor, vec3(CONSTRAST_POW)); //change contrast
				
				float mixFactor = smoothstep(-0.3, 0.3, pn.x);
				float fpFactor = (0.0 - pn.x) * 0.6 * rz;
				vec3 lavaColor = firePalette(fpFactor, 5.0);
				//vec3 lavaColor = firePalette(0.5, 5.0);

				//surfaceColor = pow(surfaceColor, vec3(1.0/2.2));
				vec3 finalColor = mix(lavaColor, surfaceColor, mixFactor);
				//finalColor = surfaceColor;
				
				//finalColor = pow(finalColor, vec3(1.0/2.2));

				gl_FragColor = vec4(finalColor, 1.0);
				//gl_FragColor = vec4(surfaceColor, 1.0);
				//gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
				//gl_FragColor = vec4(vec3(rz), 1.0);

			}
		]]
	})

	local shLog = gl.GetShaderLog() or ""
	if shLog ~= "" then
		Spring.Echo("lavaDrawShader warnings/errors\n"..shLog)
	end

	if lavaDrawShader then
		lavaDrawShaderTimeLoc = gl.GetUniformLocation(lavaDrawShader, "time")
		lavaDrawShaderCameraPosLoc = gl.GetUniformLocation(lavaDrawShader, "CameraPos")
		--Spring.Echo("GL.PATCH_VERTICES", GL.PATCH_VERTICES)
		local GL_MAX_TESS_GEN_LEVEL = 0x8E7E
		Spring.Echo("GL_MAX_TESS_GEN_LEVEL", gl.GetNumber(GL_MAX_TESS_GEN_LEVEL))
	end

	return (lavaHeightMapTex ~= nil) and (lavaHeightMapFBO ~= nil) and (lavaHeightMapShader ~= nil) and (lavaDrawShader ~= nil) and gl.IsValidFBO(lavaHeightMapFBO)
end

local saveLavaHeightMapTexOnce = true

local function UpdateLavaHeightMap()
	if gl.UseShader(lavaHeightMapShader) then
		gl.Uniform(lavaHeightMapShaderTimeLoc, 0.01 * gf)
		gl.ActiveFBO(lavaHeightMapFBO, function()
			gl.DepthTest(false)
			gl.Blending(false)

			gl.TexRect(-1, -1, 1, 1)
		end)

		gl.UseShader(0)
	end
end

local function DrawFlatMesh(x1, z1, x2, z2, tiles, uvmul)
	local xstep = (x2 - x1) / tiles
	local zstep = (z2 - z1) / tiles

	for xi = 0, tiles - 1 do
		local x = x1 + xi * xstep
		for zi = 0, tiles - 1 do
			local z = z1 + zi * zstep

			--top-left
			gl.TexCoord( (xi + 0) / tiles * uvmul, (zi + 0) / tiles * uvmul)
			gl.Vertex(x, 0, z)

			--top-right
			gl.TexCoord( (xi + 1) / tiles * uvmul, (zi + 0) / tiles * uvmul)
			gl.Vertex(x + xstep, 0, z)

			--bottom-right
			gl.TexCoord( (xi + 1) / tiles * uvmul, (zi + 1) / tiles * uvmul)
			gl.Vertex(x + xstep, 0, z + zstep)

			--bottom-left
			gl.TexCoord( (xi + 0) / tiles * uvmul, (zi + 1) / tiles * uvmul)
			gl.Vertex(x, 0, z + zstep)
		end
	end
end

local function InitLavaSurfaceDrawList()
	lavaSurfaceDrawList = gl.CreateList(function ()
		gl.SetTesselationShaderParameter( GL.PATCH_VERTICES, 4);
		gl.BeginEnd(GL.PATCHES, DrawFlatMesh, -2*Game.mapX*512, -2*Game.mapY*512,  3*Game.mapX*512, 3*Game.mapY*512, 64, 1)
	end)
end

function gadget:DrawGenesis()
	if not lavaSurfaceDrawList then
		InitLavaSurfaceDrawList()
	end
	UpdateLavaHeightMap()
end

function gadget:DrawWorldPreUnit()
	gl.DepthTest(true)
	gl.DepthMask(true)

	if gl.Texture(0, lavaHeightMapTex) then
		if gl.UseShader(lavaDrawShader) then
			gl.Uniform(lavaDrawShaderTimeLoc, 0.01 * gf)
			local cx, cy, cz = Spring.GetCameraPosition()
			--Spring.Echo(lavaDrawShaderCameraPosLoc, cx, cy, cz)
			gl.Uniform(lavaDrawShaderCameraPosLoc, cx, cy, cz)
			--gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
			gl.CallList(lavaSurfaceDrawList)
			--gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
			gl.UseShader(0)
		end
		gl.Texture(0, false)
	end

	gl.DepthTest(false)
	gl.DepthMask(false)
end

function gadget:GameFrame(frame)
	gf = frame
end

function gadget:Initialize()
	if not InitLavaHeightMap() then
		Spring.Echo("Failed to InitLavaHeightMap()")
		gadgetHandler:RemoveGadget()
	end
end

function gadget:Shutdown()
	if (lavaSurfaceDrawList) then
		gl.DeleteList(lavaSurfaceDrawList)
	end

	if (lavaHeightMapTex) then
		gl.DeleteTextureFBO(lavaHeightMapTex)
	end

	if (lavaHeightMapFBO) then
		gl.DeleteFBO(lavaHeightMapFBO)
	end

	if (lavaHeightMapShader) then
		gl.DeleteShader(lavaHeightMapShader)
	end

	if (lavaDrawShader) then
		gl.DeleteShader(lavaDrawShader)
	end

end


end --- UNSYCNED