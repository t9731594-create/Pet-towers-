-- Secret pets: when does a floor's lantern chime? Every server works the same times out from the UTC
-- clock alone, so nothing is shared between servers. No Roblox APIs, no math.random, no bit library:
-- only whole-number arithmetic that stays far below 2^53, so Lua 5.1 and Luau agree exactly.
local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local S = Config.Economy.Secret

local SecretCore = {}

local DAY = 86400
local M = 2147483647 -- 2^31 - 1; every product below is under 2^47

-- A whole number 0 .. M-1 from three small whole numbers.
local function hash(a, b, c)
	local x = a % M
	x = (x * 16807 + b * 1013 + c * 7919 + 12345) % M
	x = (x * 48271 + 11) % M
	x = (x * 16807 + 7) % M
	x = (x * 48271 + 3) % M
	return x
end

local function gcd(a, b)
	while b ~= 0 do a, b = b, a % b end
	return a
end

-- The day is cut into ChimesPerDay equal windows. Inside a window the pet may appear on a whole minute,
-- late enough for the glow to start inside the window and early enough to leave before it ends.
local function layout()
	local window = math.floor(DAY / S.ChimesPerDay)
	local lead = math.ceil(S.GlowSeconds / 60) * 60
	local slots = math.floor((window - lead - S.StaySeconds) / 60)
	if slots < 1 then slots = 1 end
	return window, lead, slots
end

-- Seconds of the day (UTC) at which the floor's Secret pet appears: sorted, ChimesPerDay long.
-- Floors share a start minute and a stride per window; the stride has no common factor with the number
-- of minute slots, so two floors fewer than `slots` apart never chime in the same minute.
function SecretCore.chimes(dayNumber, floor)
	local window, lead, slots = layout()
	local out = {}
	for i = 1, S.ChimesPerDay do
		local base = hash(dayNumber, i, 1) % slots
		local stride = 0
		if slots > 1 then
			stride = 1 + hash(dayNumber, i, 2) % (slots - 1)
			while gcd(stride, slots) ~= 1 do
				stride = stride + 1
				if stride >= slots then stride = 1 end
			end
		end
		local slot = (base + (floor - 1) * stride) % slots
		out[i] = (i - 1) * window + lead + slot * 60
	end
	return out
end

-- One day's chimes per floor are remembered: the service asks once a second.
local cache = {}
local function chimesOf(dayNumber, floor)
	local c = cache[floor]
	if not c or c.day ~= dayNumber then
		c = { day = dayNumber, list = SecretCore.chimes(dayNumber, floor) }
		cache[floor] = c
	end
	return c.list
end

-- What the floor's lantern is doing at this UTC second.
--   "glow": the glow is building; the pet appears at `at`.
--   "here": the pet is on the floor until `leaves`.
--   "idle": nothing; at, leaves and key are nil (nobody is told when the next chime is).
-- key names one chime (floor, day, which chime of the day) and is the same through its glow and visit.
function SecretCore.phase(floor, utcSeconds)
	local now = math.floor(utcSeconds)
	local day = math.floor(now / DAY)
	local list = chimesOf(day, floor)
	for i = 1, #list do
		local at = day * DAY + list[i]
		local leaves = at + S.StaySeconds
		if now >= at - S.GlowSeconds and now < leaves then
			return {
				phase = now < at and "glow" or "here",
				at = at, leaves = leaves,
				key = floor .. ":" .. day .. ":" .. i,
			}
		end
	end
	return { phase = "idle" }
end

return SecretCore
