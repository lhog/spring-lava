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

tideRhym = {}
tideIndex = 1
tideContinueFrame = 0
lavaLevel = 3
lavaGrow =0
gameframe=0

function gadget:Initialize()
	_G.lavaLevel = lavaLevel
	_G.frame = 0
	addTideRhym (0, 0, 5*6000)
	-- addTideRhym (150, 0.25, 3)
	-- addTideRhym (-20, 0.25, 5*60)
	-- addTideRhym (150, 0.25, 5)
	-- addTideRhym (-20, 1, 5*60)
	-- addTideRhym (180, 0.5, 60)
	-- addTideRhym (240, 0.2, 10)
end


function addTideRhym (targetLevel, speed, remainTime)
	local newTide = {}
	newTide.targetLevel = targetLevel
	newTide.speed = speed
	newTide.remainTime = remainTime
	table.insert (tideRhym, newTide)
end


function updateLava ()
	if (lavaGrow < 0 and lavaLevel < tideRhym[tideIndex].targetLevel)
		or (lavaGrow > 0 and lavaLevel > tideRhym[tideIndex].targetLevel) then
		tideContinueFrame = gameframe + tideRhym[tideIndex].remainTime*30
		lavaGrow = 0
		--Spring.Echo ("Next LAVA LEVEL change in " .. (tideContinueFrame-gameframe)/30 .. " seconds")
	end

	if (gameframe == tideContinueFrame) then
		tideIndex = tideIndex + 1
		if (tideIndex > table.getn (tideRhym)) then
			tideIndex = 1
		end
		--Spring.Echo ("tideIndex=" .. tideIndex .. " target=" ..tideRhym[tideIndex].targetLevel )
		if  (lavaLevel < tideRhym[tideIndex].targetLevel) then
			lavaGrow = tideRhym[tideIndex].speed
		else
			lavaGrow = -tideRhym[tideIndex].speed
		end
	end
end

local function clamp(low, x, high)
	return math.min(math.max(x, low), high)
end

function gadget:GameFrame (f)
	_G.lavaLevel = lavaLevel + clamp(-0.95, math.sin(f / 30), 0.95) * 2.1 --clamp to avoid jittering when sin(x) is around +-1
	_G.frame = f

	if (f%10==0) then
		lavaDeathCheck()
	end

	updateLava ()
	lavaLevel = lavaLevel+lavaGrow

	local x = math.random(1,Game.mapX*512)
	local z = math.random(1,Game.mapY*512)
	local y = Spring.GetGroundHeight(x,z)
	if y  < lavaLevel then
		Spring.SpawnCEG("lavaburst", x, lavaLevel, z)
	end
end

function lavaDeathCheck ()
local all_units = Spring.GetAllUnits()
	for i in ipairs(all_units) do
		local x,y,z = Spring.GetUnitPosition(all_units[i])
		if (y ~= nil) then
			if (y and y < lavaLevel) then
				Spring.AddUnitDamage(all_units[i], 50)
			end
		end
	end
end

local DAMAGE_EXTSOURCE_WATER = -5

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID)
    if (weaponDefID ~= DAMAGE_EXTSOURCE_WATER) then
           -- not water damage, do not modify
           return damage, 1.0
    end

    local unitDef = UnitDefs[unitDefID]
    local moveDef = unitDef.moveDef

    if (moveDef == nil or moveDef.family ~= "hover") then
          -- not a hovercraft, do not modify
          return damage, 1.0
    end

    return 0.0, 1.0
end


else --- UNSYCNED:

local lavaTex = ":la:LuaRules/images/lavacolor3.png"
local heightTex = "$heightmap"

local shader
local timeLoc

