-- Welcome back: a chest of coins, the journey day and tomorrow's gift. A chime and a few icons that
-- fade by themselves. Never a countdown, never "hurry".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local F = require(ReplicatedStorage.Shared.Logic.Formulas)
local Ui = require(script.Parent.Ui)

local Welcome = {}

function Welcome.init()
	local gui = Ui.screen("Welcome", 7)
	local line = Ui.label(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 170), Size = UDim2.new(0.7, 0, 0, 40), Text = "", Visible = false,
		TextColor3 = Color3.fromRGB(255, 235, 170) })
	Remotes.get("Welcome").OnClientEvent:Connect(function(w)
		local parts = {}
		if w.chest and w.chest > 0 then parts[#parts + 1] = "[ +" .. F.short(w.chest) .. " ]" end
		if w.newDay then parts[#parts + 1] = "^ " .. w.journeyDay end
		if w.ladderCoins and w.ladderCoins > 0 then parts[#parts + 1] = "+" .. F.short(w.ladderCoins) end
		if w.rested then parts[#parts + 1] = "x2" end
		if #parts == 0 then return end
		line.Text = table.concat(parts, "   ")
		line.Visible = true
		task.delay(6, function() line.Visible = false end)
	end)
	Remotes.get("EggHatched").OnClientEvent:Connect(function(pet)
		line.Text = "( ! )"
		line.TextColor3 = Ui.RarityColor[pet.rarity] or line.TextColor3
		line.Visible = true
		task.delay(4, function() line.Visible = false line.TextColor3 = Color3.fromRGB(255, 235, 170) end)
	end)
end

return Welcome
