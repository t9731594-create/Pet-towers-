-- Wild pets: shared spawns, Trust Tap tries, the head stack. The server scores every tap.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local E = Config.Economy
local Core = script.Parent.Parent.Core
local SpawnCore = require(Core.SpawnCore)
local TapCore = require(Core.TapCore)
local Profile = require(Core.Profile)
local Net = require(script.Parent.Net)
local Data = require(script.Parent.DataService)
local World = require(script.Parent.WorldService)

local Pets = { floors = {}, tries = {}, tutorial = {}, hooks = {} }
-- hooks.beforeTry(player, profile, pet) -> false, reason  blocks a try (used by later features)
-- hooks.tryOptions(player, profile, pet, opts)            may edit the ring options

local function root(player)
	local ch = player.Character
	return ch and ch:FindFirstChild("HumanoidRootPart")
end
Pets.root = root

function Pets.floorOf(player) return player:GetAttribute("Floor") or 0 end

-- Parts -------------------------------------------------------------------
local function makePart(pet, position, parent)
	local ball = World.petBall(pet.species, pet.rarity, pet.radiant, World.RaritySize[pet.rarity])
	ball.Anchored = true
	ball.CanCollide = false
	ball.Position = position
	ball:SetAttribute("PetId", pet.id)
	ball:SetAttribute("Leaves", pet.leaves)
	ball:SetAttribute("Nature", (Config.Pets.Wild[pet.species] or {}).nature)
	if pet.pillar then
		local beam = World.part({ Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(300, 3, 3), CanCollide = false,
			CFrame = CFrame.new(position + Vector3.new(0, 150, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = World.RarityColor[pet.rarity], Material = Enum.Material.Neon, Transparency = 0.4 }, ball)
		beam.Name = "Pillar"
	end
	ball.Parent = parent
	return ball
end

local function randomSpot(floor)
	local half = floor.size / 2 - 20
	return floor.center + Vector3.new(math.random(-half, half), 3, math.random(-half + 40, half - 10))
end

function Pets.spawnOn(f, forced, position)
	local fl = Pets.floors[f]
	local pet = SpawnCore.spawn(fl.core, Net.now(), forced)
	fl.parts[pet.id] = makePart(pet, position or randomSpot(World.floors[f]), World.floors[f].pets)
	if pet.pillar then Net.all("Banner", { kind = "pillar", floor = f, rarity = pet.rarity, radiant = pet.radiant }) end
	return pet
end

local function findPet(player, petId)
	local tut = Pets.tutorial[player]
	if tut and tut.pet.id == petId then return tut.pet, tut.part end
	local fl = Pets.floors[Pets.floorOf(player)]
	if fl and fl.core.pets[petId] then return fl.core.pets[petId], fl.parts[petId] end
end

-- The head stack: small balls welded above the head, rebuilt on change ------------------
function Pets.refreshStack(player, profile)
	local ch = player.Character
	local head = ch and ch:FindFirstChild("Head")
	if not head then return end
	local old = ch:FindFirstChild("PetStack")
	if old then old:Destroy() end
	local folder = Instance.new("Folder") folder.Name = "PetStack" folder.Parent = ch
	local y = head.Size.Y / 2
	for _, id in ipairs(profile.stack) do
		local pet = Profile.pet(profile, id)
		if pet then
			local size = World.RaritySize[pet.rarity] * 0.6
			local ball = World.petBall(pet.species, pet.rarity, pet.radiant, size)
			ball.CanCollide = false
			ball.Massless = true
			ball.CFrame = head.CFrame * CFrame.new(0, y + size / 2, 0)
			local weld = Instance.new("WeldConstraint") weld.Part0 = head weld.Part1 = ball weld.Parent = ball
			ball.Parent = folder
			y = y + size
		end
	end
end

-- Tries -------------------------------------------------------------------
local function finish(player)
	local try = Pets.tries[player]
	if not try then return end
	Pets.tries[player] = nil
	local profile = Data.get(player)
	if not profile then return end
	local result = TapCore.result(try.tl)
	local pet = try.pet
	Profile.noteTry(profile, result.success)
	if result.success then
		local ok, owned = Profile.addCaught(profile, pet.species, pet.rarity, pet.radiant)
		result.success = ok
		if ok then
			Profile.funnel(profile, "FirstCatch", os.time())
			if profile.tutorial < 1 then profile.tutorial = 1 end
			Pets.refreshStack(player, profile)
			result.petId = owned.id
		end
	end
	result.species, result.rarity, result.radiant = pet.species, pet.rarity, pet.radiant
	if try.tutorial then
		local tut = Pets.tutorial[player]
		if tut then tut.part:Destroy() Pets.tutorial[player] = nil end
	end
	Net.send(player, "TryEnd", result)
	Data.push(player)
	if Pets.hooks.afterTry then Pets.hooks.afterTry(player, profile, pet, result) end
end

local function tryStart(player, profile, petId)
	if type(petId) ~= "number" or Pets.tries[player] then return end
	if not profile.starter or Profile.stackFull(profile) then return end
	local pet, ball = findPet(player, petId)
	if not pet or not ball then return end
	local hrp = root(player)
	if not hrp or (hrp.Position - ball.Position).Magnitude > E.Tap.MaxDistance then return end
	local now = Net.now()
	if pet.tried[player.UserId] or now >= pet.leaves then return end
	if Pets.hooks.beforeTry then
		local ok = Pets.hooks.beforeTry(player, profile, pet)
		if ok == false then return end
	end
	SpawnCore.markTried(pet, player.UserId)
	local opts = {
		rarity = pet.rarity, floor = pet.floor, charm = profile.charm,
		assist = Profile.assistOn(profile), cannotFail = profile.tutorial < 1,
	}
	if Pets.hooks.tryOptions then Pets.hooks.tryOptions(player, profile, pet, opts) end
	local tl = TapCore.issue(opts, now)
	Pets.tries[player] = { tl = tl, pet = pet, tutorial = pet.owner ~= nil }
	Net.send(player, "TryBegin", { petId = pet.id, start = tl.start, beats = tl.beats, ringTime = tl.ringTime, rarity = pet.rarity })
end
Pets.tryStart = tryStart

local function tap(player, _, beat, offset)
	local try = Pets.tries[player]
	if not try then return end
	local ok, grade = TapCore.tap(try.tl, beat, offset, Net.now())
	if not ok then return end
	Net.send(player, "TryGrade", beat, grade)
	if TapCore.complete(try.tl) then finish(player) end
end

-- The first pet: a personal Common 20 studs from the camp spawn that cannot be missed --------
function Pets.spawnTutorialPet(player)
	local camp = World.campOf(player)
	if not camp or Pets.tutorial[player] then return end
	local pet = {
		id = -player.UserId, floor = 1, rarity = "Common", radiant = false, species = Config.Pets.ByFloor[1].Common,
		leaves = math.huge, tried = {}, owner = player.UserId, pillar = false,
	}
	local pos = (camp.spawn * CFrame.new(18, 0, -8)).Position
	Pets.tutorial[player] = { pet = pet, part = makePart(pet, Vector3.new(pos.X, 3, pos.Z), World.tutorialPets) }
end

function Pets.init()
	for f = 1, World.BuiltFloors do
		Pets.floors[f] = { core = SpawnCore.new(f, math.random), parts = {} }
	end
	Net.on("TryStart", Data, tryStart)
	Net.on("Tap", Data, tap)
	Players.PlayerRemoving:Connect(function(player)
		Pets.tries[player] = nil
		local tut = Pets.tutorial[player]
		if tut then tut.part:Destroy() Pets.tutorial[player] = nil end
	end)
	-- spawn / despawn loop, and close tries whose time ran out
	task.spawn(function()
		while true do
			task.wait(1)
			local now = Net.now()
			local busyPets = {}
			for player, try in pairs(Pets.tries) do
				busyPets[try.pet.id] = true
				if TapCore.expired(try.tl, now) then finish(player) end
			end
			for f, fl in pairs(Pets.floors) do
				local spawned, left = SpawnCore.tick(fl.core, now, function(pet)
					return busyPets[pet.id] or (Pets.hooks.keepPet and Pets.hooks.keepPet(pet, now))
				end)
				for _, pet in ipairs(left) do
					if fl.parts[pet.id] then fl.parts[pet.id]:Destroy() fl.parts[pet.id] = nil end
					if Pets.hooks.petLeft then Pets.hooks.petLeft(pet) end
				end
				for _, pet in ipairs(spawned) do
					fl.parts[pet.id] = makePart(pet, randomSpot(World.floors[f]), World.floors[f].pets)
					if pet.pillar then Net.all("Banner", { kind = "pillar", floor = f, rarity = pet.rarity, radiant = pet.radiant }) end
				end
			end
		end
	end)
end

return Pets
