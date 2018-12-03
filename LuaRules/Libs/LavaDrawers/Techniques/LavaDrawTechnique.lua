local function new(class)
	return setmetatable(
	{
	}, class)
end

local LavaDrawTechnique = setmetatable({}, {
	__call = function(self, ...) return new(self, ...) end,
})
LavaDrawTechnique.__index = LavaDrawTechnique

