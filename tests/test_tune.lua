-- tools/tune: overrides are written into the loaded config and put back exactly; the sim's default
-- output does not move.
ARGS = { "lib" }
local Tune = runfile(ROOT .. "/tools/tune.lua")
local Sim = runfile(ROOT .. "/tools/econ_sim.lua")
local Config = require(Shared.Config)
local E = Config.Economy
local F = require(Shared.Logic.Formulas)
local t = {}
local CHANGES = {
	{ "GuardianPower.5", 200000 }, { "CommonPower.4", 2500 }, { "CommonIncome.3", 10 }, { "CharmPrice.2", 250 },
	{ "Pads.Prices.1", 400 }, { "Starter.LevelCostGrowth", 1.39 }, { "Sim.TripSeconds", 100 },
}
function t.loading_as_lib_keeps_args()
	T.eq(ARGS[1], "lib")
	T.eq(#ARGS, 1)
end
function t.with_writes_the_values_and_restores_them_exactly()
	local before = Tune.snapshot()
	local gp, pads, starter = E.GuardianPower, E.Pads.Prices, E.Starter
	local seen = Tune.with(CHANGES, function()
		T.eq(E.GuardianPower[5], 200000) T.eq(E.CommonPower[4], 2500) T.eq(E.CommonIncome[3], 10)
		T.eq(E.CharmPrice[2], 250) T.eq(E.Pads.Prices[1], 400) T.eq(E.Starter.LevelCostGrowth, 1.39)
		T.eq(F.levelCost(2), 14) T.eq(F.levelCost(10), F.round(10 * 1.39 ^ 9)) -- other modules see the values
		T.no(Tune.same(before, Tune.snapshot()))
		return "ran"
	end)
	T.eq(seen, "ran")
	T.ok(Tune.same(before, Tune.snapshot()), "config differs after Tune.with")
	T.ok(E.GuardianPower == gp and E.Pads.Prices == pads and E.Starter == starter, "tables were replaced, not edited in place")
	T.eq(E.GuardianPower[5], 225000) T.eq(E.CommonPower[4], 2200) T.eq(E.CommonIncome[3], 9) T.eq(E.CharmPrice[2], 300)
	T.eq(E.Pads.Prices[1], 500) T.eq(E.Starter.LevelCostGrowth, 1.4) T.eq(E.Sim.TripSeconds, 150)
	T.eq(F.levelCost(10), F.round(10 * 1.4 ^ 9))
end
function t.restores_when_the_run_throws()
	local before = Tune.snapshot()
	local ok, err = pcall(Tune.with, CHANGES, function() error("boom") end)
	T.no(ok) T.ok(string.find(tostring(err), "boom"))
	T.ok(Tune.same(before, Tune.snapshot()))
end
function t.the_same_value_changed_twice_goes_back_to_the_original()
	local before = Tune.snapshot()
	Tune.with({ { "GuardianPower.2", 150 }, { "GuardianPower.2", 160 } }, function() T.eq(E.GuardianPower[2], 160) end)
	T.eq(E.GuardianPower[2], 180)
	T.ok(Tune.same(before, Tune.snapshot()))
end
function t.a_wrong_path_changes_nothing()
	local before = Tune.snapshot()
	T.no(pcall(Tune.with, { { "GuardianPower.5", 1 }, { "GuardianPower.9", 1 } }, function() end))
	T.no(pcall(Tune.apply, { { "NoSuchList.1", 1 } }))
	T.no(pcall(Tune.apply, { { "GuardianPower", 1 } })) -- a whole table is not one value
	T.no(pcall(Tune.apply, { { "StartCoins.x", 1 } }))
	T.no(pcall(Tune.apply, { { "GuardianPower.5", "lots" } }))
	T.eq(E.GuardianPower[5], 225000)
	T.ok(Tune.same(before, Tune.snapshot()))
end
function t.snapshot_compare_notices_any_difference()
	local a, b = Tune.snapshot(), Tune.snapshot()
	T.ok(Tune.same(a, b))
	b.Tap.Need.Rare.perfects = 2
	T.no(Tune.same(a, b))
	b = Tune.snapshot() b.Extra = 1
	T.no(Tune.same(a, b)) T.no(Tune.same(b, a))
end
function t.measure_and_the_checks_leave_the_config_alone()
	local before = Tune.snapshot()
	local oldT = T
	local m = Tune.measure({ { "GuardianPower.5", 200000 } }, 3)
	T.ok(m.pads.wins[5] and m.nopads.wins[5]) T.ok(m.monotonic)
	T.ok(Tune.firstMinutes({ { "GuardianPower.5", 200000 } }))
	T.ok(Tune.dayTwoReturn({ { "GuardianPower.5", 200000 } }))
	local ok, err = Tune.firstMinutes({ { "GuardianPower.1", 2000 } }) -- far too strong: the script must fail
	T.no(ok) T.ok(string.find(err, "Team Power"), err)
	local w = Tune.wild({ { "GuardianPower.5", 200000 } })
	T.near(w.ready[5], 150, 1e-9) T.eq(w.meter[5], 30000000) T.eq(w.meter[4], 9750000)
	T.eq(T, oldT) T.eq(ARGS[1], "lib")
	T.ok(Tune.same(before, Tune.snapshot()))
end
function t.monotonic_notices_a_list_that_stops_rising()
	T.ok(Tune.monotonic())
	T.no(Tune.with({ { "GuardianPower.5", 65000 } }, Tune.monotonic))
	T.no(Tune.with({ { "Pads.Prices.2", 400 } }, Tune.monotonic))
	T.ok(Tune.monotonic())
end
function t.every_listed_candidate_keeps_the_lists_rising_and_names_real_values()
	for _, c in ipairs(Tune.Candidates) do
		T.ok(Tune.with(c.changes, Tune.monotonic), c.name)
		T.ok(#Tune.describe(c.changes) > 0)
	end
end
function t.days_and_gaps()
	T.eq(Tune.DayMinutes, 36)
	T.eq(Tune.day(35.9), 1) T.eq(Tune.day(36), 2) T.eq(Tune.day(141), 4) T.eq(Tune.day(260), 8)
	T.near(Tune.gap(286, 5), 0.10, 1e-9)
end
-- The default sim output: the numbers in docs/STATUS.md and the branch notes, before and after tuning runs.
function t.default_sim_output_is_unchanged()
	local want = { pads = { 5.65, 18.25, 60.90, 150.68, 302.49 }, nopads = { 5.65, 17.30, 65.00, 196.01, 393.60 } }
	local a, b = Sim.table(300, { buyPads = true }), Sim.table(300)
	Tune.measure({ { "GuardianPower.4", 62000 }, { "Starter.LevelCostGrowth", 1.39 } }, 2, Tune.fineBot(3))
	local a2 = Sim.table(300, { buyPads = true })
	for f = 1, 5 do
		T.eq(string.format("%.2f", a.wins[f]), string.format("%.2f", want.pads[f]), "pads bot, Guardian " .. f)
		T.eq(string.format("%.2f", b.wins[f]), string.format("%.2f", want.nopads[f]), "no-pads bot, Guardian " .. f)
		T.eq(a.wins[f], a2.wins[f])
	end
end
function t.the_trip_hook_is_optional_and_exact()
	local plain = Sim.run(12345, { buyPads = true })
	local same = Sim.run(12345, { buyPads = true, override = { trip = function(_, seconds, catches) return seconds, catches end } })
	local empty = Sim.run(12345, { buyPads = true, override = {} })
	for f = 1, 5 do T.eq(plain.wins[f], same.wins[f]) T.eq(plain.wins[f], empty.wins[f]) end
	T.eq(plain.level, same.level) T.eq(plain.extraSeconds, same.extraSeconds)
	local seen = {}
	local fine = Sim.run(12345, { buyPads = true, override = { trip = function(n, seconds, catches)
		seen[n] = { seconds, catches }
		return Tune.fineBot(6).trip(n, seconds, catches)
	end } })
	T.eq(seen[1][1], 150) T.eq(seen[1][2], 3)
	T.ok(fine.wins[1] < plain.wins[1], "shorter first trips reach Guardian 1 sooner")
end
return t
