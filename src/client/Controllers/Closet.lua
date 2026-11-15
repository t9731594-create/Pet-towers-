-- Closet: the looks you own as big tiles. Tap one to wear it. Greybox: the look's first letters.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local Ui = require(script.Parent.Ui)
local Closet = {}
function Closet.init()
	local gui = Ui.screen("Closet", 10)
	local panel = Instance.new("TextButton")
	panel.AnchorPoint = Vector2.new(0.5, 0.5) panel.Position = UDim2.fromScale(0.5, 0.5) panel.Size = UDim2.fromScale(0.7, 0.6)
	panel.BackgroundColor3 = Color3.fromRGB(60, 45, 65) panel.Text = "" panel.AutoButtonColor = false panel.Visible = false panel.Parent = gui
	local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0.05, 0) pc.Parent = panel
	local grid = Instance.new("Frame")
	grid.Position = UDim2.fromScale(0.03, 0.05) grid.Size = UDim2.fromScale(0.94, 0.9) grid.BackgroundTransparency = 1 grid.Parent = panel
	local layout = Instance.new("UIGridLayout") layout.CellSize = UDim2.fromOffset(72, 72) layout.CellPadding = UDim2.fromOffset(8, 8) layout.Parent = grid
	panel.Activated:Connect(function() panel.Visible = false end)
	Remotes.get("Closet").OnClientEvent:Connect(function(data)
		for _, child in ipairs(grid:GetChildren()) do if child:IsA("GuiButton") then child:Destroy() end end
		local worn = {}
		for _, id in pairs(data.equipped) do worn[id] = true end
		for _, id in ipairs(data.looks) do
			local b = Instance.new("TextButton")
			b.Text = string.sub(id, 1, 6) b.Font = Enum.Font.FredokaOne b.TextScaled = true
			b.BackgroundColor3 = worn[id] and Color3.fromRGB(255, 210, 120) or Color3.fromRGB(230, 220, 240)
			local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0.2, 0) c.Parent = b
			b.Parent = grid
			b.Activated:Connect(function() Remotes.get("Equip"):FireServer(id) end)
		end
		panel.Visible = true
	end)
end
return Closet
