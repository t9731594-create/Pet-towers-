-- tools/econ_sim: the greedy bot from bible B9, reading the same Config the game uses.
-- Run:  python3 tools/lua.py tools/econ_sim.lua [runs] [key=value ...]
-- The bot: catches 3 pets per 150 s trip (success 95/85/70/50/25% by rarity), keeps the best
-- earners on its pads, buys the floor's Charm, then whatever adds most Team Power per coin, and
-- gets 3,600 s of income at each session break (18 min sessions). It ignores natures, friend and
-- rested bonuses, treasure and index sets.
-- Amendment 1: every Epic / Legendary try costs Economy.Sim.ExtraTrySeconds of play time first.
-- The word noWild (opts.noWild = true) switches that off, for a before / after comparison.
local Config = require(Shared.Config)
local F = require(Shared.Logic.Formulas)
local E, P = Config.Economy, Config.Pets
local S = E.Sim

local Sim = {}

local function rng(seed)
	local s = seed
	return function() -- Park-Miller, same numbers on every Lua
		s = (s * 16807) % 2147483647
		return s / 2147483647
	end
end

local function rollRarity(rand)
	local r, acc = rand() * 100, 0
	for _, name in ipairs(E.Rarities) do
		acc = acc + E.SpawnOdds[name]
		if r < acc then return name end
	end
	return "Common"
end

-- The extra seconds per try, by rarity, that these opts ask for (an empty table = none).
function Sim.extraTrySeconds(opts)
	opts = opts or {}
	if opts.noWild then return {} end
	return opts.extraTrySeconds or S.ExtraTrySeconds or {}
end

