local LuaShader = VFS.Include("LuaRules/Libs/LuaShader/LuaShader.lua")

--local GL_RGBA = 0x1908
local GL_RGBA32F = 0x8814
local GL_RGB32F = 0x8815
local GL_RGBA16F = 0x881A
local GL_RGB16F = 0x881B


local function new(class, params)
	local TEX_SIZE_DEF = 1024
	local TILE_SIZE_DEF = 32
	local UV_MULT_DEF = 32
	local UPD_INT_DEF = 0.2

	return setmetatable(
	{
		texSizeX = params.texSizeX or TEX_SIZE_DEF,
		texSizeY = params.texSizeY or TEX_SIZE_DEF,
		tileSize = params.tileSize or TILE_SIZE_DEF,
		uvMul = params.uvMult or UV_MULT_DEF,
		updateInterval = params.updateInterval or UPD_INT_DEF,
		textureFormat = params.textureFormat or GL_RGB16F,
		doMipMaps = params.doMipMaps or false,
		
		oldTime = 0,
		
		outTex = nil,
		outFBO = nil,
		
		heightMapShader = nil,
		
	}, class)
end

local HeightMapGenerator = setmetatable({}, {
	__call = function(self, ...) return new(self, ...) end,
})
HeightMapGenerator.__index = HeightMapGenerator

function HeightMapGenerator:Initialize()
	self.outTex = gl.CreateTexture(self.blurTexSizeX, self.blurTexSizeY, {
		format = self.blurTexIntFormat,
		border = false,
		min_filter = (self.doMipMaps and GL_LINEAR_MIPMAP_LINEAR) or GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.REPEAT,
		wrap_t = GL.REPEAT,
	})
	
	self.outFBO = gl.CreateFBO({
		color0 = self.outTex,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})
	
	local fragCodeFN = "LuaRules/Libs/LuaShader/Libs/LavaDrawers/Shaders/HeightMapGenerator.frag"
	if not VFS.FileExists(fragCodeFN) then
		Spring.Echo(string.format("LavaDraw: HeightMapGenerator. Error loading fragment shader file. File %s not found", fragCodeFN))
		return
	end
	
	local fragCode = VFS.LoadFile(fragCodeFN)
	self.heightMapShader = LuaShader({
		definitions = {
			"#version 150 compatibility\n",
			"HEIGHTMAPGENERATOR_MAIN 1"
		},
		fragment = fragCode,
		uniformFloat = {
			tileSize = self.tileSize,
			uvMul = self.uvMult,
			texSize = {self.texSizeX, self.texSizeX},
			gameFrame = 0,
		},
		uniformInt = {
			tex = self.unusedTexId,
		},

	}, "LavaDraw: HeightMapGenerator")
	self.heightMapShader:Initialize()
end

function HeightMapGenerator:GetTextureHandle()
	return self.outTex
end

local function DoUpdateTimed(self)
	--bla
end

function HeightMapGenerator:UpdateTimed(dt)
	local newTime = self.oldTime + dt 
	if newTime >= self.updateInterval then
		DoUpdateTimed(self)
		self.oldTime = 0
		return true
	else
		self.oldTime = newTime
		return false
	end
end

function HeightMapGenerator:Finalize()
	gl.DeleteTexture(self.outTex)
	gl.DeleteFBO(self.outFBO)
	self.heightMapShader:Finalize()
end