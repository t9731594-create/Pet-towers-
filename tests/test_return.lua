local Profile = require(Server.Core.Profile)
local ReturnCore = require(Server.Core.ReturnCore)
local t = {}
local DAY = 86400
local function seq(list) local i = 0 return function() i = i + 1 return list[i] or 0.5 end end
local function player(now, pets)
	local p = Profile.new(now)
	Profile.chooseStarter(p, "Narbub")
	p.upgrades.stack = 7
	for _, def in ipairs(pets or {}) do Profile.addCaught(p, def[1], def[2], false) end
	Profile.deposit(p, now)
	return p
end
function t.first_join_is_day_one_with_egg()
	local p = player(10 * DAY)
	local r = ReturnCore.onJoin(p, 10 * DAY)
	T.eq(p.journeyDay, 1) T.ok(r.newDay) T.eq(r.chest, 0) T.no(r.rested)
	T.eq(r.egg.state, "warming") T.eq(r.tomorrow.minutes, 6)
end
function t.chest_is_quarter_speed_capped_at_four_hours()
	local p = player(0, { { "Sunflion", "Legendary" } }) -- 10 coins/s
	ReturnCore.onJoin(p, 0)
	local before = p.coins
	p.lastSeen = 0
	local r = ReturnCore.onJoin(p, 3600)
	T.eq(r.chest, 10 * 0.25 * 3600)
	p.lastSeen = 3600
	r = ReturnCore.onJoin(p, 3600 + 20 * 3600)
	T.eq(r.chest, 10 * 0.25 * 4 * 3600) -- 3,600 s of income
	p.upgrades.nightLantern = true
	p.lastSeen = 0
	r = ReturnCore.onJoin(p, 30 * 3600)
	T.eq(r.chest, 10 * 0.25 * 8 * 3600)
	T.ok(p.coins > before)
end
function t.short_absence_gives_no_chest()
	local p = player(0, { { "Sunflion", "Legendary" } })
	ReturnCore.onJoin(p, 0)
	T.eq(ReturnCore.onJoin(p, 120).chest, 0)
end
function t.rested_doubles_for_ten_minutes()
	local p = player(0, { { "Sunflion", "Legendary" } })
	ReturnCore.onJoin(p, 0)
	local r = ReturnCore.onJoin(p, 8 * 3600)
	T.ok(r.rested)
	T.eq(ReturnCore.coinMult(p, 8 * 3600 + 599), 2)
	T.eq(ReturnCore.coinMult(p, 8 * 3600 + 600), 1)
	T.near(ReturnCore.coinMult(p, 8 * 3600 + 1, { friend = true }), 2.4)
end
function t.ladder_never_resets_and_missing_days_costs_nothing()
	local p = player(100 * DAY)
	ReturnCore.onJoin(p, 100 * DAY)
	ReturnCore.onJoin(p, 100 * DAY + 3600) -- same day again
	T.eq(p.journeyDay, 1)
	ReturnCore.onJoin(p, 101 * DAY + 5)
	T.eq(p.journeyDay, 2) T.ok(p.stats.funnel.Day2Return)
	local r = ReturnCore.onJoin(p, 130 * DAY) -- a month away
	T.eq(p.journeyDay, 3) -- picks up where it left off
	T.eq(r.look, "aura_spark") T.ok(p.looks.aura_spark)
	T.ok(r.ladderCoins >= 300)
end
function t.egg_hatches_after_eight_hours_one_a_day()
	local p = player(50 * DAY)
	ReturnCore.onJoin(p, 50 * DAY)
	local ok, why = ReturnCore.hatchEgg(p, 50 * DAY + 7 * 3600, seq({}))
	T.no(ok) T.eq(why, "not_ready")
	local n = #p.pets
	local _, pet = ReturnCore.hatchEgg(p, 50 * DAY + 8 * 3600, seq({ 0.999, 0.9 })) -- top 1% roll
	T.eq(pet.rarity, "Legendary") T.eq(pet.species, "Sunflion") T.eq(#p.pets, n + 1)
	T.eq(Profile.where(p, pet.id), "spare") T.ok(p.index.Sunflion)
	T.eq(p.egg, false) -- no second egg the same day
	T.no(ReturnCore.startEgg(p, 50 * DAY + 9 * 3600))
	T.ok(ReturnCore.startEgg(p, 51 * DAY + 1))
end
function t.egg_uses_spawn_odds_of_highest_floor()
	local p = player(0)
	Profile.clearFloor(p, 1)
	local counts, n = {}, 20000
	local s = 99
	local rand = function() s = (s * 16807) % 2147483647 return s / 2147483647 end
	for i = 1, n do
		p.egg = { start = 0 }
		local _, pet = ReturnCore.hatchEgg(p, 9 * 3600, rand)
		counts[pet.rarity] = (counts[pet.rarity] or 0) + 1
		T.eq(require(Shared.Config).Pets.Wild[pet.species].floor, 2)
	end
	T.near(counts.Common / n, 0.60, 0.02) T.near(counts.Rare / n, 0.10, 0.01) T.near(counts.Legendary / n, 0.01, 0.004)
end
function t.index_sets_add_five_percent()
	local p = player(0, { { "Buttercub", "Common" }, { "Hopscotch", "Uncommon" }, { "Zipwing", "Rare" }, { "Marigoat", "Epic" } })
	T.eq(Profile.indexSets(p), 0)
	local n, total = Profile.indexCount(p)
	T.eq(n, 5) T.eq(total, 28) -- starter + 4 wild: "5/28"
	Profile.addCaught(p, "Sunflion", "Legendary", false)
	T.eq(Profile.indexSets(p), 1)
	T.near(ReturnCore.coinMult(p, 0), 1.05)
	p.index.Lanternlamb = true
	n, total = Profile.indexCount(p)
	T.eq(n, 7) T.eq(total, 29)
end
-- Bible M5 test: a simulated day-2 return opens with the Lv 25 evolution.
function t.day_two_return_opens_with_lv25_evolution()
	local pets = {}
	for _ = 1, 5 do pets[#pets + 1] = { "Shellby", "Common" } end
	pets[#pets + 1] = { "Pufferpop", "Uncommon" } pets[#pets + 1] = { "Pufferpop", "Uncommon" } pets[#pets + 1] = { "Coralope", "Rare" }
	local p = player(200 * DAY, pets) -- end of session 1: eight Floor 2 pets on pads
	p.starter.level = 10 p.coins = 0
	ReturnCore.onJoin(p, 200 * DAY)
	p.coins = 0
	local r = ReturnCore.onJoin(p, 200 * DAY + 16 * 3600) -- back the next day
	T.ok(r.chest > 0) T.ok(r.rested)
	local evolved
	while true do
		local ok, f = Profile.feed(p)
		if not ok then break end
		if f.evolvedTo then evolved = f.evolvedTo end
	end
	T.ok(p.starter.level >= 25, "chest of " .. r.chest .. " coins reached only Lv " .. p.starter.level)
	T.eq(evolved, 3)
end
return t
