-- The camp lift once more than one floor is open: big number buttons, one per floor you may ride to.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local Ui = require(script.Parent.Ui)
local Lift = {}
function Lift.init()
	local gui = Ui.screen("Lift", 10)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1) panel.Position = UDim2.new(0.5, 0, 1, -20) panel.Size = UDim2.fromOffset(10, 84)
	panel.BackgroundTransparency = 1 panel.Visible = false panel.Parent = gui
	Remotes.get("LiftMenu").OnClientEvent:Connect(function(top)
		panel:ClearAllChildren()
		panel.Size = UDim2.fromOffset(top * 84, 84)
		for f = 1, top do
			local b = Instance.new("TextButton")
			b.Position = UDim2.fromOffset((f - 1) * 84, 0) b.Size = UDim2.fromOffset(76, 76)
			b.Text = tostring(f) b.Font = Enum.Font.FredokaOne b.TextScaled = true b.BackgroundColor3 = Color3.fromRGB(255, 240, 180)
			local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0.3, 0) c.Parent = b
			b.Parent = panel
			b.Activated:Connect(function() panel.Visible = false Remotes.get("Lift"):FireServer(f) end)
		end
		panel.Visible = true
		task.delay(8, function() panel.Visible = false end)
	end)
end
return Lift
