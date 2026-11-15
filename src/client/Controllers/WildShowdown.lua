-- Wild showdowns (Amendment 1): Epic, Legendary and Secret pets want to play before they trust you.
-- Walk up and the small ring opens by itself (the Showdown controller draws it). Players farther away
-- on the same floor get one big icon that points at the pet. A clip moment offers a capture where allowed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local WildView = require(Shared.Logic.WildView)
local Ui = require(script.Parent.Ui)

-- asked[petId]: when (os.clock) WildJoin was fired for this approach. done[petId]: its showdown ended.
-- prompted[petId]: the join icon was shown once. shown: the pet whose ring is on screen. running: last news of a showdown we are not in.
local WildShowdown = { asked = {}, done = {}, prompted = {}, shown = nil, running = nil }
local CAMERA = "\240\159\147\183" -- camera emoji (U+1F4F7)

-- Called by the Showdown controller.
function WildShowdown.isIn(petId) return petId ~= nil and WildShowdown.shown == petId end
function WildShowdown.showing(petId) WildShowdown.shown = petId end
-- ring / icon / none for a wild ShowdownState (the server sends it to the whole floor).
function WildShowdown.role(snap)
	if snap.petId == nil then return "none" end
	return WildView.snapshotRole(snap.mine, WildShowdown.asked[snap.petId] ~= nil, WildShowdown.done[snap.petId])
end
-- This player walked away (or the server says they are no longer in): the pet is still there, so it is
-- NOT done. Forgetting the ask lets a walk back up join again.
function WildShowdown.steppedOut(petId)
	if petId == nil then return end
	WildShowdown.asked[petId] = nil
end
function WildShowdown.seen(snap)
	if snap.petId == nil or WildShowdown.done[snap.petId] then return end
	WildShowdown.running = { petId = snap.petId, floor = snap.floor, rarity = snap.rarity, at = os.clock() }
end
function WildShowdown.ended(result)
	if result.petId == nil then return end
	WildShowdown.done[result.petId] = true
	if WildShowdown.running and WildShowdown.running.petId == result.petId then WildShowdown.running = nil end
end

local function inTry()
	local tap = script.Parent:FindFirstChild("TrustTap")
	return tap ~= nil and require(tap).current ~= nil
end

-- Every pet part in the world: parts[petId] = part, list = { { id, distance, needsPlay } }.
local function scan(origin)
	local parts, list = {}, {}
	local world = workspace:FindFirstChild("PetTowerWorld")
	if not world then return parts, list end
	for _, folder in ipairs(world:GetChildren()) do
		local pets = folder.Name == "TutorialPets" and folder or folder:FindFirstChild("Pets")
		if pets then
			for _, ball in ipairs(pets:GetChildren()) do
				local id = ball:GetAttribute("PetId")
				if id ~= nil and ball:IsA("BasePart") then
					parts[id] = ball
					list[#list + 1] = { id = id, distance = (ball.Position - origin).Magnitude, needsPlay = ball:GetAttribute("NeedsPlay") }
				end
			end
		end
	end
	return parts, list
end

local function iconButton(gui, text, color)
	local b = Instance.new("TextButton")
	b.Text = text b.Font = Enum.Font.FredokaOne b.TextScaled = true b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color b.AutoButtonColor = true b.Visible = false b.Parent = gui
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0.3, 0) corner.Parent = b
	return b
end

