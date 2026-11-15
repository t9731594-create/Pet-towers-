-- Rows for the Index Board: every pet as a silhouette until caught, with the spawn odds shown.
local Config = require(script.Parent.Parent.Config)
local E, P = Config.Economy, Config.Pets
local IndexView = {}

-- Returns { floors = { { floor, name, complete, pets = { { species, rarity, caught, odds } } } }, caught, total }
function IndexView.build(p, builtFloors)
	local out = { floors = {}, caught = p.starter and 1 or 0, total = E.IndexTotal }
	for floor = 1, builtFloors or Config.Floors.Count do
		local row = { floor = floor, name = Config.Floors.List[floor].name, pets = {}, complete = true }
		for _, rarity in ipairs(E.Rarities) do
			local species = P.ByFloor[floor][rarity]
			local caught = p.index[species] == true
			if caught then out.caught = out.caught + 1 else row.complete = false end
			row.pets[#row.pets + 1] = { species = species, rarity = rarity, caught = caught, odds = E.SpawnOdds[rarity] }
		end
		local secret = P.ByFloor[floor].Secret
		if secret and p.index[secret] then -- a Secret shows only once found
			row.pets[#row.pets + 1] = { species = secret, rarity = "Secret", caught = true }
			out.caught = out.caught + 1
			out.total = out.total + 1
		end
		out.floors[#out.floors + 1] = row
	end
	return out
end

return IndexView
