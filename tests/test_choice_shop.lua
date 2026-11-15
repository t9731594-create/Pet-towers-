local Profile = require(Server.Core.Profile)
local ShopCore = require(Server.Core.ShopCore)
local Config = require(Shared.Config)
local t = {}
local function player()
	local p = Profile.new(0)
	Profile.chooseStarter(p, "Pandle")
	Profile.addCaught(p, "Sunflion", "Legendary", false) -- 10 coins/s
	Profile.deposit(p, 0)
	return p
end
function t.share_or_keep_once_per_floor()
	local p = player()
	T.no(Profile.choose(p, 1, "share")) -- not cleared yet
	Profile.clearFloor(p, 1)
	T.eq(Profile.pendingChoice(p), 1)
	local ok, r = Profile.choose(p, 1, "share")
	T.ok(ok) T.eq(r.everyoneSeconds, 300) T.eq(r.selfSeconds, 0) T.eq(p.dawn, 1)
	T.no(Profile.choose(p, 1, "keep")) -- already chosen
	T.eq(Profile.pendingChoice(p), nil)
	Profile.clearFloor(p, 2)
	ok, r = Profile.choose(p, 2, "keep")
	T.eq(r.selfSeconds, 600) T.eq(p.dusk, 1)
	T.no(Profile.choose(p, 2, "steal"))
	T.eq(Profile.side(p), nil)
	Profile.clearFloor(p, 3) Profile.choose(p, 3, "share")
	T.eq(Profile.side(p), "dawn") T.eq(p.floors["3"].choice, "share")
end
function t.grant_income_is_own_income()
	local p = player()
	T.eq(Profile.grantIncome(p, 300, "share"), 3000)
	local poor = Profile.new(0) Profile.chooseStarter(poor, "Pandle")
	T.eq(Profile.grantIncome(poor, 300, "share"), 300) -- no pets yet: small floor-based amount
end
function t.dawn_or_dusk_form_at_42()
	local p = player()
	local ok, why = Profile.chooseForm(p, "dawn")
	T.no(ok) T.eq(why, "too_early")
	p.starter.level = 42
	T.no(Profile.chooseForm(p, "evil"))
	T.ok(Profile.chooseForm(p, "dusk")) T.eq(p.starter.form, "dusk")
	T.no(Profile.chooseForm(p, "dawn"))
end
function t.receipt_grants_once()
	local p = player()
	local catalog = { [111] = { kind = "coins", seconds = 1800 }, [222] = { kind = "look", look = "aura_gold" } }
	T.eq(ShopCore.processReceipt(p, "abc", 111, catalog, 5), "granted")
	T.eq(p.coins, 50 + 18000)
	T.eq(ShopCore.processReceipt(p, "abc", 111, catalog, 6), "already") -- same receipt again
	T.eq(p.coins, 50 + 18000)
	T.eq(ShopCore.processReceipt(p, "def", 999, catalog, 7), "unknown")
	T.eq(ShopCore.processReceipt(p, "ghi", 222, catalog, 8), "granted")
	T.ok(p.looks.aura_gold)
end
function t.receipt_survives_rejoin()
	local DataCore = require(Server.Core.DataCore)
	local rows = {}
	local store = { update = function(_, key, fn) local new = fn(rows[key]) if new ~= nil then rows[key] = new end end }
	local a = DataCore.new(store, "A", function() return 0 end)
	local p = a:load("u")
	Profile.chooseStarter(p, "Pandle")
	local catalog = { [111] = { kind = "coins", seconds = 1800 } }
	ShopCore.processReceipt(p, "r1", 111, catalog, 1)
	local coins = p.coins
	a:save("u", p, true)
	local q = DataCore.new(store, "B", function() return 10 end):load("u")
	T.eq(q.coins, coins)
	T.eq(ShopCore.processReceipt(q, "r1", 111, catalog, 11), "already")
	T.eq(q.coins, coins)
end
function t.passes_apply_once()
	local p = player()
	T.ok(ShopCore.applyPasses(p, { CampPads8 = true, BiggerStack = true, DoubleCoins = true }, 0))
	T.eq(#p.pads, 16) T.eq(Profile.stackCap(p), 5)
	T.no(ShopCore.applyPasses(p, { CampPads8 = true }, 0))
	T.eq(#p.pads, 16)
	T.eq(require(Server.Core.ReturnCore).coinMult(p, 0), 2)
end
function t.codes_once_and_capped()
	local p = player()
	local codes = { HELLO = { seconds = 99999 }, GLOW = { look = "aura_code" } }
	local ok = ShopCore.redeemCode(p, "hello", codes)
	T.ok(ok) T.eq(p.coins, 50 + 600 * 10) -- capped at 10 minutes of income
	local again, why = ShopCore.redeemCode(p, "HELLO", codes)
	T.no(again) T.eq(why, "used")
	T.no(ShopCore.redeemCode(p, "NOPE", codes))
	T.no(ShopCore.redeemCode(p, 12345, codes))
	T.ok(ShopCore.redeemCode(p, "glow", codes)) T.ok(p.looks.aura_code)
end
function t.nothing_for_sale_is_random()
	T.eq(#ShopCore.audit(Config.Shop), 0)
	T.eq(#ShopCore.audit({ Passes = { { key = "LuckBoost" }, { key = "MysteryEggPack" } } }), 2)
	T.eq(Config.Shop.Approved, false) -- no price is live until the owner approves it
end
return t
