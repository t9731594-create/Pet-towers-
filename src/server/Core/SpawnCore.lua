-- Shared wild pets on one floor. Everyone sees the same pet, each player gets one try, a success gives
-- that player their own copy. No Roblox APIs: `rand` is injected (0..1).
local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local E, P = Config.Economy, Config.Pets

local SpawnCore = {}

function SpawnCore.new(floor, rand)
	return { floor = floor, rand = rand, pets = {}, nextId = 1, count = 0 }
end

function SpawnCore.rollRarity(rand)
	local r, acc = rand() * 100, 0
	for _, name in ipairs(E.Rarities) do
		acc = acc + E.SpawnOdds[name]
		if r < acc then return name end
	end
	return "Common"
end

-- Add one pet. forced = { rarity, radiant, stay, pillar } for scripted spawns (the tutorial Rare).
function SpawnCore.spawn(s, now, forced)
	forced = forced or {}
	local rarity = forced.rarity or SpawnCore.rollRarity(s.rand)
	local radiant = forced.radiant
	if radiant == nil then radiant = s.rand() < E.RadiantChance end
	local pet = {
		id = s.floor * 100000 + s.nextId,
		floor = s.floor, rarity = rarity, radiant = radiant,
		species = P.ByFloor[s.floor][rarity],
		leaves = now + (forced.stay or E.Spawns.StaySeconds),
		tried = {}, -- userId -> true
		pillar = forced.pillar or rarity == "Legendary" or radiant,
	}
	s.nextId = s.nextId + 1
	s.pets[pet.id] = pet
	s.count = s.count + 1
	return pet
end

-- Remove pets whose time is up and top the floor back up. Returns spawned, left (lists).
-- busy(pet) -> true keeps a pet a little longer while someone is mid-try on it.
function SpawnCore.tick(s, now, busy)
	local spawned, left = {}, {}
	for id, pet in pairs(s.pets) do
		if now >= pet.leaves and not (busy and busy(pet)) then
			s.pets[id] = nil
			s.count = s.count - 1
			left[#left + 1] = pet
		end
	end
	while s.count < E.Spawns.PerFloor do spawned[#spawned + 1] = SpawnCore.spawn(s, now) end
	return spawned, left
end

-- Can this player start a try? One try per player per pet.
function SpawnCore.canTry(s, petId, userId, now)
	local pet = s.pets[petId]
	if not pet or now >= pet.leaves then return false, "gone" end
	if pet.tried[userId] then return false, "tried" end
	return true, pet
end
function SpawnCore.markTried(pet, userId) pet.tried[userId] = true end

return SpawnCore
