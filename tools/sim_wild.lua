-- tools/sim_wild: checks the Amendment 1 numbers (wild showdowns and Secret pets) from the game's Config.
-- Run:  python3 tools/lua.py tools/sim_wild.lua [runs]
-- Prints (a) the Play meter sizes and the seconds to empty them, (b) what one Secret pet adds,
-- (c) the pacing table before and after the extra try seconds. Tests load it with ARGS = { "lib" }.
local Config = require(Shared.Config)
local F = require(Shared.Logic.Formulas)
local E, P = Config.Economy, Config.Pets
local S = E.Sim

local args = ARGS
ARGS = { "lib" }
local Sim = runfile(ROOT .. "/tools/econ_sim.lua")
ARGS = args

local W = {}
W.Rarities = { "Epic", "Legendary", "Secret" } -- the rarities that need play first
W.Floors = Config.Floors.Count

-- (a) ------------------------------------------------------------------------
function W.meter(floor, rarity)
	return E.GuardianPower[floor] * E.Wild.MeterMult[rarity]
end
-- Seconds for a team with this much Team Power in total (the meter never refills).
function W.seconds(floor, rarity, teamPower, cheer)
	return W.meter(floor, rarity) / (teamPower * (1 + (cheer or 0)))
end
-- A "ready" player: Team Power equal to the floor's Guardian power, no cheers, no natures.
function W.readySeconds(floor, rarity, players, cheer)
	return W.seconds(floor, rarity, E.GuardianPower[floor] * players, cheer)
end
function W.soloSecretInTime(floor, cheer)
	return W.readySeconds(floor, "Secret", 1, cheer) <= E.Secret.StaySeconds
end
-- Team Power of a player who has only just reached the floor: the Guardian power of the floor
-- below (floor 1: a level 1 starter and nothing else).
function W.arrivalPower(floor)
	if floor == 1 then return F.starterPower(1) end
	return E.GuardianPower[floor - 1]
end
-- Players of this Team Power needed to empty a Secret's meter inside its stay.
function W.playersForSecret(floor, power, cheer)
	return math.ceil(W.seconds(floor, "Secret", power, cheer) / E.Secret.StaySeconds - 1e-9)
end

-- (b) ------------------------------------------------------------------------
function W.pet(floor, rarity)
	return { species = P.ByFloor[floor][rarity], rarity = rarity, hearts = 0 }
end
function W.secret(floor)
	local s, l = W.pet(floor, "Secret"), W.pet(floor, "Legendary")
	local out = {
		income = F.wildIncome(s), power = F.wildPower(s),
		legIncome = F.wildIncome(l), legPower = F.wildPower(l),
		guardianShare = F.wildPower(s) / E.GuardianPower[floor],
	}
	local charm = E.CharmPrice[floor + 1]
	if charm then out.charm = charm out.charmSeconds = charm / out.income end
	return out
end

-- (c) ------------------------------------------------------------------------
-- { before = minutes per Guardian with no play time, after = with it, diff = after - before }
function W.pacing(runs, buyPads)
	local before = Sim.table(runs, { buyPads = buyPads, noWild = true }).wins
	local after = Sim.table(runs, { buyPads = buyPads }).wins
	local out = { before = before, after = after, diff = {} }
	for f = 1, W.Floors do
		if before[f] and after[f] then out.diff[f] = after[f] - before[f] end
	end
	return out
end

-- Printing ----------------------------------------------------------------------
local function num(n) -- 1500000 -> 1,500,000
	local s = string.format("%d", math.floor(n + 0.5))
	local k
	repeat s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2") until k == 0
	return s
end
local function secs(x)
	if x >= 600 then return string.format("%.0f min", x / 60) end
	if x == math.floor(x) then return string.format("%d s", x) end
	return string.format("%.1f s", x)
end
local function yesno(v) return v and "yes" or "NO" end

