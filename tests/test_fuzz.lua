-- Hardening: thousands of random actions against one profile, checking after every step that nothing
-- is lost or duplicated and coins never go negative. Then a save / load round trip.
local Profile = require(Server.Core.Profile)
local ReturnCore = require(Server.Core.ReturnCore)
local WeeklyCore = require(Server.Core.WeeklyCore)
local ShopCore = require(Server.Core.ShopCore)
local DataCore = require(Server.Core.DataCore)
local Config = require(Shared.Config)
local t = {}

local function check(p, step)
	local where = "step " .. step
	T.ok(p.coins >= 0 and p.coins == math.floor(p.coins), where .. ": coins " .. tostring(p.coins))
	local seen = {}
	local function mark(id, place)
		T.ok(Profile.pet(p, id), where .. ": " .. place .. " holds a missing pet " .. tostring(id))
		T.no(seen[id], where .. ": pet " .. tostring(id) .. " is in two places (" .. tostring(seen[id]) .. ", " .. place .. ")")
		seen[id] = place
	end
	for _, id in ipairs(p.stack) do mark(id, "stack") end
	for _, id in ipairs(p.spare) do mark(id, "spare") end
	for _, pad in ipairs(p.pads) do if pad.pet ~= 0 then mark(pad.pet, "pad") end end
	for _, pet in ipairs(p.pets) do T.ok(seen[pet.id], where .. ": pet " .. pet.id .. " is nowhere") end
	T.ok(#p.stack <= Profile.stackCap(p), where .. ": stack over cap")
	T.ok(#p.team <= 2, where .. ": team too big")
	for _, id in ipairs(p.team) do T.ok(seen[id] == "pad" or seen[id] == "spare", where .. ": team pet not at camp") end
	local ids = {}
	for _, pet in ipairs(p.pets) do T.no(ids[pet.id], where .. ": duplicate pet id") ids[pet.id] = true T.ok(pet.hearts >= 0 and pet.hearts <= 5) end
end

local function run(seed, steps)
	local s = seed
	local function rand() s = (s * 16807) % 2147483647 return s / 2147483647 end
	local function pick(n) return math.floor(rand() * n) + 1 end
	local now = 20771 * 86400
	local p = Profile.new(now)
	Profile.chooseStarter(p, Config.Pets.StarterOrder[pick(3)])
	ReturnCore.onJoin(p, now)
	local rar = Config.Economy.Rarities
	for step = 1, steps do
		now = now + pick(120)
		local op = pick(20)
		local anyPet = #p.pets > 0 and p.pets[pick(#p.pets)].id or 999
		if op <= 4 then
			local floor, rarity = pick(Profile.unlockedFloor(p)), rar[pick(5)]
			Profile.addCaught(p, Config.Pets.ByFloor[floor][rarity], rarity, rand() < 0.01)
		elseif op == 5 then Profile.deposit(p, now) Profile.autoTeam(p)
		elseif op == 6 then Profile.collect(p, now, 1 + rand())
		elseif op == 7 then Profile.feed(p)
		elseif op == 8 then Profile.addHeart(p, anyPet)
		elseif op == 9 then Profile.release(p, anyPet, now, 1)
		elseif op == 10 then Profile.place(p, anyPet, pick(#p.pads + 1), now, 1)
		elseif op == 11 then Profile.setTeam(p, anyPet, #p.pets > 0 and p.pets[pick(#p.pets)].id or nil)
		elseif op == 12 then Profile.buyPads(p, now) Profile.buyStack(p) Profile.buyCharm(p)
		elseif op == 13 then if rand() < 0.2 then Profile.clearFloor(p, p.cleared + 1 <= 5 and p.cleared + 1 or 5) end
		elseif op == 14 then local f = Profile.pendingChoice(p) if f then Profile.choose(p, f, rand() < 0.5 and "share" or "keep") end
		elseif op == 15 then Profile.grantIncome(p, 300, "share")
		elseif op == 16 then now = now + pick(40) * 3600 ReturnCore.onJoin(p, now)
		elseif op == 17 then ReturnCore.hatchEgg(p, now, rand)
		elseif op == 18 then WeeklyCore.merchantBuy(p, pick(3), now)
		elseif op == 19 then ShopCore.processReceipt(p, "r" .. pick(30), 1, { [1] = { kind = "coins", seconds = 1800 } }, now)
		else WeeklyCore.win(p, WeeklyCore.week(now)) WeeklyCore.choose(p, rand() < 0.5 and "share" or "keep") end
		check(p, step)
	end
	return p, now
end

function t.random_play_keeps_every_pet_and_coin_consistent()
	for seed = 1, 6 do run(seed * 104729, 1500) end
end
function t.save_and_load_round_trip_after_random_play()
	local p, now = run(777, 1500)
	local rows = {}
	local function deep(v) if type(v) ~= "table" then return v end local c = {} for k, x in pairs(v) do c[k] = deep(x) end return c end
	local store = { update = function(_, key, fn) local new = fn(deep(rows[key])) if new ~= nil then rows[key] = deep(new) end end }
	local a = DataCore.new(store, "A", function() return now end)
	a:load("u")
	a.held.u = true
	T.ok(a:save("u", p, true))
	local q = DataCore.new(store, "B", function() return now + 5 end):load("u")
	T.eq(q.coins, p.coins) T.eq(#q.pets, #p.pets) T.eq(#q.pads, #p.pads) T.eq(q.cleared, p.cleared)
	T.eq(q.starter.level, p.starter.level) T.eq(q.dawn, p.dawn) T.eq(q.dusk, p.dusk) T.eq(q.journeyDay, p.journeyDay)
	check(q, "after load")
end
return t
