local Profile = require(Server.Core.Profile)
local t = {}
local function fresh()
	local p = Profile.new(1000)
	Profile.chooseStarter(p, "Pandle")
	return p
end
function t.starter_once()
	local p = Profile.new(0)
	T.no(Profile.chooseStarter(p, "Pikachu"))
	T.ok(Profile.chooseStarter(p, "Narbub"))
	T.no(Profile.chooseStarter(p, "Pandle"))
	T.eq(p.coins, 50)
end
function t.catch_stack_deposit_income()
	local p = fresh()
	for _ = 1, 3 do T.ok(Profile.addCaught(p, "Buttercub", "Common", false)) end
	local ok, why = Profile.addCaught(p, "Buttercub", "Common", false)
	T.no(ok) T.eq(why, "stack_full")
	local _, r = Profile.deposit(p, 1000)
	T.eq(r.placed, 3) T.eq(#p.stack, 0)
	T.eq(Profile.incomePerSecond(p), 3)
	local _, got = Profile.collect(p, 1010)
	T.eq(got, 30) T.eq(p.coins, 80)
	local _, again = Profile.collect(p, 1010)
	T.eq(again, 0)
end
function t.pad_holds_ten_minutes()
	local p = fresh()
	Profile.addCaught(p, "Sunflion", "Legendary", false)
	Profile.deposit(p, 0)
	local _, got = Profile.collect(p, 100000)
	T.eq(got, 10 * 600)
end
function t.friend_multiplier_on_collect()
	local p = fresh()
	Profile.addCaught(p, "Sunflion", "Legendary", false)
	Profile.deposit(p, 0)
	local _, got = Profile.collect(p, 10, 1.2)
	T.eq(got, 120)
end
function t.feed_and_evolve()
	local p = fresh()
	p.coins = 71
	local evolved
	for _ = 1, 4 do
		local ok, r = Profile.feed(p)
		T.ok(ok)
		evolved = r.evolvedTo
	end
	T.eq(p.starter.level, 5) T.eq(evolved, 2) T.eq(p.coins, 0)
	T.no(Profile.feed(p))
	T.eq(p.stats.sinks.feed, 71)
end
function t.overflow_goes_spare_and_release()
	local p = fresh()
	p.upgrades.stack = 7
	for _ = 1, 10 do Profile.addCaught(p, "Buttercub", "Common", false) end
	Profile.deposit(p, 0)
	T.eq(#p.spare, 2)
	local id = p.spare[1]
	local ok, coins = Profile.release(p, id, 0)
	T.ok(ok) T.eq(coins, 60) T.eq(#p.pets, 9) T.eq(#p.spare, 1)
	T.no(Profile.release(p, id, 0))
end
function t.cannot_release_team_or_stack()
	local p = fresh()
	Profile.addCaught(p, "Zipwing", "Rare", false)
	T.no(Profile.release(p, 1, 0)) -- still on the head
	Profile.deposit(p, 0)
	Profile.autoTeam(p)
	T.eq(p.team[1], 1)
	local ok, why = Profile.release(p, 1, 0)
	T.no(ok) T.eq(why, "on_team")
end
function t.place_swaps()
	local p = fresh()
	p.upgrades.stack = 7
	for _ = 1, 8 do Profile.addCaught(p, "Buttercub", "Common", false) end
	Profile.addCaught(p, "Sunflion", "Legendary", false)
	Profile.deposit(p, 0)
	T.eq(Profile.where(p, 9), "spare")
	T.ok(Profile.place(p, 9, 1, 10))
	T.eq(p.pads[1].pet, 9) T.eq(Profile.where(p, 1), "spare")
	T.eq(p.coins, 60) -- pad 1 was collected (10 s x 1) before the swap
	T.no(Profile.place(p, 999, 1, 10))
	T.no(Profile.place(p, 9, 99, 10))
end
function t.team_power_and_natures()
	local p = fresh() -- Pandle = Ember
	Profile.addCaught(p, "Zipwing", "Rare", false) -- Tide, power 5
	Profile.addCaught(p, "Buttercub", "Common", false) -- Leaf, power 2
	Profile.deposit(p, 0)
	Profile.autoTeam(p)
	T.near(Profile.teamPower(p), 3 + 5 + 2)
	T.near(Profile.teamPower(p, "Leaf"), 3 * 1.5 + 5 + 2) -- Ember beats Leaf
	T.near(Profile.teamPower(p, "Ember"), 3 + 5 * 1.5 + 2) -- Tide beats Ember
	T.ok(Profile.setTeam(p, 2, nil))
	T.near(Profile.teamPower(p), 5)
	T.no(Profile.setTeam(p, 1, 1))
end
function t.hearts()
	local p = fresh()
	Profile.addCaught(p, "Zipwing", "Rare", false)
	Profile.deposit(p, 0)
	p.coins = 7750
	for n = 1, 5 do T.ok(Profile.addHeart(p, 1)) end
	T.eq(p.coins, 0)
	local ok, why = Profile.addHeart(p, 1)
	T.no(ok) T.eq(why, "max")
end
function t.upgrades_and_floors()
	local p = fresh()
	p.coins = 1000000
	local ok, why = Profile.buyCharm(p)
	T.no(ok) T.eq(why, "locked")
	T.ok(Profile.canEnter(p, 1)) T.no(Profile.canEnter(p, 2))
	T.ok(Profile.clearFloor(p, 1)) T.no(Profile.clearFloor(p, 1))
	T.ok(Profile.canEnter(p, 2))
	T.ok(Profile.buyCharm(p)) T.eq(p.charm, 2) T.eq(p.coins, 1000000 - 300)
	local _, n = Profile.buyPads(p, 0) T.eq(n, 12)
	local _, cap = Profile.buyStack(p) T.eq(cap, 4)
end
function t.assist_after_three_misses()
	local p = fresh()
	Profile.noteTry(p, false) Profile.noteTry(p, false)
	T.no(Profile.assistOn(p))
	Profile.noteTry(p, false)
	T.ok(Profile.assistOn(p))
	Profile.noteTry(p, true) T.ok(Profile.assistOn(p))
	Profile.noteTry(p, true) T.no(Profile.assistOn(p))
end
return t
