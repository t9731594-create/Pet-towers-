-- Every pet and Guardian from bible B8. Working names: each still needs a clash check (hard rule 6).
local Pets = {}

Pets.Starters = {
	Pandle = { nature = "Ember", stages = { "Pandle", "Pandlewick", "Pandelabra" } },
	Narbub = { nature = "Tide", stages = { "Narbub", "Narbeam", "Narbeacon" } },
	Capling = { nature = "Leaf", stages = { "Capling", "Capybloom", "Capyglow" } },
}
Pets.StarterOrder = { "Pandle", "Narbub", "Capling" }

local function wild(floor, list)
	local rar = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
	for i, p in ipairs(list) do
		Pets.Wild[p[1]] = { floor = floor, rarity = rar[i], nature = p[2] }
	end
end
Pets.Wild = {}
wild(1, { { "Buttercub", "Leaf" }, { "Hopscotch", "Leaf" }, { "Zipwing", "Tide" }, { "Marigoat", "Ember" }, { "Sunflion", "Leaf" } })
wild(2, { { "Shellby", "Tide" }, { "Pufferpop", "Tide" }, { "Coralope", "Leaf" }, { "Flaremingo", "Ember" }, { "Sunsetter", "Ember" } })
wild(3, { { "Capkin", "Leaf" }, { "Glowl", "Leaf" }, { "Lumoth", "Ember" }, { "Fungiraffe", "Leaf" }, { "Wispwolf", "Tide" } })
wild(4, { { "Flurrypup", "Tide" }, { "Chillama", "Tide" }, { "Belluga", "Tide" }, { "Auroram", "Ember" }, { "Mammint", "Leaf" } })
wild(5, { { "Cometkit", "Ember" }, { "Saturtle", "Leaf" }, { "Nebulray", "Tide" }, { "Meteorhino", "Ember" }, { "Haloheron", "Tide" } })

-- Amendment 1: one Secret pet per floor. WORKING NAMES invented here (the bible gives none): each needs
-- the owner's approval and a clash check.
Pets.Secret = {
	{ "Lanternlamb", "Leaf" }, -- F1: a lamb whose wool glows like a paper lantern
	{ "Pearlotter", "Tide" }, -- F2: an otter cradling a glowing pearl
	{ "Flickerfox", "Ember" }, -- F3: a fox kit with a will-o'-wisp tail
	{ "Chimecub", "Tide" }, -- F4: a polar bear cub wearing a frozen bell
	{ "Novanewt", "Ember" }, -- F5: a newt with a tiny star on its tail
}
for floor, p in ipairs(Pets.Secret) do
	Pets.Wild[p[1]] = { floor = floor, rarity = "Secret", nature = p[2] }
end

-- species of a floor by rarity: Pets.ByFloor[floor][rarity] = species
Pets.ByFloor = {}
for species, def in pairs(Pets.Wild) do
	Pets.ByFloor[def.floor] = Pets.ByFloor[def.floor] or {}
	Pets.ByFloor[def.floor][def.rarity] = species
end

Pets.Guardians = {
	{ name = "Old Bramblehorn", nature = "Leaf" },
	{ name = "Clatterclaw", nature = "Tide" },
	{ name = "Grumblecap", nature = "Ember" },
	{ name = "Brrnard", nature = "Tide" },
	{ name = "Starsnore", nature = "Ember" },
}
Pets.WeeklyGuardians = { "Honk the Clockwork Goose", "Dozy the Pillow Dragon" }

return Pets
