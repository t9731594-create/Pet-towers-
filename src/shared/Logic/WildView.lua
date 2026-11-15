-- Pure view rules for wild showdowns (Amendment 1). No Roblox APIs. Used by the client controllers.
local E = require(script.Parent.Parent.Config).Economy
local V = {}

V.JoinMargin = 3 -- studs inside the server's JoinDistance, so latency never fails its distance check
V.ForgetMargin = 10 -- studs beyond JoinDistance before a pet may be asked again
V.WildScale = 0.6 -- a small ring: 60% of a Guardian ring
V.PromptSeconds = 6 -- the join prompt hides by itself after this long
V.CaptureSeconds = 8 -- the capture button hides by itself after this long
V.BeatWindow = 30 -- cheer rings drawn at a time when a showdown has no end time
V.RetrySeconds = 3 -- a join that brought no ring may be asked again after this long
V.PillarBannerSeconds = 5 -- a pillar banner this recent means the Secret banner would be a second one
V.ChimeForgetSeconds = 120 -- a remembered chime is dropped this long after its leave time if no "gone" came

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

-- A pet we asked may be asked again once the player has walked well away and its ring is not on screen,
-- or when the ask brought no ring after RetrySeconds (askedAge = seconds since we asked; nil = unknown).
function V.shouldForget(distance, showing, askedAge)
	if showing then return false end
	if type(distance) ~= "number" or distance > E.Wild.JoinDistance + V.ForgetMargin then return true end
	return type(askedAge) == "number" and askedAge > V.RetrySeconds
end

-- What a wild ShowdownState means for this client. The server sends it to the whole floor.
--   mine  = snap.mine: the server says this player is in the showdown now
--   asked = this client asked to join this pet and has not stepped out since
--   done  = this pet's showdown is over (meter empty or the pet left)
-- "ring" = draw the ring (and block Trust Tap); "icon" = not in it, the join icon may show; "none" = ignore.
function V.snapshotRole(mine, asked, done)
	if done then return "none" end
	if mine == true then
		if asked then return "ring" end
		return "none" -- a late copy from before we stepped out: never re-open the ring
	end
	return "icon"
end

-- What a wild ShowdownEnd means: "stepped_out" (this player walked away: the pet is still there and may
-- be joined again), "won" (meter empty: try now) or "pet_left" (the pet left; nothing is lost).
function V.endMeans(result)
	if type(result) ~= "table" then return "pet_left" end
	if result.left == true then return "stepped_out" end
	if result.won then return "won" end
	return "pet_left"
end

-- Secret banner: the pet's pillar of light already brings a banner to everyone who was in the game when
-- it appeared. Show the Secret banner only when no such banner came (a player who arrived mid-visit).
-- pillarAge = seconds since a "pillar" banner for this floor with rarity "Secret" (nil = none seen).
function V.secretBanner(pillarAge)
	return not (type(pillarAge) == "number" and pillarAge >= 0 and pillarAge <= V.PillarBannerSeconds)
end

-- Where the lantern glow stands for a remembered chime. Returns progress (0..1) and the seconds left to
-- reach full, or nil when there is nothing to draw (unknown phase, or the chime is long over).
function V.glowAt(phase, at, leaves, now, glowSeconds)
	if type(leaves) == "number" and now > leaves + V.ChimeForgetSeconds then return nil end
	if phase == "here" then return 1, 0 end
	if phase ~= "glow" or type(at) ~= "number" then return nil end
	local left = math.min(math.max(at - now, 0), glowSeconds)
	return 1 - left / glowSeconds, left
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
