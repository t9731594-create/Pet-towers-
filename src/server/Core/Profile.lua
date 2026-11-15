-- Pure rules for one player's saved data. No Roblox APIs: services call these and replicate the result.
-- Every function returns ok, value-or-reason. Nothing here trusts the client.
local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local F = require(Shared.Logic.Formulas)
local E, P = Config.Economy, Config.Pets

local Profile = {}
Profile.Version = 1

function Profile.new(now)
	local p = {
		version = Profile.Version,
		coins = E.StartCoins,
		starter = nil, -- { species, level, form }
		pets = {}, -- array of { id, species, rarity, hearts, radiant }
		nextPetId = 1,
		pads = {}, -- array of { pet = id or 0, since = time }
		spare = {}, -- pet ids at camp but not on a pad
		stack = {}, -- pet ids riding on the head
		team = {}, -- up to 2 wild pet ids
		floors = {}, -- [n] = { cleared = true, choice = "share" | "keep" | false }
		cleared = 0,
		dawn = 0, dusk = 0,
		charm = 1,
		upgrades = { pads = 0, stack = 0, nightLantern = false },
		index = {}, -- species -> true (caught) ; seen -> "seen"
		journeyDay = 1,
		lastSeen = now, firstJoin = now,
		egg = false, eggDay = 0, weekly = {}, purchases = {}, codes = {},
		passes = {}, looks = {}, -- pass key -> true ; look id -> true
		restedUntil = 0, lastPlayDay = 0, helperStars = 0,
		settings = { music = 1, effects = 1, lowGraphics = false, tapAssist = false, reducedFlash = false },
		tutorial = 0,
		assist = { misses = 0, catchesLeft = 0 },
		stats = { catches = 0, tries = 0, sources = {}, sinks = {}, funnel = {},
			wild = { started = 0, coop = 0, finished = 0 } }, -- Amendment 1 (bible C3)
	}
	for i = 1, E.Pads.Start do p.pads[i] = { pet = 0, since = now } end
	return p
end

-- Listeners for analytics (set by the Analytics service; nil in tests).
Profile.onCoins = nil -- fn(p, amount, "source" | "sink", name)
Profile.onFunnel = nil -- fn(p, step)

-- Coins (every source and sink is logged, bible C3) -------------------------
function Profile.addCoins(p, n, source)
	n = math.floor(n)
	if n <= 0 then return 0 end
	p.coins = p.coins + n
	p.stats.sources[source] = (p.stats.sources[source] or 0) + n
	if Profile.onCoins then Profile.onCoins(p, n, "source", source) end
	return n
end
function Profile.spend(p, n, sink)
	if p.coins < n then return false, "coins" end
	p.coins = p.coins - n
	p.stats.sinks[sink] = (p.stats.sinks[sink] or 0) + n
	if Profile.onCoins then Profile.onCoins(p, n, "sink", sink) end
	return true
end

-- Lookups -----------------------------------------------------------------
function Profile.pet(p, id)
	for i, pet in ipairs(p.pets) do
		if pet.id == id then return pet, i end
	end
end
local function indexOf(list, v)
	for i, x in ipairs(list) do if x == v then return i end end
end
local function padOf(p, id)
	for i, pad in ipairs(p.pads) do if pad.pet == id then return i end end
end
function Profile.where(p, id)
	if indexOf(p.stack, id) then return "stack" end
	if padOf(p, id) then return "pad" end
	if indexOf(p.spare, id) then return "spare" end
