-- Guardian showdown: one meter, one cheer ring per second. Tap on the beat to cheer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local E = require(Shared.Config).Economy
local Ui = require(script.Parent.Ui)
local Rings = require(script.Parent.Rings)

local Showdown = { rings = nil, key = nil }

function Showdown.init()
	local gui = Ui.screen("Showdown", 4)
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
		bar.Visible = false
		local tap = script.Parent:FindFirstChild("TrustTap")
		if tap then require(tap).setBlocked(false) end
	end
	local function begin(snap)
		Showdown.key = snap.start
		help.Visible = false
		local tap = script.Parent:FindFirstChild("TrustTap")
		if tap then require(tap).setBlocked(true) end
		local beats = {}
		local last = snap.ends and math.floor((snap.ends - snap.start) / E.Showdown.BeatSeconds) - 1 or 600
		for i = 1, last do beats[i] = i * E.Showdown.BeatSeconds end
		Showdown.rings = Rings.play({
			parent = gui, start = snap.start, beats = beats, ringTime = E.Showdown.BeatSeconds * 0.9, color = Color3.fromRGB(255, 220, 120),
			onTap = function(offset) cheer:FireServer(offset) end,
		})
	end
	Remotes.get("ShowdownState").OnClientEvent:Connect(function(snap)
		if Showdown.key ~= snap.start then
			if Showdown.rings then Showdown.rings.stop() end
			begin(snap)
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
