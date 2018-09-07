function gadget:GetInfo()
  return {
    name      = "Lava Draw Gadget",
    desc      = "Lava Draw Gadget",
    author    = "ivand",
    date      = "2018",
    license   = "GNU GPL, v2 or later",
    layer     = -3,
    enabled   = true,
  }
end
-----------------

if (gadgetHandler:IsSyncedCode()) then
	return
end

--- UNSYCNED:

--- Includes
local LuaShader = VFS.Include("LuaRules/Gadgets/Shaders/LuaShader.lua")
local GaussianBlur = VFS.Include("LuaRules/Gadgets/Shaders/GaussianBlur.lua")
local BloomEffect = VFS.Include("LuaRules/Gadgets/Shaders/BloomEffect.lua")

--- Const
local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0
local GL_LUMINANCE32F_ARB = 0x8818

--- Vars
local emitTexOrig, emitTexNew
local emitFBO
local emitTexX, emitTexY

local emitTexShader

local hmTexBlur
local hmFBO
local hmTexX, hmTexY
local hmBlur

local lavaSurfaceDrawList

local emitTexShaderFrag = [[
	uniform sampler2D emitTex;
	uniform sampler2D hmTexBlur;
	uniform vec2 emitTexSize;
	uniform vec2 hmTexSize;

	#define TEMPERATURE 2200.0

	vec3 blackbody(float t)
	{
		t *= TEMPERATURE;

		float u = ( 0.860117757 + 1.54118254e-4 * t + 1.28641212e-7 * t*t )
				/ ( 1.0 + 8.42420235e-4 * t + 7.08145163e-7 * t*t );

		float v = ( 0.317398726 + 4.22806245e-5 * t + 4.20481691e-8 * t*t )
				/ ( 1.0 - 2.89741816e-5 * t + 1.61456053e-7 * t*t );

		float x = 3.0*u / (2.0*u - 8.0*v + 4.0);
		float y = 2.0*v / (2.0*u - 8.0*v + 4.0);
		float z = 1.0 - x - y;

		float Y = 1.0;
		float X = Y / y * x;
		float Z = Y / y * z;

		const mat3 XYZtoRGB = mat3(3.2404542, -1.5371385, -0.4985314,
							-0.9692660,  1.8760108,  0.0415560,
							 0.0556434, -0.2040259,  1.0572252);

		return max(vec3(0.0), (vec3(X,Y,Z) * XYZtoRGB) * pow(t * 0.0004, 4.0));
	}

	const float tMod = 0.75;

	void main(void)
	{
		vec2 uvEmit = gl_FragCoord.xy / emitTexSize;

		vec4 emitTexColor = texture(emitTex, uvEmit);
		float hmVal = texture(hmTexBlur, uvEmit).x;

		float mixVal = smoothstep(0.0, 1.0, 1.0 - hmVal);

		vec4 bbColor = vec4(blackbody(tMod), 0.0);

		vec4 newEmitColor = mix(emitTexColor, bbColor, mixVal);
		//vec4 newEmitColor = vec4(hmVal, hmVal, hmVal, 1.0);

		gl_FragColor = newEmitColor;
	}
]]


--- Functions
local function CreateEmissionObjects()
	local emTexInfo = gl.TextureInfo("$ssmf_emission")
	emitTexX, emitTexY = emTexInfo.xsize, emTexInfo.ysize

	emitTexOrig = gl.CreateTexture(emitTexX, emitTexY, {
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})

	emitTexNew = gl.CreateTexture(emitTexX, emitTexY, {
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})

	emitFBO = gl.CreateFBO({
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})

	emitTexShader = LuaShader({
		definitions = {
			"#version 150 compatibility\n",
		},
		fragment = emitTexShaderFrag,
		uniformFloat = {
			emitTexSize = {emitTexX, emitTexY},
		},
		uniformInt = {
			emitTex = 0,
			hmTexBlur = 1,
		},

	}, "Lava DrawGadget: Emit Texture Shader")
	emitTexShader:Initialize()
end

local myCutOffUniforms = [[
	#line 66
	uniform sampler2D heightMap;
	uniform vec2 heightMapDim;
	uniform float cutOffHeight;
	uniform vec2 heightMinMax;
]]

