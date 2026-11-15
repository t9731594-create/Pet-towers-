-- The hub's weekly things: merchant (weekends, coins only, three clearly shown items), the Dawn-vs-Dusk
-- scale and the monument. Greybox: numbers and colours on the hub parts, three big buttons at the merchant.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local F = require(ReplicatedStorage.Shared.Logic.Formulas)
local Ui = require(script.Parent.Ui)

local Week = { data = nil }
local ICON = { look = "*", pet = "@", decor = "#" }

local function board(part, name)
	local bb = part:FindFirstChild(name)
	if bb then return bb.Label end
	bb = Instance.new("BillboardGui")
	bb.Name = name bb.Size = UDim2.fromOffset(220, 90) bb.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 4, 0) bb.MaxDistance = 120
	Ui.label(bb, { Name = "Label", Size = UDim2.fromScale(1, 1), Text = "" })
	bb.Parent = part
	return bb.Label
end

function Week.init()
	local gui = Ui.screen("Week", 6)
	local tray = Instance.new("Frame")
	tray.AnchorPoint = Vector2.new(0.5, 1) tray.Position = UDim2.new(0.5, 0, 1, -20) tray.Size = UDim2.fromOffset(3 * 110, 100)
	tray.BackgroundTransparency = 1 tray.Visible = false tray.Parent = gui
	local buttons = {}
	for slot = 1, 3 do
		local b = Instance.new("TextButton")
		b.Position = UDim2.fromOffset((slot - 1) * 110, 0) b.Size = UDim2.fromOffset(100, 100)
		b.Font = Enum.Font.FredokaOne b.TextScaled = true b.BackgroundColor3 = Color3.fromRGB(255, 225, 235) b.Text = ""
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0.2, 0) c.Parent = b
		b.Parent = tray
		b.Activated:Connect(function() Remotes.get("MerchantBuy"):FireServer(slot) end)
		buttons[slot] = b
	end
	local function draw()
		local d = Week.data
		local world = workspace:FindFirstChild("PetTowerWorld")
		if not d or not world then return end
		for _, item in ipairs(d.items) do
			local b = buttons[item.slot]
			b.Text = ICON[item.kind] .. "\n" .. F.short(item.price)
			b.BackgroundTransparency = item.bought and 0.7 or 0
			b.Active = not item.bought
		end
		local scale = world:FindFirstChild("DawnDuskScale")
		if scale then
			board(scale, "Tally").Text = F.short(d.tally.dawn or 0) .. "  |  " .. F.short(d.tally.dusk or 0)
			scale.Color = d.lastLeader == "dawn" and Color3.fromRGB(255, 205, 90) or d.lastLeader == "dusk" and Color3.fromRGB(150, 110, 235) or Color3.fromRGB(200, 200, 200)
		end
		local monument = world:FindFirstChild("Monument")
		if monument then
			local top, names = 0, nil
			for floor, list in pairs(d.monument or {}) do
				if tonumber(floor) > top and #list > 0 then top, names = tonumber(floor), list end
			end
			board(monument, "Names").Text = names and (top .. ":  " .. table.concat(names, ", ", 1, math.min(#names, 3))) or ""
		end
		local merchant = world:FindFirstChild("Merchant")
		if merchant then merchant.Transparency = d.merchantOpen and 0 or 0.8 end
	end
	Remotes.get("Week").OnClientEvent:Connect(function(d) Week.data = d draw() end)
	task.spawn(function()
		while true do
			task.wait(0.4)
			local d = Week.data
			local world = workspace:FindFirstChild("PetTowerWorld")
			local merchant = world and world:FindFirstChild("Merchant")
			local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			tray.Visible = d ~= nil and d.merchantOpen and merchant ~= nil and hrp ~= nil and (merchant.Position - hrp.Position).Magnitude < 14
		end
	end)
end

return Week
