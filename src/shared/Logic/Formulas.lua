-- Pure maths shared by server, client and tools/econ_sim. No Roblox APIs.
local Config = require(script.Parent.Parent.Config)
local E, P = Config.Economy, Config.Pets
local F = {}

local function round(x) return math.floor(x + 0.5) end
F.round = round

-- Starter ---------------------------------------------------------------
function F.starterStage(level)
	local idx, mult = 1, 1
	for i, s in ipairs(E.Starter.Stages) do
		if level >= s.level then idx, mult = i, s.mult end
	end
	return idx, mult
end
function F.starterPower(level)
	local _, mult = F.starterStage(level)
	return E.Starter.BasePower * E.Starter.PowerGrowth ^ (level - 1) * mult
end
-- Coins to feed the starter from `level` to `level + 1`.
function F.levelCost(level)
	return round(E.Starter.LevelCostBase * E.Starter.LevelCostGrowth ^ (level - 1))
end
function F.starterNature(species) return P.Starters[species].nature end

-- Wild pets (pet = { species, rarity, hearts, radiant }) -------------------
function F.petDef(pet) return P.Wild[pet.species] end
function F.rarityMults(rarity)
	return E.RarityIncomeMult[rarity], E.RarityPowerMult[rarity]
end
function F.wildPower(pet)
	local def = P.Wild[pet.species]
	local _, pm = F.rarityMults(pet.rarity)
	return E.CommonPower[def.floor] * pm * (1 + E.Hearts.PowerPer * (pet.hearts or 0))
end
function F.wildIncome(pet)
	local def = P.Wild[pet.species]
	local im = F.rarityMults(pet.rarity)
	local v = E.CommonIncome[def.floor] * im * (1 + E.Hearts.IncomePer * (pet.hearts or 0))
	if pet.radiant then v = v * E.RadiantIncomeMult end
	return v
end
-- Cost of heart number n (1..5) for this pet.
function F.heartCost(pet, n)
	local def = P.Wild[pet.species]
	local _, pm = F.rarityMults(pet.rarity)
	return round(E.Hearts.CostBase * E.CommonIncome[def.floor] * pm * 2 ^ (n - 1))
end

-- Natures -----------------------------------------------------------------
function F.natureMult(petNature, targetNature)
	if targetNature and E.NatureBeats[petNature] == targetNature then return E.Showdown.NatureMult end
	return 1
end

-- Number shortening for the HUD: 950, 1.2K, 3.4M ---------------------------
function F.short(n)
	n = math.floor(n)
	local units = { "", "K", "M", "B", "T" }
	local i = 1
	local v = n
	while v >= 1000 and i < #units do v = v / 1000 i = i + 1 end
	if i == 1 then return tostring(n) end
	v = math.floor(v * 10) / 10
	if v >= 100 or v == math.floor(v) then return string.format("%d%s", math.floor(v), units[i]) end
	return string.format("%.1f%s", v, units[i])
end

return F