function gadget:Initialize()
	Spring.SetDrawWater(true)
	Spring.SetDrawGround(true)
	Spring.SetMapRenderingParams({voidWater = true, voidGround = true})

	if (gl.CreateShader == nil) then
		Spring.Echo("Shaders not found, reverting to non-GLSL lava gadget")
	else
		shader = gl.CreateShader({

			uniform = {
				mapsizex = Game.mapSizeX,
				mapsizez = Game.mapSizeZ,
				minHeight = Spring.GetGroundExtremes(),
			},
			uniformInt = {
				lavacolor =0,
				height = 1,
			},

			vertex = [[
				// Application to vertex shader
				varying vec3 normal;
				varying float lavaHeight;

				uniform float mapsizex;
				uniform float mapsizez;

				varying vec2 hmuv;

				void main()
				{
					gl_TexCoord[0] = gl_MultiTexCoord0;
					normal  = gl_NormalMatrix * gl_Normal;

					lavaHeight = gl_Vertex.y;
					hmuv = vec2(gl_Vertex.x / mapsizex, gl_Vertex.z / mapsizez);

					gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
				}

			]],

			fragment = [[
				#define M_PI 3.1415926535897932384626433832795
				varying vec3 normal;
				varying float lavaHeight;

				uniform float time;
				uniform float mapsizex;
				uniform float mapsizez;
				uniform sampler2D lavacolor;
				uniform sampler2D height;

				uniform float minHeight;

				varying vec2 hmuv;


				////////////////////////////////////////////////////////////////////////////////

				#define FANCY_LAVA

				//#define CRASH_SHADER

				#ifdef CRASH_SHADER
					blabla1 + blabla2;
				#endif

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

				#if defined(FANCY_LAVA)
					#define time2 time * 0.005

					float rand(vec2 co)
					{
						float a = 12.9898;
						float b = 78.233;
						float c = 43758.5453;
						float dt = dot(co.xy ,vec2(a,b));
						float sn = mod(dt, M_PI);
						return fract(sin(sn) * c);
					}

					float noise(in vec2 n)
					{
						const vec2 d = vec2(0.0, 1.0);
						vec2 b = floor(n), f = smoothstep(vec2(0.0), vec2(1.0), fract(n));
						return mix(mix(rand(b), rand(b + d.yx), f.x), mix(rand(b + d.xy), rand(b + d.yy), f.x), f.y);
					}

					mat2 makem2(in float theta){float c = cos(theta);float s = sin(theta);return mat2(c,-s,s,c);}

					vec2 gradn(vec2 p)
					{
						float ep = 0.1;
						float gradx = noise(vec2(p.x+ep,p.y))-noise(vec2(p.x-ep,p.y));
						float grady = noise(vec2(p.x,p.y+ep))-noise(vec2(p.x,p.y-ep));
						return vec2(gradx,grady);
					}

					#define MAX_OCTAVES 10
					#define MIN_OCTAVES 6

					float flow(in vec2 p, int octaves)
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
								rz += (sin(noise(p)*5.0)*0.5+0.5)/z;

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
				#endif

				////////////////////////////////////////////////////////////////////////////////////

				const vec3 SHORE_COLOR = vec3(0.96, 0.13, 0.02);

				void main()
				{
					#if defined(FANCY_LAVA)
						const vec3 FANCYLAVA_COLOR = vec3(0.45, 0.1, 0.02);

						const vec2 UV_MULT = vec2(32.0);
						vec2 p = gl_TexCoord[0].st * vec2(UV_MULT);

						vec3 worldVertex = vec3(hmuv.s * mapsizex, lavaHeight, hmuv.t * mapsizez);
						float cameraDist = 1.0 / gl_FragCoord.w; //magically returns distance from the camera origin to this pixel

						const vec2 CAM_MINMAX = vec2(200.0, 6600.0);

						// LOG scaling doesn't work as well as expected. TODO, figure something out, because linear scaling overdraw things.
						//float logMul = (MAX_OCTAVES - MIN_OCTAVES) / log(CAM_MINMAX.y - CAM_MINMAX.x + 1.0);
						//int octaves = int(MAX_OCTAVES - floor(logMul * log( clamp(cameraDist, CAM_MINMAX.x, CAM_MINMAX.y) - CAM_MINMAX.x + 1.0 )));

						// Use linear scaling instead
						int octaves = int(MAX_OCTAVES - floor((MAX_OCTAVES - MIN_OCTAVES) * clamp(cameraDist, CAM_MINMAX.x, CAM_MINMAX.y) / CAM_MINMAX.y));

						float rz = flow(p, octaves);
						vec3 col = FANCYLAVA_COLOR / rz;
						vec4 vlavacolor = vec4(col, 1.0);
						const float CONSTRAST_POW = 1.6;
					#else
						const vec2 UV_MULT = vec2(16.0);
						vec2 p = gl_TexCoord[0].st * vec2(UV_MULT);

						vec2 distortion;
						distortion.x = p.s + sin(p.s * 20 + time / 50) / 350;
						distortion.y = p.t + sin(p.t * 20 + time / 73) / 400;
						vec4 vlavacolor = texture2D(lavacolor, distortion) + 0.1;

						vec2 distortion2;
						distortion2 = (distortion + M_PI * 12) * M_PI / 9;
						vec4 vlavacolor2 = texture2D(lavacolor, distortion2) * 2 + 0.1;
						vlavacolor *= vlavacolor2;
						const float CONSTRAST_POW = 0.8;
					#endif

					vlavacolor.rgb = pow(vlavacolor.rgb, vec3(CONSTRAST_POW)); //change contrast

					const vec2 SMOOTHSTEPS = vec2(-0.0015, 0.002);
					vec2 inmap = smoothstep(SMOOTHSTEPS.x, SMOOTHSTEPS.y, hmuv) * (1.0 - smoothstep(1.0 - SMOOTHSTEPS.y, 1.0 - SMOOTHSTEPS.x, hmuv));

					float groundHeight = bilinearTexture2D(height, vec2(mapsizex / 8.0, mapsizez / 8.0), hmuv).r;
					float factor = smoothstep(0.0, 1.0, (groundHeight - minHeight) / (lavaHeight - minHeight)) * min(inmap.x, inmap.y);

					const float FACTOR_POW = 8.0;
					const float FACTOR_AMP = 1.1;

					gl_FragColor = mix(vlavacolor, vec4(SHORE_COLOR.rgb, 0.0), pow(FACTOR_AMP * factor, FACTOR_POW));
					//gl_FragColor = vec4(0.0);
				}
			]],
		})
		if (shader == nil) then
			Spring.Echo(gl.GetShaderLog())
			Spring.Echo("LAVA shader compilation failed, falling back to GL Lava. See infolog for details")
		else
			timeLoc = gl.GetUniformLocation(shader, "time")
			Spring.Echo('Lava shader compiled successfully! Yay!')
		end
	end
