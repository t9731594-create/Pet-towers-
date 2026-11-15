-- One meter that teams drain together. Used for Guardian showdowns; built generic (meter, end time,
-- nature) so other "play together" moments can reuse it. Play, not fighting: nothing is hit or hurt.
-- No Roblox APIs.
local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local E = require(Shared.Config).Economy
local S = E.Showdown

local ShowdownCore = {}

-- opts: kind ("guardian"), floor, meter, nature, now, seconds (nil = no time limit, caller ends it)
function ShowdownCore.new(opts)
	return {
		kind = opts.kind, floor = opts.floor, nature = opts.nature,
		meter = opts.meter, left = opts.meter,
		start = opts.now, ends = opts.seconds and (opts.now + opts.seconds) or nil,
		last = opts.now, state = "active",
		players = {}, -- userId -> { power, boost, boostUntil, friend, cheers = { [beat] = true }, joined }
		count = 0,
	}
end

function ShowdownCore.guardian(floor, nature, now)
	return ShowdownCore.new({
		kind = "guardian", floor = floor, nature = nature, now = now,
		meter = E.GuardianPower[floor] * S.MeterMult, seconds = S.Seconds,
	})
end

-- power = the player's Team Power against this nature (server computed).
function ShowdownCore.join(sd, userId, power, now)
	if sd.state ~= "active" then return false, "over" end
	if sd.players[userId] then return false, "already" end
	ShowdownCore.tick(sd, now)
	if sd.state ~= "active" then return false, "over" end
	sd.players[userId] = { power = power, boost = 0, boostUntil = 0, friend = false, cheers = {}, joined = now }
	sd.count = sd.count + 1
	return true
end

-- Mark who has a Roblox friend in the ring (doubles their cheer bonus). isFriend(a, b) is injected.
function ShowdownCore.refreshFriends(sd, isFriend)
	for a, pa in pairs(sd.players) do
		pa.friend = false
		for b in pairs(sd.players) do
			if a ~= b and isFriend(a, b) then pa.friend = true break end
		end
	end
end

local function rate(sd, now)
	local r = 0
	for _, pl in pairs(sd.players) do
		local boost = now < pl.boostUntil and pl.boost or 0
		r = r + pl.power * (1 + boost)
	end
	return r
end

-- Advance to `now`. Boost expiry inside the step is handled by cutting the step at each expiry.
function ShowdownCore.tick(sd, now)
	if sd.state ~= "active" then return sd.state end
	local stop = sd.ends and math.min(now, sd.ends) or now
	local t = sd.last
	while t < stop and sd.left > 0 do
		local nextCut = stop
		for _, pl in pairs(sd.players) do
			if pl.boostUntil > t and pl.boostUntil < nextCut then nextCut = pl.boostUntil end
		end
		sd.left = sd.left - rate(sd, t) * (nextCut - t)
		t = nextCut
	end
	sd.last = stop
	if sd.left <= 0 then
		sd.left = 0
		sd.state = "won"
	elseif sd.ends and now >= sd.ends then
		sd.state = "lost"
	end
	return sd.state
end

-- A cheer tap. Cheer rings land every BeatSeconds from the start. `offset` is the client's time since
-- start; it must agree with the arrival time, and each player gets one cheer per beat.
function ShowdownCore.cheer(sd, userId, offset, now)
	local pl = sd.players[userId]
	if not pl then return false, "not_in" end
	if type(offset) ~= "number" or offset ~= offset then return false, "bad_args" end
	ShowdownCore.tick(sd, now)
	if sd.state ~= "active" then return false, "over" end
	local arrived = now - sd.start
	if arrived < offset - E.Tap.EarlyGrace or arrived > offset + E.Tap.LatencyGrace then return false, "clock" end
	local beat = math.floor(offset / S.BeatSeconds + 0.5)
	if beat < 1 then return false, "early" end
	if pl.cheers[beat] then return false, "already" end
	pl.cheers[beat] = true
	local delta = math.abs(offset - beat * S.BeatSeconds)
	local grade, bonus = "Miss", 0
	if delta <= E.Tap.PerfectWindow then grade, bonus = "Perfect", S.CheerPerfect
	elseif delta <= E.Tap.GoodWindow then grade, bonus = "Good", S.CheerGood end
	if bonus > 0 then
		if pl.friend then bonus = bonus * S.FriendCheerMult end
		pl.boost = bonus
		pl.boostUntil = now + S.CheerSeconds
	end
	return true, grade
end

function ShowdownCore.leave(sd, userId, now)
	if not sd.players[userId] then return end
	ShowdownCore.tick(sd, now)
	if sd.state == "active" then
		sd.players[userId] = nil
		sd.count = sd.count - 1
	end
end

-- Everyone who took part (they all get the full reward).
function ShowdownCore.participants(sd)
	local out = {}
	for userId in pairs(sd.players) do out[#out + 1] = userId end
	table.sort(out)
	return out
end

function ShowdownCore.fraction(sd) return sd.left / sd.meter end

return ShowdownCore
