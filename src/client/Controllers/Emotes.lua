-- Six sticker emotes: one small button opens six stickers; a sticker floats over the sender's head.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local Ui = require(script.Parent.Ui)

local Emotes = {}
local STICKERS = { ":)", "<3", "!", "?", "zZ", "\\o/" } -- placeholders until the sticker art is approved

function Emotes.init()
	local gui = Ui.screen("Emotes", 3)
	local open = Instance.new("TextButton")
	open.AnchorPoint = Vector2.new(0, 1) open.Position = UDim2.new(0, 12, 1, -150) open.Size = UDim2.fromOffset(52, 52)
	open.Text = ":)" open.Font = Enum.Font.FredokaOne open.TextScaled = true open.BackgroundColor3 = Color3.fromRGB(255, 255, 255) open.Parent = gui
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = open
	local tray = Instance.new("Frame")
	tray.AnchorPoint = Vector2.new(0, 1) tray.Position = UDim2.new(0, 72, 1, -150) tray.Size = UDim2.fromOffset(6 * 56, 52)
	tray.BackgroundTransparency = 1 tray.Visible = false tray.Parent = gui
	for i, text in ipairs(STICKERS) do
		local b = Instance.new("TextButton")
		b.Position = UDim2.fromOffset((i - 1) * 56, 0) b.Size = UDim2.fromOffset(52, 52)
		b.Text = text b.Font = Enum.Font.FredokaOne b.TextScaled = true b.BackgroundColor3 = Color3.fromRGB(255, 245, 210) b.Parent = tray
		local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1, 0) bc.Parent = b
		b.Activated:Connect(function() tray.Visible = false Remotes.get("Emote"):FireServer(i) end)
	end
	open.Activated:Connect(function() tray.Visible = not tray.Visible end)
	Remotes.get("Emote").OnClientEvent:Connect(function(userId, index)
		local player = Players:GetPlayerByUserId(userId)
		local head = player and player.Character and player.Character:FindFirstChild("Head")
		if not head or not STICKERS[index] then return end
		local old = head:FindFirstChild("Sticker")
		if old then old:Destroy() end
		local bb = Instance.new("BillboardGui")
		bb.Name = "Sticker" bb.Size = UDim2.fromOffset(70, 70) bb.StudsOffset = Vector3.new(0, 4, 0) bb.AlwaysOnTop = true
		Ui.label(bb, { Size = UDim2.fromScale(1, 1), Text = STICKERS[index] })
		bb.Parent = head
		game:GetService("Debris"):AddItem(bb, 3)
	end)
end

return Emotes
