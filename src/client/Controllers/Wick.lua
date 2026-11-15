-- Wick the guide: a small light that floats toward whatever WickLogic says to do next.
-- Never text. A beam of light from the player to the target.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WickLogic = require(Shared.Logic.WickLogic)
local E = require(Shared.Config).Economy
local HUD = require(script.Parent.HUD)

local Wick = {}

local function world() return workspace:FindFirstChild("PetTowerWorld") end
local function myCamp()
	local w, hrp = world(), Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not w or not hrp then return end
	local best, bestD
	for _, f in ipairs(w:GetChildren()) do
		local g = f.Name:match("^Camp%d") and f:FindFirstChild("Ground")
		if g then
			local d = (g.Position - hrp.Position).Magnitude
			if not bestD or d < bestD then best, bestD = f, d end
		end
	end
	return best -- the nearest camp: at camp this is the player's own
end
local function nearest(folder, test)
	local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not folder or not hrp then return end
	local best, bestD
	for _, part in ipairs(folder:GetChildren()) do
		if part:IsA("BasePart") and (not test or test(part)) then
			local d = (part.Position - hrp.Position).Magnitude
			if not bestD or d < bestD then best, bestD = part, d end
		end
	end
	return best
end

local function find(target, floor)
	local w = world()
	if not w then return end
	local camp = myCamp()
	local fl = w:FindFirstChild("Floor" .. floor)
	if target == "starter" then return camp and camp:FindFirstChild("Pedestal_Narbub") end
	if target == "firstPet" then return nearest(w:FindFirstChild("TutorialPets"), function(b) return b:GetAttribute("PetId") == -Players.LocalPlayer.UserId end) end
	if target == "pads" then return camp and camp:FindFirstChild("Pad1") end
	if target == "snack" then return camp and camp:FindFirstChild("SnackTable") end
	if target == "egg" then return camp and camp:FindFirstChild("EggNest") end
	if target == "lift" then return camp and camp:FindFirstChild("Lift") end
	if target == "liftHome" then return fl and fl:FindFirstChild("Lift") end
	if target == "guardian" then return fl and fl:FindFirstChild("GuardianRing") end
	if target == "pillar" then
		local asked = require(script.Parent.TrustTap).asked
		return fl and nearest(fl:FindFirstChild("Pets"), function(b) return b:FindFirstChild("Pillar") ~= nil and not asked[b:GetAttribute("PetId")] end)
	end
	if target == "pet" then return fl and nearest(fl:FindFirstChild("Pets")) end
end

function Wick.init()
	local flame = Instance.new("Part")
	flame.Name = "Wick" flame.Shape = Enum.PartType.Ball flame.Size = Vector3.new(1.2, 1.2, 1.2)
	flame.Material = Enum.Material.Neon flame.Color = Color3.fromRGB(255, 210, 110)
	flame.Anchored = true flame.CanCollide = false flame.CanQuery = false
	local light = Instance.new("PointLight") light.Color = flame.Color light.Range = 12 light.Parent = flame
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent = flame
	local anchor = Instance.new("Part")
	anchor.Anchored = true anchor.CanCollide = false anchor.CanQuery = false anchor.Transparency = 1 anchor.Size = Vector3.new(1, 1, 1)
	a1.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0 beam.Attachment1 = a1 beam.Width0 = 0.6 beam.Width1 = 0.2 beam.FaceCamera = true
	beam.Color = ColorSequence.new(flame.Color) beam.Transparency = NumberSequence.new(0.3) beam.Parent = flame
	flame.Parent = workspace anchor.Parent = workspace

	task.spawn(function()
		while true do
			task.wait(0.25)
			local p, extra = HUD.state, HUD.extra
			local ch = Players.LocalPlayer.Character
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			if p and extra and hrp then
				local floor = Players.LocalPlayer:GetAttribute("Floor") or 0
				local nextFloor = math.min(p.cleared + 1, #E.GuardianPower)
				local fl = world() and world():FindFirstChild("Floor" .. floor)
				local pending = false
				for _, f in pairs(p.floors) do if f.cleared and f.choice == false then pending = true end end
				local target = WickLogic.target(p, {
					floor = floor, stackCount = #p.stack, stackCap = extra.stackCap or 3,
					canFeed = p.coins >= (extra.feedCost or math.huge), teamPower = extra.teamPower or 0,
					guardianPower = E.GuardianPower[nextFloor],
					pillarOnFloor = fl ~= nil and find("pillar", floor) ~= nil,
					eggReady = p.egg and os.time() >= p.egg.start + E.Return.EggHatchHours * 3600 or false,
					pendingChoice = pending,
				})
				local part = target and find(target, floor)
				flame.Position = hrp.Position + Vector3.new(2, 4, 0)
				beam.Enabled = part ~= nil
				if part then anchor.Position = part.Position + Vector3.new(0, 3, 0) end
			end
		end
	end)
end

return Wick
