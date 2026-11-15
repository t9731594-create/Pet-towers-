-- Share or Keep: two big icon buttons after a first win on a floor. No timer, no pressure.
-- Dawn or Dusk: the same two buttons when the starter reaches its final stage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local Ui = require(script.Parent.Ui)
local HUD = require(script.Parent.HUD)
local F = require(ReplicatedStorage.Shared.Logic.Formulas)

local Choice = {}
local DAWN, DUSK = Color3.fromRGB(255, 205, 90), Color3.fromRGB(150, 110, 235)

function Choice.init()
	local gui = Ui.screen("Choice", 9)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 1) holder.Position = UDim2.new(0.5, 0, 1, -20) holder.Size = UDim2.fromOffset(300, 120)
	holder.BackgroundTransparency = 1 holder.Visible = false holder.Parent = gui
	local function button(x, color, icon)
		local b = Instance.new("TextButton")
		b.Position = UDim2.fromOffset(x, 0) b.Size = UDim2.fromOffset(120, 120) -- far above the 48 px minimum
		b.BackgroundColor3 = color b.Text = icon b.Font = Enum.Font.FredokaOne b.TextScaled = true b.TextColor3 = Color3.new(1, 1, 1)
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0.25, 0) c.Parent = b
		b.Parent = holder
		return b
	end
	-- icons: many small coins for everyone / one big pile for me
	local share, keep = button(0, DAWN, "o o o"), button(180, DUSK, "O")
	local mode, floor = nil, nil
	local function show(m, f) mode, floor = m, f holder.Visible = true end
	share.Activated:Connect(function()
		holder.Visible = false
		if mode == "floor" then Remotes.get("Choose"):FireServer(floor, "share")
		elseif mode == "weekly" then Remotes.get("ChooseWeekly"):FireServer("share")
		else Remotes.get("ChooseForm"):FireServer("dawn") end
	end)
	keep.Activated:Connect(function()
		holder.Visible = false
		if mode == "floor" then Remotes.get("Choose"):FireServer(floor, "keep")
		elseif mode == "weekly" then Remotes.get("ChooseWeekly"):FireServer("keep")
		else Remotes.get("ChooseForm"):FireServer("dusk") end
	end)
	Remotes.get("ChoicePrompt").OnClientEvent:Connect(function(f) show("floor", f) end)
	Remotes.get("WeeklyChoice").OnClientEvent:Connect(function() task.delay(2.5, function() show("weekly") end) end)
	Remotes.get("ShowdownEnd").OnClientEvent:Connect(function(r)
		if r.kind == "guardian" and r.won and r.firstClear then task.delay(2.5, function() show("floor", r.floor) end) end
	end)
	HUD.onState(function(p)
		if p.starter and not p.starter.form and F.starterStage(p.starter.level) >= 4 and not holder.Visible then show("form") end
	end)
	Remotes.get("Shared").OnClientEvent:Connect(function(info)
		local fx = require(script.Parent.FX)
		if fx.show then fx.show(tostring(info.name) .. "  o o o", DAWN, 4) end
	end)
end

return Choice
