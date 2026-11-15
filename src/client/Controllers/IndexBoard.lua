-- Index Board: every pet as a dark silhouette until caught, in its rarity colour once caught, with the
-- spawn odds as a number. Opens from the camp's Index Board; tap anywhere on it to close.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local Ui = require(script.Parent.Ui)

local IndexBoard = {}

function IndexBoard.init()
	local gui = Ui.screen("IndexBoard", 10)
	local panel = Instance.new("TextButton")
	panel.AnchorPoint = Vector2.new(0.5, 0.5) panel.Position = UDim2.fromScale(0.5, 0.5) panel.Size = UDim2.fromScale(0.86, 0.8)
	panel.BackgroundColor3 = Color3.fromRGB(45, 40, 60) panel.Text = "" panel.AutoButtonColor = false panel.Visible = false panel.Parent = gui
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0.05, 0) corner.Parent = panel
	local title = Ui.label(panel, { Size = UDim2.new(1, 0, 0.12, 0), Text = "" })
	local grid = Instance.new("Frame")
	grid.Position = UDim2.fromScale(0.03, 0.14) grid.Size = UDim2.fromScale(0.94, 0.82) grid.BackgroundTransparency = 1 grid.Parent = panel
	panel.Activated:Connect(function() panel.Visible = false end)
	Remotes.get("Index").OnClientEvent:Connect(function(view)
		grid:ClearAllChildren()
		title.Text = view.caught .. " / " .. view.total
		local rows = #view.floors
		for r, row in ipairs(view.floors) do
			Ui.label(grid, { Position = UDim2.fromScale(0, (r - 1) / rows), Size = UDim2.fromScale(0.08, 1 / rows * 0.9), Text = tostring(row.floor),
				TextColor3 = row.complete and Color3.fromRGB(255, 220, 110) or Color3.new(1, 1, 1) })
			for c, pet in ipairs(row.pets) do
				local cell = Instance.new("Frame")
				cell.Position = UDim2.fromScale(0.1 + (c - 1) * 0.15, (r - 1) / rows) cell.Size = UDim2.fromScale(0.13, 1 / rows * 0.9)
				cell.BackgroundColor3 = pet.caught and (Ui.RarityColor[pet.rarity] or Color3.new(1, 1, 1)) or Color3.fromRGB(20, 18, 28)
				local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0.2, 0) cc.Parent = cell
				local stroke = Instance.new("UIStroke") stroke.Thickness = 3 stroke.Color = Ui.RarityColor[pet.rarity] or Color3.new(1, 1, 1) stroke.Parent = cell
				cell.Parent = grid
				if pet.odds then Ui.label(cell, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(0.96, 0.96), Size = UDim2.fromScale(0.6, 0.4), Text = pet.odds .. "%" }) end
			end
		end
		panel.Visible = true
	end)
end

return IndexBoard