function W.printMeters()
	local cheer = S.CheerBonus
	print("(a) Play meter sizes. Meter = the floor's Guardian power x "
		.. E.Wild.MeterMult.Epic .. " / " .. E.Wild.MeterMult.Legendary .. " / " .. E.Wild.MeterMult.Secret
		.. " (Epic / Legendary / Secret).")
	print("    Ready player = Team Power equal to the floor's Guardian power, no cheers, no natures.")
	print(string.format("    A Secret stays %d s. Good cheering = +%d%%.", E.Secret.StaySeconds, cheer * 100))
	print("Floor | Rarity    |       Meter | 1 ready | 2 ready | 3 ready | cheering: 1 |       2 |       3 | lone ready player in time")
	for floor = 1, W.Floors do
		for _, rarity in ipairs(W.Rarities) do
			local fits = "-"
			if rarity == "Secret" then
				fits = string.format("%s (%s left), cheering %s (%s left)",
					yesno(W.soloSecretInTime(floor)), secs(E.Secret.StaySeconds - W.readySeconds(floor, rarity, 1)),
					yesno(W.soloSecretInTime(floor, cheer)), secs(E.Secret.StaySeconds - W.readySeconds(floor, rarity, 1, cheer)))
			end
			print(string.format("  %d   | %-9s | %11s | %7s | %7s | %7s | %11s | %7s | %7s | %s", floor, rarity,
				num(W.meter(floor, rarity)),
				secs(W.readySeconds(floor, rarity, 1)), secs(W.readySeconds(floor, rarity, 2)), secs(W.readySeconds(floor, rarity, 3)),
				secs(W.readySeconds(floor, rarity, 1, cheer)), secs(W.readySeconds(floor, rarity, 2, cheer)),
				secs(W.readySeconds(floor, rarity, 3, cheer)), fits))
		end
	end
	print("")
	print("    The same meters for a player who has only just reached the floor (Team Power = the Guardian")
	print("    power of the floor below; floor 1 = a level 1 starter alone), solo, no cheers:")
	print("Floor | Team Power |    Epic | Legendary |   Secret | such players needed for a Secret in "
		.. E.Secret.StaySeconds .. " s (cheering)")
	for floor = 1, W.Floors do
		local p = W.arrivalPower(floor)
		print(string.format("  %d   | %10s | %7s | %9s | %8s | %d (%d)", floor, num(p),
			secs(W.seconds(floor, "Epic", p)), secs(W.seconds(floor, "Legendary", p)), secs(W.seconds(floor, "Secret", p)),
			W.playersForSecret(floor, p), W.playersForSecret(floor, p, cheer)))
	end
	local need = E.Wild.MeterMult.Secret / E.Secret.StaySeconds
	print(string.format("    Solo Secret inside %d s needs Team Power of %.1f%% of the floor's Guardian power (%.1f%% with cheering).",
		E.Secret.StaySeconds, need * 100, need / (1 + cheer) * 100))
	print(string.format("    The sim bot beats a Guardian at %.1f%% of its power (it cheers), so a player who can only just",
		100 / (1 + cheer)))
	print(string.format("    beat the Guardian empties a Secret solo in %s without cheers and %s with them.",
		secs(E.Wild.MeterMult.Secret * (1 + cheer)), secs(E.Wild.MeterMult.Secret)))
end

function W.printSecret()
	print(string.format("(b) What one Secret pet adds (income x%g, power x%g, no hearts) next to the floor's Legendary (x%g, x%g).",
		E.RarityIncomeMult.Secret, E.RarityPowerMult.Secret, E.RarityIncomeMult.Legendary, E.RarityPowerMult.Legendary))
	print("Floor | Secret coins/s | Legendary coins/s | Secret power | Legendary power | Secret power / Guardian | next Charm | Secret income pays it in")
	for floor = 1, W.Floors do
		local s = W.secret(floor)
		print(string.format("  %d   | %14s | %17s | %12s | %15s | %22.1f%% | %10s | %s", floor,
			num(s.income), num(s.legIncome), num(s.power), num(s.legPower), s.guardianShare * 100,
			s.charm and num(s.charm) or "-", s.charmSeconds and secs(s.charmSeconds) or "-"))
	end
	print(string.format("    On every floor a Secret earns %gx and adds %.2fx the power of that floor's Legendary.",
		E.RarityIncomeMult.Secret / E.RarityIncomeMult.Legendary, E.RarityPowerMult.Secret / E.RarityPowerMult.Legendary))
end

function W.printPacing(runs)
	local ex = Sim.extraTrySeconds()
	print(string.format("(c) Pacing: mean active minutes to beat each Guardian, %d runs each. Before = no play time;", runs))
	print(string.format("    after = +%g s per Epic try and +%g s per Legendary try. Difference = after - before.",
		ex.Epic or 0, ex.Legendary or 0))
	local on, off = W.pacing(runs, true), W.pacing(runs, false)
	print("Guardian | bible | buyPads: before |  after |   diff | after - bible | no pads: before |  after |   diff | after - bible")
	for f = 1, W.Floors do
		local target = S.TargetWinMinutes[f]
		print(string.format("   %d     | %5d | %15.2f | %6.2f | %+6.2f | %+13.2f | %15.2f | %6.2f | %+6.2f | %+13.2f", f, target,
			on.before[f] or -1, on.after[f] or -1, on.diff[f] or 0, (on.after[f] or -1) - target,
			off.before[f] or -1, off.after[f] or -1, off.diff[f] or 0, (off.after[f] or -1) - target))
	end
	return on, off
end

if not (args and args[1] == "lib") then
	local runs = tonumber(args and args[1]) or 300
	print("sim_wild: Amendment 1 numbers, read from Config")
	print("")
	W.printMeters()
	print("")
	W.printSecret()
	print("")
	W.printPacing(runs)
end
return W
