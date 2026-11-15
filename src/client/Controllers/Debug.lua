-- Testing panel. STUDIO ONLY: never created in a live game (and the server ignores the remote there).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local Ui = require(script.Parent.Ui)

local Debug = {}
local BUTTONS = {
	{ "+10K", "coins", 10000 }, { "+10M", "coins", 10000000 }, { "Lv5", "level", 5 }, { "Lv25", "level", 25 }, { "Lv42", "level", 42 },
	{ "Clear", "clear" }, { "Epic", "spawn", "Epic" }, { "Legend", "spawn", "Legendary" }, { "Secret", "spawn", "Secret" }, { "Radiant", "radiant" },
	{ "Away16h", "away", 16 }, { "Egg", "egg" }, { "Stack10", "stack", 7 }, { "Wipe", "wipe" },
}

function Debug.init()
	if not RunService:IsStudio() then return end
	local gui = Ui.screen("Debug", 20)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0, 1) holder.Position = UDim2.new(0, 8, 1, -210) holder.Size = UDim2.fromOffset(7 * 66, 2 * 34)
	holder.BackgroundTransparency = 1 holder.Parent = gui
	for i, def in ipairs(BUTTONS) do
		local b = Instance.new("TextButton")
		b.Position = UDim2.fromOffset(((i - 1) % 7) * 66, math.floor((i - 1) / 7) * 34) b.Size = UDim2.fromOffset(62, 30)
		b.Text = def[1] b.TextScaled = true b.BackgroundColor3 = Color3.fromRGB(60, 60, 60) b.TextColor3 = Color3.new(1, 1, 1) b.BackgroundTransparency = 0.3
		b.Parent = holder
		b.Activated:Connect(function() Remotes.get("Debug"):FireServer(def[2], def[3]) end)
	end
end

return Debug
