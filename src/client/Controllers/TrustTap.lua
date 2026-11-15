-- Walk up to a wild pet and the try starts by itself. Tap anywhere as each ring meets the heart.
-- The client only sends tap times; the server scores them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local Ui = require(script.Parent.Ui)
local Rings = require(script.Parent.Rings)
local HUD = require(script.Parent.HUD)

local TrustTap = { current = nil, asked = {}, blocked = false }
local APPROACH = 9 -- studs: closer than the server's 15 so latency never fails the distance check

-- Other controllers can stop auto-tries (e.g. while a showdown is on screen).
function TrustTap.setBlocked(v) TrustTap.blocked = v end

local function nearestPet()
	local ch = Players.LocalPlayer.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local world = workspace:FindFirstChild("PetTowerWorld")
	if not hrp or not world then return end
	local best, bestD
	for _, folder in ipairs(world:GetChildren()) do
		local pets = folder.Name == "TutorialPets" and folder or folder:FindFirstChild("Pets")
		if pets then
			for _, ball in ipairs(pets:GetChildren()) do
				local id = ball:GetAttribute("PetId")
				if id and not TrustTap.asked[id] and not ball:GetAttribute("NeedsPlay") then
					local d = (ball.Position - hrp.Position).Magnitude
					if d < APPROACH and (not bestD or d < bestD) then best, bestD = id, d end
				end
			end
		end
	end
	return best
end

-- With a full stack the server refuses the try. Asking anyway would mark the pet as asked, and it
-- could then never be tried, even after the pets on the head have been put down.
local function stackFull()
	local p, extra = HUD.state, HUD.extra
	return p ~= nil and extra ~= nil and type(extra.stackCap) == "number" and #p.stack >= extra.stackCap
end

function TrustTap.init()
	local gui = Ui.screen("TrustTap", 5)
	local word = Ui.label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromOffset(360, 60), Text = "", Visible = false })
	local tapRemote = Remotes.get("Tap")
	Remotes.get("TryBegin").OnClientEvent:Connect(function(try)
		if TrustTap.current then TrustTap.current.rings.stop() end
		local cur = { next = 1 }
		cur.rings = Rings.play({
			parent = gui, start = try.start, beats = try.beats, ringTime = try.ringTime, color = Ui.RarityColor[try.rarity],
			onTap = function(offset)
				-- skip rings whose window has already passed
				while try.beats[cur.next] and offset > try.beats[cur.next] + 0.2 do cur.next = cur.next + 1 end
				if not try.beats[cur.next] then return end
				if offset < try.beats[cur.next] - try.ringTime then return end -- that ring has not started
				tapRemote:FireServer(cur.next, offset)
				cur.next = cur.next + 1
			end,
		})
		TrustTap.current = cur
	end)
	Remotes.get("TryGrade").OnClientEvent:Connect(function(beat, grade)
		if TrustTap.current then TrustTap.current.rings.mark(beat, grade) end
	end)
	Remotes.get("TryEnd").OnClientEvent:Connect(function(result)
		if TrustTap.current then TrustTap.current.rings.stop() TrustTap.current = nil end
		word.Text = result.success and (result.perfectAll and "PERFECT x3" or "!") or (result.lastBeatMiss and "SO CLOSE" or "...")
		word.TextColor3 = result.success and Ui.RarityColor[result.rarity] or Color3.new(1, 1, 1)
		word.Visible = true
		task.delay(1.2, function() word.Visible = false end)
	end)
	local start = Remotes.get("TryStart")
	task.spawn(function()
		while true do
			task.wait(0.2)
			if not TrustTap.current and not TrustTap.blocked and not stackFull() then
				local id = nearestPet()
				if id then
					TrustTap.asked[id] = true -- one try per pet
					start:FireServer(id)
				end
			end
		end
	end)
end

return TrustTap
