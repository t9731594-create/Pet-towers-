-- Pure view rules for wild showdowns (Amendment 1). No Roblox APIs. Used by the client controllers.
local E = require(script.Parent.Parent.Config).Economy
local V = {}

V.JoinMargin = 3 -- studs inside the server's JoinDistance, so latency never fails its distance check
V.ForgetMargin = 10 -- studs beyond JoinDistance before a pet may be asked again
V.WildScale = 0.6 -- a small ring: 60% of a Guardian ring
V.PromptSeconds = 6 -- the join prompt hides by itself after this long
V.CaptureSeconds = 8 -- the capture button hides by itself after this long
V.BeatWindow = 30 -- cheer rings drawn at a time when a showdown has no end time

function V.joinReach() return E.Wild.JoinDistance - V.JoinMargin end

-- Step in? Only a pet that still needs play, close enough, not already asked, not in a Trust Tap try.
function V.shouldJoin(distance, needsPlay, alreadyIn, inTry)
	if needsPlay ~= true or alreadyIn or inTry then return false end
	if type(distance) ~= "number" or distance ~= distance then return false end
	return distance <= V.joinReach()
end

-- candidates = { { id, distance, needsPlay }, ... }; asked = { [id] = true }. Returns the nearest pet to join, or nil.
function V.pickJoin(candidates, asked, inTry)
	local best, bestD
	for _, c in ipairs(candidates) do
		if c.id ~= nil and V.shouldJoin(c.distance, c.needsPlay, asked[c.id], inTry) then
			if not bestD or c.distance < bestD then best, bestD = c.id, c.distance end
		end
	end
	return best
end

-- A pet we asked may be asked again once the player has walked well away and its ring is not on screen.
function V.shouldForget(distance, showing)
	if showing then return false end
	return type(distance) ~= "number" or distance > E.Wild.JoinDistance + V.ForgetMargin
end

function V.ringScale(kind)
	if kind == "wild" then return V.WildScale end
	return 1
end

-- The join prompt: same floor, a showdown the player is not in, shown once per pet.
function V.shouldPrompt(showdownFloor, myFloor, asked, prompted, inTry)
	if asked or prompted or inTry then return false end
	return showdownFloor ~= nil and showdownFloor == myFloor
end

-- Degrees to turn a ">" so it points at a spot given in camera space (x = right, z = back).
function V.arrowAngle(x, z)
	if x == 0 and z == 0 then return -90 end
	return math.deg(math.atan2(z, x))
end

-- Which beats to draw now when a showdown has no end time: `count` beats from the current one.
function V.beatWindow(elapsed, beatSeconds, count)
	local first = math.max(1, math.floor(math.max(elapsed, 0) / beatSeconds))
	return first, first + (count or V.BeatWindow) - 1
end

-- Draw the next window when fewer than 3 seconds of rings are left.
function V.needsRefill(elapsed, lastBeat, beatSeconds)
	return elapsed > lastBeat * beatSeconds - 3
end

-- policy = what PolicyService reports for this player (or nil when the call failed).
-- Captures are offered only when the platform plainly says sharing is allowed; anything else means no.
function V.captureAllowed(policy)
	if type(policy) ~= "table" then return false end
	if policy.IsSubjectToChinaPolicies then return false end
	return policy.IsContentSharingAllowed == true
end

return V
