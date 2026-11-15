-- Funnel steps and every coin source and sink (bible C3). Calls are wrapped: analytics must never
-- break play. Signatures checked against the Creator docs source on 2026-11-15; events only log in a published game.
local Players = game:GetService("Players")
local RobloxAnalytics = game:GetService("AnalyticsService")
local Profile = require(script.Parent.Parent.Core.Profile)
local Data = require(script.Parent.DataService)

local Analytics = {}
local STEPS = { "Joined", "StarterChosen", "FirstCatch", "FirstPetPlaced", "Floor1", "FirstEvolution", "FirstGuardianWin",
	"FirstChoice", "Floor2", "FirstCoopShowdown", "Session10Min", "Day2Return", "Lv25Evolution" }
local STEP_INDEX = {}
for i, name in ipairs(STEPS) do STEP_INDEX[name] = i end

local function playerOf(profile)
	for player, p in pairs(Data.profiles) do if p == profile then return player end end
end

function Analytics.init()
	Profile.onFunnel = function(profile, step)
		local player, index = playerOf(profile), STEP_INDEX[step]
		if not player or not index then return end
		pcall(function() RobloxAnalytics:LogOnboardingFunnelStepEvent(player, index, step) end)
	end
	Profile.onCoins = function(profile, amount, kind, name)
		local player = playerOf(profile)
		if not player then return end
		pcall(function()
			local flow = kind == "source" and Enum.AnalyticsEconomyFlowType.Source or Enum.AnalyticsEconomyFlowType.Sink
			-- (player, flowType, currencyType, amount, endingBalance, transactionType, itemSku)
			RobloxAnalytics:LogEconomyEvent(player, flow, "Coins", amount, profile.coins, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, name)
		end)
	end
	Data.onLoaded(function(player, profile)
		task.wait(600)
		if player.Parent and Data.get(player) == profile then Profile.funnel(profile, "Session10Min", os.time()) end
	end)
end

return Analytics