local myDoCutOffDef = [[
	#line 74
	////////////////////////////////////////////////
	vec4 bilinearTexture2D(sampler2D tex, vec2 res, vec2 uv)
	{
		vec2 st = uv * res - 0.5;

		vec2 iuv = floor( st );
		vec2 fuv = fract( st );

		vec4 a = texture( tex, (iuv+vec2(0.5,0.5))/res );
		vec4 b = texture( tex, (iuv+vec2(1.5,0.5))/res );
		vec4 c = texture( tex, (iuv+vec2(0.5,1.5))/res );
		vec4 d = texture( tex, (iuv+vec2(1.5,1.5))/res );

		return mix(
					mix( a, b, fuv.x),
					mix( c, d, fuv.x), fuv.y
		);
	}
	////////////////////////////////////////////////

	////////////////////////////////////////////////
	#define HM2WORLD 8.0
	vec4 DoCutOff(vec4 color) {
		//vec2 uv = gl_FragCoord.xy / heightMapDim * vec2(HM2WORLD);
		vec2 uv = gl_FragCoord.xy / heightMapDim;

		float height = heightMinMax.x; //min height

		//bvec4 okCoords = bvec4(uv.x >= 0.0, uv.x <= 1.0, uv.y >= 0.0, uv.y <= 1.0); //Required since lava world rectangle will go beyond regular map. Or CLAMP_TO_EDGE does it for us already? TEST!!!
		//if (all(okCoords))
			height = bilinearTexture2D(heightMap, heightMapDim, uv).x; //update height if it makes sense

/*
		if (height >= cutOffHeight)
			return vec4(height);
		else
			return vec4(heightMinMax.x);
*/
		//return vec4(1.0 - step(cutOffHeight, height));
		return vec4(fwidth(step(cutOffHeight, height)));
/*
		const float eps = 5.0;
		
		bvec2 okHeight = bvec2(height <= cutOffHeight + eps, height >= cutOffHeight - eps);
		return vec4(float(all(okHeight)));
*/		
	}
	////////////////////////////////////////////////
]]

local myCombUniforms = [[
	uniform vec2 heightMinMax;
]]

local myDoToneMapping = [[
	////////////////////////////////////////////////
	vec4 DoToneMapping(vec4 color) {
		//return vec4( (color.x - heightMinMax.x) / (heightMinMax.y - heightMinMax.x) );
		return vec4(color.x);
	}
	////////////////////////////////////////////////
]]

local doCombineFunc = [[
	////////////////////////////////////////////////
	vec4 DoCombine(in vec4 colorTexIn, in vec4 colorGauss) {
		return colorGauss;
		if (colorTexIn.x == 1.0)
			return colorTexIn;
		else
			return colorGauss / gaussIn.length();
	}
	////////////////////////////////////////////////
]]


local function CreateHeightMapObjects()
	local hmTexInfo = gl.TextureInfo("$heightmap")
	hmTexX, hmTexY = hmTexInfo.xsize, hmTexInfo.ysize

	hmTexBlur = gl.CreateTexture(hmTexX, hmTexY, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		format = GL_LUMINANCE32F_ARB,
	})

	hmFBO = gl.CreateFBO({
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})

	hmBlur = BloomEffect({
		texIn = "$heightmap",
		texOut = hmTexBlur,
		gParams = {
			[1] = {
				-- texIn = texIn, --will be set by BloomEffect()
				-- texOut = texOut, --will be set by BloomEffect()
				-- unusedTexId MUST be set in case of multiple gausses
				unusedTexId = 16,
				downScale = 1,
				linearSampling = false,
				sigma = 0.1,
				halfKernelSize = 5,
				valMult = 1.0,
				repeats = 1,
				blurTexIntFormat = GL_LUMINANCE32F_ARB,
			},
		},
		cutOffTexFormat = GL_LUMINANCE32F_ARB,

		doCutOffFunc = myDoCutOffDef,
		cutOffUniforms = myCutOffUniforms,

		doCombineFunc = doCombineFunc,
		doToneMappingFunc = myDoToneMapping,
		combUniforms = myCombUniforms,

		bloomOnly = true,
	})

	hmBlur:Initialize()

	local cutoffShader, displayShader = hmBlur:GetShaders()

	cutoffShader:ActivateWith( function()
		cutoffShader:SetUniformInt("heightMap", 0)
	end)

	cutoffShader:ActivateWith( function()
		cutoffShader:SetUniformFloat("heightMapDim", hmTexX, hmTexY)
	end)

end

local function InitEmissionObjects()
	if (gl.Texture(0, "$ssmf_emission")) then
		emitFBO.color0 = emitTexOrig
		gl.ActiveFBO(emitFBO, function()
			gl.DepthTest(false)
			gl.Blending(false)
			gl.TexRect(0, 0, emitTexX, emitTexY)
		end)

		emitFBO.color0 = emitTexNew
		--[[
		gl.ActiveFBO(emitFBO, function()
			gl.DepthTest(false)
			gl.Blending(false)
			gl.TexRect(0, 0, emitTexX, emitTexY)
		end)
		]]--
		gl.Texture(0, false)
		Spring.SetMapShadingTexture("$ssmf_emission", emitTexNew)
	end
