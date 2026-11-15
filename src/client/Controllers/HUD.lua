-- Coins top left; floor number and Team Power top centre. Numbers shortened (1.2K, 3.4M).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local F = require(ReplicatedStorage.Shared.Logic.Formulas)
local Ui = require(script.Parent.Ui)

local HUD = { state = nil, extra = nil, listeners = {} }

function HUD.onState(fn) table.insert(HUD.listeners, fn) end

function HUD.init()
	local gui = Ui.screen("HUD", 1)
	local coins = Ui.label(gui, { Name = "Coins", Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(170, 44), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 220, 90), Text = "0" })
	local floor = Ui.label(gui, { Name = "Floor", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(140, 44), Text = "1" })
	local power = Ui.label(gui, { Name = "Power", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(140, 28),
		TextColor3 = Color3.fromRGB(255, 150, 150), Text = "" })
	local feed = Ui.label(gui, { Name = "Feed", Position = UDim2.fromOffset(12, 52), Size = UDim2.fromOffset(170, 26), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 190, 150), Text = "" })
	local mult = Ui.label(gui, { Name = "Mult", Position = UDim2.fromOffset(12, 80), Size = UDim2.fromOffset(90, 24), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(150, 230, 150), Text = "" })
	Remotes.get("State").OnClientEvent:Connect(function(profile, extra)
		HUD.state, HUD.extra = profile, extra
		coins.Text = F.short(profile.coins)
		floor.Text = tostring(math.min(profile.cleared + 1, 100))
		power.Text = profile.starter and F.short(extra.teamPower) or ""
		mult.Text = (extra.coinMult or 1) > 1 and string.format("x%.1f", extra.coinMult) or ""
		feed.Text = profile.starter and ("Lv " .. profile.starter.level .. "  >  " .. F.short(extra.feedCost)) or ""
		for _, fn in ipairs(HUD.listeners) do task.spawn(fn, profile, extra) end
	end)
	Remotes.get("Coins").OnClientEvent:Connect(function(amount)
		local pop = Ui.label(gui, { Position = UDim2.fromOffset(190, 8), Size = UDim2.fromOffset(120, 36), TextColor3 = Color3.fromRGB(255, 240, 150), Text = "+" .. F.short(amount) })
		game:GetService("TweenService"):Create(pop, TweenInfo.new(0.8), { Position = UDim2.fromOffset(190, -30), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		game:GetService("Debris"):AddItem(pop, 1)
	end)
end

return HUD
