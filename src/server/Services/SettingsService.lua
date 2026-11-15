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
	for _, camp in ipairs(World.camps) do
		camp.IndexBoardPrompt.Triggered:Connect(function(player)
			local profile = camp.owner == player and Data.get(player)
			if profile then index(player, profile) end
		end)
	end
end
return Settings