end

local function UpdateHeightMapObjects()
	local cutoffShader, displayShader = hmBlur:GetShaders()

	local minHeight, maxHeight = Spring.GetGroundExtremes()
	Spring.Echo(minHeight, maxHeight)
	cutoffShader:ActivateWith( function()
		cutoffShader:SetUniformFloat("cutOffHeight", 0.0)
		cutoffShader:SetUniformFloat("heightMinMax", minHeight, maxHeight)
	end)

	displayShader:ActivateWith( function()
		displayShader:SetUniformFloat("heightMinMax", minHeight, maxHeight)
	end)

	gl.Texture(0, "$heightmap")
	hmBlur:Execute(false) -- false = "world space"
	gl.Texture(0, false)
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

local function CreateLavaSurfaceDrawList()
	lavaSurfaceDrawList = gl.CreateList(function ()
		--gl.BeginEnd(GL.QUADS, DrawFlatMesh, -2 * Game.mapX * 512, -2 * Game.mapY * 512,  3 * Game.mapX * 512, 3 * Game.mapY * 512, 64, 1)
		gl.BeginEnd(GL.QUADS, DrawFlatMesh, 0, 0,  1 * Game.mapX * 512, 1 * Game.mapY * 512, 64, 1)
	end)
end

local function DestroyLavaSurfaceDrawList()
	gl.DeleteList(lavaSurfaceDrawList)
end

local function DestroyEmissionObjects()
	gl.DeleteTexture(emitTexOrig)
	gl.DeleteTexture(emitTexNew)

	gl.DeleteFBO(emitFBO)

	emitTexShader:Finalize()
end

local function DestroyHeightMapObjects()
	gl.DeleteTexture(hmTexBlur)

	gl.DeleteFBO(hmFBO)

	hmBlur:Finalize()
end

local function SetWaterRenderingMode()
	Spring.SetDrawWater(true)
	Spring.SetDrawGround(true)
	Spring.SetMapRenderingParams({voidWater = true, voidGround = true})
end

function gadget:Initialize()
	SetWaterRenderingMode()
	CreateHeightMapObjects()
	CreateEmissionObjects()	
	CreateLavaSurfaceDrawList()
end

function gadget:Shutdown()
	Spring.SetMapShadingTexture("$ssmf_emission", "")
	DestroyHeightMapObjects()
	DestroyEmissionObjects()	
	DestroyLavaSurfaceDrawList()
end


local initEmissionObjects = true
local updateHeightMapObjects = true
function gadget:DrawGenesis()
	if initEmissionObjects then
		Spring.Echo("initEmissionObjects")
		InitEmissionObjects()
		initEmissionObjects = false
	end
	if updateHeightMapObjects then
		Spring.Echo("updateHeightMapObjects")
		UpdateHeightMapObjects()
		updateHeightMapObjects = false
	end

	gl.ActiveFBO(emitFBO, function()
		gl.DepthTest(false)
		gl.Blending(false)

		gl.Texture(0, emitTexOrig)
		gl.Texture(1, hmTexBlur)
		emitTexShader:ActivateWith( function ()
			gl.TexRect(-1, -1, 1, 1)
			--gl.TexRect(0, 0, 1 * Game.mapX * 512, 1 * Game.mapY * 512)
		end)
		gl.Texture(0, false)
		gl.Texture(1, false)
		--gl.Clear(GL.COLOR_BUFFER_BIT)
		--gl.Clear(GL.COLOR_BUFFER_BIT, math.fmod(Spring.GetGameFrame(), 60) / 60, 0, 0, 0)
		--gl.Texture(0, hmTexBlur)
		--gl.TexRect(0, 0, emitTexX, emitTexY)
		--gl.TexRect(-1, -1, 1, 1)

	end)

end

function gadget:DrawWorld()
	--gl.Texture(0, "$heightmap")
	gl.Texture(0, hmTexBlur)
	--gl.DepthTest(true)
	gl.CallList(lavaSurfaceDrawList)
	--gl.Texture(0, false)
end

--[[
function gadget:DrawScreenEffects()
	gl.Texture(0, hmTexBlur)
	local sx, sy = Spring.GetViewGeometry()
	local sx2, sy2 = sx / 2, sy / 2
	local size = 300

	gl.TexRect(sx2 - size, sy2 - size, sx2 + size, sy2 + size)
	--gl.TexRect(0, 0, sx, sy)
	gl.Texture(0, false)
end
]]--

function gadget:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	Spring.Echo("UnsyncedHeightMapUpdate")
	updateHeightMapObjects = true
end