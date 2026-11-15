local SD = require(Server.Core.ShowdownCore)
local t = {}
function t.solo_needs_power_near_guardian()
	local sd = SD.guardian(1, "Leaf", 0) -- meter 800
	SD.join(sd, 1, 20, 0)
	T.eq(SD.tick(sd, 39.9), "active")
	T.eq(SD.tick(sd, 40), "won")
	sd = SD.guardian(1, "Leaf", 0)
	SD.join(sd, 1, 19, 0)
	T.eq(SD.tick(sd, 40), "lost")
end
function t.three_players_at_forty_percent_each()
	local sd = SD.guardian(2, "Tide", 0)
	for u = 1, 3 do SD.join(sd, u, 180 * 0.4, 0) end
	T.eq(SD.tick(sd, 40), "won")
	T.eq(#SD.participants(sd), 3)
end
function t.late_joiner_adds_and_is_rewarded()
	local sd = SD.guardian(1, "Leaf", 0)
	SD.join(sd, 1, 10, 0)
	T.ok(SD.join(sd, 2, 40, 30)) -- 300 drained, 500 left, now 50/s
	T.eq(SD.tick(sd, 39.9), "active")
	T.eq(SD.tick(sd, 40), "won")
	T.eq(#SD.participants(sd), 2)
	T.no(SD.join(sd, 3, 10, 41))
end
function t.cheer_grades_and_boost()
	local sd = SD.guardian(1, "Leaf", 0)
	SD.join(sd, 1, 10, 0)
	local ok, g = SD.cheer(sd, 1, 1.02, 1.05)
	T.ok(ok) T.eq(g, "Perfect")
	SD.tick(sd, 3.05) -- 1.05 s at 10, then 2 s at 15
	T.near(sd.left, 800 - 10.5 - 30, 1e-6)
	SD.tick(sd, 4.05) -- boost over
	T.near(sd.left, 800 - 10.5 - 30 - 10, 1e-6)
	ok, g = SD.cheer(sd, 1, 5.15, 5.2)
	T.eq(g, "Good")
	ok, g = SD.cheer(sd, 1, 6.4, 6.45)
	T.eq(g, "Miss")
end
function t.cheer_rules()
	local sd = SD.guardian(1, "Leaf", 0)
	SD.join(sd, 1, 10, 0)
	T.ok(SD.cheer(sd, 1, 1.0, 1.05))
	local ok, why = SD.cheer(sd, 1, 1.05, 1.1)
	T.no(ok) T.eq(why, "already") -- one cheer per beat
	ok, why = SD.cheer(sd, 1, 5.0, 2.0)
	T.no(ok) T.eq(why, "clock") -- claims a time that has not happened
	ok, why = SD.cheer(sd, 9, 2.0, 2.0)
	T.no(ok) T.eq(why, "not_in")
end
function t.friend_doubles_cheer()
	local sd = SD.guardian(1, "Leaf", 0)
	SD.join(sd, 1, 10, 0) SD.join(sd, 2, 0, 0)
	SD.refreshFriends(sd, function(a, b) return true end)
	SD.cheer(sd, 1, 1.0, 1.0)
	SD.tick(sd, 3.0)
	T.near(sd.left, 800 - 10 - 2 * 10 * 2, 1e-6) -- +100% for 2 s
end
function t.perfect_cheering_is_about_plus_fifty()
	local sd = SD.guardian(1, "Leaf", 0)
	SD.join(sd, 1, 14, 0) -- 14 x 40 = 560 without cheers
	for beat = 1, 39 do SD.cheer(sd, 1, beat, beat + 0.02) end
	T.eq(SD.tick(sd, 40), "won")
end
function t.no_time_limit_mode()
	local sd = SD.new({ kind = "x", meter = 100, now = 0 })
	SD.join(sd, 1, 1, 0)
	T.eq(SD.tick(sd, 99), "active")
	T.eq(SD.tick(sd, 100), "won")
end
return t
