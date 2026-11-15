-- Settings: music, effects, low graphics, tap assist, reduced flash. One small gear, five icon rows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local Ui = require(script.Parent.Ui)
local HUD = require(script.Parent.HUD)

local Settings = { values = {} }
local ROWS = { { "music", "~" }, { "effects", "!" }, { "lowGraphics", "LO" }, { "tapAssist", "O+" }, { "reducedFlash", "-*" } }

function Settings.get(key) return Settings.values[key] end

function Settings.init()
	local gui = Ui.screen("Settings", 11)
	local gear = Instance.new("TextButton")
	gear.AnchorPoint = Vector2.new(1, 0) gear.Position = UDim2.new(1, -12, 0, 8) gear.Size = UDim2.fromOffset(48, 48)
	gear.Text = "=" gear.Font = Enum.Font.FredokaOne gear.TextScaled = true gear.BackgroundColor3 = Color3.fromRGB(240, 240, 240) gear.Parent = gui
	local gc = Instance.new("UICorner") gc.CornerRadius = UDim.new(1, 0) gc.Parent = gear
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0) panel.Position = UDim2.new(1, -12, 0, 64) panel.Size = UDim2.fromOffset(120, #ROWS * 56)
	panel.BackgroundColor3 = Color3.fromRGB(45, 40, 60) panel.Visible = false panel.Parent = gui
	local buttons = {}
	local function paint()
		for key, b in pairs(buttons) do
			local v = Settings.values[key]
			local on = v == true or (type(v) == "number" and v > 0)
			b.BackgroundColor3 = on and Color3.fromRGB(120, 210, 120) or Color3.fromRGB(120, 120, 130)
		end
		Lighting.GlobalShadows = not Settings.values.lowGraphics
	end
	for i, row in ipairs(ROWS) do
		local key = row[1]
		local b = Instance.new("TextButton")
		b.Position = UDim2.fromOffset(8, (i - 1) * 56 + 4) b.Size = UDim2.fromOffset(104, 48)
		b.Text = row[2] b.Font = Enum.Font.FredokaOne b.TextScaled = true b.TextColor3 = Color3.new(1, 1, 1) b.Parent = panel
		local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0.3, 0) bc.Parent = b
		buttons[key] = b
		b.Activated:Connect(function()
			local v = Settings.values[key]
			local new
			if type(v) == "number" then new = v > 0 and 0 or 1 else new = not v end
			Settings.values[key] = new
			paint()
			Remotes.get("SetSetting"):FireServer(key, new)
		end)
	end
	gear.Activated:Connect(function() panel.Visible = not panel.Visible end)
	HUD.onState(function(p)
		for k, v in pairs(p.settings) do Settings.values[k] = v end
		paint()
	end)
end

return Settings
