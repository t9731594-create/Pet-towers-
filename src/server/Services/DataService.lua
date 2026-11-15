-- Loads, autosaves and releases player profiles (session-locked, bible C1).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataCore = require(script.Parent.Parent.Core.DataCore)
local Profile = require(script.Parent.Parent.Core.Profile)
local F = require(ReplicatedStorage.Shared.Logic.Formulas)
local E = require(ReplicatedStorage.Shared.Config).Economy
local Net = require(script.Parent.Net)

local Data = { profiles = {}, loaded = {}, extras = {}, away = {} }
-- away[player] = seconds the Studio debug command "away" pretends the player has been gone: every save
-- stamps lastSeen with the time now, so the pretend time has to be taken off there.
local STORE_NAME = "PetTower_PlayerData_v1"
local core

-- In Studio without API access the DataStore throws: fall back to memory so play-testing works.
local function memoryStore()
	local rows = {}
	return { update = function(_, key, fn) local new = fn(rows[key]) if new ~= nil then rows[key] = new end end }
end
local function realStore()
	local ds = DataStoreService:GetDataStore(STORE_NAME)
	return { update = function(_, key, fn) ds:UpdateAsync(key, fn) end }
end

function Data.get(player) return Data.profiles[player] end
function Data.onLoaded(fn) table.insert(Data.loaded, fn) end

-- Send the player their state. Services call this after any change.
function Data.push(player)
	local p = Data.profiles[player]
	if not p then return end
	local extra = Data.extras[player] or {}
	extra.teamPower = Profile.teamPower(p)
	extra.income = Profile.incomePerSecond(p)
	extra.stackCap = Profile.stackCap(p)
	extra.feedCost = p.starter and F.levelCost(p.starter.level) or 0
	extra.coinMult = require(script.Parent.CoinMult)(player, p)
	extra.index = { Profile.indexCount(p) }
	Data.extras[player] = extra
	Net.send(player, "State", p, extra)
	local ls = player:FindFirstChild("leaderstats")
	if ls then ls.Floor.Value = Profile.unlockedFloor(p) ls.Power.Value = math.floor(extra.teamPower) end
end
function Data.setExtra(player, key, value)
	Data.extras[player] = Data.extras[player] or {}
	Data.extras[player][key] = value
end

local function key(player) return "u_" .. player.UserId end

local function load(player)
	local p, why = core:load(key(player))
	if not p and why == "locked" then
		-- another server may still be saving: wait and try a few more times
		for _ = 1, 4 do
			task.wait(4)
			if not player.Parent then return end
			p, why = core:load(key(player))
			if p then break end
		end
	end
	if not p then
		player:Kick("Your pets are safe. The tower could not open your save just now - please join again in a minute.")
		return
	end
	if not player.Parent then core:save(key(player), p, true) return end
	local ls = Instance.new("Folder") ls.Name = "leaderstats"
	local floor = Instance.new("IntValue") floor.Name = "Floor" floor.Parent = ls
	local power = Instance.new("IntValue") power.Name = "Power" power.Parent = ls
	ls.Parent = player
	Data.profiles[player] = p
	for _, fn in ipairs(Data.loaded) do task.spawn(fn, player, p) end
	Data.push(player)
end

local function save(player, release)
	local p = Data.profiles[player]
	if not p then return end
	p.lastSeen = os.time() - (Data.away[player] or 0)
	if release then Data.profiles[player] = nil Data.extras[player] = nil Data.away[player] = nil end -- first, so a second caller does nothing
	local ok, why = core:save(key(player), p, release)
	if not ok then warn("[PetTower] save failed for " .. player.UserId .. ": " .. tostring(why)) end
end

-- Save right now and report success (used before answering a purchase receipt).
function Data.saveNow(player)
	local p = Data.profiles[player]
	if not p then return false end
	p.lastSeen = os.time() - (Data.away[player] or 0)
	local ok = core:save(key(player), p, false)
	return ok
end

function Data.init()
	local store
	local ok = pcall(function() store = realStore() store:update("__probe", function() return nil end) end)
	if not ok then
		if RunService:IsStudio() then
			warn("[PetTower] DataStore unavailable in Studio: using memory only (nothing is saved).")
			store = memoryStore()
		else
			store = realStore()
		end
	end
	core = DataCore.new(store, game.JobId ~= "" and game.JobId or "studio", os.time, task.wait)
	Players.PlayerAdded:Connect(load)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(load, player) end
	Players.PlayerRemoving:Connect(function(player) save(player, true) end)
	game:BindToClose(function()
		local waiting = 0
		for _, player in ipairs(Players:GetPlayers()) do
			waiting = waiting + 1
			task.spawn(function() save(player, true) waiting = waiting - 1 end)
		end
		local t0 = os.clock()
		while waiting > 0 and os.clock() - t0 < 25 do task.wait(0.1) end
	end)
	task.spawn(function()
		while true do
			task.wait(E.Data.AutosaveSeconds)
			for _, player in ipairs(Players:GetPlayers()) do task.spawn(save, player, false) end
		end
	end)
end

return Data
