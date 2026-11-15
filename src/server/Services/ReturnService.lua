-- Welcome-back chest, rested bonus, journey ladder, Mystery Egg. Warm, never urgent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Core = script.Parent.Parent.Core
local ReturnCore = require(Core.ReturnCore)
local Profile = require(Core.Profile)
local Net = require(script.Parent.Net)
local Data = require(script.Parent.DataService)
local World = require(script.Parent.WorldService)
local Camp = require(script.Parent.CampService)

local Return = {}

local function hatch(player, profile)
	local ok, pet = ReturnCore.hatchEgg(profile, os.time(), math.random)
	if not ok then return end
	Profile.autoTeam(profile)
	Camp.refresh(player, profile)
	Net.send(player, "EggHatched", { species = pet.species, rarity = pet.rarity, radiant = pet.radiant })
	Data.push(player)
end

function Return.init()
	Data.onLoaded(function(player, profile)
		local summary = ReturnCore.onJoin(profile, os.time())
		task.wait(2) -- let the client finish loading its controllers
		if player.Parent then
			Net.send(player, "Welcome", summary)
			Data.push(player)
		end
	end)
	Net.on("HatchEgg", Data, hatch)
	for _, camp in ipairs(World.camps) do
		camp.EggNestPrompt.Triggered:Connect(function(player)
			local profile = camp.owner == player and Data.get(player)
			if profile then hatch(player, profile) end
		end)
	end
	-- the first egg starts when the starter is chosen, and the egg of a new day starts while online
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local profile = Data.get(player)
				if profile and ReturnCore.startEgg(profile, os.time()) then Data.push(player) end
			end
		end
	end)
end

return Return
