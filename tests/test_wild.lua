local W = require(Server.Core.WildCore)
local SD = require(Server.Core.ShowdownCore)
local Profile = require(Server.Core.Profile)
local Tap = require(Server.Core.TapCore)
local Config = require(Shared.Config)
local E = Config.Economy
local t = {}

local function pet(floor, rarity, id)
	return { id = id or (floor * 100000 + 1), floor = floor, rarity = rarity, radiant = false, tried = {}, leaves = 90 }
end

function t.needs_play_only_epic_legendary_secret()
	T.no(W.needsPlay("Common")) T.no(W.needsPlay("Uncommon")) T.no(W.needsPlay("Rare"))
	T.ok(W.needsPlay("Epic")) T.ok(W.needsPlay("Legendary")) T.ok(W.needsPlay("Secret"))
	T.no(W.needsPlay(nil)) T.no(W.needsPlay("Guardian"))
end

function t.meter_sizes_every_floor_and_rarity()
	local gp = { 20, 180, 7500, 65000, 225000 }
	local mult = { Epic = 4, Legendary = 10, Secret = 150 }
	T.eq(#E.GuardianPower, 5)
	for floor = 1, 5 do
		T.eq(E.GuardianPower[floor], gp[floor])
		for rarity, m in pairs(mult) do
			T.eq(W.meter(floor, rarity), gp[floor] * m, "floor " .. floor .. " " .. rarity)
			local s = W.new(pet(floor, rarity), "Leaf", 0)
			T.eq(s.sd.meter, gp[floor] * m)
			T.eq(s.sd.left, gp[floor] * m)
		end
	end
	T.eq(W.meter(1, "Epic"), 80)
	T.eq(W.meter(1, "Legendary"), 200)
	T.eq(W.meter(1, "Secret"), 3000)
	T.eq(W.meter(5, "Secret"), 33750000)
end

function t.new_session_shape()
	local s = W.new(pet(2, "Epic", 200007), "Tide", 5)
	T.eq(s.petId, 200007) T.eq(s.floor, 2) T.eq(s.rarity, "Epic") T.eq(s.nature, "Tide")
	T.eq(s.state, "active")
	T.eq(s.sd.kind, "wild") T.eq(s.sd.floor, 2) T.eq(s.sd.nature, "Tide")
	T.eq(s.sd.start, 5)
	T.eq(s.sd.ends, nil) -- no time limit
	T.eq(s.sd.count, 0)
end

function t.equal_power_empties_epic_in_4s_every_floor()
	for floor = 1, 5 do
		local s = W.new(pet(floor, "Epic"), "Leaf", 0)
		T.ok(W.join(s, 1, E.GuardianPower[floor], 0))
		T.eq(W.tick(s, 3.9), "active")
		T.eq(W.tick(s, 4), "won")
		T.eq(s.sd.left, 0)
	end
end

function t.equal_power_empties_legendary_in_10s_every_floor()
	for floor = 1, 5 do
		local s = W.new(pet(floor, "Legendary"), "Leaf", 0)
		T.ok(W.join(s, 1, E.GuardianPower[floor], 0))
		T.eq(W.tick(s, 9.9), "active")
		s = W.new(pet(floor, "Legendary"), "Leaf", 0) -- fresh: one exact step, no rounding from 9.9 + 0.1
		W.join(s, 1, E.GuardianPower[floor], 0)
		T.eq(W.tick(s, 10), "won")
	end
end

function t.three_players_empty_secret_in_50s()
	for floor = 1, 5 do
		local s = W.new(pet(floor, "Secret"), "Leaf", 0)
		for u = 1, 3 do T.ok(W.join(s, u, E.GuardianPower[floor], 0)) end
		T.eq(W.tick(s, 49.9), "active")
		T.eq(W.tick(s, 50), "won")
		T.eq(#W.participants(s), 3)
	end
end

function t.one_player_secret_takes_150s()
	local s = W.new(pet(1, "Secret"), "Leaf", 0)
	W.join(s, 1, 20, 0)
	T.eq(W.tick(s, 149.9), "active")
	s = W.new(pet(1, "Secret"), "Leaf", 0)
	W.join(s, 1, 20, 0)
	T.eq(W.tick(s, 150), "won")
end

function t.nobody_playing_never_drains()
	local s = W.new(pet(1, "Epic"), "Leaf", 0)
	T.eq(W.tick(s, 1000), "active")
	T.eq(s.sd.left, 80)
end

function t.joining_late_adds_power()
	local s = W.new(pet(1, "Legendary"), "Leaf", 0) -- meter 200
	W.join(s, 1, 10, 0)
	T.ok(W.join(s, 2, 30, 4)) -- 40 drained, 160 left, now 40/s
	T.near(s.sd.left, 160, 1e-9)
	T.eq(W.tick(s, 7.5), "active")
	T.near(s.sd.left, 20, 1e-9)
	T.eq(W.tick(s, 8.001), "won") -- alone it would have taken 20 s
	T.ok(W.canTry(s, 1)) T.ok(W.canTry(s, 2))
end

function t.session_can_start_long_after_spawn()
	local s = W.new(pet(1, "Epic"), "Leaf", 100) -- pet spawned at 100, nobody near until 130
	T.ok(W.join(s, 1, 20, 130))
	T.near(s.sd.left, 80, 1e-9)
	T.eq(W.tick(s, 133.9), "active")
	T.eq(W.tick(s, 134), "won")
end

function t.meter_never_refills_when_someone_steps_out()
	local s = W.new(pet(1, "Legendary"), "Leaf", 0) -- 200
	W.join(s, 1, 10, 0)
	W.join(s, 2, 10, 0)
	W.stepOut(s, 2, 5) -- 100 drained
	T.near(s.sd.left, 100, 1e-9)
	T.eq(s.sd.count, 1)
	T.eq(W.tick(s, 10), "active")
	T.near(s.sd.left, 50, 1e-9) -- only player 1 now, and nothing came back
	W.stepOut(s, 1, 10)
	T.eq(W.tick(s, 60), "active")
	T.near(s.sd.left, 50, 1e-9) -- empty ring: the meter waits, it does not refill
	T.eq(s.sd.count, 0)
	local lowest = s.sd.left
	T.ok(W.join(s, 3, 25, 60))
	T.eq(W.tick(s, 61), "active")
	T.ok(s.sd.left <= lowest)
	T.eq(W.tick(s, 62), "won")
	-- everyone who took part may try, even those who stepped out before the end
	T.ok(W.canTry(s, 1)) T.ok(W.canTry(s, 2)) T.ok(W.canTry(s, 3))
	T.eq(#W.participants(s), 3)
end

function t.meter_only_ever_goes_down()
	local s = W.new(pet(2, "Epic"), "Tide", 0) -- 720
	local last = s.sd.left
	local now = 0
	local function check()
		T.ok(s.sd.left <= last, "meter went up")
		T.ok(s.sd.left >= 0)
		last = s.sd.left
	end
	W.join(s, 1, 30, 0)
	for i = 1, 40 do
		now = now + 0.25
		if i == 5 then W.join(s, 2, 15, now) end
		if i == 9 then SD.cheer(s.sd, 1, 2, now) end
		if i == 12 then W.stepOut(s, 1, now) end
		if i == 20 then W.stepOut(s, 2, now) end
		if i == 30 then W.join(s, 1, 30, now) end
		W.tick(s, now)
		check()
	end
end

function t.rejoin_after_stepping_out()
	local s = W.new(pet(1, "Legendary"), "Leaf", 0)
	W.join(s, 1, 10, 0)
	W.stepOut(s, 1, 2)
	T.ok(W.join(s, 1, 10, 5))
	T.near(s.sd.left, 180, 1e-9)
	T.eq(#W.participants(s), 1)
	T.eq(s.tookCount, 1)
end

function t.join_rules()
	local s = W.new(pet(1, "Epic"), "Leaf", 0)
	T.ok(W.join(s, 1, 20, 0))
	local ok, why = W.join(s, 1, 20, 1)
	T.no(ok) T.eq(why, "already")
	ok, why = W.join(s, 2, -5, 1)
	T.no(ok) T.eq(why, "bad_power")
	ok, why = W.join(s, 2, 0 / 0, 1)
	T.no(ok) T.eq(why, "bad_power")
	ok, why = W.join(s, 2, "9", 1)
	T.no(ok) T.eq(why, "bad_power")
	T.eq(#W.participants(s), 1)
	T.eq(W.tick(s, 4), "won")
	ok, why = W.join(s, 3, 20, 5)
	T.no(ok) T.eq(why, "over")
	T.no(W.canTry(s, 3))
end

function t.join_that_arrives_after_empty_is_refused()
	local s = W.new(pet(1, "Epic"), "Leaf", 0)
	W.join(s, 1, 20, 0)
	-- no tick since: the join itself finds the meter empty
	local ok, why = W.join(s, 2, 20, 6)
	T.no(ok) T.eq(why, "over")
	T.eq(s.state, "won")
	T.ok(W.canTry(s, 1)) T.no(W.canTry(s, 2))
end

function t.can_try_only_after_empty_and_only_participants()
	local s = W.new(pet(1, "Epic"), "Leaf", 0)
	T.no(W.canTry(s, 1)) -- nobody has played
	W.join(s, 1, 20, 0)
	T.no(W.canTry(s, 1)) -- before empty
	T.no(W.canTry(s, 2))
	W.tick(s, 3.9)
	T.no(W.canTry(s, 1)) -- still not empty
	T.eq(W.tick(s, 4), "won")
	T.ok(W.canTry(s, 1)) -- took part
	T.no(W.canTry(s, 2)) -- did not take part
	T.no(W.canTry(s, nil))
	T.eq(W.tick(s, 500), "won") -- stays won
	T.ok(W.canTry(s, 1))
end

function t.pet_leaves_early_nobody_can_try()
	local s = W.new(pet(1, "Legendary"), "Leaf", 0)
	W.join(s, 1, 10, 0) W.join(s, 2, 5, 0)
	W.tick(s, 5) -- 75 of 200 drained
	T.eq(W.leave(s, 5), "left")
	T.eq(s.state, "left")
	T.eq(W.tick(s, 100), "left") -- stays left, and nothing more drains
	T.near(s.sd.left, 125, 1e-9)
	T.no(W.canTry(s, 1)) T.no(W.canTry(s, 2)) T.no(W.canTry(s, 3))
	local ok, why = W.join(s, 3, 1000, 6)
	T.no(ok) T.eq(why, "over")
	ok, why = SD.cheer(s.sd, 1, 6, 6)
	T.no(ok) T.eq(why, "over")
	T.no(W.keep(s, 6))
	T.eq(W.graceEnds(s), nil)
end

function t.pet_leaves_with_nobody_playing()
	local s = W.new(pet(3, "Epic"), "Ember", 0)
	T.eq(W.leave(s, 90), "left")
	T.eq(#W.participants(s), 0)
end

function t.leaving_after_empty_keeps_the_win()
	local s = W.new(pet(1, "Epic"), "Leaf", 0)
	W.join(s, 1, 20, 0)
	T.eq(W.tick(s, 4), "won")
	T.eq(W.leave(s, 30), "won")
	T.ok(W.canTry(s, 1))
end

function t.nothing_is_lost_when_the_pet_leaves()
	local p = Profile.new(0)
	Profile.chooseStarter(p, "Pandle")
	local coins, catches = p.coins, p.stats.catches
	local s = W.new(pet(1, "Legendary"), "Leaf", 0)
	W.join(s, 1, Profile.teamPower(p, "Leaf"), 0)
	W.tick(s, 1)
	W.leave(s, 1)
	T.eq(p.coins, coins) T.eq(p.stats.catches, catches) T.ok(p.starter ~= nil)
end

function t.cheers_speed_it_up()
	-- 10 power on a floor 1 Legendary (200): 20 s without cheers
	local plain = W.new(pet(1, "Legendary"), "Leaf", 0)
	W.join(plain, 1, 10, 0)
	T.eq(W.tick(plain, 19.9), "active")
	T.eq(W.tick(plain, 20), "won")

	local s = W.new(pet(1, "Legendary"), "Leaf", 0)
	W.join(s, 1, 10, 0)
	local ok, g = SD.cheer(s.sd, 1, 1.0, 1.02)
	T.ok(ok) T.eq(g, "Perfect")
	W.tick(s, 3.02) -- 1.02 s at 10, then 2 s at 15
	T.near(s.sd.left, 200 - 10.2 - 30, 1e-6)
	for beat = 2, 19 do SD.cheer(s.sd, 1, beat, beat + 0.02) end
	T.eq(W.tick(s, 14), "won") -- perfect cheers: +50% almost all the way
	T.ok(s.wonAt <= 14)
end

function t.cheer_rules_are_the_guardian_rules()
	local s = W.new(pet(1, "Secret"), "Leaf", 10) -- beats count from the session start
	W.join(s, 1, 10, 10)
	local ok, why = SD.cheer(s.sd, 2, 1, 11)
	T.no(ok) T.eq(why, "not_in") -- not in the ring
	T.ok(SD.cheer(s.sd, 1, 1.0, 11.0))
	ok, why = SD.cheer(s.sd, 1, 1.05, 11.1)
	T.no(ok) T.eq(why, "already")
	ok, why = SD.cheer(s.sd, 1, 9, 12)
	T.no(ok) T.eq(why, "clock")
	local _, g = SD.cheer(s.sd, 1, 2.15, 12.2)
	T.eq(g, "Good")
end

function t.friend_doubles_the_cheer()
	local s = W.new(pet(1, "Secret"), "Leaf", 0)
	W.join(s, 1, 10, 0) W.join(s, 2, 0, 0)
	SD.refreshFriends(s.sd, function() return true end)
	SD.cheer(s.sd, 1, 1.0, 1.0)
	W.tick(s, 3)
	T.near(s.sd.left, 3000 - 10 - 2 * 10 * 2, 1e-6) -- +100% for 2 s instead of +50%
end

function t.nature_multiplier_passes_through()
	-- Pandle is Ember; find the nature Ember beats and one it does not
	local beaten = E.NatureBeats.Ember
	T.ok(beaten ~= nil)
	local other = E.NatureBeats[beaten] -- the nature that `beaten` beats: Ember does not beat it
	T.ok(other ~= beaten)
	local p = Profile.new(0)
	Profile.chooseStarter(p, "Pandle")
	local base = Profile.teamPower(p, nil)
	T.ok(base > 0)
	T.near(Profile.teamPower(p, beaten), base * 1.5, 1e-9)
	T.near(Profile.teamPower(p, other), base, 1e-9)

	local fast = W.new(pet(1, "Legendary"), beaten, 0)
	T.eq(fast.nature, beaten) T.eq(fast.sd.nature, beaten)
	W.join(fast, 1, Profile.teamPower(p, fast.nature), 0)
	local slow = W.new(pet(1, "Legendary"), other, 0)
	W.join(slow, 1, Profile.teamPower(p, slow.nature), 0)
	W.tick(fast, 1) W.tick(slow, 1)
	T.near(200 - fast.sd.left, (200 - slow.sd.left) * 1.5, 1e-9)
	T.near(200 - fast.sd.left, base * 1.5, 1e-9)
	-- and it finishes in two thirds of the time
	local tSlow = 200 / base
	T.eq(W.tick(fast, tSlow * 2 / 3 + 1e-6), "won")
	T.eq(W.tick(slow, tSlow * 2 / 3 + 1e-6), "active")
end

function t.every_secret_and_wild_pet_has_a_nature()
	for floor = 1, 5 do
		for _, rarity in ipairs({ "Epic", "Legendary", "Secret" }) do
			local species = Config.Pets.ByFloor[floor][rarity]
			T.ok(species, "no species floor " .. floor .. " " .. rarity)
			local nature = Config.Pets.Wild[species].nature
			T.ok(E.NatureBeats[nature] ~= nil, species .. " nature")
		end
	end
end

function t.grace_after_empty()
	local s = W.new(pet(1, "Epic"), "Leaf", 0)
	W.join(s, 1, 20, 0)
	T.no(W.keep(s, 3)) -- still playing: the pet is not kept past its time
	T.eq(W.graceEnds(s), nil)
	T.eq(W.tick(s, 4), "won")
	T.eq(s.wonAt, 4)
	T.eq(W.graceEnds(s), 4 + E.Wild.TryGraceSeconds)
	T.ok(W.keep(s, 4))
	T.ok(W.keep(s, 4 + E.Wild.TryGraceSeconds - 0.01))
	T.no(W.keep(s, 4 + E.Wild.TryGraceSeconds))
	W.tick(s, 9) -- later ticks do not move the grace
	T.eq(s.wonAt, 4)
end

function t.friendly_try_rings_are_20_percent_slower()
	T.eq(E.Wild.FriendlySlow, 0.20)
	for _, rarity in ipairs({ "Epic", "Legendary", "Secret" }) do
		local plain = Tap.ringTime({ rarity = rarity, floor = 1, charm = 1 })
		local friendly = Tap.ringTime({ rarity = rarity, floor = 1, charm = 1, friendly = true })
		T.near(friendly, plain * 1.2, 1e-9, rarity)
	end
end

function t.participants_sorted_and_counted_once()
	local s = W.new(pet(1, "Secret"), "Leaf", 0)
	W.join(s, 30, 1, 0) W.join(s, 10, 1, 0) W.join(s, 20, 1, 0)
	W.stepOut(s, 10, 1) W.join(s, 10, 1, 2)
	local ids = W.participants(s)
	T.eq(#ids, 3) T.eq(ids[1], 10) T.eq(ids[2], 20) T.eq(ids[3], 30)
	T.eq(s.tookCount, 3)
end

return t