-- opts: buyPads = bool; noWild = bool (no play time before tries);
-- extraTrySeconds = { Epic = n, Legendary = n } replaces Economy.Sim.ExtraTrySeconds.
function Sim.run(seed, opts)
	opts = opts or {}
	local extra = Sim.extraTrySeconds(opts)
	local tries, extraSeconds = {}, 0
	local rand = rng(seed)
	local t, coins = 0, E.StartCoins
	local level, cleared, charm = 1, 0, 1
	local pads = E.Pads.Start
	local pets = {} -- kept on pads, sorted by income
	local wins, evo = {}, {}
	local nextBreak = S.SessionSeconds
	local maxT = 60 * 60 * 40

	local function income()
		local v = 0
		for _, p in ipairs(pets) do v = v + F.wildIncome(p) end
		return v
	end
	local function team()
		local a, b
		for _, p in ipairs(pets) do
			if not a or F.wildPower(p) > F.wildPower(a) then b = a a = p
			elseif not b or F.wildPower(p) > F.wildPower(b) then b = p end
		end
		return a, b
	end
	local function teamPower()
		local a, b = team()
		return F.starterPower(level) + (a and F.wildPower(a) or 0) + (b and F.wildPower(b) or 0)
	end
	local function advance(dt)
		coins = coins + income() * dt
		t = t + dt
		while t >= nextBreak do
			coins = coins + income() * S.BreakIncomeSeconds
			nextBreak = nextBreak + S.SessionSeconds
		end
	end
	local function spend()
		local floor = math.min(cleared + 1, Config.Floors.Count)
		if charm < floor then
			if coins >= E.CharmPrice[floor] then
				coins = coins - E.CharmPrice[floor]
				charm = floor
			else
				return -- saving for the Charm
			end
		end
		if opts.buyPads then
			local step = (pads - E.Pads.Start) / E.Pads.Step + 1
			local price = E.Pads.Prices[step]
			if price and #pets >= pads and coins >= price then coins = coins - price pads = pads + E.Pads.Step end
		end
		while true do
			local best, bestRatio, bestCost
			local c = F.levelCost(level)
			if coins >= c then
				best, bestCost = "level", c
				bestRatio = (F.starterPower(level + 1) - F.starterPower(level)) / c
			end
			local a, b = team()
			for _, p in ipairs({ a, b }) do
				local n = (p.hearts or 0) + 1
				if n <= E.Hearts.Max then
					local hc = F.heartCost(p, n)
					local base = F.wildPower({ species = p.species, rarity = p.rarity, hearts = 0 })
					local ratio = base * E.Hearts.PowerPer / hc
					if coins >= hc and (not best or ratio > bestRatio) then best, bestRatio, bestCost = p, ratio, hc end
				end
			end
			if not best then break end
			coins = coins - bestCost
			if best == "level" then
				level = level + 1
				local stage = F.starterStage(level)
				if stage > F.starterStage(level - 1) then evo[stage - 1] = t end
			else
				best.hearts = (best.hearts or 0) + 1
			end
		end
	end

	while cleared < Config.Floors.Count and t < maxT do
		local floor = math.min(charm, cleared + 1)
		local trip = S.TripSeconds
		local caught = {}
		for _ = 1, S.CatchesPerTrip do
			local rarity = rollRarity(rand)
			tries[rarity] = (tries[rarity] or 0) + 1
			if extra[rarity] then
				trip = trip + extra[rarity]
				extraSeconds = extraSeconds + extra[rarity]
			end
			if rand() < S.CatchSuccess[rarity] then
				caught[#caught + 1] = { species = P.ByFloor[floor][rarity], rarity = rarity, hearts = 0 }
			end
		end
		advance(trip)
		for _, p in ipairs(caught) do pets[#pets + 1] = p end
		table.sort(pets, function(x, y) return F.wildIncome(x) > F.wildIncome(y) end)
		while #pets > pads do
			coins = coins + F.wildIncome(pets[#pets]) * E.ReleaseSeconds
			pets[#pets] = nil
		end
		spend()
		local nextFloor = cleared + 1
		if teamPower() * (1 + S.CheerBonus) >= E.GuardianPower[nextFloor] then
			advance(E.Showdown.Seconds)
			cleared = nextFloor
			wins[cleared] = t
		end
	end
	return { wins = wins, evo = evo, level = level, tries = tries, extraSeconds = extraSeconds }
end

function Sim.table(runs, opts)
	local sums, evos, done = {}, {}, {}
	for seed = 1, runs do
		local r = Sim.run(seed * 7919, opts)
		for f = 1, Config.Floors.Count do
			if r.wins[f] then sums[f] = (sums[f] or 0) + r.wins[f] done[f] = (done[f] or 0) + 1 end
		end
		for s = 1, 3 do
			if r.evo[s] then evos[s] = evos[s] or { 0, 0 } evos[s][1] = evos[s][1] + r.evo[s] evos[s][2] = evos[s][2] + 1 end
		end
	end
	local out = { wins = {}, evo = {} }
	for f = 1, Config.Floors.Count do out.wins[f] = done[f] and sums[f] / done[f] / 60 or nil end
	for s = 1, 3 do out.evo[s] = evos[s] and evos[s][1] / evos[s][2] / 60 or nil end
	return out
end

local function day(minutes) -- 2 sessions of 18 min a day
	return math.floor(minutes / 36) + 1
end

function Sim.print(runs, opts, title)
	local r = Sim.table(runs, opts)
	local ex = Sim.extraTrySeconds(opts)
	local wild = (ex.Epic or ex.Legendary)
		and string.format("play time per try: Epic +%g s, Legendary +%g s", ex.Epic or 0, ex.Legendary or 0)
		or "no play time before tries"
	print(title or ("econ_sim, " .. runs .. " runs, mean active minutes, " .. wild))
	print("Guardian | sim min | bible min | day")
	for f = 1, Config.Floors.Count do
		print(string.format("   %d     | %7.1f | %9d | %d", f, r.wins[f] or -1, S.TargetWinMinutes[f], day(r.wins[f] or 0)))
	end
	print(string.format("Evolutions (Lv 5 / 25 / 42) at active minute: %.1f / %.1f / %.1f",
		r.evo[1] or -1, r.evo[2] or -1, r.evo[3] or -1))
	return r
end

if ARGS and ARGS[1] ~= "lib" then
	local runs = tonumber(ARGS[1]) or 300
	local opts = {}
	for i = 1, #ARGS do
		if ARGS[i] == "buyPads" then opts.buyPads = true end
		if ARGS[i] == "noWild" then opts.noWild = true end
	end
	Sim.print(runs, opts)
end
return Sim
