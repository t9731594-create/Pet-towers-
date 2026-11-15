-- Secret pets on the client: the floor's lantern glows brighter while the chime builds, a short icon
-- banner when the pet appears, and the lantern goes back to how it was when the pet has gone.
-- Kindness rule (bible B2): no countdown, no clock, no words. Nothing here shows how long is left.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Config = require(Shared.Config)
local WildView = require(Shared.Logic.WildView)
local Ui = require(script.Parent.Ui)

local S = Config.Economy.Secret
local COLOR = Ui.RarityColor.Secret
local LIGHT_FULL, LIGHT_RANGE = 6, 60 -- PointLight at full glow
local HALO_FULL, HALO_CLEAR = 2.2, 0.55 -- halo size (x the lantern) and transparency at full glow
local SPARKLES_FULL = 14 -- particles per second at full glow

-- glows[floor] = { key, lantern, light, halo, sparkles, tweens }: what is drawn now.
-- chimes[floor] = { phase, at, leaves, key }: the chime going on now, remembered so the glow can be put
-- on a lantern that loads later (streaming: a far floor's lantern is not there at chime time).
-- pillarAt[floor] = os.clock() of the last "pillar" banner for a Secret pet on that floor.
local Secret = { glows = {}, chimes = {}, pillarAt = {} }

local function lanternOf(floor)
	-- no waiting: with streaming on, a far floor's lantern is simply not loaded yet
	local world = workspace:FindFirstChild("PetTowerWorld")
	local folder = world and world:FindFirstChild("Floor" .. floor)
	local lantern = folder and folder:FindFirstChild("Lantern")
	if lantern and lantern:IsA("BasePart") then return lantern end
end

-- Everything the glow adds is made here, on this client, as children of the lantern. The lantern's own
-- colour and size are never touched, so taking the children away puts it back exactly as it was.
local function clear(floor)
	local g = Secret.glows[floor]
	if not g then return end
	Secret.glows[floor] = nil
	-- the lantern may have been streamed out with everything on it: nothing here may stop the rest
	for _, tween in ipairs(g.tweens) do pcall(function() tween:Cancel() end) end
	for _, inst in ipairs({ g.light, g.halo, g.sparkles }) do pcall(function() inst:Destroy() end) end
end

local function lerp(a, b, t) return a + (b - a) * t end

-- Build the glow on `lantern` from `progress` (0 = just started, 1 = full) up to full over `seconds`.
local function glow(floor, key, lantern, progress, seconds)
	clear(floor)
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

	local g = { key = key, lantern = lantern, light = light, halo = halo, sparkles = sparkles, tweens = {} }
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

-- Make what is drawn on this floor's lantern match the remembered chime. Called on every chime and once
-- a second, so a lantern that loads later (the player arrives on the floor) gets its glow then.
local function refresh(floor)
	local c = Secret.chimes[floor]
	local progress, seconds
	if c then progress, seconds = WildView.glowAt(c.phase, c.at, c.leaves, Ui.now(), S.GlowSeconds) end
	if not progress then
		Secret.chimes[floor] = nil
		clear(floor)
		return
	end
	local lantern = lanternOf(floor)
	if not lantern then clear(floor) return end -- not loaded here (yet): try again on the next pass
	local g = Secret.glows[floor]
	if g and g.key == c.key and g.lantern == lantern and g.light.Parent == lantern then return end -- already drawn
	glow(floor, c.key, lantern, progress, seconds)
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

	-- The pet's pillar of light brings its own banner (FX draws "* floor *" in the Secret colour). Note
	-- when it comes so this controller does not draw a second one.
	Remotes.get("Banner").OnClientEvent:Connect(function(b)
		if type(b) ~= "table" or b.kind ~= "pillar" or b.rarity ~= S.Rarity or type(b.floor) ~= "number" then return end
		Secret.pillarAt[b.floor] = os.clock()
	end)

	Remotes.get("SecretChime").OnClientEvent:Connect(function(c)
		if type(c) ~= "table" or type(c.floor) ~= "number" then return end
		local floor = c.floor
		local key = tostring(c.at)
		if c.phase == "glow" and type(c.at) == "number" then
			-- a player who joins part-way through starts part-way up (WildView.glowAt)
			Secret.chimes[floor] = { phase = "glow", at = c.at, leaves = c.leaves, key = key }
			refresh(floor)
		elseif c.phase == "here" then
			-- same key as the glow: a lantern already glowing just carries on to full
			Secret.chimes[floor] = { phase = "here", at = c.at, leaves = c.leaves, key = key }
			refresh(floor)
			-- One banner: wait a moment for the pillar banner (it is sent just before this chime, on another
			-- remote), and show our own only if none came (a player who arrived in the middle of the visit).
			task.delay(1, function()
				local at = Secret.pillarAt[floor]
				if WildView.secretBanner(at and (os.clock() - at) or nil) then show(floor) end
			end)
		elseif c.phase == "gone" then
			Secret.chimes[floor] = nil
			clear(floor)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local floors = {}
			for floor in pairs(Secret.chimes) do floors[#floors + 1] = floor end
			for floor in pairs(Secret.glows) do if not Secret.chimes[floor] then floors[#floors + 1] = floor end end
			for _, floor in ipairs(floors) do
				local ok, err = pcall(refresh, floor)
				if not ok then warn("[PetTower] Secret glow: " .. tostring(err)) end
			end
		end
	end)
end

return Secret
