-- CONTRACT: every remote name and payload. Server creates them; clients wait for them.
-- All client -> server remotes are rate-limited and validated on the server (see server/Services/Net).
local Remotes = {}

-- Client -> server. Value = rate rule { rate per second, burst }.
Remotes.C2S = {
	ChooseStarter = { rate = 1, burst = 2 }, -- (species)
	TryStart = { rate = 2, burst = 4 }, -- (petId)
	Tap = { rate = 8, burst = 8 }, -- (beat 1..3, offset seconds since the try's start)
	Lift = { rate = 0.5, burst = 2 }, -- (floor; 0 = home camp)
	Feed = { rate = 6, burst = 12 }, -- ()
	Collect = { rate = 2, burst = 4 }, -- ()
	Buy = { rate = 2, burst = 4 }, -- ("charm" | "pads" | "stack")
	Heart = { rate = 4, burst = 8 }, -- (petId)
	SetTeam = { rate = 2, burst = 4 }, -- (petIdA, petIdB)
	Place = { rate = 4, burst = 8 }, -- (petId, padIndex)
	Release = { rate = 4, burst = 8 }, -- (petId)
	ShowdownJoin = { rate = 1, burst = 2 }, -- ()
	Cheer = { rate = 4, burst = 6 }, -- (offset seconds since the showdown's start)
	CallHelp = { rate = 0.1, burst = 1 }, -- ()
}

-- Server -> client.
Remotes.S2C = {
	"State", -- (profile snapshot, extras { floor, teamPower, coinMult })
	"TryBegin", -- ({ petId, start, beats = {t1,t2,t3}, ringTime, rarity })
	"TryGrade", -- (beat, "Perfect" | "Good" | "Miss")
	"TryEnd", -- ({ success, grades, lastBeatMiss, perfectAll, species, rarity, radiant })
	"Evolve", -- ({ species, stage })
	"Banner", -- ({ kind = "pillar" | "help" | "relit", floor, rarity, name })
	"ShowdownState", -- ({ floor, start, ends, meter, left, count, kind })
	"ShowdownEnd", -- ({ floor, won, firstClear, kind })
	"CheerGrade", -- (grade)
	"Coins", -- (amount, source)  for coin pops
}

Remotes.FolderName = "PetTowerRemotes"

function Remotes.get(name)
	local folder = game:GetService("ReplicatedStorage"):WaitForChild(Remotes.FolderName)
	return folder:WaitForChild(name)
end

return Remotes
