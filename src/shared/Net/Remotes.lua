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
	WildJoin = { rate = 1, burst = 3 }, -- (petId)  Amendment 1: step in to play with an Epic+ pet
	Choose = { rate = 1, burst = 2 }, -- (floor, "share" | "keep")
	ChooseForm = { rate = 1, burst = 2 }, -- ("dawn" | "dusk")  at starter Lv 42
	HatchEgg = { rate = 1, burst = 2 }, -- ()
	Emote = { rate = 0.5, burst = 3 }, -- (index 1..6)
	RedeemCode = { rate = 0.2, burst = 2 }, -- (code string, 24 characters at most)
	MerchantBuy = { rate = 1, burst = 3 }, -- (slot 1..3)  weekends only, coins only
	ChooseWeekly = { rate = 1, burst = 2 }, -- ("share" | "keep")  after a Weekly Guardian win
	SetSetting = { rate = 2, burst = 6 }, -- (key, value)
	IndexOpen = { rate = 1, burst = 2 }, -- ()
	Equip = { rate = 2, burst = 6 }, -- (look id, or "" with a slot name to take it off)
	MailOpen = { rate = 1, burst = 2 }, -- ()
	Debug = { rate = 5, burst = 10 }, -- (command, argument)  Studio only: ignored in a live game
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
	-- Amendment 1. Wild showdowns reuse ShowdownState / ShowdownEnd / Cheer / CheerGrade with
	-- kind = "wild" and two extra fields: petId, rarity. ShowdownEnd for kind "wild" carries
	-- { kind, petId, won = true (meter empty: you may now try) | false (the pet left) }.
	-- Wild ShowdownState goes to everyone on the floor and carries mine = true for players who are in.
	-- Wild ShowdownEnd carries left = true when the player stepped out (walked away) and the pet stays.
	"SecretChime", -- ({ floor, phase = "glow" | "here" | "gone", at, leaves })  times are UTC seconds
	"Welcome", -- ({ away, chest, rested, newDay, journeyDay, ladderCoins, look, tomorrow = { minutes, look }, egg = { state, readyAt } })
	"ChoicePrompt", -- (floor)  show the two big Share / Keep buttons
	"Shared", -- ({ userId, name, coins })  "<name> shared!"  (keeping is never announced)
	"EggHatched", -- ({ species, rarity, radiant })
	"Emote", -- (userId, index)
	"Week", -- ({ week, guardian, merchantOpen, items = { { slot, kind, id, price, bought } }, tally = { dawn, dusk }, lastLeader, trim, monument = { [floor] = { names } } })
	"WeeklyChoice", -- ()  show the Share / Keep buttons after a Weekly Guardian win
	"Index", -- (IndexView rows)
	"Mail", -- ({ journeyDay, tomorrow = { minutes, look }, egg = { state, readyAt }, codes = bool })
	"Closet", -- ({ looks = { id, ... }, equipped = { slot = id } })
	"ClipMoment", -- ({ kind = "wild_legendary" | "secret" | ..., floor })  offer a capture where allowed
}

Remotes.FolderName = "PetTowerRemotes"

function Remotes.get(name)
	local folder = game:GetService("ReplicatedStorage"):WaitForChild(Remotes.FolderName)
	return folder:WaitForChild(name)
end

return Remotes
