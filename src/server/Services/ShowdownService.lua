-- Guardian showdowns: walk into the ring to start or join. Teams play by themselves, players cheer.
-- Everyone in the ring adds their Team Power and everyone gets the full reward.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Core = script.Parent.Parent.Core
local ShowdownCore = require(Core.ShowdownCore)
local Profile = require(Core.Profile)
local Net = require(script.Parent.Net)
local Data = require(script.Parent.DataService)
local World = require(script.Parent.WorldService)
local Friends = require(script.Parent.FriendService)

local Showdown = { active = {}, cooldown = {}, lostAt = {}, byPlayer = {} }
-- byPlayer[player] = the ShowdownCore session that player's cheers go to (guardian or any other kind)

local function snapshot(sd)
	return { floor = sd.floor, kind = sd.kind, start = sd.start, ends = sd.ends, meter = sd.meter, left = sd.left, count = sd.count, id = sd.id }
end
Showdown.snapshot = snapshot

local function playerById(id) return Players:GetPlayerByUserId(id) end

local function join(player, profile, f)
	local floor = World.floors[f]
	if not floor or (player:GetAttribute("Floor") or 0) ~= f or not profile.starter then return end
	local now = Net.now()
	local sd = Showdown.active[f]
	if not sd then
		if Showdown.cooldown[f] and now < Showdown.cooldown[f] then return end
		local guardian = Config.Pets.Guardians[f]
		sd = ShowdownCore.guardian(f, guardian.nature, now)
		Showdown.active[f] = sd
	end
	if sd.players[player.UserId] or Showdown.byPlayer[player] then return end
	if ShowdownCore.join(sd, player.UserId, Profile.teamPower(profile, sd.nature), now) then
		Showdown.byPlayer[player] = sd
		ShowdownCore.refreshFriends(sd, Friends.are)
		Net.send(player, "ShowdownState", snapshot(sd))
	end
end

local function finish(f, sd)
	Showdown.active[f] = nil
	Showdown.cooldown[f] = Net.now() + 3
	local ids = ShowdownCore.participants(sd)
	local won = sd.state == "won"
	if won then World.relight(f) end
	for _, id in ipairs(ids) do
		local player = playerById(id)
		local profile = player and Data.get(player)
		if player then Showdown.byPlayer[player] = nil end
		if profile then
			local first = false
			if won then
				first = Profile.clearFloor(profile, f)
				if first and f == 1 then Profile.funnel(profile, "FirstGuardianWin", os.time()) end
				if #ids >= 2 then Profile.funnel(profile, "FirstCoopShowdown", os.time()) end
				if not first then profile.stats.helps = (profile.stats.helps or 0) + 1 end
			else
				Showdown.lostAt[player] = Net.now()
			end
			Net.send(player, "ShowdownEnd", { floor = f, won = won, firstClear = first, kind = sd.kind, count = #ids })
			Data.push(player)
		end
	end
	if won then Net.all("Banner", { kind = "relit", floor = f }) end
end

function Showdown.init()
	for f, floor in pairs(World.floors) do
		local last = {}
		floor.ring.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			local player = model and Players:GetPlayerFromCharacter(model)
			local profile = player and Data.get(player)
			if not profile then return end
			if last[player] and os.clock() - last[player] < 1 then return end
			last[player] = os.clock()
			join(player, profile, f)
		end)
	end
	Net.on("ShowdownJoin", Data, function(player, profile) join(player, profile, player:GetAttribute("Floor") or 0) end)
	Net.on("Cheer", Data, function(player, _, offset)
		local sd = Showdown.byPlayer[player]
		if not sd then return end
		local ok, grade = ShowdownCore.cheer(sd, player.UserId, offset, Net.now())
		if ok then Net.send(player, "CheerGrade", grade) end
	end)
	-- Call for help: only after a lost showdown, pings the server. The client offers the invite prompt.
	Net.on("CallHelp", Data, function(player)
		local t = Showdown.lostAt[player]
		if not t or Net.now() - t > 120 then return end
		Showdown.lostAt[player] = nil
		Net.all("Banner", { kind = "help", floor = player:GetAttribute("Floor") or 0, userId = player.UserId })
	end)
	Players.PlayerRemoving:Connect(function(player)
		Showdown.byPlayer[player] = nil
		Showdown.lostAt[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = Net.now()
			for f, sd in pairs(Showdown.active) do
				local state = ShowdownCore.tick(sd, now)
				local snap = snapshot(sd)
				for id in pairs(sd.players) do
					local player = playerById(id)
					if player then Net.send(player, "ShowdownState", snap) end
				end
				if state ~= "active" then finish(f, sd) end
			end
		end
	end)
end

return Showdown
