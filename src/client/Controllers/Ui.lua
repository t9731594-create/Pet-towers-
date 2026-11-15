-- Small helpers shared by the greybox controllers.
local Players = game:GetService("Players")
local Ui = {}
Ui.RarityColor = {
	Common = Color3.fromRGB(170, 170, 170), Uncommon = Color3.fromRGB(90, 200, 90), Rare = Color3.fromRGB(70, 140, 255),
	Epic = Color3.fromRGB(170, 90, 230), Legendary = Color3.fromRGB(255, 200, 60), Secret = Color3.fromRGB(255, 120, 200),
}
Ui.GradeColor = { Perfect = Color3.fromRGB(255, 215, 80), Good = Color3.fromRGB(120, 220, 120), Miss = Color3.fromRGB(200, 200, 200) }

function Ui.screen(name, order)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false -- keep inside the safe area
	gui.DisplayOrder = order or 1
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end
function Ui.label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.TextScaled = true
	for k, v in pairs(props) do l[k] = v end
	l.Parent = parent
	return l
end
function Ui.ring(parent, diameter, color, thickness)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(diameter, diameter)
	f.BackgroundTransparency = 1
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(1, 0) corner.Parent = f
	local stroke = Instance.new("UIStroke") stroke.Thickness = thickness or 6 stroke.Color = color stroke.Parent = f
	f.Parent = parent
	return f, stroke
end
function Ui.now() return workspace:GetServerTimeNow() end
return Ui
