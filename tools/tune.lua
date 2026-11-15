-- tools/tune: tries tuning candidates against the bible B9 pacing targets WITHOUT changing any file.
-- Run:  python3 tools/lua.py tools/tune.lua [runs]              the candidates listed below (300 runs)
--       python3 tools/lua.py tools/tune.lua [runs] try GuardianPower.5=200000 Starter.LevelCostGrowth=1.39
--       python3 tools/lua.py tools/tune.lua [runs] bot           the trip-granularity check only
-- A candidate is a list of { "Path.In.Economy", value }. Tune.with() writes the values into the
-- loaded Config.Economy table (in place, so every module sees them), runs, then puts the old values
-- back, also when the run throws. Tests load this file with ARGS = { "lib" }.
local Config = require(Shared.Config)
local E = Config.Economy
local S = E.Sim

local args = ARGS
ARGS = { "lib" }
local Sim = runfile(ROOT .. "/tools/econ_sim.lua")
local Wild = runfile(ROOT .. "/tools/sim_wild.lua")
ARGS = args

local Tune = {}
Tune.Targets = S.TargetWinMinutes
Tune.DayMinutes = 2 * S.SessionSeconds / 60 -- 36 active minutes a day
Tune.Tolerance = 0.10

-- Overrides ---------------------------------------------------------------------
-- "GuardianPower.4" -> the table that holds the value, and its key (numbers become numeric keys).
local function resolve(path)
	local node, key = E, nil
	for part in string.gmatch(path, "[^%.]+") do
		if key ~= nil then
			node = node[key]
			if type(node) ~= "table" then error("tune: no table at '" .. path .. "'") end
		end
		key = tonumber(part) or part
	end
	if key == nil or node[key] == nil then error("tune: no value at '" .. path .. "'") end
	if type(node[key]) == "table" then error("tune: '" .. path .. "' is a table, name one value") end
	return node, key
end
Tune.resolve = resolve
function Tune.get(path)
	local node, key = resolve(path)
	return node[key]
