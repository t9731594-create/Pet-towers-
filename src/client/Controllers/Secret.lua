-- Secret pets on the client: the floor's lantern glows brighter while the chime builds, a short icon
-- banner when the pet appears, and the lantern goes back to how it was when the pet has gone.
-- Kindness rule (bible B2): no countdown, no clock, no words. Nothing here shows how long is left.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Config = require(Shared.Config)
local Ui = require(script.Parent.Ui)

local S = Config.Economy.Secret
local COLOR = Ui.RarityColor.Secret
local LIGHT_FULL, LIGHT_RANGE = 6, 60 -- PointLight at full glow
local HALO_FULL, HALO_CLEAR = 2.2, 0.55 -- halo size (x the lantern) and transparency at full glow
local SPARKLES_FULL = 14 -- particles per second at full glow

local Secret = { glows = {} } -- glows[floor] = { key, light, halo, sparkles, tweens }

local function lanternOf(floor)
	local world = workspace:WaitForChild("PetTowerWorld", 10)
	local folder = world and world:WaitForChild("Floor" .. floor, 10)
	local lantern = folder and folder:WaitForChild("Lantern", 10)
	if lantern and lantern:IsA("BasePart") then return lantern end
end

-- Everything the glow adds is made here, on this client, as children of the lantern. The lantern's own
-- colour and size are never touched, so taking the children away puts it back exactly as it was.
local function clear(floor)
	local g = Secret.glows[floor]
	if not g then return end
	Secret.glows[floor] = nil
	for _, tween in ipairs(g.tweens) do tween:Cancel() end
	for _, inst in ipairs({ g.light, g.halo, g.sparkles }) do inst:Destroy() end
end

local function lerp(a, b, t) return a + (b - a) * t end

-- Build the glow from `progress` (0 = just started, 1 = full) up to full over `seconds`.
local function glow(floor, key, progress, seconds)
	local old = Secret.glows[floor]
	if old and old.key == key and seconds <= 0 then return end -- already glowing for this chime
	local lantern = lanternOf(floor)
	clear(floor)
	if not lantern then return end
	local size = lantern.Size.X

	local light = Instance.new("PointLight")
	light.Name = "SecretGlow"
	light.Color = COLOR
	light.Range = LIGHT_RANGE
	light.Brightness = lerp(0, LIGHT_FULL, progress)
	light.Parent = lantern

	local halo = Instance.new("Part")
	halo.Name = "SecretHalo"
	halo.Shape = Enum.PartType.Ball
	halo.Anchored = true
	halo.CanCollide = false
	halo.CanTouch = false
	halo.CanQuery = false
	halo.CastShadow = false
	halo.Material = Enum.Material.Neon
	halo.Color = COLOR
	local s0 = size * lerp(1.05, HALO_FULL, progress)
	halo.Size = Vector3.new(s0, s0, s0)
	halo.Transparency = lerp(1, HALO_CLEAR, progress)
	halo.CFrame = lantern.CFrame
	halo.Parent = lantern

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "SecretSparkles"
	sparkles.Color = ColorSequence.new(COLOR)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.8, 0)
	sparkles.Lifetime = NumberRange.new(2, 3)
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Rate = lerp(0, SPARKLES_FULL, progress)
	sparkles.Parent = lantern

	local g = { key = key, light = light, halo = halo, sparkles = sparkles, tweens = {} }
	Secret.glows[floor] = g
	if seconds > 0 then
		local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		local full = size * HALO_FULL
		g.tweens[1] = TweenService:Create(light, info, { Brightness = LIGHT_FULL })
		g.tweens[2] = TweenService:Create(halo, info, { Size = Vector3.new(full, full, full), Transparency = HALO_CLEAR })
		g.tweens[3] = TweenService:Create(sparkles, info, { Rate = SPARKLES_FULL })
		for _, tween in ipairs(g.tweens) do tween:Play() end
	end
end

function Secret.init()
	local gui = Ui.screen("Secret", 9)
	-- below the FX banner (which sits at y 120..160), same look: a symbol and the floor number
	local banner = Ui.label(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 166), Size = UDim2.new(0.6, 0, 0, 44),
		Text = "", TextColor3 = COLOR, Visible = false })
	local shown = 0
	local function show(floor)
		shown = shown + 1
		local mine = shown
		banner.Text = "o * " .. floor .. " * o"
		banner.Visible = true
		task.delay(6, function() if shown == mine then banner.Visible = false end end)
	end

	Remotes.get("SecretChime").OnClientEvent:Connect(function(c)
		if type(c) ~= "table" or type(c.floor) ~= "number" then return end
		local floor = c.floor
		local key = tostring(c.at)
		if c.phase == "glow" and type(c.at) == "number" then
			-- a player who joins part-way through starts part-way up
			local left = math.clamp(c.at - Ui.now(), 0, S.GlowSeconds)
			glow(floor, key, 1 - left / S.GlowSeconds, left)
		elseif c.phase == "here" then
			local g = Secret.glows[floor]
			if not (g and g.key == key) then glow(floor, key, 1, 0) end -- joined mid-visit: full glow at once
			show(floor)
		elseif c.phase == "gone" then
			clear(floor)
		end
	end)
end

return Secret
