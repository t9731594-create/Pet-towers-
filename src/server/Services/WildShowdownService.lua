-- Wild showdowns: Epic, Legendary and Secret pets want to play first. Walk up, your team plays with the
-- pet, you cheer (the Guardian cheer rings). Meter empty = everyone who took part gets one friendly try.
-- Rules live in Core/WildCore; this file only talks to Roblox, PetService and ShowdownService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local E = Config.Economy
local Core = script.Parent.Parent.Core
local WildCore = require(Core.WildCore)
local ShowdownCore = require(Core.ShowdownCore)
local Profile = require(Core.Profile)
local Net = require(script.Parent.Net)
local Data = require(script.Parent.DataService)
local Pets = require(script.Parent.PetService)
local Showdown = require(script.Parent.ShowdownService)
local Friends = require(script.Parent.FriendService)

local Wild = { sessions = {} } -- pet id -> { s = WildCore session, pet = the SpawnCore pet }

local function wildStats(profile)
	local stats = profile.stats
	stats.wild = stats.wild or { started = 0, coop = 0, finished = 0 }
	return stats.wild
end

local function snapshot(entry)
	local snap = Showdown.snapshot(entry.s.sd) -- floor, kind = "wild", start, ends = nil, meter, left, count
	snap.petId = entry.pet.id
	snap.rarity = entry.pet.rarity
	return snap
end

-- Stop routing this player's cheers here (only if they still point at this session).
local function release(player, entry)
	if Showdown.byPlayer[player] == entry.s.sd then Showdown.byPlayer[player] = nil end
end

-- Tell everyone who took part and is still on the floor how it ended, and free their cheers.
local function tellEnd(entry, won)
	local pet = entry.pet
	for _, id in ipairs(WildCore.participants(entry.s)) do
		local player = Players:GetPlayerByUserId(id)
		if player then
			release(player, entry)
			if Pets.floorOf(player) == pet.floor then
				Net.send(player, "ShowdownEnd", { kind = "wild", petId = pet.id, floor = pet.floor, won = won })
			end
		end
	end
end

-- The meter is empty: the pet now trusts everyone who played. Runs once per pet.
local function playedOut(entry)
	if entry.done then return end
	entry.done = true
	local pet, s = entry.pet, entry.s
	local part = Pets.partOf(pet)
	-- PetService refuses a try once now >= pet.leaves, so the grace has to move the leave time itself
	-- (the keepPet hook alone only keeps the part in the world).
	local grace = WildCore.graceEnds(s)
	if grace and pet.leaves < grace then pet.leaves = grace end
	if part then
		part:SetAttribute("NeedsPlay", nil)
		part:SetAttribute("Leaves", pet.leaves)
	end
	local coop = s.tookCount >= 2
	for _, id in ipairs(WildCore.participants(s)) do
		local player = Players:GetPlayerByUserId(id)
		local profile = player and Data.get(player)
		if profile then
			local w = wildStats(profile)
			w.finished = w.finished + 1
			if coop then w.coop = w.coop + 1 end
			Data.push(player)
		end
	end
	tellEnd(entry, true)
	if coop and (pet.rarity == "Legendary" or pet.rarity == "Secret") then
		Net.all("ClipMoment", { kind = pet.rarity == "Secret" and "secret" or "wild_legendary", floor = pet.floor })
	end
end

local function join(player, profile, petId)
	if type(petId) ~= "number" then return end
	local entry = Wild.sessions[petId]
	if not entry or entry.s.state ~= "active" then return end
	local pet = entry.pet
	if Pets.floorOf(player) ~= pet.floor then return end
	if not profile.starter then return end
	if Showdown.byPlayer[player] or Pets.tries[player] then return end
	local part, hrp = Pets.partOf(pet), Pets.root(player)
	if not part or not hrp then return end
	if (hrp.Position - part.Position).Magnitude > E.Wild.JoinDistance then return end
	local now = Net.now()
	if now >= pet.leaves then return end
	local s = entry.s
	local first = not s.took[player.UserId]
	if not WildCore.join(s, player.UserId, Profile.teamPower(profile, s.nature), now) then
		if s.state == "won" then playedOut(entry) end
		return
	end
	Showdown.byPlayer[player] = s.sd
	ShowdownCore.refreshFriends(s.sd, Friends.are)
	if first then
		local w = wildStats(profile)
		w.started = w.started + 1
	end
	Net.send(player, "ShowdownState", snapshot(entry))
end

-- One pass over every pet that still wants to play.
local function step(now)
	for _, entry in pairs(Wild.sessions) do
		local s = entry.s
		if s.state == "active" then
			-- players who left the floor or the game step out; what they drained stays drained
			local gone = {}
			for id in pairs(s.sd.players) do
				local player = Players:GetPlayerByUserId(id)
				if not player or Pets.floorOf(player) ~= entry.pet.floor then gone[#gone + 1] = id end
			end
			for _, id in ipairs(gone) do
				WildCore.stepOut(s, id, now)
				local player = Players:GetPlayerByUserId(id)
				if player then release(player, entry) end
			end
			if #gone > 0 then ShowdownCore.refreshFriends(s.sd, Friends.are) end
			local state = WildCore.tick(s, now)
			if s.sd.count > 0 then
				local snap = snapshot(entry)
				for id in pairs(s.sd.players) do
					local player = Players:GetPlayerByUserId(id)
					if player then Net.send(player, "ShowdownState", snap) end
				end
			end
			if state == "won" then playedOut(entry) end
		end
	end
end

function Wild.init()
	Pets.hook("petSpawned", function(pet, ball)
		if pet.owner or not WildCore.needsPlay(pet.rarity) then return end
		local def = Config.Pets.Wild[pet.species]
		Wild.sessions[pet.id] = { s = WildCore.new(pet, def and def.nature, Net.now()), pet = pet }
		ball:SetAttribute("NeedsPlay", true)
	end)
	-- Nobody tries before the meter is empty, and only players who took part may try.
	Pets.hook("beforeTry", function(player, _, pet)
		if pet.owner or not WildCore.needsPlay(pet.rarity) then return end
		local entry = Wild.sessions[pet.id]
		if not entry or not WildCore.canTry(entry.s, player.UserId) then return false end
	end)
	-- The pet has played with you: rings 20% slower.
	Pets.hook("tryOptions", function(player, _, pet, opts)
		local entry = Wild.sessions[pet.id]
		if entry and WildCore.canTry(entry.s, player.UserId) then opts.friendly = true end
	end)
	Pets.hook("keepPet", function(pet, now)
		local entry = Wild.sessions[pet.id]
		if entry and WildCore.keep(entry.s, now) then return true end
	end)
	-- The pet left. If the meter was not empty it just leaves: nothing is lost.
	Pets.hook("petLeft", function(pet)
		local entry = Wild.sessions[pet.id]
		if not entry then return end
		Wild.sessions[pet.id] = nil
		if entry.s.state == "active" then
			WildCore.leave(entry.s, Net.now())
			tellEnd(entry, false)
		end
	end)
	Net.on("WildJoin", Data, join)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(step, Net.now())
			if not ok then warn("[PetTower] wild showdown: " .. tostring(err)) end
		end
	end)
end

return Wild