end

function gadget:DrawWorldPreUnit()
    if (SYNCED.lavaLevel) then
		DrawGroundHuggingSquare(-2*Game.mapX*512, -2*Game.mapY*512,  3*Game.mapX*512, 3*Game.mapY*512, SYNCED.lavaLevel) --***map.width bla
		--DrawGroundHuggingSquare(-0*Game.mapX*512, -0*Game.mapY*512,  1*Game.mapX*512, 1*Game.mapY*512, SYNCED.lavaLevel) --***map.width bla
	end
end

function DrawGroundHuggingSquare(x1, z1, x2, z2, HoverHeight)
	if (shader==nil) then
		--Spring.Echo('no shader, fallback renderer working...')
		gl.PushAttrib(gl.ALL_ATTRIB_BITS)
		gl.DepthTest(true)
		gl.DepthMask(true)
		gl.Texture(":la:LuaRules/images/lavacolor3.png")-- Texture file
		gl.BeginEnd(GL.QUADS, DrawGroundHuggingSquareVertices,  x1, z1, x2, z2, 5,  HoverHeight)
		gl.Texture(false)
		gl.DepthMask(false)
		gl.DepthTest(false)
	else
		gl.PushAttrib(gl.ALL_ATTRIB_BITS)
		us=gl.UseShader(shader)

		local f=Spring.GetGameFrame()

		gl.Uniform(timeLoc, f)

		gl.Texture(0, lavaTex)-- Texture file
		gl.Texture(1, heightTex)-- Texture file

		gl.DepthTest(true)
		gl.DepthMask(true)

		gl.BeginEnd(GL.QUADS, DrawGroundHuggingSquareVertices, x1, z1, x2, z2, 1, HoverHeight)

		gl.DepthTest(false)
		gl.DepthMask(false)

		gl.UseShader(0)
	end
	gl.PopAttrib()
end


function DrawGroundHuggingSquareVertices(x1, z1, x2, z2, tiles, HoverHeight)
	local y = HoverHeight

	local xstep = (x2 - x1) / tiles
	local zstep = (z2 - z1) / tiles

	for x = x1, x2 - 1, xstep do
		for z = z1, z2 - 1, zstep do
		gl.TexCoord(tiles * x / (x2 - 1), tiles * z / (z2 - 1))
		gl.Vertex(x, y, z)

		gl.TexCoord(tiles * x / (x2 - 1), tiles * (z + zstep) / (z2 - 1))
		gl.Vertex(x, y, z + zstep)

		gl.TexCoord(tiles * (x + xstep) / (x2 - 1), tiles * (z + zstep) / (z2 - 1))
		gl.Vertex(x + xstep, y, z + zstep)

		gl.TexCoord(tiles * (x + xstep) / (x2 - 1), tiles * z / (z2 - 1))
		gl.Vertex(x + xstep, y, z)
		end
	end
end

end--ende unsync