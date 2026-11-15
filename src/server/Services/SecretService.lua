-- Secret pets: the floor's lantern chimes and its Secret pet visits for a few minutes. The times come
-- from SecretCore (the UTC clock only), so every server chimes together without sharing anything.
-- Kindness rule (bible B2): the clients are told what is happening now, never when the next chime is.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local S = Config.Economy.Secret
local SecretCore = require(script.Parent.Parent.Core.SecretCore)
local Net = require(script.Parent.Net)
local World = require(script.Parent.WorldService)
local Pets = require(script.Parent.PetService)

-- floors[f] = { glowKey, hereKey = keys already handled, visit = { at, leaves, petId } while the pet is out }
local Secret = { floors = {} }

local GONE_GRACE = 60 -- seconds after `leaves` to wait for a pet another service is keeping

local function chime(floor, phase, at, leaves)
	return { floor = floor, phase = phase, at = at, leaves = leaves }
end

local function step(f, now)
	local st = Secret.floors[f]
	local p = SecretCore.phase(f, now)
	if p.phase == "glow" and st.glowKey ~= p.key then
		st.glowKey = p.key
		Net.all("SecretChime", chime(f, "glow", p.at, p.leaves))
	elseif p.phase == "here" and st.hereKey ~= p.key then
		st.hereKey = p.key -- set first: one spawn per chime, even if the spawn fails
		local stay = p.leaves - now -- the whole visit, or what is left of it when the server starts late
		if stay >= 1 and Pets.floors[f] then
			local ok, pet = pcall(Pets.spawnOn, f, { rarity = S.Rarity, radiant = false, stay = stay, pillar = true })
			if ok and pet then
				st.visit = { at = p.at, leaves = p.leaves, petId = pet.id }
				Net.all("SecretChime", chime(f, "here", p.at, p.leaves))
				Net.all("Banner", { kind = "secret", floor = f })
			else
				warn("[PetTower] secret spawn on floor " .. f .. ": " .. tostring(pet))
			end
		end
	end
	-- the visit ends when its time is up and the pet has really left (a pet being played with may stay a little)
	local v = st.visit
	if v and now >= v.leaves and (v.petId == nil or now >= v.leaves + GONE_GRACE) then
		st.visit = nil
		Net.all("SecretChime", chime(f, "gone", v.at, v.leaves))
	end
end

-- A player who arrives in the middle of a glow or a visit sees it too.
local function catchUp(player)
	local now = os.time()
	for f, st in pairs(Secret.floors) do
		if st.visit then
			Net.send(player, "SecretChime", chime(f, "here", st.visit.at, st.visit.leaves))
		else
			local p = SecretCore.phase(f, now)
			if p.phase == "glow" then Net.send(player, "SecretChime", chime(f, "glow", p.at, p.leaves)) end
		end
	end
end

function Secret.init()
	for f = 1, World.BuiltFloors do Secret.floors[f] = {} end
	Pets.hook("petLeft", function(pet)
		local st = Secret.floors[pet.floor]
		if st and st.visit and st.visit.petId == pet.id then st.visit.petId = nil end
	end)
	Players.PlayerAdded:Connect(function(player)
		local ok, err = pcall(catchUp, player)
		if not ok then warn("[PetTower] secret catch-up: " .. tostring(err)) end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for f = 1, World.BuiltFloors do
				local ok, err = pcall(step, f, now)
				if not ok then warn("[PetTower] secret floor " .. f .. ": " .. tostring(err)) end
			end
		end
	end)
end

return Secret
