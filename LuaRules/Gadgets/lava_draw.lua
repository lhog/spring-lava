function gadget:GetInfo()
	return {
		name      = "Lava Draw Gadget",
		desc      = "Lava Draw Gadget",
		author    = "ivand",
		date      = "2018-2019",
		license   = "GNU GPL, v2 or later",
		layer     = -3,
		enabled   = true
	}
end
-----------------

if (gadgetHandler:IsSyncedCode()) then
	return
end

local LuaShader = VFS.Include("LuaRules/Libs/LuaShader/LuaShader.lua")

local function DisableEngineWaterDrawing()
	Spring.SetDrawWater(true)
	Spring.SetDrawGround(true)
	Spring.SetMapRenderingParams({voidWater = true, voidGround = true})
end


function gadget:Initialize()
	DisableEngineWaterDrawing()
end

function gadget:Updade(dt)
	
end

function gadget:DrawWorldPreUnit()
	
end

function gadget:DrawGenesis()
	
end

function gadget:Shutdown()
	
end