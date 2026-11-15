-- Reasons to come back: welcome-back chest, rested bonus, journey ladder, Mystery Egg, and the one
-- coin multiplier everything uses. Warm, never urgent: a missed day costs nothing. No Roblox APIs.
local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Profile = require(script.Parent.Profile)
local SpawnCore = require(script.Parent.SpawnCore)
local E, P = Config.Economy, Config.Pets
local R = E.Return

local ReturnCore = {}

function ReturnCore.day(now) return math.floor(now / 86400) end -- UTC day number

-- Ladder gift for a journey day: { minutes, look } (look only on milestone days).
function ReturnCore.ladderGift(day)
	local minutes = R.LadderMinutes[day] or R.LadderMinutes[#R.LadderMinutes - 1]
	if day > #R.LadderMinutes and day % 7 == 0 then minutes = R.LadderMinutes[#R.LadderMinutes] end
	return { minutes = minutes, look = R.LadderLooks[day] }
end

-- Coin multiplier for pad income and gifts. ctx = { friend = bool }.
function ReturnCore.coinMult(p, now, ctx)
	local m = 1
	if ctx and ctx.friend then m = m * (1 + E.FriendCoinBonus) end
	if now < (p.restedUntil or 0) then m = m * R.RestedMult end
	m = m * (1 + E.IndexSetBonus * Profile.indexSets(p))
	if p.passes and p.passes.DoubleCoins then m = m * E.Passes.DoubleCoinsMult end
	return m
end

-- Call once when a profile loads. Returns a summary for the welcome-back moment.
function ReturnCore.onJoin(p, now)
	local out = { away = 0, chest = 0, rested = false, newDay = false, journeyDay = p.journeyDay }
	local today = ReturnCore.day(now)
	if p.starter then
		out.away = math.max(0, now - (p.lastSeen or now))
		if out.away >= R.ChestMinAwaySeconds then
			local cap = (p.upgrades.nightLantern and R.ChestHoursLantern or R.ChestHours) * 3600
			local coins = Profile.incomePerSecond(p) * R.ChestRate * math.min(out.away, cap)
			out.chest = Profile.addCoins(p, coins, "chest")
		end
		if out.away >= R.RestedAfterHours * 3600 then
			p.restedUntil = now + R.RestedMinutes * 60
			out.rested = true
		end
	end
	if p.lastPlayDay ~= today then
		if p.lastPlayDay ~= 0 then p.journeyDay = p.journeyDay + 1 end
		p.lastPlayDay = today
		out.newDay = true
		out.journeyDay = p.journeyDay
		local gift = ReturnCore.ladderGift(p.journeyDay)
		if p.starter then
			local rate = math.max(Profile.incomePerSecond(p), 0)
			local coins = math.max(rate * gift.minutes * 60, R.LadderMinCoins * p.journeyDay)
			out.ladderCoins = Profile.addCoins(p, coins, "ladder")
		end
		if gift.look then p.looks[gift.look] = true out.look = gift.look end
		if p.journeyDay >= 2 then Profile.funnel(p, "Day2Return", now) end
	end
	out.tomorrow = ReturnCore.ladderGift(p.journeyDay + 1)
	ReturnCore.startEgg(p, now)
	out.egg = ReturnCore.eggState(p, now)
	p.lastSeen = now
	return out
end

-- Mystery Egg: one free egg a day, hatches after 8 real hours, never buyable or skippable.
function ReturnCore.startEgg(p, now)
	if not p.starter or p.egg then return false end
	if p.eggDay == ReturnCore.day(now) then return false end
	p.egg = { start = now }
	p.eggDay = ReturnCore.day(now)
	return true
end
function ReturnCore.eggState(p, now)
	if not p.egg then return { state = "none" } end
	local ready = p.egg.start + R.EggHatchHours * 3600
	return { state = now >= ready and "ready" or "warming", readyAt = ready }
end
-- Hatch: a pet from the player's highest floor at the same odds as wild spawns (shown in the index).
-- The pet waits at camp as a spare. rand is injected (0..1).
function ReturnCore.hatchEgg(p, now, rand)
	if ReturnCore.eggState(p, now).state ~= "ready" then return false, "not_ready" end
	local floor = Profile.unlockedFloor(p)
	local rarity = SpawnCore.rollRarity(rand)
	local radiant = rand() < E.RadiantChance
	local pet = { id = p.nextPetId, species = P.ByFloor[floor][rarity], rarity = rarity, hearts = 0, radiant = radiant }
	p.nextPetId = p.nextPetId + 1
	p.pets[#p.pets + 1] = pet
	p.spare[#p.spare + 1] = pet.id
	p.index[pet.species] = true
	p.egg = false
	ReturnCore.startEgg(p, now) -- a new day's egg starts at once if the day has changed
	return true, pet
end

return ReturnCore
