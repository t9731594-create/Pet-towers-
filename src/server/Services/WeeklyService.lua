-- The week: Weekly Guardian in the hub, weekend merchant, Dawn-vs-Dusk scale, monument of first clears.
-- Shared numbers (tally, monument) live in one global DataStore and are batched: never per action.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Core = script.Parent.Parent.Core
local WeeklyCore = require(Core.WeeklyCore)
local ShowdownCore = require(Core.ShowdownCore)
local Profile = require(Core.Profile)
local Net = require(script.Parent.Net)
local Data = require(script.Parent.DataService)
local World = require(script.Parent.WorldService)
local Camp = require(script.Parent.CampService)
local Showdown = require(script.Parent.ShowdownService)
local Friends = require(script.Parent.FriendService)
local CoinMult = require(script.Parent.CoinMult)

local Weekly = { sd = nil, cooldown = 0, tally = {}, monument = {}, pendingTally = { dawn = 0, dusk = 0 }, pendingNames = {} }
local store
local function global(key, fn)
	if not store then return false end
	return pcall(function() store:UpdateAsync(key, fn) end)
end

local function payload(player, profile)
	local now = os.time()
	local week = WeeklyCore.week(now)
	local items = WeeklyCore.merchantItems(profile, week)
	local bought = profile.weekly.merchantWeek == week and profile.weekly.bought or {}
	for _, item in ipairs(items) do item.bought = bought[tostring(item.slot)] == true end
	local names = {}
	for floor, list in pairs(Weekly.monument) do
		names[floor] = {}
		for i, e in ipairs(list) do names[floor][i] = e.name end
	end
	return {
		week = week, guardian = WeeklyCore.guardian(week), merchantOpen = WeeklyCore.merchantOpen(now), items = items,
		tally = Weekly.tally[week] or { dawn = 0, dusk = 0 }, lastLeader = WeeklyCore.leader(Weekly.tally[week - 1]),
		trim = WeeklyCore.wearsTrim(profile, Weekly.tally[week - 1]), monument = names,
	}
end
local function push(player)
	local profile = Data.get(player)
	if profile then Net.send(player, "Week", payload(player, profile)) end
end

local function sync()
	local week = WeeklyCore.week(os.time())
	local add = Weekly.pendingTally
	Weekly.pendingTally = { dawn = 0, dusk = 0 }
	for _, w in ipairs({ week, week - 1 }) do
		local ok = global("tally_" .. w, function(old)
			old = old or { dawn = 0, dusk = 0 }
			if w == week then old.dawn = old.dawn + add.dawn old.dusk = old.dusk + add.dusk end
			Weekly.tally[w] = old
			return old
		end)
		if not ok and w == week then -- keep the points for the next try
			Weekly.pendingTally.dawn = Weekly.pendingTally.dawn + add.dawn
			Weekly.pendingTally.dusk = Weekly.pendingTally.dusk + add.dusk
		end
	end
	local names = Weekly.pendingNames
	Weekly.pendingNames = {}
	global("monument", function(old)
		old = old or {}
		for _, e in ipairs(names) do
			local key = tostring(e.floor)
			old[key] = WeeklyCore.monumentAdd(old[key], e.userId, e.name, e.t)
		end
		Weekly.monument = old
		return old
	end)
end

-- Called by ChoiceService-style code paths: every Share / Keep adds to the week's scale.
function Weekly.addPoint(side) Weekly.pendingTally[side] = Weekly.pendingTally[side] + 1 end

local function join(player, profile)
	if (player:GetAttribute("Floor") or 0) ~= 0 or not profile.starter or Showdown.byPlayer[player] then return end
	local now = Net.now()
	if not Weekly.sd then
		if now < Weekly.cooldown then return end
		Weekly.sd = WeeklyCore.newShowdown(now)
	end
	if WeeklyCore.join(Weekly.sd, player.UserId, Profile.teamPower(profile), now) then
		Showdown.byPlayer[player] = Weekly.sd
		ShowdownCore.refreshFriends(Weekly.sd, Friends.are)
	end
end

local function finish(sd)
	Weekly.sd = nil
	Weekly.cooldown = Net.now() + 5
	local week = WeeklyCore.week(os.time())
	for _, id in ipairs(ShowdownCore.participants(sd)) do
		local player = Players:GetPlayerByUserId(id)
		local profile = player and Data.get(player)
		if player then Showdown.byPlayer[player] = nil end
		if profile then
			local first = false
			if sd.state == "won" then first = WeeklyCore.win(profile, week).first end
			Net.send(player, "ShowdownEnd", { kind = "weekly", floor = 0, won = sd.state == "won", firstClear = first })
			if first then Net.send(player, "WeeklyChoice") end
			Data.push(player)
		end
	end
end

function Weekly.init()
	pcall(function() store = DataStoreService:GetDataStore("PetTower_Global_v1") end)
	local last = {}
	World.hub.weeklyRing.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		local player = model and Players:GetPlayerFromCharacter(model)
		local profile = player and Data.get(player)
		if not profile or (last[player] and os.clock() - last[player] < 1) then return end
		last[player] = os.clock()
		join(player, profile)
	end)
	Net.on("ChooseWeekly", Data, function(player, profile, choice)
		local ok, r = WeeklyCore.choose(profile, choice)
		if not ok then return end
		Weekly.addPoint(r.side)
		if r.selfSeconds > 0 then
			Net.send(player, "Coins", Profile.grantIncome(profile, r.selfSeconds, "keep", CoinMult(player, profile)), "keep")
		else
			for _, other in ipairs(Players:GetPlayers()) do
				local op = Data.get(other)
				if op and op.starter then
					Net.send(other, "Coins", Profile.grantIncome(op, r.everyoneSeconds, "share", CoinMult(other, op)), "share")
					if other ~= player then Data.push(other) end
				end
			end
			Net.all("Shared", { userId = player.UserId, name = player.DisplayName })
		end
		player:SetAttribute("Side", Profile.side(profile) or "")
		Data.push(player)
	end)
	Net.on("MerchantBuy", Data, function(player, profile, slot)
		if type(slot) ~= "number" then return end
		if WeeklyCore.merchantBuy(profile, slot, os.time()) then
			Profile.autoTeam(profile)
			Camp.refresh(player, profile)
			Data.push(player)
			push(player)
		end
	end)
	table.insert(Showdown.onClear, function(player, _, floor)
		table.insert(Weekly.pendingNames, { floor = floor, userId = player.UserId, name = player.DisplayName, t = os.time() })
	end)
	Data.onLoaded(function(player) task.wait(3) if player.Parent then push(player) end end)
	Players.PlayerRemoving:Connect(function(player) last[player] = nil end)
	task.spawn(function() -- the showdown
		while true do
			task.wait(0.25)
			local sd = Weekly.sd
			if sd then
				local state = ShowdownCore.tick(sd, Net.now())
				local snap = Showdown.snapshot(sd)
				for id in pairs(sd.players) do
					local player = Players:GetPlayerByUserId(id)
					if player then Net.send(player, "ShowdownState", snap) end
				end
				if state ~= "active" then finish(sd) end
			end
		end
	end)
	task.spawn(function() -- shared numbers, once a minute
		while true do
			sync()
			for _, player in ipairs(Players:GetPlayers()) do push(player) end
			task.wait(60)
		end
	end)
end

return Weekly
