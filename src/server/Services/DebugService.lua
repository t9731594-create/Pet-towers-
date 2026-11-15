-- Testing commands. STUDIO ONLY: in a live game this service does nothing at all.
local RunService = game:GetService("RunService")
local Profile = require(script.Parent.Parent.Core.Profile)
local Net = require(script.Parent.Net)
local Data = require(script.Parent.DataService)
local Pets = require(script.Parent.PetService)
local Camp = require(script.Parent.CampService)
local World = require(script.Parent.WorldService)

local Debug = {}
local commands = {
	coins = function(_, p, n) Profile.addCoins(p, tonumber(n) or 1000, "debug") end,
	level = function(player, p, n) if p.starter then p.starter.level = math.max(1, tonumber(n) or 5) Camp.refreshStarter(player, p) end end,
	clear = function(_, p, n) Profile.clearFloor(p, tonumber(n) or (p.cleared + 1)) end,
	spawn = function(player, _, rarity) -- "Epic", "Legendary", "Secret", ... next to the player
		local f = Pets.floorOf(player)
		local hrp = Pets.root(player)
		if f >= 1 and hrp then Pets.spawnOn(f, { rarity = rarity or "Legendary", radiant = false, pillar = rarity == "Secret" }, hrp.Position + Vector3.new(12, 0, 0)) end
	end,
	radiant = function(player)
		local f, hrp = Pets.floorOf(player), Pets.root(player)
		if f >= 1 and hrp then Pets.spawnOn(f, { rarity = "Common", radiant = true }, hrp.Position + Vector3.new(12, 0, 0)) end
	end,
	away = function(player, p, hours) -- then rejoin. (Saving stamps lastSeen, so the save is told the pretend time.)
		local seconds = (tonumber(hours) or 16) * 3600
		Data.away[player] = seconds
		p.lastSeen = os.time() - seconds
		p.lastPlayDay = math.floor(p.lastSeen / 86400) -- the journey ladder counts UTC days
	end,
	egg = function(_, p) if p.egg then p.egg.start = os.time() - 9 * 3600 end end,
	stack = function(_, p, n) p.upgrades.stack = math.min(7, tonumber(n) or 7) end,
	wipe = function(player, p) -- fresh profile on next join
		for k in pairs(p) do p[k] = nil end
		for k, v in pairs(Profile.new(os.time())) do p[k] = v end
		Camp.refresh(player, p)
	end,
}

function Debug.init()
	if not RunService:IsStudio() then return end
	Net.on("Debug", Data, function(player, profile, command, arg)
		local fn = type(command) == "string" and commands[command]
		if not fn then return end
		fn(player, profile, arg)
		Camp.refresh(player, profile)
		Data.push(player)
		print("[PetTower debug]", player.Name, command, arg)
	end)
	print("[PetTower] debug commands on (Studio only), floors built: " .. World.BuiltFloors)
end

return Debug
