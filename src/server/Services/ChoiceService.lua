-- Share or Keep after a first win on a floor; Dawn or Dusk form at starter Lv 42.
-- Only sharing gets a banner. Keeping is never announced.
local Players = game:GetService("Players")
local Profile = require(script.Parent.Parent.Core.Profile)
local Net = require(script.Parent.Net)
local Data = require(script.Parent.DataService)
local Camp = require(script.Parent.CampService)
local CoinMult = require(script.Parent.CoinMult)

local Choice = {}

function Choice.init()
	Net.on("Choose", Data, function(player, profile, floor, choice)
		if type(floor) ~= "number" or type(choice) ~= "string" then return end
		local ok, r = Profile.choose(profile, floor, choice)
		if not ok then return end
		Profile.funnel(profile, "FirstChoice", os.time())
		local weekly = script.Parent:FindFirstChild("WeeklyService")
		if weekly then require(weekly).addPoint(choice == "share" and "dawn" or "dusk") end
		if r.selfSeconds > 0 then
			Net.send(player, "Coins", Profile.grantIncome(profile, r.selfSeconds, "keep", CoinMult(player, profile)), "keep")
		end
		if r.everyoneSeconds > 0 then
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
		local nextFloor = Profile.pendingChoice(profile)
		if nextFloor then Net.send(player, "ChoicePrompt", nextFloor) end
	end)
	Net.on("ChooseForm", Data, function(player, profile, form)
		if Profile.chooseForm(profile, form) then
			Camp.refreshStarter(player, profile)
			Net.send(player, "Evolve", { species = profile.starter.species, stage = 4, form = form })
			Net.send(player, "ClipMoment", { kind = "dawn_dusk", floor = 0 })
			Data.push(player)
		end
	end)
	Data.onLoaded(function(player, profile)
		player:SetAttribute("Side", Profile.side(profile) or "")
		local floor = Profile.pendingChoice(profile)
		if floor then
			task.wait(3)
			if player.Parent then Net.send(player, "ChoicePrompt", floor) end
		end
	end)
end

return Choice