end
function Profile.stackCap(p)
	local cap = math.min(E.Stack.Start + p.upgrades.stack, E.Stack.Start + #E.Stack.Prices)
	if p.passes and p.passes.BiggerStack then cap = cap + E.Passes.BiggerStack end
	return cap
end
function Profile.stackFull(p) return #p.stack >= Profile.stackCap(p) end
function Profile.unlockedFloor(p) return math.min(p.cleared + 1, Config.Floors.Count) end

-- Starter -----------------------------------------------------------------
function Profile.chooseStarter(p, species)
	if p.starter then return false, "has_starter" end
	if not P.Starters[species] then return false, "bad_species" end
	p.starter = { species = species, level = 1, form = false }
	return true
end
-- Feed one level. Returns ok, { level, evolvedTo = stage index or nil }.
function Profile.feed(p)
	if not p.starter then return false, "no_starter" end
	local lv = p.starter.level
	local ok, why = Profile.spend(p, F.levelCost(lv), "feed")
	if not ok then return false, why end
	p.starter.level = lv + 1
	local before, after = F.starterStage(lv), F.starterStage(lv + 1)
	return true, { level = lv + 1, evolvedTo = after > before and after or nil }
end

-- Catching and the stack ----------------------------------------------------
function Profile.addCaught(p, species, rarity, radiant)
	if Profile.stackFull(p) then return false, "stack_full" end
	local pet = { id = p.nextPetId, species = species, rarity = rarity, hearts = 0, radiant = radiant and true or false }
	p.nextPetId = p.nextPetId + 1
	p.pets[#p.pets + 1] = pet
	p.stack[#p.stack + 1] = pet.id
	p.index[species] = true
	p.stats.catches = p.stats.catches + 1
	return true, pet
end
-- Assist: after 3 failed tries in a row rings run slower until 2 catches.
function Profile.noteTry(p, success)
	p.stats.tries = p.stats.tries + 1
	local a = p.assist
	if success then
		a.misses = 0
		if a.catchesLeft > 0 then a.catchesLeft = a.catchesLeft - 1 end
	else
		a.misses = a.misses + 1
		if a.misses >= E.Tap.AssistAfterMisses then a.catchesLeft = E.Tap.AssistUntilCatches end
	end
end
function Profile.assistOn(p)
	return p.settings.tapAssist or p.assist.catchesLeft > 0
end

-- Camp --------------------------------------------------------------------
function Profile.padIncome(p, i)
	local pet = Profile.pet(p, p.pads[i].pet)
	return pet and F.wildIncome(pet) or 0
end
function Profile.incomePerSecond(p)
	local v = 0
	for i = 1, #p.pads do v = v + Profile.padIncome(p, i) end
	return v
end
-- Coins waiting on one pad (a pad holds 10 minutes).
function Profile.padWaiting(p, i, now)
	local dt = math.max(0, math.min(now - p.pads[i].since, E.Pads.HoldSeconds))
	return Profile.padIncome(p, i) * dt
end
-- Collect pads. `only` = pad index or nil for all. mult = friend / rested / pass multipliers.
function Profile.collect(p, now, mult, only)
	local total = 0
	for i = 1, #p.pads do
		if not only or only == i then
			total = total + Profile.padWaiting(p, i, now)
			p.pads[i].since = now
		end
	end
	return true, Profile.addCoins(p, total * (mult or 1), "pads")
end
-- Stack pets come home: fill empty pads first, the rest wait as spares.
function Profile.deposit(p, now)
	local placed = 0
	for _, id in ipairs(p.stack) do
		local free
		for i, pad in ipairs(p.pads) do if pad.pet == 0 then free = i break end end
		if free then
			p.pads[free] = { pet = id, since = now }
			placed = placed + 1
		else
			p.spare[#p.spare + 1] = id
		end
	end
	local n = #p.stack
	p.stack = {}
	return true, { moved = n, placed = placed }
end
-- Put a camp pet on a pad (swaps with whatever is there). Collects that pad first.
function Profile.place(p, id, padIndex, now, mult)
	local pad = p.pads[padIndex]
	if not pad then return false, "bad_pad" end
	local from = Profile.where(p, id)
	if from ~= "spare" and from ~= "pad" then return false, "not_at_camp" end
	if pad.pet == id then return true end
	Profile.collect(p, now, mult, padIndex)
	local old = pad.pet
	if from == "pad" then
		local j = padOf(p, id)
		Profile.collect(p, now, mult, j)
		p.pads[j].pet = old
	else
		table.remove(p.spare, indexOf(p.spare, id))
		if old ~= 0 then p.spare[#p.spare + 1] = old end
	end
	pad.pet = id
	return true
end
-- Release a spare or pad pet for 60 s of its income. Team pets and stack pets cannot be released.
function Profile.release(p, id, now, mult)
	local pet, at = Profile.pet(p, id)
	if not pet then return false, "no_pet" end
	if indexOf(p.team, id) then return false, "on_team" end
	local from = Profile.where(p, id)
	if from == "stack" or not from then return false, "not_at_camp" end
	if from == "pad" then
		local j = padOf(p, id)
		Profile.collect(p, now, mult, j)
		p.pads[j].pet = 0
	else
		table.remove(p.spare, indexOf(p.spare, id))
	end
	table.remove(p.pets, at)
	return true, Profile.addCoins(p, F.wildIncome(pet) * E.ReleaseSeconds, "release")
end

-- Team --------------------------------------------------------------------
function Profile.setTeam(p, a, b)
	local ids = {}
	for _, id in ipairs({ a, b }) do
		if id and id ~= 0 then
			local from = Profile.where(p, id)
			if from ~= "pad" and from ~= "spare" then return false, "not_at_camp" end
			if indexOf(ids, id) then return false, "duplicate" end
			ids[#ids + 1] = id
		end
	end
	p.team = ids
	return true
end
-- Fill empty team slots with the strongest camp pets (used after deposit so new players need no menu).
function Profile.autoTeam(p)
	local keep = {}
	for _, id in ipairs(p.team) do if Profile.pet(p, id) then keep[#keep + 1] = id end end
	p.team = keep
	while #p.team < 2 do
		local best
		for _, pet in ipairs(p.pets) do
			local from = Profile.where(p, pet.id)
			if (from == "pad" or from == "spare") and not indexOf(p.team, pet.id) then
				if not best or F.wildPower(pet) > F.wildPower(best) then best = pet end
			end
		end
		if not best then break end
		p.team[#p.team + 1] = best.id
	end
end
-- Team Power, optionally against a Guardian or wild pet nature (x1.5 for a pet whose nature beats it).
function Profile.teamPower(p, targetNature)
	if not p.starter then return 0 end
	local total = F.starterPower(p.starter.level) * F.natureMult(F.starterNature(p.starter.species), targetNature)
	for _, id in ipairs(p.team) do
		local pet = Profile.pet(p, id)
		if pet then total = total + F.wildPower(pet) * F.natureMult(P.Wild[pet.species].nature, targetNature) end
	end
	return total
end
function Profile.addHeart(p, id)
	local pet = Profile.pet(p, id)
	if not pet then return false, "no_pet" end
	if pet.hearts >= E.Hearts.Max then return false, "max" end
	local ok, why = Profile.spend(p, F.heartCost(pet, pet.hearts + 1), "heart")
	if not ok then return false, why end
	pet.hearts = pet.hearts + 1
	return true, pet.hearts
end

-- Upgrades ------------------------------------------------------------------
function Profile.buyCharm(p)
	local tier = p.charm + 1
	if tier > Profile.unlockedFloor(p) then return false, "locked" end
	local ok, why = Profile.spend(p, E.CharmPrice[tier], "charm")
	if not ok then return false, why end
	p.charm = tier
	return true, tier
end
function Profile.buyPads(p, now)
	local price = E.Pads.Prices[p.upgrades.pads + 1]
	if not price then return false, "max" end
	local ok, why = Profile.spend(p, price, "pads")
	if not ok then return false, why end
	p.upgrades.pads = p.upgrades.pads + 1
	for _ = 1, E.Pads.Step do p.pads[#p.pads + 1] = { pet = 0, since = now } end
	return true, #p.pads
end
function Profile.buyStack(p)
	local price = E.Stack.Prices[p.upgrades.stack + 1]
	if not price then return false, "max" end
	local ok, why = Profile.spend(p, price, "stack")
	if not ok then return false, why end
	p.upgrades.stack = p.upgrades.stack + 1
	return true, Profile.stackCap(p)
end

-- Index -------------------------------------------------------------------
-- Caught count for the Index Board ("5/28"): the starter counts as one; Secrets count once found.
function Profile.indexCount(p)
	local n, total = p.starter and 1 or 0, E.IndexTotal
	for species in pairs(p.index) do
		local def = P.Wild[species]
		if def then
			n = n + 1
			if def.rarity == "Secret" then total = total + 1 end
		end
	end
	return n, total
end
-- Floors whose five pets are all caught (each gives +5% coins forever).
function Profile.indexSets(p)
	local sets = 0
	for floor = 1, Config.Floors.Count do
		local all = true
		for _, rarity in ipairs(E.Rarities) do
			if not p.index[P.ByFloor[floor][rarity]] then all = false break end
		end
		if all then sets = sets + 1 end
	end
	return sets
end

-- Share or Keep, Dawn or Dusk ------------------------------------------------
function Profile.pendingChoice(p)
	for floor = 1, Config.Floors.Count do
		local f = p.floors[tostring(floor)]
		if f and f.cleared and f.choice == false then return floor end
	end
end
-- Returns ok, { selfSeconds, everyoneSeconds } : seconds of each receiver's OWN income.
function Profile.choose(p, floor, choice)
	local f = p.floors[tostring(floor)]
	if not f or not f.cleared or f.choice ~= false then return false, "no_choice" end
	if choice == "share" then
		f.choice = "share"
		p.dawn = p.dawn + 1
		return true, { selfSeconds = 0, everyoneSeconds = E.Choice.ShareSeconds }
	elseif choice == "keep" then
		f.choice = "keep"
		p.dusk = p.dusk + 1
		return true, { selfSeconds = E.Choice.KeepSeconds, everyoneSeconds = 0 }
	end
	return false, "bad_choice"
end
-- Coins for `seconds` of this player's own income (never less than a small floor-based amount).
function Profile.grantIncome(p, seconds, source, mult)
	local rate = math.max(Profile.incomePerSecond(p), E.Choice.MinIncome * E.CommonIncome[Profile.unlockedFloor(p)])
	return Profile.addCoins(p, rate * seconds * (mult or 1), source)
end
function Profile.side(p)
	if p.dawn > p.dusk then return "dawn" elseif p.dusk > p.dawn then return "dusk" end
end
-- At Lv 42 the starter takes a Dawn or Dusk form of the player's choosing (once).
function Profile.chooseForm(p, form)
	if not p.starter or p.starter.form then return false, "no_choice" end
	if F.starterStage(p.starter.level) < 4 then return false, "too_early" end
	if form ~= "dawn" and form ~= "dusk" then return false, "bad_form" end
	p.starter.form = form
	return true
end

-- Settings (bible B12) ---------------------------------------------------------
function Profile.setSetting(p, key, value)
	local cur = p.settings[key]
	if cur == nil then return false, "bad_key" end
	if type(cur) == "boolean" then
		if type(value) ~= "boolean" then return false, "bad_value" end
	else
		if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then return false, "bad_value" end
	end
	p.settings[key] = value
	return true
end

-- Floors --------------------------------------------------------------------
function Profile.canEnter(p, floor)
	return floor >= 1 and floor <= Profile.unlockedFloor(p) and p.starter ~= nil
end
-- Returns true when this is the player's first clear of the floor.
function Profile.clearFloor(p, floor)
	local key = tostring(floor)
	if p.floors[key] and p.floors[key].cleared then return false end
	p.floors[key] = { cleared = true, choice = false }
	if floor > p.cleared then p.cleared = floor end
	return true
end

function Profile.funnel(p, step, now)
	if p.stats.funnel[step] then return false end
	p.stats.funnel[step] = now - p.firstJoin
	if Profile.onFunnel then Profile.onFunnel(p, step) end
	return true
end

return Profile
