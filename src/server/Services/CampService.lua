-- The camp: starter pedestals, pads and income, Snack Table, Charm Bench. Stations are things you
-- walk to, not menus.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Profile = require(script.Parent.Parent.Core.Profile)
local Net = require(script.Parent.Net)
local Data = require(script.Parent.DataService)
local World = require(script.Parent.WorldService)
local Pets = require(script.Parent.PetService)
local CoinMult = require(script.Parent.CoinMult)

local Camp = {}

local function playerOf(hit)
	local model = hit and hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

-- Show pad pets and how many pads the owner has.
function Camp.refresh(player, profile)
	local camp = World.campOf(player)
	if not camp then return end
	for n, pad in ipairs(camp.pads) do
		pad.Transparency = n <= #profile.pads and 0 or 1
		pad.CanCollide = n <= #profile.pads
		local old = pad:FindFirstChild("PadPet")
		if old then old:Destroy() end
		local slot = profile.pads[n]
		local pet = slot and Profile.pet(profile, slot.pet)
		if pet then
			local ball = World.petBall(pet.species, pet.rarity, pet.radiant, World.RaritySize[pet.rarity] * (pet.hearts >= 5 and 1.4 or pet.hearts >= 3 and 1.2 or 1))
			ball.Anchored = true ball.CanCollide = false ball.Name = "PadPet"
			ball.Position = pad.Position + Vector3.new(0, ball.Size.Y / 2 + 0.3, 0)
			ball.Parent = pad
		end
	end
	for species, st in pairs(camp.pedestals) do
		st.ball.Transparency = profile.starter and 1 or 0
	end
end

-- The starter follows at the player's side (greybox: a welded ball that grows with each stage).
function Camp.refreshStarter(player, profile)
	local ch = player.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not hrp or not profile.starter then return end
	local old = ch:FindFirstChild("StarterPet")
	if old then old:Destroy() end
	local F = require(ReplicatedStorage.Shared.Logic.Formulas)
	local stage = F.starterStage(profile.starter.level)
	local size = 2 + stage * 0.8
	local ball = World.petBall(profile.starter.species, "Common", false, size)
	ball.Name = "StarterPet"
	ball.Color = World.NatureColor[Config.Pets.Starters[profile.starter.species].nature]
	ball.CanCollide = false ball.Massless = true
	ball.CFrame = hrp.CFrame * CFrame.new(3.5, -1, -2)
	local weld = Instance.new("WeldConstraint") weld.Part0 = hrp weld.Part1 = ball weld.Parent = ball
	ball:SetAttribute("Stage", stage)
	ball.Parent = ch
end

local function chooseStarter(player, profile, species)
	if type(species) ~= "string" then return end
	if not Profile.chooseStarter(profile, species) then return end
	Profile.funnel(profile, "StarterChosen", os.time())
	Camp.refresh(player, profile)
	Camp.refreshStarter(player, profile)
	Pets.spawnTutorialPet(player)
	Data.push(player)
end

local function collect(player, profile)
	local _, got = Profile.collect(profile, os.time(), CoinMult(player, profile))
	if got > 0 then Net.send(player, "Coins", got, "pads") Data.push(player) end
end

local function comeHome(player, profile)
	if #profile.stack == 0 then return end
	local _, r = Profile.deposit(profile, os.time())
	Profile.autoTeam(profile)
	if r.placed > 0 then Profile.funnel(profile, "FirstPetPlaced", os.time()) end
	Pets.refreshStack(player, profile)
	Camp.refresh(player, profile)
	Data.push(player)
end
Camp.comeHome = comeHome

local function feed(player, profile)
	local ok, r = Profile.feed(profile)
	if not ok then return end
	if r.evolvedTo then
		if r.evolvedTo == 2 then Profile.funnel(profile, "FirstEvolution", os.time()) end
		if r.evolvedTo == 3 then Profile.funnel(profile, "Lv25Evolution", os.time()) end
		Camp.refreshStarter(player, profile)
		Net.send(player, "Evolve", { species = profile.starter.species, stage = r.evolvedTo })
	end
	Data.push(player)
