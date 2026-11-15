-- Team screen (HUD button "Team"): your camp pets as coloured tiles. Tap a pet, then one of three big
-- icon buttons: put on team, give a heart, release. No sentences.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local F = require(Shared.Logic.Formulas)
local Ui = require(script.Parent.Ui)
local HUD = require(script.Parent.HUD)

local Team = { selected = nil }

function Team.init()
	local gui = Ui.screen("Team", 10)
	local open = Instance.new("TextButton")
	open.AnchorPoint = Vector2.new(1, 0) open.Position = UDim2.new(1, -12, 0, 64) open.Size = UDim2.fromOffset(56, 56)
	open.Text = "x3" open.Font = Enum.Font.FredokaOne open.TextScaled = true open.BackgroundColor3 = Color3.fromRGB(255, 200, 200) open.Parent = gui
	local oc = Instance.new("UICorner") oc.CornerRadius = UDim.new(0.3, 0) oc.Parent = open
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5) panel.Position = UDim2.fromScale(0.5, 0.5) panel.Size = UDim2.fromScale(0.8, 0.78)
	panel.BackgroundColor3 = Color3.fromRGB(45, 40, 60) panel.Visible = false panel.Parent = gui
	local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0.05, 0) pc.Parent = panel
	local grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromScale(0.02, 0.03) grid.Size = UDim2.fromScale(0.96, 0.7) grid.BackgroundTransparency = 1 grid.ScrollBarThickness = 6 grid.Parent = panel
	local layout = Instance.new("UIGridLayout") layout.CellSize = UDim2.fromOffset(64, 64) layout.CellPadding = UDim2.fromOffset(8, 8) layout.Parent = grid
	local actions = {}
	local function action(i, text, color, fire)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0.5, 1) b.Position = UDim2.new(0.2 + (i - 1) * 0.2, 0, 0.97, 0) b.Size = UDim2.fromOffset(72, 72)
		b.Text = text b.Font = Enum.Font.FredokaOne b.TextScaled = true b.BackgroundColor3 = color b.Parent = panel
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0.3, 0) c.Parent = b
		b.Activated:Connect(function() if Team.selected then fire(Team.selected) end end)
		actions[i] = b
	end
	local function draw(p)
		for _, child in ipairs(grid:GetChildren()) do if child:IsA("GuiButton") then child:Destroy() end end
		local onTeam = {}
		for _, id in ipairs(p.team) do onTeam[id] = true end
		local riding = {}
		for _, id in ipairs(p.stack) do riding[id] = true end
		for _, pet in ipairs(p.pets) do
			if not riding[pet.id] then
				local tile = Instance.new("TextButton")
				tile.BackgroundColor3 = Ui.RarityColor[pet.rarity] or Color3.new(1, 1, 1)
				tile.Font = Enum.Font.FredokaOne tile.TextScaled = true tile.TextColor3 = Color3.new(1, 1, 1)
				tile.Text = (onTeam[pet.id] and "x " or "") .. string.rep("<3", 0) .. F.short(F.wildPower(pet)) .. (pet.hearts > 0 and ("\n+" .. pet.hearts) or "")
				local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0.2, 0) tc.Parent = tile
				local stroke = Instance.new("UIStroke") stroke.Thickness = Team.selected == pet.id and 5 or 0 stroke.Color = Color3.new(1, 1, 1) stroke.Parent = tile
				tile.Parent = grid
				tile.Activated:Connect(function() Team.selected = pet.id draw(p) end)
			end
		end
		grid.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y)
	end
	action(1, "x3", Color3.fromRGB(255, 200, 200), function(id)
		local p = HUD.state
		local other = p.team[1] ~= id and p.team[1] or p.team[2]
		Remotes.get("SetTeam"):FireServer(id, other ~= id and other or nil)
	end)
	action(2, "+<3", Color3.fromRGB(255, 150, 190), function(id) Remotes.get("Heart"):FireServer(id) end)
	action(3, "bye", Color3.fromRGB(190, 190, 200), function(id) Remotes.get("Release"):FireServer(id) Team.selected = nil end)
	action(4, "X", Color3.fromRGB(240, 240, 240), function() end)
	actions[4].Activated:Connect(function() panel.Visible = false end)
	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible and HUD.state then draw(HUD.state) end
	end)
	HUD.onState(function(p)
		open.Visible = p.starter ~= nil
		if panel.Visible then draw(p) end
	end)
end

return Team
