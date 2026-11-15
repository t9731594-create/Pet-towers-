-- Wild showdowns: Epic, Legendary and Secret pets want to play before they trust you. One Play meter
-- per pet, drained by every team that steps in (ShowdownCore does the meter, cheers and friends).
-- The meter never refills. Empty = everyone who took part may try. Pet leaves first = nothing happens.
-- No Roblox APIs.
local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local E = require(Shared.Config).Economy
local ShowdownCore = require(script.Parent.ShowdownCore)
local W = E.Wild

local WildCore = {}

function WildCore.needsPlay(rarity)
	return W.MeterMult[rarity] ~= nil
end

-- Play meter = the floor's Guardian power x 4 (Epic), x 10 (Legendary), x 150 (Secret).
function WildCore.meter(floor, rarity)
	return E.GuardianPower[floor] * W.MeterMult[rarity]
end

-- pet = { id, floor, rarity, ... } (a SpawnCore pet). nature = the pet's nature (teams that beat it
-- count x1.5; the caller applies that when it computes `power` for join).
-- session.sd is the ShowdownCore session: cheers go to ShowdownCore.cheer(session.sd, ...).
function WildCore.new(pet, nature, now)
	return {
		petId = pet.id, floor = pet.floor, rarity = pet.rarity, nature = nature,
		state = "active", -- "active" | "won" | "left"
		took = {}, -- userId -> true: everyone who ever stepped in (kept when they step out)
		far = {}, -- userId -> the time this player was first seen beyond the leash (nil = close)
		tookCount = 0,
		wonAt = nil,
		sd = ShowdownCore.new({
			kind = "wild", floor = pet.floor, nature = nature, now = now,
			meter = WildCore.meter(pet.floor, pet.rarity), -- no `seconds`: no time limit
		}),
	}
end

local function sync(session, now)
	if session.state == "active" and session.sd.state == "won" then
		session.state = "won"
		session.wonAt = now
	end
	return session.state
end

-- Anyone on the floor may step in at any time while the pet still wants to play.
function WildCore.join(session, userId, power, now)
	if session.state ~= "active" then return false, "over" end
	if type(power) ~= "number" or power ~= power or power < 0 then return false, "bad_power" end
	local ok, why = ShowdownCore.join(session.sd, userId, power, now)
	sync(session, now)
	if not ok then return false, why end
	session.far[userId] = nil
	if not session.took[userId] then
		session.took[userId] = true
		session.tookCount = session.tookCount + 1
	end
	return true
end

function WildCore.tick(session, now)
	if session.state ~= "active" then return session.state end
	ShowdownCore.tick(session.sd, now)
	return sync(session, now)
end

-- One player steps out (walked away, left the floor or the game). Their team stops adding; what was
-- drained stays drained, and they still count as having taken part (they may step in again, and may
-- try if the meter empties later).
function WildCore.stepOut(session, userId, now)
	session.far[userId] = nil
	if session.state ~= "active" then return end
	ShowdownCore.leave(session.sd, userId, now)
	sync(session, now)
end

-- Walk-away leash: a player who stays farther than twice the join distance from the pet for
-- LeashSeconds steps out, so nobody is held in a showdown they have walked away from.
WildCore.LeashSeconds = 1.5
function WildCore.leashDistance() return W.JoinDistance * 2 end

-- The pure decision. farSince = when this player was first seen too far (nil = was close).
-- distance = studs to the pet, or nil when it cannot be measured (no character): that counts as far.
-- Returns the new farSince and whether the player should step out now.
function WildCore.leashed(farSince, distance, now)
	if type(distance) == "number" and distance == distance and distance <= WildCore.leashDistance() then
		return nil, false
	end
	farSince = farSince or now
	return farSince, now - farSince >= WildCore.LeashSeconds
end

-- Call every step for each player in the session. True = step this player out now.
function WildCore.leash(session, userId, distance, now)
	if session.state ~= "active" or not session.sd.players[userId] then
		session.far[userId] = nil
		return false
	end
	local since, out = WildCore.leashed(session.far[userId], distance, now)
	session.far[userId] = since
	return out
end

-- Is this player in the showdown right now (stepped in and not stepped out)?
function WildCore.isIn(session, userId)
	return session.state == "active" and session.sd.players[userId] ~= nil
end

-- The pet left. If the meter was not empty the pet just leaves: state "left", nothing is lost.
function WildCore.leave(session, now)
	if session.state ~= "active" then return session.state end
	session.state = "left"
	session.sd.state = "left" -- ShowdownCore refuses joins and cheers on anything not "active"
	return session.state
end

-- Meter empty AND this player took part.
function WildCore.canTry(session, userId)
	return session.state == "won" and session.took[userId] == true
end

-- After the meter empties the pet stays at least TryGraceSeconds so everyone gets their try.
function WildCore.graceEnds(session)
	return session.wonAt and (session.wonAt + W.TryGraceSeconds) or nil
end
function WildCore.keep(session, now)
	return session.state == "won" and now < session.wonAt + W.TryGraceSeconds
end

-- Everyone who took part, sorted (includes players who stepped out).
function WildCore.participants(session)
	local out = {}
	for userId in pairs(session.took) do out[#out + 1] = userId end
	table.sort(out)
	return out
end

return WildCore
