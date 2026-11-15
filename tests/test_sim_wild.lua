ARGS = { "lib" }
local W = runfile(ROOT .. "/tools/sim_wild.lua")
local E = require(Shared.Config).Economy
local t = {}
function t.loading_as_lib_keeps_args()
	T.eq(ARGS[1], "lib")
	T.eq(#ARGS, 1)
end
function t.meter_is_guardian_power_times_mult()
	T.eq(W.meter(1, "Epic"), 80)
	T.eq(W.meter(1, "Legendary"), 200)
	T.eq(W.meter(1, "Secret"), 3000)
	T.eq(W.meter(5, "Secret"), 33750000)
	for floor = 1, 5 do
		for _, rarity in ipairs(W.Rarities) do
			T.eq(W.meter(floor, rarity), E.GuardianPower[floor] * E.Wild.MeterMult[rarity])
		end
	end
end
function t.ready_player_timings_on_every_floor()
	for floor = 1, 5 do
		T.near(W.readySeconds(floor, "Epic", 1), 4, 1e-9, "Epic solo, floor " .. floor)
		T.near(W.readySeconds(floor, "Legendary", 1), 10, 1e-9, "Legendary solo, floor " .. floor)
		T.near(W.readySeconds(floor, "Secret", 1), 150, 1e-9, "Secret solo, floor " .. floor)
		T.near(W.readySeconds(floor, "Secret", 2), 75, 1e-9, "Secret with two, floor " .. floor)
		T.near(W.readySeconds(floor, "Secret", 3), 50, 1e-9, "Secret with three, floor " .. floor)
	end
end
function t.lone_ready_player_finishes_a_secret_in_its_stay()
	for floor = 1, 5 do
		T.ok(W.soloSecretInTime(floor), "floor " .. floor)
		T.ok(W.soloSecretInTime(floor, 0.20), "cheering, floor " .. floor)
		T.near(W.readySeconds(floor, "Secret", 1, 0.20), 125, 1e-9)
	end
	T.eq(E.Secret.StaySeconds, 180)
end
function t.new_arrivals_need_help_with_a_secret()
	T.eq(W.arrivalPower(1), 3)
	T.eq(W.arrivalPower(3), 180)
	T.near(W.seconds(2, "Secret", W.arrivalPower(2)), 1350, 1e-9)
	T.eq(W.playersForSecret(2, W.arrivalPower(2)), 8)
	T.eq(W.playersForSecret(5, W.arrivalPower(5)), 3)
	T.eq(W.playersForSecret(1, E.GuardianPower[1]), 1)
	-- exactly on the limit counts as in time
	T.eq(W.playersForSecret(1, E.GuardianPower[1] * 150 / 180), 1)
end
function t.secret_next_to_legendary()
	for floor = 1, 5 do
		local s = W.secret(floor)
		T.near(s.income, E.CommonIncome[floor] * 20, 1e-9)
		T.near(s.power, E.CommonPower[floor] * 10, 1e-9)
		T.near(s.income / s.legIncome, 2, 1e-9)
		T.near(s.power / s.legPower, 10 / 7, 1e-9)
	end
	T.near(W.secret(1).charmSeconds, 15, 1e-9)
	T.near(W.secret(4).charmSeconds, 600000 / 540, 1e-9)
	T.eq(W.secret(5).charm, nil)
	T.eq(W.secret(5).charmSeconds, nil)
end
function t.pacing_is_deterministic_and_has_both_columns()
	local a, b = W.pacing(8, true), W.pacing(8, true)
	for f = 1, 5 do
		T.ok(a.before[f] and a.after[f], "floor " .. f)
		T.eq(a.before[f], b.before[f])
		T.eq(a.after[f], b.after[f])
		T.near(a.diff[f], a.after[f] - a.before[f], 1e-9)
	end
	local differs = false
	for f = 1, 5 do if a.diff[f] ~= 0 then differs = true end end
	T.ok(differs, "the extra seconds move the table")
end
return t
