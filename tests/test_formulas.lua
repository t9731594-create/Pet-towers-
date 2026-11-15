local F = require(Shared.Logic.Formulas)
local t = {}
function t.level_cost() T.eq(F.levelCost(1), 10) T.eq(F.levelCost(2), 14) T.eq(F.levelCost(5), 38) end
function t.starter_power()
	T.near(F.starterPower(1), 3)
	T.near(F.starterPower(4), 3 * 1.2 ^ 3)
	T.near(F.starterPower(5), 3 * 1.2 ^ 4 * 1.5)
	T.near(F.starterPower(25), 3 * 1.2 ^ 24 * 2.5, 1e-3)
	T.near(F.starterPower(42), 3 * 1.2 ^ 41 * 4, 1e-2)
end
function t.heart_costs_floor1_rare() -- bible: 250, 500, 1,000, 2,000, 4,000
	local pet = { species = "Zipwing", rarity = "Rare" }
	local want = { 250, 500, 1000, 2000, 4000 }
	for n = 1, 5 do T.eq(F.heartCost(pet, n), want[n]) end
end
function t.wild_values()
	T.near(F.wildIncome({ species = "Sunflion", rarity = "Legendary", hearts = 0 }), 10)
	T.near(F.wildIncome({ species = "Buttercub", rarity = "Common", hearts = 0, radiant = true }), 3)
	T.near(F.wildPower({ species = "Wispwolf", rarity = "Legendary", hearts = 2 }), 250 * 7 * 1.5)
	T.near(F.wildIncome({ species = "Shellby", rarity = "Common", hearts = 5 }), 3 * 1.5)
end
function t.natures()
	T.eq(F.natureMult("Ember", "Leaf"), 1.5) T.eq(F.natureMult("Leaf", "Tide"), 1.5) T.eq(F.natureMult("Tide", "Ember"), 1.5)
	T.eq(F.natureMult("Leaf", "Ember"), 1) T.eq(F.natureMult("Leaf", "Leaf"), 1) T.eq(F.natureMult("Leaf", nil), 1)
end
function t.short() T.eq(F.short(999), "999") T.eq(F.short(1200), "1.2K") T.eq(F.short(3400000), "3.4M") T.eq(F.short(250000), "250K") T.eq(F.short(1000), "1K") end
function t.config_complete()
	local C = require(Shared.Config)
	local n = 0
	for _ in pairs(C.Pets.Wild) do n = n + 1 end
	T.eq(n, 25)
	for f = 1, 5 do for _, r in ipairs(C.Economy.Rarities) do T.ok(C.Pets.ByFloor[f][r], f .. r) end end
	local odds = 0
	for _, v in pairs(C.Economy.SpawnOdds) do odds = odds + v end
	T.eq(odds, 100)
end
return t
