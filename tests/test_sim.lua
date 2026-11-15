ARGS = { "lib" }
local Sim = runfile(ROOT .. "/tools/econ_sim.lua")
local t = {}
function t.deterministic()
	local a, b = Sim.run(12345), Sim.run(12345)
	for f = 1, 5 do T.eq(a.wins[f], b.wins[f]) end
end
function t.all_five_guardians_fall_in_order()
	local r = Sim.table(40, { buyPads = true })
	for f = 1, 5 do T.ok(r.wins[f], "floor " .. f) end
	for f = 2, 5 do T.ok(r.wins[f] > r.wins[f - 1]) end
end
return t