end

local function buy(player, profile, kind)
	local ok
	if kind == "charm" then ok = Profile.buyCharm(profile)
	elseif kind == "pads" then ok = Profile.buyPads(profile, os.time())
	elseif kind == "stack" then ok = Profile.buyStack(profile) end
	if ok then Camp.refresh(player, profile) Data.push(player) end
end

local function wire(camp)
	local last = {}
	local function debounced(player, what, seconds)
		local k = what .. player.UserId
		if last[k] and os.clock() - last[k] < seconds then return false end
		last[k] = os.clock()
		return true
	end
	for species, st in pairs(camp.pedestals) do
		st.ped.Touched:Connect(function(hit)
			local player = playerOf(hit)
			local profile = player and camp.owner == player and Data.get(player)
			if profile and not profile.starter and debounced(player, "ped", 0.5) then chooseStarter(player, profile, species) end
		end)
	end
	for _, pad in ipairs(camp.pads) do
		pad.Touched:Connect(function(hit)
			local player = playerOf(hit)
			local profile = player and camp.owner == player and Data.get(player)
			if profile and debounced(player, "pad", 0.5) then collect(player, profile) end
		end)
	end
	camp.zone.Touched:Connect(function(hit)
		local player = playerOf(hit)
		local profile = player and camp.owner == player and Data.get(player)
		if profile and (player:GetAttribute("Floor") or 0) == 0 and debounced(player, "zone", 0.5) then comeHome(player, profile) end
	end)
	camp.SnackTablePrompt.Triggered:Connect(function(player)
		local profile = camp.owner == player and Data.get(player)
		if profile then feed(player, profile) end
	end)
	camp.CharmBenchPrompt.Triggered:Connect(function(player)
		local profile = camp.owner == player and Data.get(player)
		if profile then buy(player, profile, "charm") end
	end)
end

function Camp.init()
	for _, camp in ipairs(World.camps) do wire(camp) end
	Net.on("ChooseStarter", Data, chooseStarter)
	Net.on("Collect", Data, collect)
	Net.on("Feed", Data, feed)
	Net.on("Buy", Data, buy)
	Net.on("Heart", Data, function(player, profile, id)
		if type(id) == "number" and Profile.addHeart(profile, id) then Camp.refresh(player, profile) Data.push(player) end
	end)
	Net.on("SetTeam", Data, function(player, profile, a, b)
		if (a == nil or type(a) == "number") and (b == nil or type(b) == "number") and Profile.setTeam(profile, a, b) then Data.push(player) end
	end)
	Net.on("Place", Data, function(player, profile, id, pad)
		if type(id) == "number" and type(pad) == "number" and Profile.place(profile, id, pad, os.time(), CoinMult(player, profile)) then
			Camp.refresh(player, profile) Data.push(player)
		end
	end)
	Net.on("Release", Data, function(player, profile, id)
		if type(id) == "number" and Profile.release(profile, id, os.time(), CoinMult(player, profile)) then
			Camp.refresh(player, profile) Data.push(player)
		end
	end)
	Data.onLoaded(function(player, profile)
		local camp = World.claimCamp(player)
		Profile.funnel(profile, "Joined", os.time())
		local function onCharacter(ch)
			local hrp = ch:WaitForChild("HumanoidRootPart", 10)
			if not hrp then return end
			task.wait()
			if camp then ch:PivotTo(camp.spawn) end
			player:SetAttribute("Floor", 0)
			Camp.refreshStarter(player, profile)
			Pets.refreshStack(player, profile)
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then task.spawn(onCharacter, player.Character) end
		Camp.refresh(player, profile)
		if profile.starter and profile.tutorial < 1 then Pets.spawnTutorialPet(player) end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local camp = World.freeCamp(player)
		if camp then
			for _, pad in ipairs(camp.pads) do
				local old = pad:FindFirstChild("PadPet")
				if old then old:Destroy() end
			end
			for _, st in pairs(camp.pedestals) do st.ball.Transparency = 0 end
		end
	end)
end

return Camp
