-- Purchases and codes. Everything sold is a look or a time-saver with a fixed, shown result: never
-- chance, never odds. Grants happen once per PurchaseId and survive a rejoin. No Roblox APIs.
local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Profile = require(script.Parent.Profile)
local E = Config.Economy

local ShopCore = {}

-- catalog: productId -> { kind = "coins", seconds = n } | { kind = "look", look = id }
-- Returns "granted", "already" or "unknown". Only "unknown" should make ProcessReceipt answer
-- NotProcessedYet; the caller must also save before answering PurchaseGranted.
function ShopCore.processReceipt(p, purchaseId, productId, catalog, now)
	purchaseId = tostring(purchaseId)
	if p.purchases[purchaseId] then return "already" end
	local item = catalog[productId]
	if not item then return "unknown" end
	if item.kind == "coins" then
		Profile.grantIncome(p, item.seconds, "robux_coins")
	elseif item.kind == "look" then
		p.looks[item.look] = true
	else
		return "unknown"
	end
	p.purchases[purchaseId] = now
	return "granted", item
end

-- Passes: owned = what the platform says the player owns now. Adds pads for the pad pass once.
function ShopCore.applyPasses(p, owned, now)
	local changed = false
	for key in pairs(owned) do
		if not p.passes[key] then
			p.passes[key] = true
			changed = true
			if key == "CampPads8" then
				for _ = 1, E.Passes.CampPads do p.pads[#p.pads + 1] = { pet = 0, since = now } end
			end
		end
	end
	return changed
end

-- Codes: codes = { CODE = { seconds = n } | { look = id } }. Once per player. At most 10 min of income.
function ShopCore.redeemCode(p, code, codes)
	if type(code) ~= "string" or #code > 24 then return false, "bad" end
	code = string.upper(code)
	local def = codes[code]
	if not def then return false, "unknown" end
	if p.codes[code] then return false, "used" end
	p.codes[code] = true
	if def.look then p.looks[def.look] = true end
	if def.seconds then Profile.grantIncome(p, math.min(def.seconds, E.CodeMaxSeconds), "code") end
	return true, def
end

-- Policy check used by tests and at server start: nothing for sale may be random or change odds.
function ShopCore.audit(shop)
	local problems = {}
	local banned = { "egg", "spin", "crate", "luck", "random", "chance", "odds", "gacha", "loot" }
	local function scan(key)
		local k = string.lower(tostring(key))
		for _, word in ipairs(banned) do
			if string.find(k, word, 1, true) then problems[#problems + 1] = tostring(key) end
		end
	end
	for _, pass in ipairs(shop.Passes or {}) do scan(pass.key) end
	for _, look in ipairs(shop.Looks or {}) do scan(look.key) end
	return problems
end

return ShopCore
