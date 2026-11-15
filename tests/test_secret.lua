local SecretCore = require(Server.Core.SecretCore)
local S = require(Shared.Config).Economy.Secret
local t = {}
local DAY = 86400
local D0 = 20772 -- 2026-11-15

function t.deterministic()
	for floor = 1, 5 do
		local a, b = SecretCore.chimes(D0, floor), SecretCore.chimes(D0, floor)
		T.eq(#a, #b)
		for i = 1, #a do T.eq(a[i], b[i]) end
	end
	-- fixed values: the same numbers must come out in Roblox Luau (whole-number arithmetic only)
	T.eq(table.concat(SecretCore.chimes(D0, 1), ","), "18960,55740,84900") -- 05:16 15:29 23:35 UTC
end

function t.count_sorted_and_inside_its_window()
	local window = DAY / S.ChimesPerDay
	for day = D0, D0 + 400 do
		for floor = 1, 5 do
			local c = SecretCore.chimes(day, floor)
			T.eq(#c, S.ChimesPerDay)
			for i = 1, #c do
				T.eq(c[i], math.floor(c[i]), "whole second")
				T.eq(c[i] % 60, 0, "whole minute")
				if i > 1 then T.ok(c[i] > c[i - 1], "sorted") end
				-- glow starts inside window i, the pet leaves before the window (and the day) ends
				T.ok(c[i] - S.GlowSeconds >= (i - 1) * window, "glow starts in its window")
				T.ok(c[i] + S.StaySeconds < i * window, "leaves in its window")
			end
			T.ok(c[#c] + S.StaySeconds < DAY, "never crosses midnight")
		end
	end
end

function t.floors_differ()
	for day = D0, D0 + 400 do
		for i = 1, S.ChimesPerDay do
			local seen = {}
			for floor = 1, 100 do
				local at = SecretCore.chimes(day, floor)[i]
				T.no(seen[at], "two floors chime together on day " .. day)
				seen[at] = true
			end
		end
	end
end

function t.days_differ()
	local same = 0
	for day = D0, D0 + 400 do
		local a, b = SecretCore.chimes(day, 1), SecretCore.chimes(day + 1, 1)
		T.ok(table.concat(a, ",") ~= table.concat(b, ","), "day " .. day .. " repeats")
		for i = 1, #a do if a[i] == b[i] then same = same + 1 end end
	end
	T.ok(same < 20, "times should move from day to day")
end

function t.spread_over_the_window()
	-- every part of the day gets chimes: no hour of the 24 is left out over a year
	local hours = {}
	for day = D0, D0 + 365 do
		for _, c in ipairs(SecretCore.chimes(day, 2)) do hours[math.floor(c / 3600)] = true end
	end
	for h = 0, 23 do T.ok(hours[h], "no chime ever in hour " .. h) end
end

function t.phase_changes_on_the_exact_second()
	for floor = 1, 3 do
		for i, c in ipairs(SecretCore.chimes(D0, floor)) do
			local at = D0 * DAY + c
			local glow = at - S.GlowSeconds
			local leaves = at + S.StaySeconds
			T.eq(SecretCore.phase(floor, glow - 1).phase, "idle")
			T.eq(SecretCore.phase(floor, glow - 1).key, nil)
			local p = SecretCore.phase(floor, glow)
			T.eq(p.phase, "glow") T.eq(p.at, at) T.eq(p.leaves, leaves)
			T.eq(SecretCore.phase(floor, at - 1).phase, "glow")
			local q = SecretCore.phase(floor, at)
			T.eq(q.phase, "here") T.eq(q.at, at) T.eq(q.leaves, leaves)
			T.eq(q.leaves - q.at, S.StaySeconds)
			T.eq(SecretCore.phase(floor, leaves - 1).phase, "here")
			T.eq(SecretCore.phase(floor, leaves).phase, "idle")
			-- one key through the whole chime
			T.eq(p.key, q.key)
			T.eq(SecretCore.phase(floor, leaves - 1).key, p.key)
			T.ok(i >= 1)
		end
	end
end

function t.fractional_clock_is_fine()
	local at = D0 * DAY + SecretCore.chimes(D0, 1)[1]
	T.eq(SecretCore.phase(1, at - 0.25).phase, "glow")
	T.eq(SecretCore.phase(1, at + 0.75).phase, "here")
	T.eq(SecretCore.phase(1, at + 0.75).at, at)
end

function t.keys_differ_between_chimes_floors_and_days()
	local seen, n = {}, 0
	for day = D0, D0 + 6 do
		for floor = 1, 5 do
			for _, c in ipairs(SecretCore.chimes(day, floor)) do
				local key = SecretCore.phase(floor, day * DAY + c).key
				T.ok(type(key) == "string")
				T.no(seen[key], "key used twice: " .. key)
				seen[key] = true
				n = n + 1
			end
		end
	end
	T.eq(n, 7 * 5 * S.ChimesPerDay)
end

function t.thirty_days_average_exactly_chimes_per_day()
	-- walk the clock like the service does and count each change of phase
	local step = 20
	T.eq(S.GlowSeconds % step, 0) T.eq(S.StaySeconds % step, 0)
	for floor = 1, 3 do
		local last, glows, visits, ends, keys, hereSeconds = "idle", 0, 0, 0, {}, 0
		for now = D0 * DAY, (D0 + 30) * DAY, step do
			local p = SecretCore.phase(floor, now)
			if p.phase ~= last then
				if p.phase == "glow" then glows = glows + 1 T.eq(last, "idle") end
				if p.phase == "here" then visits = visits + 1 T.eq(last, "glow") T.no(keys[p.key]) keys[p.key] = true end
				if p.phase == "idle" then ends = ends + 1 T.eq(last, "here") end
				last = p.phase
			end
			if p.phase == "here" then hereSeconds = hereSeconds + step end
		end
		T.eq(glows, 30 * S.ChimesPerDay)
		T.eq(visits, 30 * S.ChimesPerDay)
		T.eq(ends, 30 * S.ChimesPerDay)
		T.eq(visits / 30, S.ChimesPerDay)
		T.eq(hereSeconds, 30 * S.ChimesPerDay * S.StaySeconds)
	end
end

return t
