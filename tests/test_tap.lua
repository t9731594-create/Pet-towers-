local TapCore = require(Server.Core.TapCore)
local t = {}
local function play(opts, deltas) -- deltas: seconds off each beat, or false to skip
	local tl = TapCore.issue(opts, 100)
	for i, d in ipairs(deltas) do
		if d then
			local off = tl.beats[i] + d
			TapCore.tap(tl, i, off, 100 + off + 0.05)
		end
	end
	return TapCore.result(tl), tl
end
function t.ring_times()
	T.near(TapCore.ringTime({ rarity = "Common" }), 1.2)
	T.near(TapCore.ringTime({ rarity = "Legendary" }), 0.5)
	T.near(TapCore.ringTime({ rarity = "Rare", floor = 3, charm = 1 }), 0.8 * 0.85 * 0.85)
	T.near(TapCore.ringTime({ rarity = "Rare", floor = 1, charm = 3 }), 0.8)
	T.near(TapCore.ringTime({ rarity = "Epic", assist = true }), 0.65 * 1.2)
end
function t.grades()
	T.eq(TapCore.grade(0.08), "Perfect") T.eq(TapCore.grade(-0.081), "Good")
	T.eq(TapCore.grade(0.2), "Good") T.eq(TapCore.grade(0.201), "Miss")
end
function t.common_needs_one_good()
	T.ok(play({ rarity = "Common" }, { 0.5, 0.15, false }).success)
	T.no(play({ rarity = "Common" }, { 0.5, 0.3, 0.25 }).success)
end
function t.uncommon_two_goods()
	T.ok(play({ rarity = "Uncommon" }, { 0.1, 0.5, 0.1 }).success)
	T.no(play({ rarity = "Uncommon" }, { 0.1, 0.5, 0.5 }).success)
end
function t.rare_two_goods_one_perfect()
	T.ok(play({ rarity = "Rare" }, { 0.05, 0.15, 0.4 }).success)
	T.no(play({ rarity = "Rare" }, { 0.15, 0.15, 0.15 }).success)
end
function t.epic_three_hits_two_perfect()
	T.ok(play({ rarity = "Epic" }, { 0.05, -0.05, 0.15 }).success)
	T.no(play({ rarity = "Epic" }, { 0.05, 0.15, 0.15 }).success)
	T.no(play({ rarity = "Epic" }, { 0.05, 0.05, 0.3 }).success)
end
function t.legendary_three_perfects_and_bolt()
	local r = play({ rarity = "Legendary" }, { 0.01, -0.02, 0.07 })
	T.ok(r.success) T.ok(r.perfectAll)
	r = play({ rarity = "Legendary" }, { 0.01, 0.02, 0.3 })
	T.no(r.success) T.ok(r.lastBeatMiss)
end
function t.first_tap_cannot_fail()
	T.ok(play({ rarity = "Common", cannotFail = true }, { false, false, false }).success)
end
function t.server_checks_the_clock()
	local tl = TapCore.issue({ rarity = "Legendary" }, 100)
	-- a perfect offset sent the instant the try starts is a Miss
	local ok, g, why = TapCore.tap(tl, 1, tl.beats[1], 100.01)
	T.ok(ok) T.eq(g, "Miss") T.eq(why, "clock")
	-- a perfect offset that arrives 2 s late is a Miss
	ok, g = TapCore.tap(tl, 2, tl.beats[2], 100 + tl.beats[2] + 2)
	T.eq(g, "Miss")
	T.no(TapCore.tap(tl, 2, tl.beats[2], 101)) -- one tap per ring
	T.no(TapCore.tap(tl, 7, 1, 101))
	T.no(TapCore.tap(tl, 3, 0 / 0, 101))
	T.no(TapCore.tap(tl, 3, "x", 101))
end
function t.expiry()
	local tl = TapCore.issue({ rarity = "Common" }, 0)
	T.no(TapCore.expired(tl, 4)) T.ok(TapCore.expired(tl, 6))
end
return t