function WildShowdown.init()
	local player = Players.LocalPlayer
	local gui = Ui.screen("WildShowdown", 6)

	-- Join icon: a ring in the pet's colour with an arrow that turns toward the pet. 96 px; no words.
	local prompt = iconButton(gui, "", Color3.fromRGB(40, 40, 50))
	prompt.Position = UDim2.fromOffset(12, 90) prompt.Size = UDim2.fromOffset(96, 96)
	local _, promptStroke = Ui.ring(prompt, 72, Color3.new(1, 1, 1), 6)
	local arrow = Ui.label(prompt, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(48, 48), Text = ">" })
	local promptPet, promptUntil = nil, 0
	local function hidePrompt() prompt.Visible = false promptPet = nil end
	prompt.Activated:Connect(hidePrompt)

	-- Capture icon: only ever shown where the platform allows it for this player.
	local capture = iconButton(gui, CAMERA, Color3.fromRGB(70, 140, 255))
	capture.AnchorPoint = Vector2.new(1, 0) capture.Position = UDim2.new(1, -12, 0, 90) capture.Size = UDim2.fromOffset(72, 72)
	local captureKey = 0
	local policyKnown, policy = false, nil
	local function allowed()
		if not policyKnown then
			local ok, info = pcall(function() return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player) end)
			policy = ok and info or nil
			policyKnown = ok -- a failed call is asked again next time; until then nothing is shown
		end
		return WildView.captureAllowed(policy)
	end
	Remotes.get("ClipMoment").OnClientEvent:Connect(function(clip)
		if type(clip) ~= "table" then return end
		if clip.floor ~= nil and clip.floor ~= player:GetAttribute("Floor") then return end
		if not allowed() then return end
		captureKey = captureKey + 1
		local key = captureKey
		capture.Visible = true
		task.delay(WildView.CaptureSeconds, function() if captureKey == key then capture.Visible = false end end)
	end)
	capture.Activated:Connect(function()
		capture.Visible = false
		captureKey = captureKey + 1
		pcall(function()
			local service = game:GetService("CaptureService")
			service:CaptureScreenshot(function(contentId)
				pcall(function() service:PromptSaveCapturesToGallery({ contentId }, function() end) end)
			end)
		end)
	end)

	local join = Remotes.get("WildJoin")
	local function step()
		local ch = player.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		if not hrp then hidePrompt() return end
		local parts, list = scan(hrp.Position)
		local distance = {}
		for _, c in ipairs(list) do
			distance[c.id] = c.distance
			if WildShowdown.done[c.id] then c.needsPlay = false end -- its showdown is over: never ask again
		end
		local trying = inTry()

		-- A pet may be asked again after the player has walked well away (or it is gone).
		for id in pairs(WildShowdown.asked) do
			if WildView.shouldForget(distance[id], WildShowdown.shown == id, os.clock() - WildShowdown.asked[id]) then WildShowdown.asked[id] = nil end
		end

		-- Auto-join: walk up and the ring opens.
		local id = WildView.pickJoin(list, WildShowdown.asked, trying)
		if id ~= nil then
			WildShowdown.asked[id] = os.clock()
			join:FireServer(id)
		end

		-- Join icon for players farther away on the same floor. Shown once per pet, hides by itself.
		local run = WildShowdown.running
		if run and os.clock() - run.at > 2 then WildShowdown.running = nil run = nil end
		if run and not promptPet and parts[run.petId]
			and WildView.shouldPrompt(run.floor, player:GetAttribute("Floor"), WildShowdown.asked[run.petId], WildShowdown.prompted[run.petId], trying) then
			WildShowdown.prompted[run.petId] = true
			promptPet, promptUntil = run.petId, os.clock() + WildView.PromptSeconds
			promptStroke.Color = Ui.RarityColor[run.rarity] or Color3.new(1, 1, 1)
			prompt.Visible = true
		end
		if promptPet then
			local ball = parts[promptPet]
			local camera = workspace.CurrentCamera
			if not ball or not camera or os.clock() > promptUntil or WildShowdown.asked[promptPet] or WildShowdown.done[promptPet] then
				hidePrompt()
			else
				local v = camera.CFrame:PointToObjectSpace(ball.Position)
				arrow.Rotation = WildView.arrowAngle(v.X, v.Z)
			end
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(step)
			if not ok then warn("[PetTower] WildShowdown: " .. tostring(err)) end
		end
	end)
end

return WildShowdown
