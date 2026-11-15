-- Every tuning value from bible B7 / B9. The game and tools/econ_sim both read this file.
-- Prices here are coin prices. Robux prices live in Config/Shop and need the owner's approval.
local Economy = {}

Economy.StartCoins = 50

-- Rarity order is the index used everywhere (1 = Common ... 5 = Legendary).
Economy.Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
-- "Secret" is a sixth rarity that never comes from the spawn roll (Amendment 1): see Economy.Secret.
Economy.RarityIncomeMult = { Common = 1, Uncommon = 2, Rare = 3.5, Epic = 6, Legendary = 10, Secret = 20 }
Economy.RarityPowerMult = { Common = 1, Uncommon = 1.5, Rare = 2.5, Epic = 4, Legendary = 7, Secret = 10 }

-- Wild spawn odds per floor (percent), shown in the index. Nothing purchasable changes these.
Economy.SpawnOdds = { Common = 60, Uncommon = 25, Rare = 10, Epic = 4, Legendary = 1 }
Economy.RadiantChance = 1 / 500
Economy.RadiantIncomeMult = 3

-- By floor.
Economy.CommonIncome = { 1, 3, 9, 27, 81 } -- coins per second
Economy.CommonPower = { 2, 8, 250, 2200, 7500 }
Economy.GuardianPower = { 20, 180, 7500, 65000, 225000 }
Economy.CharmPrice = { 0, 300, 4000, 50000, 600000 }

-- Starter.
Economy.Starter = {
	BasePower = 3,
	PowerGrowth = 1.2,
	LevelCostBase = 10,
	LevelCostGrowth = 1.4,
	-- Stage reached at level -> power multiplier.
	Stages = { { level = 1, mult = 1 }, { level = 5, mult = 1.5 }, { level = 25, mult = 2.5 }, { level = 42, mult = 4 } },
}

-- Hearts on wild pets.
Economy.Hearts = { Max = 5, PowerPer = 0.25, IncomePer = 0.10, CostBase = 100, GrowAt = { 3, 5 } }

-- Camp.
Economy.Pads = { Start = 8, Step = 4, Prices = { 500, 6000, 70000, 800000 }, HoldSeconds = 600 }
Economy.ReleaseSeconds = 60

-- Head stack (prices are untested guesses, bible B9).
Economy.Stack = { Start = 3, Prices = { 200, 1000, 5000, 25000, 120000, 600000, 3000000 } }
Economy.NightLanternPrice = 250000 -- untested guess

-- Trust Tap.
Economy.Tap = {
	PerfectWindow = 0.080,
	GoodWindow = 0.200,
	RingTime = { Common = 1.2, Uncommon = 1.0, Rare = 0.8, Epic = 0.65, Legendary = 0.5, Secret = 0.5 },
	-- hits = rings that are Good or better; perfects = rings that are Perfect.
	Need = {
		Common = { hits = 1, perfects = 0 },
		Uncommon = { hits = 2, perfects = 0 },
		Rare = { hits = 2, perfects = 1 },
		Epic = { hits = 3, perfects = 2 },
		Legendary = { hits = 3, perfects = 3 },
		Secret = { hits = 3, perfects = 3 },
	},
	Beats = 3,
	GapSeconds = 0.25, -- pause between one ring landing and the next starting
	CharmSpeedPerTier = 0.15, -- rings 15% faster per Charm tier below the floor
	AssistAfterMisses = 3,
	AssistSlow = 0.20, -- rings 20% slower
	AssistUntilCatches = 2,
	MaxDistance = 15, -- studs
	LatencyGrace = 0.6, -- seconds a tap may arrive after its claimed time
	EarlyGrace = 0.10, -- seconds a tap may arrive before its claimed time (clock skew)
}

-- Wild spawns.
Economy.Spawns = { PerFloor = 11, StaySeconds = 90 }

-- Guardian showdowns.
Economy.Showdown = {
	Seconds = 40,
	MeterMult = 40,
	CheerPerfect = 0.50,
	CheerGood = 0.20,
	CheerSeconds = 2,
	FriendCheerMult = 2,
	BeatSeconds = 1.0, -- one cheer ring per second
	NatureMult = 1.5,
}

-- Amendment 1: wild showdowns (play first, then catch). Epic, Legendary and Secret pets have a Play
-- meter = the floor's Guardian power x MeterMult. Teams drain it at Team Power per second.
Economy.Wild = {
	MeterMult = { Epic = 4, Legendary = 10, Secret = 150 },
	FriendlySlow = 0.20, -- rings 20% slower once the pet has played with you
	JoinDistance = 20, -- studs from the pet to step in
	TryGraceSeconds = 12, -- a played-out pet stays at least this long so everyone gets their try
}

-- Amendment 1: Secret pets. One per floor, appears when the floor's lantern chimes, about 3 times a
-- day at times every server derives from the UTC clock. Income and power multipliers are untested.
Economy.Secret = {
	Rarity = "Secret",
	StaySeconds = 180,
	ChimesPerDay = 3,
	GlowSeconds = 60, -- the lantern glow builds for this long before the pet appears
}

-- Natures: key beats value.
Economy.NatureBeats = { Ember = "Leaf", Leaf = "Tide", Tide = "Ember" }

Economy.FriendCoinBonus = 0.20

-- Saving.
Economy.Data = { AutosaveSeconds = 120, LockStaleSeconds = 600, Retries = 5 }

-- tools/econ_sim bot (bible B9).
Economy.Sim = {
	TripSeconds = 150,
	CatchesPerTrip = 3,
	CatchSuccess = { Common = 0.95, Uncommon = 0.85, Rare = 0.70, Epic = 0.50, Legendary = 0.25 },
	SessionSeconds = 18 * 60,
	BreakIncomeSeconds = 3600,
	CheerBonus = 0.20,
	TargetWinMinutes = { 4, 15, 58, 141, 260 },
	ExtraTrySeconds = { Epic = 5, Legendary = 12 }, -- Amendment 1: play time before the catch try
}

return Economy
