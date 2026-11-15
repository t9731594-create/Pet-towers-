-- Robux purchases. NOTHING is offered until Config.Shop.Approved is true and the owner has approved
-- every price. ProcessReceipt is always connected so a purchase can never be lost.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Core = script.Parent.Parent.Core
local ShopCore = require(Core.ShopCore)
local Profile = require(Core.Profile)
local Net = require(script.Parent.Net)
local Data = require(script.Parent.DataService)
local Camp = require(script.Parent.CampService)
local CoinMult = require(script.Parent.CoinMult)

local Shop = {}

local function refreshPasses(player, profile)
	local owned = {}
	for key, id in pairs(Config.Shop.PassIds) do
		local ok, has = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id) end)
		if ok and has then owned[key] = true end
	end
	if ShopCore.applyPasses(profile, owned, os.time()) then
		Camp.refresh(player, profile)
		Data.push(player)
	end
end

function Shop.init()
	local problems = ShopCore.audit(Config.Shop)
	if #problems > 0 then error("[PetTower] shop items that look random: " .. table.concat(problems, ", ")) end
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local profile = player and Data.get(player)
		if not profile then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local result = ShopCore.processReceipt(profile, info.PurchaseId, info.ProductId, Config.Shop.ProductCatalog, os.time())
		if result == "unknown" then return Enum.ProductPurchaseDecision.NotProcessedYet end
		if result == "granted" then
			-- save before answering, so the grant and the receipt are stored together
			if not Data.saveNow(player) then return Enum.ProductPurchaseDecision.NotProcessedYet end
			Data.push(player)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	Data.onLoaded(function(player, profile) refreshPasses(player, profile) end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _, bought)
		local profile = bought and Data.get(player)
		if profile then refreshPasses(player, profile) end
	end)
	Net.on("RedeemCode", Data, function(player, profile, code)
		local ok = ShopCore.redeemCode(profile, code, Config.Codes)
		if ok then Data.push(player) end
	end)
	-- Auto-Collect pass: pads empty themselves while the player is online
	task.spawn(function()
		while true do
			task.wait(Config.Economy.Passes.AutoCollectSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = Data.get(player)
				if profile and profile.passes.AutoCollect then
					local _, got = Profile.collect(profile, os.time(), CoinMult(player, profile))
					if got > 0 then Net.send(player, "Coins", got, "pads") Data.push(player) end
				end
			end
		end
	end)
end

return Shop
