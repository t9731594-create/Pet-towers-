-- The week: Weekly Guardian, weekend merchant, Dawn-vs-Dusk tally, monument of first clears.
-- Everything is derived from the UTC clock so every server agrees. No Roblox APIs.
local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Profile = require(script.Parent.Profile)
local ShowdownCore = require(script.Parent.ShowdownCore)
local E, P = Config.Economy, Config.Pets
local W = E.Weekly

local WeeklyCore = {}
local WEEK, DAY = 604800, 86400
local SATURDAY = 2 * DAY -- 1 Jan 1970 was a Thursday

function WeeklyCore.week(now) return math.floor((now - SATURDAY) / WEEK) end
function WeeklyCore.weekday(now) return (math.floor(now / DAY) + 4) % 7 end -- 0 = Sunday

-- Weekly Guardian -------------------------------------------------------------
function WeeklyCore.guardian(week)
	local list = P.WeeklyGuardians
	return list[week % #list + 1]
end
function WeeklyCore.factor(count)
	if count <= 1 then return W.SoloFactor end
	local t = math.min(count - 1, W.FullRing - 1) / (W.FullRing - 1)
	return W.SoloFactor + (W.FullFactor - W.SoloFactor) * t
end
-- A showdown whose meter follows the ring: call WeeklyCore.join for each player.
function WeeklyCore.newShowdown(now)
	local sd = ShowdownCore.new({ kind = "weekly", floor = 0, meter = 1, now = now, seconds = E.Showdown.Seconds })
	sd.powerSum = 0
	return sd
end
-- Joining rescales the meter to the new ring and keeps the fraction already drained.
function WeeklyCore.join(sd, userId, power, now)
	ShowdownCore.tick(sd, now)
	local fraction = sd.count > 0 and (sd.left / sd.meter) or 1
	local ok, why = ShowdownCore.join(sd, userId, power, now)
	if not ok then return false, why end
	sd.powerSum = sd.powerSum + power
	sd.meter = math.max(1, sd.powerSum * E.Showdown.Seconds * WeeklyCore.factor(sd.count))
	sd.left = sd.meter * fraction
	return true
end
-- A win: one cosmetic reward a week, and a Share-or-Keep choice. Returns { first, look }.
function WeeklyCore.win(p, week)
	if p.weekly.wonWeek == week then return { first = false } end
	p.weekly.wonWeek = week
	p.weekly.pendingChoice = week
	local look = "weekly_" .. tostring(week % 52)
	p.looks[look] = true
	return { first = true, look = look }
end
function WeeklyCore.choose(p, choice)
	if not p.weekly.pendingChoice then return false, "no_choice" end
	if choice ~= "share" and choice ~= "keep" then return false, "bad_choice" end
	p.weekly.pendingChoice = nil
	if choice == "share" then
		p.dawn = p.dawn + 1
		return true, { selfSeconds = 0, everyoneSeconds = E.Choice.ShareSeconds, side = "dawn" }
	end
	p.dusk = p.dusk + 1
	return true, { selfSeconds = E.Choice.KeepSeconds, everyoneSeconds = 0, side = "dusk" }
end

-- Dawn vs Dusk ----------------------------------------------------------------
-- tally = { dawn = n, dusk = n } for one week (kept in a shared store by the service).
function WeeklyCore.addTally(tally, side, n)
	tally = tally or { dawn = 0, dusk = 0 }
	tally[side] = (tally[side] or 0) + (n or 1)
	return tally
end
function WeeklyCore.leader(tally)
	if not tally then return nil end
	if (tally.dawn or 0) > (tally.dusk or 0) then return "dawn" end
	if (tally.dusk or 0) > (tally.dawn or 0) then return "dusk" end
	return nil
end
-- The side that led LAST week wears a special trim this week.
function WeeklyCore.wearsTrim(p, lastWeekTally)
	local lead = WeeklyCore.leader(lastWeekTally)
	return lead ~= nil and Profile.side(p) == lead
end

-- Weekend merchant ---------------------------------------------------------------
function WeeklyCore.merchantOpen(now)
	local d = WeeklyCore.weekday(now)
	for _, open in ipairs(W.MerchantDays) do if d == open then return true end end
	return false
end
-- Three clearly shown items for coins: a look, a named Rare pet, a camp decoration. Fixed for the
-- week, the same for everyone except that the pet and prices follow the player's highest floor.
-- Nothing here is random to the buyer: what you see is what you get.
function WeeklyCore.merchantItems(p, week)
	local floor = Profile.unlockedFloor(p)
	local unit = E.CommonIncome[floor]
	return {
		{ slot = 1, kind = "look", id = W.MerchantLooks[week % #W.MerchantLooks + 1], price = W.MerchantLookSeconds * unit },
		{ slot = 2, kind = "pet", id = P.ByFloor[floor].Rare, rarity = "Rare", price = W.MerchantPetSeconds * unit },
		{ slot = 3, kind = "decor", id = W.MerchantDecor[week % #W.MerchantDecor + 1], price = W.MerchantDecorSeconds * unit },
	}
end
-- One of each per week. The pet waits at camp as a spare.
function WeeklyCore.merchantBuy(p, slot, now)
	if not WeeklyCore.merchantOpen(now) then return false, "closed" end
	local week = WeeklyCore.week(now)
	local item = WeeklyCore.merchantItems(p, week)[slot]
	if not item then return false, "bad_slot" end
	if p.weekly.merchantWeek ~= week then p.weekly.merchantWeek = week p.weekly.bought = {} end
	p.weekly.bought = p.weekly.bought or {}
	local key = tostring(slot)
	if p.weekly.bought[key] then return false, "bought" end
	if item.kind ~= "pet" and p.looks[item.id] then return false, "owned" end
	local ok, why = Profile.spend(p, item.price, "merchant")
	if not ok then return false, why end
	p.weekly.bought[key] = true
	if item.kind == "pet" then
		local pet = { id = p.nextPetId, species = item.id, rarity = "Rare", hearts = 0, radiant = false }
		p.nextPetId = p.nextPetId + 1
		p.pets[#p.pets + 1] = pet
		p.spare[#p.spare + 1] = pet.id
		p.index[pet.species] = true
	else
		p.looks[item.id] = true
	end
	return true, item
end

-- Monument of first clears ---------------------------------------------------------
-- list = array of { userId, name, t } for one floor, oldest first, at most MonumentNames long.
function WeeklyCore.monumentAdd(list, userId, name, now)
	list = list or {}
	for _, e in ipairs(list) do if e.userId == userId then return list, false end end
	if #list >= W.MonumentNames then return list, false end
	list[#list + 1] = { userId = userId, name = name, t = now }
	return list, true
end

return WeeklyCore
