local WeeklyCore = require(Server.Core.WeeklyCore)
local Profile = require(Server.Core.Profile)
local SD = require(Server.Core.ShowdownCore)
local IndexView = require(Shared.Logic.IndexView)
local t = {}
local DAY = 86400
local SAT = 20772 * DAY -- 15 Nov 2026 is a Sunday; day 20771 is Saturday 14 Nov 2026
local function player()
	local p = Profile.new(0)
	Profile.chooseStarter(p, "Pandle")
	return p
end
function t.week_starts_saturday_utc()
	local sat = 20771 * DAY
	T.eq(WeeklyCore.weekday(sat), 6) T.eq(WeeklyCore.weekday(sat + DAY), 0)
	T.eq(WeeklyCore.week(sat), WeeklyCore.week(sat + 6 * DAY + 86399))
	T.eq(WeeklyCore.week(sat - 1) + 1, WeeklyCore.week(sat))
	T.ok(WeeklyCore.guardian(WeeklyCore.week(sat)) ~= WeeklyCore.guardian(WeeklyCore.week(sat) + 1))
end
function t.merchant_only_on_weekends()
	local sat = 20771 * DAY
	T.ok(WeeklyCore.merchantOpen(sat)) T.ok(WeeklyCore.merchantOpen(sat + DAY))
	for d = 2, 6 do T.no(WeeklyCore.merchantOpen(sat + d * DAY)) end
end
function t.weekly_meter_solo_needs_near_perfect_cheers()
	local sd = WeeklyCore.newShowdown(0)
	WeeklyCore.join(sd, 1, 100, 0)
	T.near(sd.meter, 100 * 40 * 1.45)
	T.eq(SD.tick(sd, 40), "lost") -- no cheers: 4,000 of 5,800
	sd = WeeklyCore.newShowdown(0)
	WeeklyCore.join(sd, 1, 100, 0)
	for beat = 1, 39 do SD.cheer(sd, 1, beat + 0.1, beat + 0.15) end -- Good cheers only: +20%
	T.eq(SD.tick(sd, 40), "lost")
	sd = WeeklyCore.newShowdown(0)
	WeeklyCore.join(sd, 1, 100, 0)
	for beat = 1, 39 do SD.cheer(sd, 1, beat, beat + 0.02) end -- Perfect cheers
	T.eq(SD.tick(sd, 40), "won")
end
function t.weekly_full_ring_wins_without_cheering()
	local sd = WeeklyCore.newShowdown(0)
	for u = 1, 7 do WeeklyCore.join(sd, u, 10 * u, 0) end -- strong and weak players together
	T.near(sd.meter, 280 * 40 * 1.0)
	T.eq(SD.tick(sd, 40), "won")
	T.near(WeeklyCore.factor(4), 1.225)
end
function t.weekly_late_join_keeps_progress()
	local sd = WeeklyCore.newShowdown(0)
	WeeklyCore.join(sd, 1, 100, 0)
	SD.tick(sd, 20)
	local frac = sd.left / sd.meter
	WeeklyCore.join(sd, 2, 100, 20)
	T.near(sd.left / sd.meter, frac, 1e-9)
	T.near(sd.meter, 200 * 40 * WeeklyCore.factor(2))
end
function t.weekly_reward_once_then_choice()
	local p = player()
	local r = WeeklyCore.win(p, 3000)
	T.ok(r.first) T.ok(p.looks[r.look])
	T.no(WeeklyCore.win(p, 3000).first)
	local ok, c = WeeklyCore.choose(p, "share")
	T.ok(ok) T.eq(c.everyoneSeconds, 300) T.eq(p.dawn, 1)
	T.no(WeeklyCore.choose(p, "keep"))
	T.ok(WeeklyCore.win(p, 3001).first)
	ok, c = WeeklyCore.choose(p, "keep")
	T.eq(c.selfSeconds, 600) T.eq(p.dusk, 1)
end
function t.tally_and_trim()
	local tally = WeeklyCore.addTally(nil, "dawn")
	tally = WeeklyCore.addTally(tally, "dusk", 3)
	T.eq(WeeklyCore.leader(tally), "dusk") T.eq(WeeklyCore.leader(nil), nil)
	T.eq(WeeklyCore.leader({ dawn = 2, dusk = 2 }), nil)
	local p = player() p.dusk = 2
	T.ok(WeeklyCore.wearsTrim(p, tally))
	p.dawn = 5
	T.no(WeeklyCore.wearsTrim(p, tally))
end
function t.merchant_items_are_fixed_and_bought_once()
	local p = player()
	local sat = 20771 * DAY
	local week = WeeklyCore.week(sat)
	local items = WeeklyCore.merchantItems(p, week)
	T.eq(#items, 3) T.eq(items[2].id, "Zipwing") T.eq(items[2].price, 900)
	local again = WeeklyCore.merchantItems(p, week)
	for i = 1, 3 do T.eq(items[i].id, again[i].id) T.eq(items[i].price, again[i].price) end
	local ok, why = WeeklyCore.merchantBuy(p, 2, sat)
	T.no(ok) T.eq(why, "coins")
	p.coins = 5000
	T.ok(WeeklyCore.merchantBuy(p, 2, sat))
	T.eq(p.coins, 4100) T.eq(p.pets[1].species, "Zipwing") T.eq(Profile.where(p, p.pets[1].id), "spare")
	ok, why = WeeklyCore.merchantBuy(p, 2, sat + 100)
	T.no(ok) T.eq(why, "bought")
	T.ok(WeeklyCore.merchantBuy(p, 1, sat)) T.ok(p.looks[items[1].id])
	ok, why = WeeklyCore.merchantBuy(p, 3, sat + 3 * DAY)
	T.no(ok) T.eq(why, "closed")
	T.ok(WeeklyCore.merchantBuy(p, 2, sat + 7 * DAY)) -- next weekend it is back
end
function t.monument_first_ten_once_each()
	local list
	for u = 1, 12 do list = WeeklyCore.monumentAdd(list, u, "P" .. u, u) end
	T.eq(#list, 10) T.eq(list[1].name, "P1")
	local _, added = WeeklyCore.monumentAdd({ { userId = 5 } }, 5, "again", 9)
	T.no(added)
end
function t.settings_validated()
	local p = player()
	T.ok(Profile.setSetting(p, "music", 0.5)) T.ok(Profile.setSetting(p, "tapAssist", true))
	T.no(Profile.setSetting(p, "music", 7)) T.no(Profile.setSetting(p, "music", "loud"))
	T.no(Profile.setSetting(p, "tapAssist", 1)) T.no(Profile.setSetting(p, "coins", 99))
	T.ok(Profile.assistOn(p))
end
function t.index_board_rows()
	local p = player()
	p.index.Buttercub = true p.index.Zipwing = true
	local v = IndexView.build(p, 5)
	T.eq(v.caught, 3) T.eq(v.total, 28) T.eq(#v.floors, 5) T.eq(#v.floors[1].pets, 5)
	T.eq(v.floors[1].pets[1].odds, 60) T.ok(v.floors[1].pets[1].caught) T.no(v.floors[1].pets[2].caught)
	p.index.Lanternlamb = true
	v = IndexView.build(p, 5)
	T.eq(#v.floors[1].pets, 6) T.eq(v.total, 29) T.eq(v.caught, 4)
	T.eq(#v.floors[2].pets, 5) -- an unfound Secret is not even a silhouette
end
return t
