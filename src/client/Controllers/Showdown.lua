-- Guardian showdown: one meter, one cheer ring per second. Tap on the beat to cheer.
-- Wild showdowns (kind = "wild", Amendment 1) reuse it with a smaller ring and meter and no end time.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local E = require(Shared.Config).Economy
local Ui = require(script.Parent.Ui)
local Rings = require(script.Parent.Rings)
local WildView = require(Shared.Logic.WildView)

local Showdown = { rings = nil, key = nil, pet = nil, lastBeat = nil, seen = 0 }
local BEAT = E.Showdown.BeatSeconds
local QUIET = 5 -- seconds without news before a wild ring (which has no end time) closes by itself

local function wildController()
	local m = script.Parent:FindFirstChild("WildShowdown")
	return m and require(m)
end

function Showdown.init()
	local gui = Ui.screen("Showdown", 4)
	-- Rings are drawn inside this frame; its UIScale makes a wild ring small (Rings.lua sizes are fixed).
	local stage = Instance.new("Frame")
	stage.AnchorPoint = Vector2.new(0.5, 0.5) stage.Position = UDim2.fromScale(0.5, 0.5) stage.Size = UDim2.fromScale(1, 1)
	stage.BackgroundTransparency = 1 stage.Parent = gui
	local scale = Instance.new("UIScale") scale.Parent = stage
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0) bar.Position = UDim2.new(0.5, 0, 0, 90) bar.Size = UDim2.new(0.5, 0, 0, 22)
	bar.BackgroundColor3 = Color3.fromRGB(60, 60, 70) bar.Visible = false bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1) fill.BackgroundColor3 = Color3.fromRGB(255, 200, 90) fill.BorderSizePixel = 0 fill.Parent = bar
	local count = Ui.label(bar, { Position = UDim2.new(1, 8, 0, -4), Size = UDim2.fromOffset(60, 30), Text = "" })
	local grade = Ui.label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(240, 44), Text = "", Visible = false })
	local help = Instance.new("TextButton")
	help.AnchorPoint = Vector2.new(0.5, 1) help.Position = UDim2.new(0.5, 0, 1, -24) help.Size = UDim2.fromOffset(96, 96) -- 48 px or more
	help.Text = "?!" help.Font = Enum.Font.FredokaOne help.TextScaled = true help.BackgroundColor3 = Color3.fromRGB(255, 170, 90)
	help.Visible = false help.Parent = gui
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0.3, 0) corner.Parent = help

	local cheer = Remotes.get("Cheer")
	local function stop()
		if Showdown.rings then Showdown.rings.stop() Showdown.rings = nil end
		Showdown.key = nil
		Showdown.pet = nil
		Showdown.lastBeat = nil
		bar.Visible = false
		local wild = wildController()
		if wild then wild.showing(nil) end
		local tap = script.Parent:FindFirstChild("TrustTap")
		if tap then require(tap).setBlocked(false) end
	end
	local function begin(snap, key)
		local isWild = snap.kind == "wild"
		Showdown.key = key
		Showdown.pet = isWild and snap.petId or nil
		help.Visible = false
		local size = WildView.ringScale(snap.kind)
		scale.Scale = size
		bar.Size = UDim2.new(0.5 * size, 0, 0, 22)
		fill.BackgroundColor3 = isWild and Ui.RarityColor[snap.rarity] or Color3.fromRGB(255, 200, 90)
		local wild = wildController()
		if wild then wild.showing(Showdown.pet) end
		local tap = script.Parent:FindFirstChild("TrustTap")
		if tap then require(tap).setBlocked(true) end
		local beats = {}
		local first, last = 1, nil
		if snap.ends then
			last = math.floor((snap.ends - snap.start) / BEAT) - 1
			Showdown.lastBeat = nil
		else -- no end time: draw a window of beats from now; ShowdownState refills it
			first, last = WildView.beatWindow(Ui.now() - snap.start, BEAT)
			Showdown.lastBeat = last
		end
		for i = first, last do beats[#beats + 1] = i * BEAT end
		Showdown.rings = Rings.play({
			parent = stage, start = snap.start, beats = beats, ringTime = BEAT * 0.9, color = Color3.fromRGB(255, 220, 120),
			onTap = function(offset) cheer:FireServer(offset) end,
		})
	end
	Remotes.get("ShowdownState").OnClientEvent:Connect(function(snap)
		if snap.kind == "wild" and Showdown.pet ~= snap.petId then
			-- A wild showdown this player has not stepped into: no ring, WildShowdown may show the join icon.
			local wild = wildController()
			if wild and not wild.isIn(snap.petId) then wild.seen(snap) return end
		end
		local key = tostring(snap.kind) .. ":" .. tostring(snap.petId) .. ":" .. tostring(snap.start)
		Showdown.seen = os.clock()
		if Showdown.key ~= key then
			if Showdown.rings then Showdown.rings.stop() end
			begin(snap, key)
			if not snap.ends then
				task.spawn(function()
					while Showdown.key == key do
						task.wait(1)
						if Showdown.key == key and os.clock() - Showdown.seen > QUIET then stop() end
					end
				end)
			end
		elseif Showdown.lastBeat and WildView.needsRefill(Ui.now() - snap.start, Showdown.lastBeat, BEAT) then
			Showdown.rings.stop()
			begin(snap, key)
		end
		bar.Visible = true
		fill.Size = UDim2.fromScale(math.clamp(snap.left / snap.meter, 0, 1), 1)
		count.Text = "x" .. snap.count
	end)
	Remotes.get("CheerGrade").OnClientEvent:Connect(function(g)
		grade.Text = g == "Miss" and "" or g
		grade.TextColor3 = Ui.GradeColor[g]
		grade.Visible = true
		task.delay(0.5, function() grade.Visible = false end)
	end)
	Remotes.get("ShowdownEnd").OnClientEvent:Connect(function(result)
		if result.kind == "wild" then
			local wild = wildController()
			if wild then wild.ended(result) end
			if Showdown.pet ~= result.petId then return end -- not the ring on screen (e.g. a Guardian showdown)
		end
		-- stop() un-blocks Trust Tap, so after a wild win (the server clears NeedsPlay) the catch try can begin at once.
		stop()
		if result.kind == "guardian" and not result.won then
			help.Visible = true
			task.delay(30, function() help.Visible = false end)
		end
	end)
	help.Activated:Connect(function()
		help.Visible = false
		Remotes.get("CallHelp"):FireServer()
		-- Offer the Roblox invite prompt where the platform allows it for this player.
		pcall(function()
			if SocialService:CanSendGameInviteAsync(Players.LocalPlayer) then SocialService:PromptGameInvite(Players.LocalPlayer) end
		end)
	end)
end

return Showdown
