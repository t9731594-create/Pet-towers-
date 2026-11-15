ARGS = { "lib" }
local Sim = runfile(ROOT .. "/tools/econ_sim.lua")
local S = require(Shared.Config).Economy.Sim
local t = {}
function t.deterministic()
	local a, b = Sim.run(12345), Sim.run(12345)
	for f = 1, 5 do T.eq(a.wins[f], b.wins[f]) end
	T.eq(a.extraSeconds, b.extraSeconds)
	T.eq(a.level, b.level)
end
function t.all_five_guardians_fall_in_order()
	local r = Sim.table(40, { buyPads = true })
	for f = 1, 5 do T.ok(r.wins[f], "floor " .. f) end
	for f = 2, 5 do T.ok(r.wins[f] > r.wins[f - 1]) end
end
-- Amendment 1: play time before Epic and Legendary tries.
function t.extra_try_seconds_come_from_config_by_default()
	T.eq(Sim.extraTrySeconds(), S.ExtraTrySeconds)
	T.eq(Sim.extraTrySeconds({ buyPads = true }).Epic, 5)
	T.eq(Sim.extraTrySeconds({}).Legendary, 12)
	local r = Sim.run(12345)
	T.ok((r.tries.Epic or 0) > 0, "the run tried an Epic")
	T.ok((r.tries.Legendary or 0) > 0, "the run tried a Legendary")
	T.eq(r.extraSeconds, 5 * r.tries.Epic + 12 * r.tries.Legendary)
	local same = Sim.run(12345, { extraTrySeconds = S.ExtraTrySeconds })
	for f = 1, 5 do T.eq(r.wins[f], same.wins[f]) end
end
function t.no_wild_switches_the_extra_seconds_off()
	T.eq(next(Sim.extraTrySeconds({ noWild = true })), nil)
	local off = Sim.run(12345, { noWild = true })
	T.eq(off.extraSeconds, 0)
	local none = Sim.run(12345, { extraTrySeconds = {} })
	for f = 1, 5 do T.eq(off.wins[f], none.wins[f]) end
	-- noWild wins over an explicit table too
	T.eq(Sim.run(12345, { noWild = true, extraTrySeconds = { Epic = 99 } }).extraSeconds, 0)
end
function t.extra_seconds_change_the_clock_not_the_rolls()
	local on, off = Sim.run(777), Sim.run(777, { noWild = true })
	local differs = false
	for f = 1, 5 do if on.wins[f] ~= off.wins[f] then differs = true end end
	T.ok(differs, "win times move when tries take longer")
	-- a custom table is applied per try and repeats exactly
	local a, b = Sim.run(777, { extraTrySeconds = { Epic = 1 } }), Sim.run(777, { extraTrySeconds = { Epic = 1 } })
	T.eq(a.extraSeconds, b.extraSeconds)
	T.eq(a.extraSeconds, a.tries.Epic)
end
function t.custom_extra_seconds_are_used()
	local r = Sim.run(12345, { extraTrySeconds = { Legendary = 100 } })
	T.eq(r.extraSeconds, 100 * r.tries.Legendary)
end
function t.table_is_deterministic_with_and_without_wild()
	local a, b = Sim.table(10, { buyPads = true }), Sim.table(10, { buyPads = true })
	local c, d = Sim.table(10, { noWild = true }), Sim.table(10, { noWild = true })
	for f = 1, 5 do T.eq(a.wins[f], b.wins[f]) T.eq(c.wins[f], d.wins[f]) end
end
return t