end
-- Writes the values and returns what was there, newest last. A bad path throws before any write.
function Tune.apply(changes)
	local found, saved = {}, {}
	for i, c in ipairs(changes or {}) do -- every path is checked before anything is written
		if type(c[2]) ~= "number" then error("tune: '" .. tostring(c[1]) .. "' needs a number") end
		found[i] = { resolve(c[1]) }
	end
	for i, c in ipairs(changes or {}) do
		local node, key = found[i][1], found[i][2]
		saved[#saved + 1] = { node, key, node[key] }
		node[key] = c[2]
	end
	return saved
end
function Tune.restore(saved)
	for i = #saved, 1, -1 do saved[i][1][saved[i][2]] = saved[i][3] end
end
-- Runs fn() with the changes in place; the config is restored before this returns or throws.
function Tune.with(changes, fn)
	local saved = Tune.apply(changes)
	local ok, a, b, c = pcall(fn)
	Tune.restore(saved)
	if not ok then error(a, 0) end
	return a, b, c
end
-- A deep copy of a config table and an exact comparison, for the restore test.
function Tune.snapshot(node)
	node = node or E
	if type(node) ~= "table" then return node end
	local out = {}
	for k, v in pairs(node) do out[k] = Tune.snapshot(v) end
	return out
end
function Tune.same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in pairs(a) do if not Tune.same(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
-- Every per-floor list a candidate may touch must keep rising.
function Tune.monotonic()
	for _, list in ipairs({ E.CommonIncome, E.CommonPower, E.GuardianPower, E.CharmPrice, E.Pads.Prices, E.Stack.Prices }) do
		for i = 2, #list do if list[i] <= list[i - 1] then return false end end
	end
	return true
end

-- Measuring ---------------------------------------------------------------------
function Tune.day(minutes) return math.floor(minutes / Tune.DayMinutes) + 1 end
function Tune.gap(minutes, floor) return minutes / Tune.Targets[floor] - 1 end
-- { pads = Sim.table result, nopads = ..., worstPads = largest |gap|, worstNoPads = ... }
function Tune.measure(changes, runs, botOpts)
	return Tune.with(changes, function()
		local out = { monotonic = Tune.monotonic() }
		for _, bot in ipairs({ "pads", "nopads" }) do
			local opts = { buyPads = bot == "pads", override = botOpts }
			local r = Sim.table(runs, opts)
			local worst, worst25 = 0, 0
			for f = 1, Config.Floors.Count do
				local g = r.wins[f] and math.abs(Tune.gap(r.wins[f], f)) or 99
				if g > worst then worst = g end
				if f >= 2 and g > worst25 then worst25 = g end
			end
			r.worst, r.worst25 = worst, worst25
			out[bot] = r
		end
		return out
	end)
end

-- The three checks from the brief -------------------------------------------------
local function assertKit() -- the same T the test runner gives the test files
	local K = {}
	function K.eq(a, b, msg) if a ~= b then error((msg or "eq") .. ": got " .. tostring(a) .. ", want " .. tostring(b), 2) end end
	function K.near(a, b, tol, msg) if math.abs(a - b) > (tol or 1e-6) then error((msg or "near") .. ": got " .. tostring(a) .. ", want " .. tostring(b), 2) end end
	function K.ok(v, msg) if not v then error(msg or "expected true", 2) end end
	function K.no(v, msg) if v then error(msg or "expected false", 2) end end
	return K
end
-- Runs one test of a real test file under the changes. Returns ok, error text.
function Tune.runTest(changes, file, name)
	local oldT, oldArgs = T, ARGS
	T = assertKit()
	local ok, err = pcall(Tune.with, changes, function()
		local tests = runfile(ROOT .. "/tests/" .. file .. ".lua")
		tests[name]()
	end)
	T, ARGS = oldT, oldArgs
	return ok, (not ok) and tostring(err) or nil
end
function Tune.firstMinutes(changes) return Tune.runTest(changes, "test_first_minutes", "b6_script") end
function Tune.dayTwoReturn(changes)
	return Tune.runTest(changes, "test_return", "day_two_return_opens_with_lv25_evolution")
end
-- Wild showdowns: ready-player seconds are ratios of Guardian power, so only the absolute meter and
-- what a Secret pet is worth against the Guardian can move.
function Tune.wild(changes)
	return Tune.with(changes, function()
		local out = { ready = {}, meter = {}, share = {}, arrivals = {} }
		for floor = 1, Config.Floors.Count do
			out.ready[floor] = Wild.readySeconds(floor, "Secret", 1)
			out.meter[floor] = Wild.meter(floor, "Secret")
			out.share[floor] = Wild.secret(floor).guardianShare
			out.arrivals[floor] = Wild.playersForSecret(floor, Wild.arrivalPower(floor))
		end
		out.epic, out.legendary = Wild.readySeconds(1, "Epic", 1), Wild.readySeconds(1, "Legendary", 1)
		return out
	end)
end

-- Printing ------------------------------------------------------------------------
local function fmt(v)
	if v == math.floor(v) and math.abs(v) < 1e15 then
		local s, k = string.format("%d", v), nil
		repeat s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2") until k == 0
		return s
	end
	return tostring(v)
end
function Tune.describe(changes)
	if not changes or #changes == 0 then return "no change" end
	local parts = {}
	for _, c in ipairs(changes) do parts[#parts + 1] = string.format("%s %s -> %s", c[1], fmt(Tune.get(c[1])), fmt(c[2])) end
	return table.concat(parts, "; ")
end
local function row(label, r)
	local a, b, c = {}, {}, {}
	for f = 1, Config.Floors.Count do
		local m = r.wins[f]
		a[f] = m and string.format("%7.2f", m) or "  never"
		b[f] = m and string.format("%+6.0f%%", Tune.gap(m, f) * 100) or "      -"
		c[f] = m and string.format("%7d", Tune.day(m)) or "      -"
	end
	print(string.format("  %-8s minutes | %s", label, table.concat(a, " | ")))
	print(string.format("  %-8s vs bible| %s", "", table.concat(b, " | ")))
	print(string.format("  %-8s day     | %s", "", table.concat(c, " | ")))
	print(string.format("  %-8s evolutions Lv 5 / 25 / 42 at minute %.1f / %.1f / %.1f (day %d / %d / %d)", "",
		r.evo[1] or -1, r.evo[2] or -1, r.evo[3] or -1,
		Tune.day(r.evo[1] or 0), Tune.day(r.evo[2] or 0), Tune.day(r.evo[3] or 0)))
end
local function within(r) return r.worst25 <= Tune.Tolerance + 1e-9 end
function Tune.print(name, changes, runs, botOpts)
	print(name .. ": " .. Tune.describe(changes))
	local m = Tune.measure(changes, runs, botOpts)
	print(string.format("  %-8s Guardian|       1 |       2 |       3 |       4 |       5", ""))
	print(string.format("  %-8s bible   | %7d | %7d | %7d | %7d | %7d", "", Tune.Targets[1], Tune.Targets[2], Tune.Targets[3], Tune.Targets[4], Tune.Targets[5]))
	row("pads", m.pads)
	row("no pads", m.nopads)
	print(string.format("  Guardians 2-5 within %d%%: pads bot %s (worst %.0f%%), no-pads bot %s (worst %.0f%%). Lists still rising: %s",
		Tune.Tolerance * 100, within(m.pads) and "yes" or "NO", m.pads.worst25 * 100,
		within(m.nopads) and "yes" or "NO", m.nopads.worst25 * 100, m.monotonic and "yes" or "NO"))
	return m
end
function Tune.printChecks(changes)
	local ok1, e1 = Tune.firstMinutes(changes)
	local ok2, e2 = Tune.dayTwoReturn(changes)
	print("  first five minutes (tests/test_first_minutes b6_script): " .. (ok1 and "passes" or ("FAILS: " .. e1)))
	print("  day-2 return opens with the Lv 25 evolution (tests/test_return): " .. (ok2 and "passes" or ("FAILS: " .. e2)))
	local w, base = Tune.wild(changes), Tune.wild({})
	print(string.format("  wild showdown, ready player solo: Epic %g s, Legendary %g s, Secret %g s on every floor (now %g / %g / %g)",
		w.epic, w.legendary, w.ready[1], base.epic, base.legendary, base.ready[1]))
	for f = 1, Config.Floors.Count do
		if w.meter[f] ~= base.meter[f] or w.share[f] ~= base.share[f] or w.arrivals[f] ~= base.arrivals[f] then
			print(string.format("    floor %d Secret: meter %s -> %s; one Secret is %.0f%% -> %.0f%% of the Guardian; just-arrived players needed %d -> %d",
				f, fmt(base.meter[f]), fmt(w.meter[f]), base.share[f] * 100, w.share[f] * 100, base.arrivals[f], w.arrivals[f]))
		end
	end
	return ok1 and ok2
end

-- The bot's trip granularity ------------------------------------------------------
-- The bot only spends and only challenges at the end of a trip, so Guardian 1 can fall at 150 + 40 s,
-- 300 + 40 s, ... and nowhere between. FineBot keeps the catch rate (1 catch per 50 s = 3 per 150 s)
-- but comes home after every catch for the first `trips` short trips.
function Tune.fineBot(trips)
	return { trip = function(n, seconds, catches)
		if n <= trips then return seconds / catches, 1 end
		return seconds, catches
	end }
end
function Tune.printBot(runs)
	print("Bot check: when does Guardian 1 fall? Share of " .. runs .. " runs (pads bot, current values).")
	print("  The first trip ends at 150 s and the showdown takes 40 s, so the bot as written can win at about 190 s, 340 s, 490 s, never between.")
	for _, v in ipairs({ { "bot as written (150 s trips)", nil }, { "first 6 trips 50 s with 1 catch each (same catch rate)", Tune.fineBot(6) } }) do
		local early, mid, late, sum = 0, 0, 0, 0
		for seed = 1, runs do
			local t = Sim.run(seed * 7919, { buyPads = true, override = v[2] }).wins[1]
			sum = sum + t
			if t <= 240 then early = early + 1 elseif t <= 300 then mid = mid + 1 else late = late + 1 end
		end
		print(string.format("  %-55s mean %.2f min | by 4 min: %.0f%%, 4-5 min: %.0f%%, after 5 min: %.0f%%",
			v[1], sum / runs / 60, early / runs * 100, mid / runs * 100, late / runs * 100))
	end
end

-- Candidates ----------------------------------------------------------------------
-- Found by searching Guardian power, Common power / income, Charm prices, pad prices and the level
-- cost growth (see docs/TUNING_PROPOSAL.md). Charm prices moved nothing, so no candidate uses them.
Tune.Candidates = {
	{ name = "C  (change nothing)", changes = {} },
	{ name = "C, attentive bot", changes = {}, bot = Tune.fineBot(1e9),
		note = "Same values; the bot comes home after every catch (50 s trips, 1 catch) for the whole run." },
	{ name = "A  (smallest)", changes = { { "GuardianPower.5", 200000 } } },
	{ name = "B  (closest fit)", changes = { { "GuardianPower.4", 62000 }, { "GuardianPower.5", 210000 } } },
	{ name = "B, attentive bot", changes = { { "GuardianPower.4", 62000 }, { "GuardianPower.5", 210000 } }, bot = Tune.fineBot(1e9) },
	{ name = "B + Guardian 2", changes = { { "GuardianPower.2", 150 }, { "GuardianPower.4", 62000 }, { "GuardianPower.5", 210000 } } },
	{ name = "B + Guardian 2, attentive bot", changes = { { "GuardianPower.2", 150 }, { "GuardianPower.4", 62000 }, { "GuardianPower.5", 210000 } }, bot = Tune.fineBot(1e9) },
	{ name = "Not offered: level cost growth", changes = { { "Starter.LevelCostGrowth", 1.39 }, { "GuardianPower.2", 150 } },
		note = "Fits the pads bot as well as B but changes the coin price of every starter level." },
	{ name = "Not offered: best for both bots at once",
		changes = { { "Starter.LevelCostGrowth", 1.39 }, { "CommonPower.4", 2500 }, { "GuardianPower.2", 150 }, { "GuardianPower.5", 200000 } },
		note = "The closest the search came to both bots at once (about 380 combinations): neither bot is within 10%." },
}

local function parseTry(list, from)
	local changes = {}
	for i = from, #list do
		local path, value = string.match(list[i], "^([%w%.]+)=([%d%.]+)$")
		if not path then error("tune: write changes as Path.Name=number, got '" .. tostring(list[i]) .. "'") end
		changes[#changes + 1] = { path, tonumber(value) }
	end
	return changes
end

if ARGS and ARGS[1] ~= "lib" then
	local runs = tonumber(ARGS[1]) or 300
	local at = tonumber(ARGS[1]) and 2 or 1
	if ARGS[at] == "try" then
		local changes = parseTry(ARGS, at + 1)
		Tune.print("try", changes, runs)
		Tune.printChecks(changes)
	elseif ARGS[at] == "bot" then
		Tune.printBot(runs)
	else
		print(string.format("tune, %d runs, mean active minutes, %d active minutes a day. Nothing is written to any file.", runs, Tune.DayMinutes))
		Tune.printBot(runs)
		for _, c in ipairs(Tune.Candidates) do
			print("")
			Tune.print(c.name, c.changes, runs, c.bot)
			if c.note then print("  " .. c.note) end
			Tune.printChecks(c.changes)
		end
	end
end
return Tune
