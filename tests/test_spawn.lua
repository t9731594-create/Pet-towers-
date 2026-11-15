local SpawnCore = require(Server.Core.SpawnCore)
local t = {}
local function lcg(seed) local s = seed return function() s = (s * 16807) % 2147483647 return s / 2147483647 end end
function t.fills_floor_and_expires()
	local s = SpawnCore.new(1, lcg(42))
	local spawned = SpawnCore.tick(s, 0)
	T.eq(#spawned, 11) T.eq(s.count, 11)
	local again, left = SpawnCore.tick(s, 50)
	T.eq(#again, 0) T.eq(#left, 0)
	again, left = SpawnCore.tick(s, 90)
	T.eq(#left, 11) T.eq(#again, 11) T.eq(s.count, 11)
end
function t.one_try_each()
	local s = SpawnCore.new(2, lcg(7))
	local pet = SpawnCore.spawn(s, 0)
	T.ok(SpawnCore.canTry(s, pet.id, 1, 10))
	SpawnCore.markTried(pet, 1)
	local ok, why = SpawnCore.canTry(s, pet.id, 1, 11)
	T.no(ok) T.eq(why, "tried")
	T.ok(SpawnCore.canTry(s, pet.id, 2, 11)) -- another player still can
	ok, why = SpawnCore.canTry(s, pet.id, 2, 95)
	T.no(ok) T.eq(why, "gone")
end
function t.odds_match_config()
	local s = SpawnCore.new(3, lcg(123))
	local n, counts, radiant = 200000, {}, 0
	for _ = 1, n do
		local pet = SpawnCore.spawn(s, 0)
		counts[pet.rarity] = (counts[pet.rarity] or 0) + 1
		if pet.radiant then radiant = radiant + 1 end
		s.pets[pet.id] = nil
	end
	T.near(counts.Common / n, 0.60, 0.01) T.near(counts.Uncommon / n, 0.25, 0.01)
	T.near(counts.Rare / n, 0.10, 0.005) T.near(counts.Epic / n, 0.04, 0.004)
	T.near(counts.Legendary / n, 0.01, 0.002) T.near(radiant / n, 0.002, 0.0006)
end
function t.pillar_and_forced()
	local s = SpawnCore.new(1, lcg(5))
	local pet = SpawnCore.spawn(s, 0, { rarity = "Rare", radiant = false, pillar = true })
	T.eq(pet.species, "Zipwing") T.ok(pet.pillar)
	T.ok(SpawnCore.spawn(s, 0, { rarity = "Legendary", radiant = false }).pillar)
	T.no(SpawnCore.spawn(s, 0, { rarity = "Common", radiant = false }).pillar)
	T.ok(SpawnCore.spawn(s, 0, { rarity = "Common", radiant = true }).pillar)
end
function t.busy_pet_waits()
	local s = SpawnCore.new(1, lcg(5))
	local pet = SpawnCore.spawn(s, 0, { rarity = "Common", radiant = false })
	local _, left = SpawnCore.tick(s, 91, function(p) return p.id == pet.id end)
	T.eq(#left, 0) T.ok(s.pets[pet.id])
end
return t
