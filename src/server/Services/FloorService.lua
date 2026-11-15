-- The lift: camp <-> floors. A player may ride to any floor they have unlocked.
local Profile = require(script.Parent.Parent.Core.Profile)
local Net = require(script.Parent.Net)
local Data = require(script.Parent.DataService)
local World = require(script.Parent.WorldService)
local Pets = require(script.Parent.PetService)

local Floors = {}

function Floors.go(player, profile, floor)
	if type(floor) ~= "number" or floor ~= math.floor(floor) then return end
	local ch = player.Character
	if not ch then return end
	if floor == 0 then
		local camp = World.campOf(player)
		if not camp then return end
		pcall(function() player:RequestStreamAroundAsync(camp.spawn.Position, 5) end)
		ch:PivotTo(camp.spawn)
		player:SetAttribute("Floor", 0)
		Data.setExtra(player, "floor", 0)
		require(script.Parent.CampService).comeHome(player, profile)
		Data.push(player)
		return
	end
	if floor > World.BuiltFloors or not Profile.canEnter(profile, floor) then return end
	if profile.tutorial < 1 then return end -- first make a friend at camp
	pcall(function() player:RequestStreamAroundAsync(World.floors[floor].spawn.Position, 5) end)
	ch:PivotTo(World.floors[floor].spawn)
	player:SetAttribute("Floor", floor)
	Data.setExtra(player, "floor", floor)
	if Profile.funnel(profile, "Floor" .. floor, os.time()) and floor == 1 and profile.tutorial < 2 then
		-- first ride to Floor 1: a guaranteed Rare under a pillar of light, close to the lift
		profile.tutorial = 2
		Pets.spawnOn(1, { rarity = "Rare", radiant = false, pillar = true }, World.floors[1].center + Vector3.new(25, 3, 45))
	end
	Data.push(player)
end

function Floors.init()
	Net.on("Lift", Data, Floors.go)
	for _, camp in ipairs(World.camps) do
		camp.LiftPrompt.Triggered:Connect(function(player)
			local profile = camp.owner == player and Data.get(player)
			if not profile then return end
			local top = math.min(Profile.unlockedFloor(profile), World.BuiltFloors)
			-- one floor open: just ride (no menus in the first minutes). More: choose with number buttons.
			if top <= 1 then Floors.go(player, profile, top) else Net.send(player, "LiftMenu", top) end
		end)
	end
	for _, floor in pairs(World.floors) do
		floor.liftPrompt.Triggered:Connect(function(player)
			local profile = Data.get(player)
			if profile then Floors.go(player, profile, 0) end
		end)
	end
end

return Floors
