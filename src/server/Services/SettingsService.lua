-- Settings (music, effects, low graphics, tap assist, reduced flash) and the Index Board.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Profile = require(script.Parent.Parent.Core.Profile)
local IndexView = require(ReplicatedStorage.Shared.Logic.IndexView)
local Net = require(script.Parent.Net)
local Data = require(script.Parent.DataService)
local World = require(script.Parent.WorldService)
local Settings = {}
function Settings.init()
	Net.on("SetSetting", Data, function(player, profile, key, value)
		if type(key) == "string" and Profile.setSetting(profile, key, value) then Data.push(player) end
	end)
	local function index(player, profile) Net.send(player, "Index", IndexView.build(profile, World.BuiltFloors)) end
	Net.on("IndexOpen", Data, index)
	local ReturnCore = require(script.Parent.Parent.Core.ReturnCore)
	local function closet(player, profile)
		local looks = {}
		for id in pairs(profile.looks) do looks[#looks + 1] = id end
		table.sort(looks)
		Net.send(player, "Closet", { looks = looks, equipped = profile.equipped or {} })
	end
	local function wear(player, profile)
		local e = profile.equipped or {}
		player:SetAttribute("Aura", e.aura or "") player:SetAttribute("Trail", e.trail or "")
		player:SetAttribute("Trim", e.trim or "") player:SetAttribute("CampLook", e.camp or "") player:SetAttribute("LiftLook", e.lift or "")
	end
	local function mail(player, profile)
		Net.send(player, "Mail", { journeyDay = profile.journeyDay, tomorrow = ReturnCore.ladderGift(profile.journeyDay + 1),
			egg = ReturnCore.eggState(profile, os.time()), codes = next(require(ReplicatedStorage.Shared.Config).Codes) ~= nil })
	end
	Net.on("Equip", Data, function(player, profile, look, slot)
		if type(look) ~= "string" or #look > 40 then return end
		if Profile.equip(profile, look, type(slot) == "string" and slot or nil) then
			wear(player, profile) closet(player, profile) Data.push(player)
		end
	end)
	Net.on("MailOpen", Data, mail)
	Data.onLoaded(function(player, profile) wear(player, profile) end)
	for _, camp in ipairs(World.camps) do
		camp.IndexBoardPrompt.Triggered:Connect(function(player)
			local profile = camp.owner == player and Data.get(player)
			if profile then index(player, profile) end
		end)
		camp.ClosetPrompt.Triggered:Connect(function(player)
			local profile = camp.owner == player and Data.get(player)
			if profile then closet(player, profile) end
		end)
		camp.MailboxPrompt.Triggered:Connect(function(player)
			local profile = camp.owner == player and Data.get(player)
			if profile then mail(player, profile) end
		end)
	end
end
return Settings
