-- Trust Tap rules. The server issues a ring timeline, the client sends one tap offset per ring as it
-- happens, and the server grades it. Skill decides, never dice. No Roblox APIs.
local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local E = require(Shared.Config).Economy
local T = E.Tap

local TapCore = {}

-- Ring speed for one try. opts: rarity, floor, charm, assist (bool), friendly (bool: after a wild
-- showdown the pet likes you, rings 20% slower), ringTime (override, e.g. Secret pets).
function TapCore.ringTime(opts)
	local t = opts.ringTime or T.RingTime[opts.rarity]
	local deficit = math.max(0, (opts.floor or 1) - (opts.charm or 1))
	t = t * (1 - T.CharmSpeedPerTier) ^ deficit
	if opts.assist then t = t * (1 + T.AssistSlow) end
	if opts.friendly then t = t * (1 + T.AssistSlow) end
	return t
end

-- A timeline: beat i lands (ring meets the heart) at beats[i] seconds after `start`.
function TapCore.issue(opts, now)
	local rt = TapCore.ringTime(opts)
	local beats = {}
	for i = 1, T.Beats do beats[i] = i * rt + (i - 1) * T.GapSeconds end
	return {
		rarity = opts.rarity, need = opts.need or T.Need[opts.rarity], ringTime = rt, beats = beats,
		start = now, grades = {}, cannotFail = opts.cannotFail or false,
	}
end

function TapCore.grade(delta)
	delta = math.abs(delta)
	if delta <= T.PerfectWindow then return "Perfect" end
	if delta <= T.GoodWindow then return "Good" end
	return "Miss"
end

-- One tap. `offset` is the client's time since the timeline started; `now` is server time on arrival.
-- A claimed offset must agree with when the tap actually arrived, so a client cannot send a perfect
-- number early or late. Returns ok, grade-or-reason.
function TapCore.tap(tl, beat, offset, now)
	if type(beat) ~= "number" or type(offset) ~= "number" or offset ~= offset then return false, "bad_args" end
	if beat ~= math.floor(beat) or not tl.beats[beat] then return false, "bad_beat" end
	if tl.grades[beat] then return false, "already" end
	if beat > 1 and not tl.grades[beat - 1] then tl.grades[beat - 1] = "Miss" end
	local arrived = now - tl.start
	if arrived < offset - T.EarlyGrace or arrived > offset + T.LatencyGrace then
		tl.grades[beat] = "Miss"
		return true, "Miss", "clock"
	end
	local g = TapCore.grade(offset - tl.beats[beat])
	tl.grades[beat] = g
	return true, g
end

function TapCore.duration(tl) return tl.beats[#tl.beats] + T.GoodWindow + T.LatencyGrace end
function TapCore.expired(tl, now) return now - tl.start > TapCore.duration(tl) end
function TapCore.complete(tl) return tl.grades[#tl.beats] ~= nil end

-- Final result. Missing beats count as Miss.
function TapCore.result(tl)
	local hits, perfects = 0, 0
	for i = 1, #tl.beats do
		local g = tl.grades[i] or "Miss"
		tl.grades[i] = g
		if g ~= "Miss" then hits = hits + 1 end
		if g == "Perfect" then perfects = perfects + 1 end
	end
	local ok = tl.cannotFail or (hits >= tl.need.hits and perfects >= tl.need.perfects)
	return {
		success = ok, hits = hits, perfects = perfects, grades = tl.grades,
		lastBeatMiss = (not ok) and tl.grades[#tl.beats] == "Miss", -- the slow-motion bolt
		perfectAll = perfects == #tl.beats,
	}
end

return TapCore
