-- Boots src/server/Main.server.lua against tools/roblox_mock.lua and plays the Studio checklist
-- (docs/HANDOFF_MAC.md) through remotes, touches and prompts, exactly as a client would.
local H = runfile(ROOT .. "/tests/boot_helpers.lua")
local Mock = H.Mock
local V3 = Mock.Vector3
local tests = {}

local function config(world) return world.server:call(world.server.env.require, world.services.ReplicatedStorage.Shared.Config) end

-- Start ------------------------------------------------------------------------------------------------
function tests.a01_server_starts_and_creates_every_remote()
	local world = H.fresh()
	H.clean("server start")
	local found = false
	for _, line in ipairs(Mock.prints) do if line == "[PetTower] server ready" then found = true end end
	T.ok(found, "the server printed that it is ready")
	local Remotes = world.server:call(world.server.env.require, world.services.ReplicatedStorage.Shared.Net.Remotes)
	local n, names = 0, {}
	for name in pairs(Remotes.C2S) do
		T.eq(world:remote(name).ClassName, "RemoteEvent", name)
		names[name] = true
		n = n + 1
	end
	for _, name in ipairs(Remotes.S2C) do
		T.eq(world:remote(name).ClassName, "RemoteEvent", name)
		if not names[name] then n = n + 1 end
		names[name] = true
	end
	T.eq(n, 27 + 22 - 1, "27 client-to-server and 22 server-to-client names; Emote goes both ways")
	T.eq(#world.services.ReplicatedStorage.PetTowerRemotes:GetChildren(), n, "exactly one RemoteEvent per name")
	T.eq(#world.workspace.PetTowerWorld:GetChildren(), 1 + 5 + 1 + 7 + 5 + 1, "hub, 5 hub parts, tower, 7 camps, 5 floors, tutorial folder")
	Mock.step(300) -- five minutes of an empty server
	H.clean("empty server")
end

function tests.a02_join_gets_a_camp_and_state()
	local world = H.fresh()
	local ann, c = H.join(world, 101, "Ann")
	H.clean("join")
	local camp = H.camp(world, ann)
	T.ok(camp, "a camp was claimed")
	T.eq(camp.owner, ann)
	local state, extra = c:got("State")[1][1], c:got("State")[1][2]
	T.eq(state.coins, 50)
	T.eq(state.starter, nil)
	T.eq(#state.pads, 8)
	T.eq(extra.teamPower, 0)
	T.eq(extra.coinMult, 1)
	T.eq(ann:GetAttribute("Floor"), 0)
	T.near((H.pos(world, ann) - camp.spawn.Position).Magnitude, 0, 0.01, "the character was moved to the camp spawn")
	T.ok(ann.leaderstats.Floor.Value == 1 and ann.leaderstats.Power.Value == 0, "leaderstats")
	local w = H.payload(c, "Welcome")
	T.ok(w and w.newDay and w.journeyDay == 1 and w.chest == 0 and w.rested == false, "welcome summary for a first join")
	T.eq(w.egg.state, "none")
	T.ok(H.payload(c, "Week"), "the week arrives")
	-- the spawn faces the three pedestals: they are in front (negative Z in the spawn's space) and close
	for _, species in ipairs({ "Pandle", "Narbub", "Capling" }) do
		local l = camp.spawn:PointToObjectSpace(camp.pedestals[species].ped.Position)
		T.ok(l.Z < -10 and l.Z > -25 and math.abs(l.X) <= 8, species .. " pedestal is ahead of the spawn")
	end
	-- a second player gets a different camp
	local bob = H.join(world, 102, "Bob")
	T.ok(H.camp(world, bob) ~= camp, "two players, two camps")
	T.eq(#world.analytics, 2, "one Joined funnel step each")
	T.eq(world.analytics[1].step, 1)
	T.eq(world.analytics[1].stepName, "Joined")
	H.clean("two joins")
end

-- M1 -----------------------------------------------------------------------------------------------------
function tests.b01_touching_a_pedestal_picks_the_starter()
	local world = H.fresh()
	local ann, c = H.join(world, 101, "Ann")
	local bob = H.join(world, 102, "Bob")
	-- someone else's pedestal does nothing
	local other = H.camp(world, bob).pedestals.Narbub.ped
	world:walkTo(ann, V3.new(other.Position.X, 3, other.Position.Z))
	world:touch(other, ann)
	Mock.step(0.6)
	T.eq(H.profile(world, ann).starter, nil, "another camp's pedestal is not mine")
	H.chooseStarter(world, ann, "Narbub")
	local p = H.profile(world, ann)
	T.eq(p.starter.species, "Narbub")
	T.eq(p.starter.level, 1)
	T.eq(H.state(c).starter.species, "Narbub")
	T.ok(ann.Character:FindFirstChild("StarterPet"), "the starter follows the player")
	T.eq(H.camp(world, ann).pedestals.Pandle.ball.Transparency, 1, "the other starters are put away")
	local ball = H.tutorialPart(world, ann)
	T.ok(ball, "the first pet appears")
	T.eq(ball:GetAttribute("Species"), "Buttercub")
	local d = (ball.Position - H.camp(world, ann).spawn.Position).Magnitude
	T.ok(d > 15 and d < 25, "about 20 studs from the camp spawn")
	-- a second pedestal changes nothing
	H.chooseStarter(world, ann, "Pandle")
	T.eq(H.profile(world, ann).starter.species, "Narbub")
	H.clean("starter")
end

function tests.b02_first_trust_tap_three_perfect_taps()
	local world = H.fresh()
	local ann, c = H.join(world, 101, "Ann")
	H.chooseStarter(world, ann)
	-- too far away: no try
	c:fire("TryStart", -101)
	Mock.step(0.1)
	T.eq(H.count(c, "TryBegin"), 0, "a try needs the player within reach")
	local ball = H.tutorialPart(world, ann)
	H.walkNear(world, ann, ball.Position, 4)
	Mock.step(1)
	c:fire("TryStart", -101)
	Mock.step(0.1)
	local try = H.payload(c, "TryBegin")
	T.ok(try, "the try begins")
	T.eq(try.petId, -101)
	T.eq(#try.beats, 3)
	T.eq(try.rarity, "Common")
	T.near(try.ringTime, 1.2, 1e-9)
	local result = H.playTry(world, c)
	local grades = c:got("TryGrade")
	T.eq(#grades, 3)
	for i = 1, 3 do T.eq(grades[i][1], i) T.eq(grades[i][2], "Perfect") end
	T.ok(result.success and result.perfectAll, "caught with three Perfects")
	T.eq(result.species, "Buttercub")
	local p = H.profile(world, ann)
	T.eq(#p.stack, 1, "the pet rides on the stack")
	T.eq(p.tutorial, 1)
	T.eq(#ann.Character.PetStack:GetChildren(), 1, "one ball on the head")
	T.eq(H.tutorialPart(world, ann), nil, "the first pet's part is gone")
	T.ok(p.stats.funnel.FirstCatch, "funnel: first catch")
	-- one try per pet, and the pet is gone anyway
	c:fire("TryStart", -101)
	Mock.step(0.1)
	T.eq(H.count(c, "TryBegin"), 1)
	H.clean("first catch")
end

function tests.b03_first_trust_tap_cannot_fail()
	local world = H.fresh()
	local ann, c = H.join(world, 101, "Ann")
	H.chooseStarter(world, ann)
	H.walkNear(world, ann, H.tutorialPart(world, ann).Position, 4)
	c:fire("TryStart", -101)
	Mock.step(0.1)
	local result = H.playTry(world, c, { "Miss", "skip", "skip" }) -- one bad tap, then nothing at all
	T.ok(result, "the try ends by itself")
	T.ok(result.success, "the first try cannot fail")
	T.eq(#H.profile(world, ann).stack, 1)
	H.clean("cannot fail")
end

function tests.b04_tap_with_a_perfect_offset_at_the_wrong_time_is_a_miss()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	H.lift(world, ann, c, 1)
	local rare = H.findPet(world, 1, "Rare", true)
	H.walkNear(world, ann, rare.Position, 4)
	c:clear()
	c:fire("TryStart", rare:GetAttribute("PetId"))
	Mock.step(0.05)
	local try = H.payload(c, "TryBegin")
	T.ok(try, "try on the Rare")
	-- claim the perfect moment of every ring right now
	for i = 1, 3 do c:fire("Tap", i, try.beats[i]) end
	Mock.step(0.5)
	local grades = c:got("TryGrade")
	T.eq(#grades, 3)
	for i = 1, 3 do T.eq(grades[i][2], "Miss", "beat " .. i) end
	local result = H.payload(c, "TryEnd")
	T.no(result.success, "nothing caught")
	T.eq(#H.profile(world, ann).stack, 0)
	-- junk arguments are ignored without an error
	c:fire("Tap", "x", {})
	c:fire("Tap")
	c:fire("TryStart", "abc")
	c:fire("TryStart", 0 / 0)
	Mock.step(0.5)
	H.clean("wrong-time tap")
end

function tests.b05_pet_lands_on_a_pad_and_income_collects()
	local world = H.fresh()
	local ann, c = H.join(world, 101, "Ann")
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c)
	local p = H.profile(world, ann)
	T.eq(#p.stack, 1)
	-- the first pet was caught inside the camp: walking onto a pad puts it down
	H.deposit(world, ann)
	T.eq(#p.stack, 0, "the stack is empty")
	T.eq(p.pads[1].pet, 1, "the pet is on pad 1")
	T.ok(H.camp(world, ann).pads[1]:FindFirstChild("PadPet"), "a pet shows on the pad")
	T.eq(#ann.Character.PetStack:GetChildren(), 0)
	T.ok(p.stats.funnel.FirstPetPlaced, "funnel: first pet placed")
	T.eq(#H.state(c).team, 1, "the pet joined the team by itself")
	c:clear()
	Mock.step(30)
	world:touch(H.camp(world, ann).pads[1], ann)
	Mock.step(0.1)
	local coins = c:got("Coins")
	T.eq(#coins, 1, "one coin pop")
	T.eq(coins[1][2], "pads")
	T.ok(coins[1][1] >= 30 and coins[1][1] <= 31, "about 30 s of 1 coin a second, got " .. coins[1][1])
	T.eq(p.coins, 50 + coins[1][1])
	-- the Collect remote does the same
	Mock.step(10)
	c:fire("Collect")
	Mock.step(0.1)
	T.eq(#c:got("Coins"), 2)
	H.clean("pads")
end

function tests.b06_walking_home_into_the_camp_zone_deposits()
	local world = H.fresh()
	local ann, c = H.join(world, 101, "Ann")
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c)
	local camp = H.camp(world, ann)
	world:walkTo(ann, V3.new(0, 3, 0)) -- out to the hub
	Mock.step(1)
	T.no(world:overlaps(ann, camp.zone), "outside the camp")
	world:walkTo(ann, camp.spawn.Position)
	world:touch(camp.zone, ann)
	Mock.step(0.1)
	T.eq(#H.profile(world, ann).stack, 0)
	T.eq(H.profile(world, ann).pads[1].pet, 1)
	H.clean("zone deposit")
end

-- M2 -----------------------------------------------------------------------------------------------------
function tests.c01_lift_to_floor_1_spawns_the_guaranteed_rare()
	local world = H.fresh()
	local ann, c = H.join(world, 101, "Ann")
	local bob, cb = H.join(world, 102, "Bob")
	H.chooseStarter(world, ann)
	-- not before the first friend is made
	local camp = H.camp(world, ann)
	H.walkToPart(world, ann, camp.Lift)
	world:trigger(camp.LiftPrompt, ann)
	Mock.step(0.5)
	T.eq(ann:GetAttribute("Floor"), 0, "the lift waits for the first catch")
	H.tutorialCatch(world, ann, c)
	H.deposit(world, ann)
	c:clear() cb:clear()
	H.walkToPart(world, ann, camp.Lift)
	world:trigger(camp.LiftPrompt, ann)
	Mock.step(0.5)
	T.eq(ann:GetAttribute("Floor"), 1)
	local floor = H.floor(world, 1)
	T.near((H.pos(world, ann) - floor.spawn.Position).Magnitude, 0, 0.01, "moved to the floor's lift")
	T.eq(H.state(c) and c:last("State")[2].floor, 1)
	local rare = H.findPet(world, 1, "Rare", true)
	T.ok(rare, "a Rare is on the floor")
	T.ok(rare:FindFirstChild("Pillar"), "under a pillar of light")
	T.ok((rare.Position - floor.lift.Position).Magnitude < 70, "near the lift")
	T.eq(H.profile(world, ann).tutorial, 2)
	-- the pillar banner reaches every client
	for _, client in ipairs({ c, cb }) do
		local b = H.banners(client, "pillar")
		T.eq(#b, 1)
		T.eq(b[1].floor, 1)
		T.eq(b[1].rarity, "Rare")
	end
	T.eq(#H.petParts(world, 1), 12, "11 shared pets and the Rare")
	-- only once
	H.walkToPart(world, ann, floor.lift)
	world:trigger(floor.liftPrompt, ann)
	Mock.step(2.5)
	T.eq(ann:GetAttribute("Floor"), 0, "home again")
	H.lift(world, ann, c, 1)
	T.eq(ann:GetAttribute("Floor"), 1)
	local rares = 0
	for _, ball in ipairs(H.petParts(world, 1)) do if ball:FindFirstChild("Pillar") and ball:GetAttribute("Rarity") == "Rare" then rares = rares + 1 end end
	T.eq(rares, 1, "one guaranteed Rare only")
	-- floors that are not unlocked, and nonsense, are refused
	for _, f in ipairs({ 2, 5, 6, -1, 1.5, "1" }) do
		Mock.step(2.1)
		c:fire("Lift", f)
		Mock.step(0.2)
		T.eq(ann:GetAttribute("Floor"), 1, "lift to " .. tostring(f) .. " refused")
	end
	H.clean("lift")
end

function tests.c02_catch_on_a_floor_then_ride_home()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	H.lift(world, ann, c, 1)
	local rare = H.findPet(world, 1, "Rare", true)
	H.walkNear(world, ann, rare.Position, 4)
	c:fire("TryStart", rare:GetAttribute("PetId"))
	Mock.step(0.05)
	local result = H.playTry(world, c) -- Rare: 2 hits, 1 Perfect
	T.ok(result.success, "Rare caught")
	T.eq(result.rarity, "Rare")
	T.eq(result.species, "Zipwing")
	local p = H.profile(world, ann)
	T.eq(#p.stack, 1)
	-- the shared pet stays for the others, but this player has had their try
	T.ok(rare.Parent, "the shared pet is still there")
	c:fire("TryStart", rare:GetAttribute("PetId"))
	Mock.step(0.3)
	T.eq(H.count(c, "TryBegin"), 2, "tutorial try + this one; no second try on the same pet")
	local floor = H.floor(world, 1)
	H.walkToPart(world, ann, floor.lift)
	world:trigger(floor.liftPrompt, ann)
	Mock.step(0.5)
	T.eq(ann:GetAttribute("Floor"), 0)
	T.eq(#p.stack, 0, "riding home puts the stack on the pads")
	T.eq(p.pads[2].pet, 2)
	T.eq(#p.team, 2, "both pets are on the team")
	H.clean("floor catch")
end

function tests.c03_feeding_to_level_5_fires_evolve()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	local camp = H.camp(world, ann)
	Mock.step(30)
	world:touch(camp.pads[1], ann) -- collect about 30 coins: 50 + 30 covers 10 + 14 + 20 + 27
	Mock.step(0.1)
	H.walkToPart(world, ann, camp.SnackTable)
	c:clear()
	for _ = 1, 3 do
		world:trigger(camp.SnackTablePrompt, ann)
		Mock.step(0.3)
	end
	T.eq(H.profile(world, ann).starter.level, 4)
	T.eq(H.count(c, "Evolve"), 0)
	c:fire("Feed") -- the remote feeds too
	Mock.step(0.3)
	local p = H.profile(world, ann)
	T.eq(p.starter.level, 5)
	local evolve = c:got("Evolve")
	T.eq(#evolve, 1, "one evolution moment")
	T.eq(evolve[1][1].species, "Pandle")
	T.eq(evolve[1][1].stage, 2)
	T.eq(ann.Character.StarterPet:GetAttribute("Stage"), 2, "the starter ball grew")
	T.ok(p.stats.funnel.FirstEvolution, "funnel: first evolution")
	T.eq(H.state(c).starter.level, 5)
	-- no coins left: feeding again does nothing
	local coins = p.coins
	c:fire("Feed")
	Mock.step(0.3)
	T.eq(p.starter.level, 5)
	T.eq(p.coins, coins)
	H.clean("feed")
end

function tests.c04_rate_limiting_drops_a_flood()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	local bob, cb = H.join(world, 102, "Bob")
	c:clear() cb:clear()
	for i = 1, 50 do c:fire("Emote", (i % 6) + 1) end
	Mock.step(0.1)
	T.eq(H.count(cb, "Emote"), 3, "Emote: burst of 3, the other 47 are dropped")
	T.eq(H.count(c, "Emote"), 3)
	T.eq(cb:got("Emote")[1][1], 101)
	Mock.step(2) -- 0.5 a second: one more token
	for _ = 1, 10 do c:fire("Emote", 1) end
	Mock.step(0.1)
	T.eq(H.count(cb, "Emote"), 4)
	-- a flood on one remote does not block another, and bad emotes are ignored
	c:fire("Emote", 7) c:fire("Emote", "1")
	local before = H.count(c, "Index")
	c:fire("IndexOpen")
	Mock.step(0.1)
	T.eq(H.count(c, "Index"), before + 1)
	local Net = H.svc(world, "Net")
	T.ok(Net.limiter.flags[101] >= 47, "the flood was flagged for review")
	-- the other player's bucket is their own
	cb:fire("Emote", 2)
	Mock.step(0.1)
	T.eq(H.count(c, "Emote"), 5)
	H.clean("rate limit")
end

-- M3: Guardian showdowns ---------------------------------------------------------------------------------
local function toRing(world, player, f)
	local ring = H.floor(world, f).ring
	world:walkTo(player, V3.new(ring.Position.X, ring.Position.Y + 2.5, ring.Position.Z))
	world:touch(ring, player)
end

function tests.d01_guardian_showdown_alone_wins_and_unlocks_floor_2()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	local bob, cb = H.join(world, 102, "Bob")
	H.debug(c, "level", 12)
	H.lift(world, ann, c, 1)
	-- the remote from the camp does nothing; the ring on the floor starts it
	c:clear() cb:clear()
	toRing(world, ann, 1)
	Mock.step(0.05)
	local snap = H.payload(c, "ShowdownState")
	T.ok(snap, "the showdown starts on walking into the ring")
	T.eq(snap.kind, "guardian")
	T.eq(snap.floor, 1)
	T.eq(snap.meter, 800)
	T.eq(snap.count, 1)
	T.near(snap.ends - snap.start, 40, 1e-9)
	-- cheer on the first three beats
	for beat = 1, 3 do
		Mock.step(snap.start + beat - Mock.now)
		c:fire("Cheer", Mock.now - snap.start)
		Mock.step(0.05)
	end
	local cheers = c:got("CheerGrade")
	T.eq(#cheers, 3)
	T.eq(cheers[1][1], "Perfect")
	-- a cheer with a made-up time is not graded
	c:fire("Cheer", 30)
	Mock.step(0.05)
	T.eq(H.count(c, "CheerGrade"), 3)
	T.ok(H.waitFor(c, "ShowdownEnd", 45), "the showdown ends")
	local result = H.payload(c, "ShowdownEnd")
	T.ok(result.won, "won")
	T.ok(result.firstClear, "first clear")
	T.eq(result.kind, "guardian")
	T.eq(result.floor, 1)
	T.eq(#c:got("ShowdownEnd"), 1, "told once")
	local p = H.profile(world, ann)
	T.eq(p.cleared, 1)
	T.eq(p.floors["1"].cleared, true)
	T.eq(p.floors["1"].choice, false)
	T.ok(p.stats.funnel.FirstGuardianWin, "funnel: first guardian win")
	T.eq(H.state(c).cleared, 1)
	T.eq(ann.leaderstats.Floor.Value, 2)
	T.eq(#H.banners(c, "relit"), 1)
	T.eq(#H.banners(cb, "relit"), 1, "everyone sees the lantern relit")
	T.eq(H.count(cb, "ShowdownEnd"), 0, "a player who did not play gets no result")
	T.eq(H.floor(world, 1).lantern.Color, Mock.Color3.fromRGB(255, 220, 120), "the lantern is lit")
	-- Floor 2 is open
	H.lift(world, ann, c, 2)
	T.eq(ann:GetAttribute("Floor"), 2)
	H.clean("guardian solo")
end

function tests.d02_guardian_showdown_with_three_players()
	local world = H.fresh()
	local players, clients = {}, {}
	for i = 1, 3 do
		players[i], clients[i] = H.ready(world, 200 + i, "P" .. i, ({ "Pandle", "Narbub", "Capling" })[i])
		H.debug(clients[i], "level", 8)
	end
	for i = 1, 3 do H.lift(world, players[i], clients[i], 1) clients[i]:clear() end
	for i = 1, 3 do toRing(world, players[i], 1) Mock.step(0.3) end
	Mock.step(0.3)
	T.eq(H.payload(clients[1], "ShowdownState").count, 3, "three in the ring")
	T.eq(H.payload(clients[3], "ShowdownState").start, H.payload(clients[1], "ShowdownState").start, "one showdown")
	H.cheerUntil(world, clients, H.payload(clients[1], "ShowdownState"), "ShowdownEnd", 45)
	for i = 1, 3 do
		local ends = clients[i]:got("ShowdownEnd")
		T.eq(#ends, 1, "P" .. i .. " is told once")
		T.ok(ends[1][1].won and ends[1][1].firstClear, "P" .. i .. " gets the clear")
		T.eq(ends[1][1].count, 3)
		local p = H.profile(world, players[i])
		T.eq(p.cleared, 1)
		T.ok(p.stats.funnel.FirstCoopShowdown, "funnel: first co-op showdown")
		T.eq(#H.banners(clients[i], "relit"), 1)
		T.eq(players[i].leaderstats.Floor.Value, 2)
	end
	-- helping on a floor you have cleared: a Helper star, and a small reward once a day
	Mock.step(4)
	clients[1]:clear()
	local coinsBefore = H.profile(world, players[1]).coins
	toRing(world, players[1], 1)
	Mock.step(0.3)
	T.ok(H.payload(clients[1], "ShowdownState"), "a second showdown starts after the short rest")
	H.cheerUntil(world, { clients[1] }, H.payload(clients[1], "ShowdownState"), "ShowdownEnd", 45)
	local again = H.payload(clients[1], "ShowdownEnd")
	T.ok(again.won, "won again")
	T.no(again.firstClear, "not a first clear")
	local p1 = H.profile(world, players[1])
	T.eq(p1.helperStars, 1)
	T.eq(#clients[1]:got("Coins"), 1, "the helper reward")
	T.eq(clients[1]:got("Coins")[1][2], "helper")
	T.eq(p1.coins, coinsBefore + clients[1]:got("Coins")[1][1])
	T.eq(p1.cleared, 1)
	H.clean("guardian trio")
end

function tests.d03_lost_showdown_then_call_help()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	local bob, cb = H.join(world, 102, "Bob")
	H.lift(world, ann, c, 1)
	c:clear() cb:clear()
	-- asking for help before losing does nothing (and uses up the one token)
	c:fire("CallHelp")
	Mock.step(0.1)
	T.eq(#H.banners(cb, "help"), 0)
	toRing(world, ann, 1) -- Lv 1 against Old Bramblehorn: no chance
	T.ok(H.waitFor(c, "ShowdownEnd", 45), "the showdown ends")
	local result = H.payload(c, "ShowdownEnd")
	T.no(result.won, "lost")
	T.no(result.firstClear)
	T.eq(H.profile(world, ann).cleared, 0)
	T.eq(#H.banners(c, "relit"), 0)
	Mock.step(10) -- CallHelp refills one token every 10 s
	c:fire("CallHelp")
	Mock.step(0.1)
	local help = H.banners(cb, "help")
	T.eq(#help, 1, "the call for help reaches the other player")
	T.eq(help[1].floor, 1)
	T.eq(help[1].userId, 101)
	T.eq(#H.banners(c, "help"), 1)
	Mock.step(11)
	c:fire("CallHelp")
	Mock.step(0.1)
	T.eq(#H.banners(cb, "help"), 1, "one call per lost showdown")
	H.clean("lost + help")
end

function tests.d04_share_and_keep_after_a_clear()
	local world = H.fresh()
	local ann, ca = H.ready(world, 101, "Ann")
	local bob, cb = H.ready(world, 102, "Bob")
	local cat, cc = H.ready(world, 103, "Cat")
	local dan, cd = H.join(world, 104, "Dan") -- no starter yet: gets no gift
	H.debug(ca, "level", 10)
	H.debug(cb, "level", 10)
	H.lift(world, ann, ca, 1)
	H.lift(world, bob, cb, 1)
	toRing(world, ann, 1)
	Mock.step(0.3)
	toRing(world, bob, 1)
	T.ok(H.waitFor(ca, "ShowdownEnd", 45))
	T.ok(H.payload(cb, "ShowdownEnd").firstClear)
	-- the Tower Trophy block of Floor 1 is lit as soon as the floor is cleared
	local Enum = Mock.Enum
	T.eq(H.camp(world, ann).trophy[1].Material, Enum.Material.Neon, "lit on the clear")
	T.eq(H.camp(world, ann).trophy[1].Color, Mock.Color3.fromRGB(240, 240, 240))
	T.eq(H.camp(world, cat).trophy[1].Material, Enum.Material.SmoothPlastic)
	for _, client in ipairs({ ca, cb, cc, cd }) do client:clear() end
	local before = { H.profile(world, ann).coins, H.profile(world, bob).coins, H.profile(world, cat).coins, H.profile(world, dan).coins }
	-- nonsense first
	ca:fire("Choose", 2, "share")
	ca:fire("Choose", "1", "share")
	Mock.step(2.1)
	ca:fire("Choose", 1, "both")
	Mock.step(2.1)
	T.eq(H.profile(world, ann).floors["1"].choice, false)
	-- Ann shares: everyone with a starter gets 300 s of their own income, and everyone sees who shared
	ca:fire("Choose", 1, "share")
	Mock.step(0.2)
	T.eq(H.profile(world, ann).floors["1"].choice, "share")
	T.eq(H.profile(world, ann).dawn, 1)
	-- (each player's own income, never less than the Common income of their highest floor: Ann and Bob
	-- have Floor 2 open, 3 coins a second; Cat has Floor 1, 1 coin a second)
	local gift = { 900, 900, 300 }
	for i, client in ipairs({ ca, cb, cc }) do
		local coins = client:got("Coins")
		T.eq(#coins, 1, "player " .. i .. " is paid once")
		T.eq(coins[1][2], "share")
		T.eq(coins[1][1], gift[i], "300 s of their own income")
		local shared = client:got("Shared")
		T.eq(#shared, 1)
		T.eq(shared[1][1].userId, 101)
		T.eq(shared[1][1].name, "Ann")
	end
	T.eq(H.profile(world, ann).coins, before[1] + 900)
	T.eq(H.profile(world, bob).coins, before[2] + 900)
	T.eq(H.profile(world, cat).coins, before[3] + 300)
	T.eq(H.state(cc).coins, before[3] + 300, "the others' HUD is updated")
	T.eq(H.count(cd, "Coins"), 0, "no starter, no gift")
	T.eq(H.profile(world, dan).coins, before[4])
	T.eq(H.count(cd, "Shared"), 1, "but the banner is for everyone")
	T.eq(ann:GetAttribute("Side"), "dawn")
	-- Bob keeps: 600 s for him, nobody is told
	for _, client in ipairs({ ca, cb, cc, cd }) do client:clear() end
	cb:fire("Choose", 1, "keep")
	Mock.step(0.2)
	T.eq(H.profile(world, bob).floors["1"].choice, "keep")
	T.eq(cb:got("Coins")[1][2], "keep")
	T.eq(cb:got("Coins")[1][1], 1800)
	T.eq(H.profile(world, bob).coins, before[2] + 900 + 1800)
	for _, client in ipairs({ ca, cc, cd }) do
		T.eq(H.count(client, "Coins"), 0, "keeping pays nobody else")
		T.eq(H.count(client, "Shared"), 0, "keeping is never announced")
		T.eq(H.count(client, "Banner"), 0)
	end
	T.eq(H.count(cb, "Shared"), 0)
	T.eq(bob:GetAttribute("Side"), "dusk")
	-- a choice is made once
	Mock.step(2.1)
	cb:fire("Choose", 1, "share")
	Mock.step(0.2)
	T.eq(H.profile(world, bob).floors["1"].choice, "keep")
	T.eq(H.count(cb, "Coins"), 1)
	-- the Tower Trophy shows the choice
	T.eq(H.camp(world, ann).trophy[1].Color, Mock.Color3.fromRGB(255, 205, 90))
	T.eq(H.camp(world, bob).trophy[1].Color, Mock.Color3.fromRGB(150, 110, 235))
	H.clean("share / keep")
end

-- Amendment 1: wild showdowns ----------------------------------------------------------------------------
local function spawnWild(world, client, rarity)
	local seen = {}
	for _, ball in ipairs(H.petParts(world, 1)) do seen[ball] = true end
	H.debug(client, "spawn", rarity)
	for _, ball in ipairs(H.petParts(world, 1)) do
		if not seen[ball] then return ball, ball:GetAttribute("PetId") end
	end
	error("the debug spawn made no pet", 2)
end

function tests.e01_wild_showdown_on_an_epic_alone_then_the_friendly_try()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	H.debug(c, "level", 8) -- Team Power about 18: the Epic's meter (80) empties in about 5 s
	H.lift(world, ann, c, 1)
	world:walkTo(ann, V3.new(-60, 403, 0))
	local ball, id = spawnWild(world, c, "Epic")
	T.eq(ball:GetAttribute("Rarity"), "Epic")
	T.eq(ball:GetAttribute("NeedsPlay"), true, "the pet wants to play first")
	c:clear()
	-- no try before playing
	c:fire("TryStart", id)
	Mock.step(0.3)
	T.eq(H.count(c, "TryBegin"), 0, "no catch try before the showdown")
	local t0 = Mock.now
	c:fire("WildJoin", id)
	Mock.step(0.05)
	local snap = H.payload(c, "ShowdownState")
	T.ok(snap, "the ring opens")
	T.eq(snap.kind, "wild")
	T.eq(snap.petId, id)
	T.eq(snap.rarity, "Epic")
	T.eq(snap.mine, true)
	T.eq(snap.meter, 80)
	T.eq(snap.ends, nil, "no time limit")
	T.ok(H.waitFor(c, "ShowdownEnd", 20), "the meter empties")
	local took = Mock.now - t0
	T.ok(took > 3 and took < 7, "about 5 s, took " .. took)
	local result = H.payload(c, "ShowdownEnd")
	T.eq(result.kind, "wild")
	T.eq(result.petId, id)
	T.eq(result.won, true)
	T.eq(result.left, nil)
	T.eq(ball:GetAttribute("NeedsPlay"), nil, "the pet may now be tried")
	T.eq(H.count(c, "ShowdownEnd"), 1)
	-- the friendly try: rings 20% slower
	c:fire("TryStart", id)
	Mock.step(0.05)
	local try = H.payload(c, "TryBegin")
	T.ok(try, "the catch try begins")
	T.eq(try.rarity, "Epic")
	T.near(try.ringTime, 0.65 * 1.2, 1e-9, "slower rings after playing")
	local caught = H.playTry(world, c)
	T.ok(caught.success, "caught")
	T.eq(caught.species, "Marigoat")
	local p = H.profile(world, ann)
	T.eq(p.stats.wild.started, 1)
	T.eq(p.stats.wild.finished, 1)
	T.eq(p.stats.wild.coop, 0)
	T.eq(#p.stack, 1, "granted once")
	T.eq(p.index.Marigoat, true)
	Mock.step(120) -- the pet leaves in its own time
	T.eq(ball.Parent, nil)
	H.clean("epic alone")
end

function tests.e02_wild_showdown_on_a_legendary_with_two_players()
	local world = H.fresh()
	local ann, ca = H.ready(world, 101, "Ann")
	local bob, cb = H.ready(world, 102, "Bob")
	local cat, cc = H.ready(world, 103, "Cat")
	H.debug(ca, "level", 10)
	H.debug(cb, "level", 10)
	for _, pc in ipairs({ { ann, ca }, { bob, cb }, { cat, cc } }) do
		H.lift(world, pc[1], pc[2], 1)
		world:walkTo(pc[1], V3.new(-60, 403, 0))
	end
	local ball, id = spawnWild(world, ca, "Legendary")
	T.ok(ball:FindFirstChild("Pillar"), "a Legendary stands under a pillar")
	for _, client in ipairs({ ca, cb, cc }) do client:clear() end
	ca:fire("WildJoin", id)
	Mock.step(0.3)
	cb:fire("WildJoin", id)
	Mock.step(0.3)
	T.eq(H.payload(cb, "ShowdownState").count, 2)
	T.eq(H.payload(cb, "ShowdownState").mine, true)
	-- the third player is on the floor: they hear about it but are not in
	local seen = H.payload(cc, "ShowdownState")
	T.ok(seen, "everyone on the floor hears about the showdown")
	T.eq(seen.mine, nil)
	T.eq(seen.petId, id)
	H.cheerUntil(world, { ca, cb }, H.payload(ca, "ShowdownState"), "ShowdownEnd", 30)
	T.ok(H.payload(ca, "ShowdownEnd").won and H.payload(cb, "ShowdownEnd").won, "both are told the pet trusts them")
	T.eq(H.count(cc, "ShowdownEnd"), 0)
	-- both get a try
	ca:fire("TryStart", id)
	cb:fire("TryStart", id)
	cc:fire("TryStart", id)
	Mock.step(0.05)
	T.ok(H.payload(ca, "TryBegin") and H.payload(cb, "TryBegin"), "both players get a try")
	T.eq(H.count(cc, "TryBegin"), 0, "a player who did not play cannot try")
	local start = H.payload(ca, "TryBegin")
	T.near(start.ringTime, 0.5 * 1.2, 1e-9)
	for i, beat in ipairs(start.beats) do
		Mock.step(start.start + beat - Mock.now)
		ca:fire("Tap", i, Mock.now - start.start)
		cb:fire("Tap", i, Mock.now - start.start)
	end
	Mock.step(0.5)
	T.ok(H.payload(ca, "TryEnd").success and H.payload(cb, "TryEnd").success, "both caught their own copy")
	T.eq(H.payload(ca, "TryEnd").species, "Sunflion")
	T.eq(#H.profile(world, ann).stack, 1)
	T.eq(#H.profile(world, bob).stack, 1)
	T.eq(#H.profile(world, cat).stack, 0)
	T.eq(H.profile(world, ann).stats.wild.coop, 1)
	T.eq(H.profile(world, bob).stats.wild.finished, 1)
	-- clip moments: the co-op Legendary for everyone, three Perfects for each catcher
	local kinds = {}
	for _, args in ipairs(ca:got("ClipMoment")) do kinds[args[1].kind] = (kinds[args[1].kind] or 0) + 1 end
	T.eq(kinds.wild_legendary, 1)
	T.eq(kinds.perfect3, 1)
	T.eq(#cc:got("ClipMoment"), 1, "the third player gets the shared moment only")
	H.clean("legendary duo")
end

function tests.e03_walking_away_from_a_wild_showdown_steps_out()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann") -- Lv 1: the Legendary's meter (200) takes about a minute
	H.lift(world, ann, c, 1)
	world:walkTo(ann, V3.new(-60, 403, 0))
	local ball, id = spawnWild(world, c, "Legendary")
	c:clear()
	c:fire("WildJoin", id)
	Mock.step(3)
	local Showdown = H.svc(world, "ShowdownService")
	T.ok(Showdown.byPlayer[ann], "in the showdown")
	local left = H.payload(c, "ShowdownState").left
	T.ok(left < 200 and left > 150, "the meter is draining")
	world:walkTo(ann, V3.new(60, 403, 0)) -- 100 studs away
	Mock.step(2.5)
	local result = H.payload(c, "ShowdownEnd")
	T.ok(result, "the ring closes")
	T.eq(result.left, true, "this player stepped out")
	T.eq(result.won, false)
	T.eq(Showdown.byPlayer[ann], nil, "cheers are free again")
	T.ok(ball.Parent, "the pet stays")
	T.eq(ball:GetAttribute("NeedsPlay"), true)
	-- the Guardian ring works at once (nothing holds the player)
	-- walk back and step in again: what was drained stays drained
	world:walkTo(ann, V3.new(-60, 403, 0))
	Mock.step(1)
	c:clear()
	c:fire("WildJoin", id)
	Mock.step(0.5)
	local snap = H.payload(c, "ShowdownState")
	T.ok(snap and snap.mine, "joined again")
	T.ok(snap.left <= left, "the meter did not refill")
	-- going home also steps out
	H.lift(world, ann, c, 0)
	Mock.step(1)
	T.eq(Showdown.byPlayer[ann], nil)
	H.clean("walk away")
end

function tests.e04_wild_pet_leaves_with_the_meter_half_full()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	H.lift(world, ann, c, 1)
	world:walkTo(ann, V3.new(-60, 403, 0))
	local ball, id = spawnWild(world, c, "Legendary") -- stays 90 s; this team needs about 31 s to empty the meter
	Mock.step(72)
	c:clear()
	c:fire("WildJoin", id)
	Mock.step(1)
	T.ok(H.payload(c, "ShowdownState").mine)
	local coins, pets = H.profile(world, ann).coins, #H.profile(world, ann).pets
	T.ok(H.waitFor(c, "ShowdownEnd", 45), "the pet leaves")
	local result = H.payload(c, "ShowdownEnd")
	T.eq(result.won, false)
	T.eq(result.left, nil, "the pet left, the player did not")
	T.eq(ball.Parent, nil)
	T.eq(H.svc(world, "ShowdownService").byPlayer[ann], nil)
	T.eq(H.profile(world, ann).coins, coins, "nothing is lost")
	T.eq(#H.profile(world, ann).pets, pets)
	T.eq(H.profile(world, ann).stats.wild.finished, 0)
	Mock.step(5)
	H.clean("pet leaves")
end

-- Secret pets --------------------------------------------------------------------------------------------
function tests.f01_secret_chime_spawns_its_pet_on_the_clock()
	Mock.reset(H.FRIDAY_14)
	local probe = Mock.newWorld()
	local SecretCore = probe.server:require("Core", "SecretCore")
	local day = math.floor(H.FRIDAY_14 / 86400) + 1
	local at = day * 86400 + SecretCore.chimes(day, 1)[2] -- floor 1's second chime of the next day
	probe.dead = true
	Mock.setTime(at - 70)
	local world = H.boot()
	local ann, c = H.join(world, 101, "Ann")
	T.eq(#c:got("SecretChime"), 0, "nothing is said before the glow")
	Mock.step(6)
	local chimes = {}
	for _, args in ipairs(c:got("SecretChime")) do if args[1].floor == 1 then chimes[#chimes + 1] = args[1] end end
	T.eq(#chimes, 1)
	T.eq(chimes[1].phase, "glow")
	T.eq(chimes[1].at, at)
	T.eq(chimes[1].leaves, at + 180)
	T.eq(H.findPet(world, 1, "Secret"), nil, "no pet during the glow")
	-- a player who joins during the glow is told too
	local bob, cb = H.join(world, 102, "Bob", 1)
	T.eq(H.payload(cb, "SecretChime").phase, "glow")
	Mock.step(at + 1.5 - Mock.now)
	local ball = H.findPet(world, 1, "Secret")
	T.ok(ball, "the Secret pet is on the floor")
	T.eq(ball:GetAttribute("Species"), "Lanternlamb")
	T.eq(ball:GetAttribute("NeedsPlay"), true)
	T.ok(ball:FindFirstChild("Pillar"))
	T.near(ball:GetAttribute("Leaves"), at + 180, 1.01)
	T.eq(H.payload(c, "SecretChime").phase, "here")
	local pillars = 0
	for _, b in ipairs(H.banners(c, "pillar")) do if b.rarity == "Secret" then pillars = pillars + 1 T.eq(b.floor, 1) end end
	T.eq(pillars, 1, "one banner")
	-- a player who joins during the visit is told it is here
	local cat, cc = H.join(world, 103, "Cat", 1)
	T.eq(H.payload(cc, "SecretChime").phase, "here")
	Mock.step(at + 183 - Mock.now)
	T.eq(ball.Parent, nil, "the pet has left")
	T.eq(H.payload(c, "SecretChime").phase, "gone")
	local secrets = 0
	for _, e in ipairs(world.sent) do
		if e.name == "Banner" and e.args[1].rarity == "Secret" and e.player == ann then secrets = secrets + 1 end
	end
	T.eq(secrets, 1, "one spawn per chime")
	H.clean("secret chime")
end

-- M5: reasons to come back ---------------------------------------------------------------------------------
local function dayOne()
	local world = H.fresh(H.FRIDAY_14, { studio = false, jobId = "server-A" })
	local ann, c = H.ready(world, 101, "Ann")
	Mock.step(70) -- the first egg starts within a minute of choosing the starter
	return world, ann, c
end
local function dayTwo(studio)
	Mock.setTime(H.SATURDAY_06)
	local world = H.boot({ studio = studio or false, jobId = studio and "" or "server-B" })
	local ann, c = H.join(world, 101, "Ann")
	return world, ann, c
end

function tests.g01_save_on_leave_then_rejoin_on_a_second_server_keeps_everything()
	local world, ann, c = dayOne()
	H.lift(world, ann, c, 1)
	local rare = H.findPet(world, 1, "Rare", true)
	H.walkNear(world, ann, rare.Position, 4)
	c:fire("TryStart", rare:GetAttribute("PetId"))
	Mock.step(0.05)
	T.ok(H.playTry(world, c).success)
	H.lift(world, ann, c, 0)
	c:fire("Feed")
	Mock.step(0.5)
	local p = H.profile(world, ann)
	local was = { coins = p.coins, pets = #p.pets, level = p.starter.level, pad1 = p.pads[1].pet, pad2 = p.pads[2].pet, tutorial = p.tutorial,
		team = #p.team, catches = p.stats.catches, egg = p.egg.start, firstJoin = p.firstJoin }
	T.eq(was.pets, 2)
	T.eq(was.level, 2)
	world:removePlayer(ann)
	Mock.step(1)
	T.eq(H.profile(world, ann), nil, "the profile is released")
	T.eq(H.camp(world, ann), nil, "the camp is free")
	local row = Mock.stores.PetTower_PlayerData_v1.u_101
	T.ok(row and row.data, "saved")
	T.eq(row.lock, nil, "the lock is given back")
	H.clean("leave")
	world:shutdown()
	-- a second server, a minute later
	Mock.setTime(Mock.now + 60)
	local world2 = H.boot({ studio = false, jobId = "server-B" })
	local ann2, c2 = H.join(world2, 101, "Ann")
	local q = H.profile(world2, ann2)
	T.ok(q, "loaded on the second server")
	T.eq(q.coins, was.coins)
	T.eq(#q.pets, was.pets)
	T.eq(q.starter.level, was.level)
	T.eq(q.starter.species, "Pandle")
	T.eq(q.pads[1].pet, was.pad1)
	T.eq(q.pads[2].pet, was.pad2)
	T.eq(q.tutorial, was.tutorial)
	T.eq(#q.team, was.team)
	T.eq(q.stats.catches, was.catches)
	T.eq(q.egg.start, was.egg)
	T.eq(q.firstJoin, was.firstJoin)
	T.eq(q.index.Zipwing, true)
	T.eq(q.journeyDay, 1, "the same day")
	-- the world shows it: pets on the pads, the starter at the player's side, no first-pet tutorial again
	T.ok(H.camp(world2, ann2).pads[2]:FindFirstChild("PadPet"), "pad pets are shown")
	T.ok(ann2.Character:FindFirstChild("StarterPet"))
	T.eq(H.tutorialPart(world2, ann2), nil)
	T.eq(H.state(c2).coins, was.coins)
	T.eq(Mock.stores.PetTower_PlayerData_v1.u_101.lock.job, "server-B")
	H.clean("rejoin")
end

function tests.g02_two_servers_cannot_hold_the_same_profile()
	local world, ann, c = dayOne()
	T.eq(Mock.stores.PetTower_PlayerData_v1.u_101.lock.job, "server-A")
	local world2 = H.boot({ studio = false, jobId = "server-B" })
	local twin, c2 = H.join(world2, 101, "Ann", 1)
	T.eq(H.profile(world2, twin), nil, "the second server does not get the profile")
	Mock.step(20) -- it waits and tries four more times
	T.eq(#world2.kicks, 1, "the second session is asked to join again later")
	T.ok(string.find(world2.kicks[1].message, "safe"), "with a kind message")
	T.eq(twin.Parent, nil)
	T.eq(H.count(c2, "State"), 0, "no state was ever sent")
	T.eq(Mock.stores.PetTower_PlayerData_v1.u_101.lock.job, "server-A", "the lock is still the first server's")
	H.clean("second server")
	-- the first server still saves and plays
	c:fire("Collect")
	Mock.step(130) -- past an autosave
	H.clean("first server carries on")
	local coins = H.profile(world, ann).coins
	world:removePlayer(ann)
	Mock.step(1)
	T.eq(Mock.stores.PetTower_PlayerData_v1.u_101.data.coins, coins)
	-- now the second server may have it
	local again = H.join(world2, 101, "Ann")
	T.ok(H.profile(world2, again), "free after the first server let go")
	T.eq(H.profile(world2, again).coins, coins)
	H.clean("handed over")
end

function tests.g03_return_after_16_hours_chest_rested_journey_day_2()
	local world, ann, c = dayOne()
	local coins = H.profile(world, ann).coins
	world:shutdown()
	T.eq(world.closeStuck, 0, "the shutdown save finished")
	T.ok(world.closeSeconds < 25, "inside the shutdown window")
	H.clean("day one")
	local world2, ann2, c2 = dayTwo()
	local w = H.payload(c2, "Welcome")
	T.ok(w, "welcome back")
	T.ok(w.away > 15.9 * 3600 and w.away < 16.1 * 3600, "away 16 hours")
	T.eq(w.chest, 3600, "4 hours of 1 coin a second at 25%")
	T.eq(w.rested, true)
	T.eq(w.newDay, true)
	T.eq(w.journeyDay, 2)
	T.eq(w.ladderCoins, 360, "day 2: 6 minutes of income")
	T.eq(w.egg.state, "ready")
	T.eq(w.tomorrow.minutes, 7)
	T.eq(w.tomorrow.look, "aura_spark")
	local p = H.profile(world2, ann2)
	T.eq(p.journeyDay, 2)
	T.eq(p.coins, coins + 3600 + 360)
	T.eq(H.state(c2).coins, p.coins, "the HUD has the gifts")
	T.ok(p.stats.funnel.Day2Return, "funnel: day 2 return")
	T.eq(c2:last("State")[2].coinMult, 2, "rested: x2 coins")
	-- rested doubles pad income for 10 minutes
	c2:clear()
	c2:fire("Collect")
	Mock.step(0.1)
	T.eq(c2:got("Coins")[1][1], 2 * 600, "the pad held its 10 minutes while away, doubled")
	Mock.step(20)
	c2:fire("Collect")
	Mock.step(0.1)
	local got = c2:got("Coins")[2][1]
	T.ok(got >= 2 * 20 and got <= 2 * 21, "x2 on the pads, got " .. got)
	Mock.step(600)
	c2:fire("Collect")
	Mock.step(0.1)
	T.eq(c2:last("State")[2].coinMult, 1, "the rested bonus has run out")
	H.clean("return")
end

function tests.g04_mystery_egg_hatches()
	local world, ann, c = dayOne()
	T.ok(H.profile(world, ann).egg, "an egg is warming")
	-- not ready yet
	local camp = H.camp(world, ann)
	H.walkToPart(world, ann, camp.EggNest)
	world:trigger(camp.EggNestPrompt, ann)
	c:fire("HatchEgg")
	Mock.step(0.5)
	T.eq(H.count(c, "EggHatched"), 0, "an egg takes 8 hours")
	world:shutdown()
	local world2, ann2, c2 = dayTwo()
	local p = H.profile(world2, ann2)
	local pets = #p.pets
	camp = H.camp(world2, ann2)
	H.walkToPart(world2, ann2, camp.EggNest)
	world2:trigger(camp.EggNestPrompt, ann2)
	Mock.step(0.5)
	local hatched = c2:got("EggHatched")
	T.eq(#hatched, 1)
	T.eq(#p.pets, pets + 1)
	local pet = p.pets[#p.pets]
	T.eq(hatched[1][1].species, pet.species)
	T.eq(hatched[1][1].rarity, pet.rarity)
	T.eq(p.index[pet.species], true)
	T.eq(p.spare[#p.spare], pet.id, "the pet waits at camp")
	T.ok(p.egg and p.egg.start == math.floor(Mock.now) or p.egg.start <= Mock.now, "the new day's egg starts at once")
	c2:fire("HatchEgg")
	Mock.step(0.5)
	T.eq(H.count(c2, "EggHatched"), 1, "one egg a day")
	H.clean("egg")
end

-- The week -------------------------------------------------------------------------------------------------
function tests.h01_weekly_guardian_join_win_and_choice()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	local bob, cb = H.ready(world, 102, "Bob")
	H.debug(c, "level", 10)
	local ring = world.workspace.PetTowerWorld.WeeklyRing
	world:walkTo(ann, V3.new(ring.Position.X, 3, ring.Position.Z))
	c:clear() cb:clear()
	world:touch(ring, ann)
	Mock.step(0.3)
	local snap = H.payload(c, "ShowdownState")
	T.ok(snap, "the weekly showdown starts in the hub ring")
	T.eq(snap.kind, "weekly")
	T.eq(snap.floor, 0)
	T.eq(snap.count, 1)
	T.near(snap.ends - snap.start, 40, 1e-9)
	H.cheerUntil(world, { c }, snap, "ShowdownEnd", 45) -- alone it takes near-perfect cheers
	local result = H.payload(c, "ShowdownEnd")
	T.ok(result, "it ends")
	T.eq(result.kind, "weekly")
	T.ok(result.won, "won with Perfect cheers")
	T.ok(result.firstClear, "the first win of the week")
	T.eq(H.count(c, "WeeklyChoice"), 1)
	local p = H.profile(world, ann)
	local WeeklyCore = H.core(world, "WeeklyCore")
	local week = WeeklyCore.week(Mock.now)
	T.eq(p.weekly.wonWeek, week)
	T.eq(p.looks["weekly_" .. (week % 52)], true, "the week's look")
	-- share
	c:clear() cb:clear()
	c:fire("ChooseWeekly", "maybe")
	Mock.step(2.1)
	T.eq(H.count(c, "Coins"), 0)
	c:fire("ChooseWeekly", "share")
	Mock.step(0.2)
	T.eq(c:got("Coins")[1][2], "share")
	T.eq(cb:got("Coins")[1][2], "share")
	T.eq(cb:got("Shared")[1][1].name, "Ann")
	T.eq(p.dawn, 1)
	Mock.step(2.1)
	c:fire("ChooseWeekly", "share")
	Mock.step(0.2)
	T.eq(H.count(c, "Coins"), 1, "one choice per win")
	-- the scale: the point reaches the shared tally within a minute
	Mock.step(61)
	local wk = H.payload(cb, "Week")
	T.eq(wk.week, week)
	T.eq(wk.tally.dawn, 1)
	T.eq(wk.tally.dusk, 0)
	T.eq(Mock.stores.PetTower_Global_v1["tally_" .. week].dawn, 1)
	-- a second win the same week is not a first
	c:clear()
	world:walkTo(ann, V3.new(ring.Position.X, 3, ring.Position.Z))
	world:touch(ring, ann)
	Mock.step(0.3)
	H.cheerUntil(world, { c }, H.payload(c, "ShowdownState"), "ShowdownEnd", 45)
	T.ok(H.payload(c, "ShowdownEnd").won)
	T.no(H.payload(c, "ShowdownEnd").firstClear)
	T.eq(H.count(c, "WeeklyChoice"), 0)
	H.clean("weekly guardian")
end

function tests.h02_merchant_buy_on_a_saturday()
	-- Friday: closed
	local world = H.fresh(H.FRIDAY_14)
	local ann, c = H.ready(world, 101, "Ann")
	H.debug(c, "coins", 5000)
	T.eq(H.payload(c, "Week").merchantOpen, false)
	c:fire("MerchantBuy", 2)
	Mock.step(0.3)
	T.eq(#H.profile(world, ann).pets, 1, "closed on a Friday")
	world:shutdown()
	-- Saturday: open
	Mock.setTime(H.SATURDAY_06)
	local world2 = H.boot()
	local ann2, c2 = H.join(world2, 101, "Ann")
	local wk = H.payload(c2, "Week")
	T.eq(wk.merchantOpen, true)
	T.eq(#wk.items, 3)
	T.eq(wk.items[2].kind, "pet")
	T.eq(wk.items[2].id, "Zipwing")
	T.eq(wk.items[2].price, 900)
	T.eq(wk.items[2].bought, false)
	local p = H.profile(world2, ann2)
	local coins = p.coins
	c2:clear()
	c2:fire("MerchantBuy", 2)
	Mock.step(0.3)
	T.eq(p.coins, coins - 900)
	T.eq(#p.pets, 2)
	T.eq(p.pets[2].species, "Zipwing")
	T.eq(p.pets[2].rarity, "Rare")
	T.eq(H.payload(c2, "Week").items[2].bought, true, "the tray shows it as bought")
	T.eq(H.payload(c2, "Week").items[1].bought, false)
	c2:fire("MerchantBuy", 2)
	Mock.step(1.1)
	T.eq(p.coins, coins - 900, "one of each per week")
	c2:fire("MerchantBuy", 1) -- the look
	Mock.step(1.1)
	T.eq(p.looks[wk.items[1].id], true)
	T.eq(p.coins, coins - 900 - 1200)
	c2:fire("MerchantBuy", 4)
	c2:fire("MerchantBuy", "2")
	Mock.step(1.1)
	T.eq(p.coins, coins - 900 - 1200)
	H.clean("merchant")
end

function tests.h03_monument_gets_the_first_clears()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	H.debug(c, "level", 12)
	H.lift(world, ann, c, 1)
	toRing(world, ann, 1)
	T.ok(H.waitFor(c, "ShowdownEnd", 45))
	Mock.step(61)
	local wk = H.payload(c, "Week")
	T.eq(wk.monument["1"][1], "Ann", "the first clear is on the monument")
	T.eq(Mock.stores.PetTower_Global_v1.monument["1"][1].userId, 101)
	H.clean("monument")
end

-- Settings, index, closet, mailbox, codes --------------------------------------------------------------------
function tests.i01_settings_index_closet_mailbox()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	local camp = H.camp(world, ann)
	-- settings
	c:fire("SetSetting", "tapAssist", true)
	c:fire("SetSetting", "music", 0)
	Mock.step(0.2)
	local p = H.profile(world, ann)
	T.eq(p.settings.tapAssist, true)
	T.eq(p.settings.music, 0)
	T.eq(H.state(c).settings.tapAssist, true)
	c:fire("SetSetting", "music", 5)
	c:fire("SetSetting", "nope", true)
	c:fire("SetSetting", 5, true)
	c:fire("SetSetting", "effects", "loud")
	Mock.step(0.2)
	T.eq(p.settings.music, 0)
	T.eq(p.settings.effects, 1)
	-- index: remote and board
	c:fire("IndexOpen")
	Mock.step(0.2)
	local view = H.payload(c, "Index")
	T.eq(view.caught, 2, "the starter and the first pet")
	T.eq(view.total, 28)
	T.eq(#view.floors, 5)
	T.eq(#view.floors[1].pets, 5)
	T.eq(view.floors[1].pets[1].caught, true)
	T.eq(view.floors[1].pets[1].odds, 60)
	T.eq(view.floors[1].pets[5].caught, false)
	H.walkToPart(world, ann, camp.IndexBoard)
	world:trigger(camp.IndexBoardPrompt, ann)
	Mock.step(0.2)
	T.eq(H.count(c, "Index"), 2)
	T.eq(c:last("State")[2].index[1], 2)
	-- mailbox
	c:fire("MailOpen")
	Mock.step(0.2)
	local mail = H.payload(c, "Mail")
	T.eq(mail.journeyDay, 1)
	T.eq(mail.tomorrow.minutes, 6)
	T.eq(mail.codes, false, "no codes yet: the box is hidden")
	T.ok(mail.egg.state == "none" or mail.egg.state == "warming")
	H.walkToPart(world, ann, camp.Mailbox)
	world:trigger(camp.MailboxPrompt, ann)
	Mock.step(0.2)
	T.eq(H.count(c, "Mail"), 2)
	-- closet
	p.looks.aura_spark = true -- as if the journey ladder had given it
	H.walkToPart(world, ann, camp.Closet)
	world:trigger(camp.ClosetPrompt, ann)
	Mock.step(0.2)
	local closet = H.payload(c, "Closet")
	T.eq(#closet.looks, 1)
	T.eq(closet.looks[1], "aura_spark")
	T.eq(next(closet.equipped), nil)
	c:fire("Equip", "aura_spark")
	Mock.step(0.2)
	T.eq(p.equipped.aura, "aura_spark")
	T.eq(ann:GetAttribute("Aura"), "aura_spark")
	T.eq(H.payload(c, "Closet").equipped.aura, "aura_spark")
	c:fire("Equip", "trail_star") -- not owned
	c:fire("Equip", 12)
	Mock.step(0.2)
	T.eq(p.equipped.trail, nil)
	c:fire("Equip", "", "aura")
	Mock.step(0.2)
	T.eq(p.equipped.aura, nil)
	T.eq(ann:GetAttribute("Aura"), "")
	-- someone else's stations do nothing
	local bob, cb = H.join(world, 102, "Bob")
	world:walkTo(bob, H.pos(world, ann))
	world:trigger(camp.ClosetPrompt, bob)
	Mock.step(0.2)
	T.eq(H.count(cb, "Closet"), 0)
	H.clean("settings, index, closet, mailbox")
end

function tests.i02_codes_redeem_once()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	local Config = config(world)
	c:fire("RedeemCode", "HELLO")
	Mock.step(0.3)
	T.eq(H.profile(world, ann).coins, 50, "no codes exist")
	Config.Codes.HELLO = { seconds = 600 }
	Config.Codes.SPARK = { look = "aura_spark" }
	Mock.step(5)
	c:fire("RedeemCode", "hello")
	Mock.step(0.3)
	T.eq(H.profile(world, ann).coins, 50 + 600)
	Mock.step(5)
	c:fire("RedeemCode", "HELLO")
	Mock.step(0.3)
	T.eq(H.profile(world, ann).coins, 650, "once per player")
	Mock.step(5)
	c:fire("RedeemCode", "SPARK")
	c:fire("RedeemCode", { "SPARK" })
	Mock.step(0.3)
	T.eq(H.profile(world, ann).looks.aura_spark, true)
	c:fire("MailOpen")
	Mock.step(0.2)
	T.eq(H.payload(c, "Mail").codes, true)
	Config.Codes.HELLO, Config.Codes.SPARK = nil, nil
	H.clean("codes")
end

-- M6 -------------------------------------------------------------------------------------------------------
function tests.j01_purchase_receipt_is_processed_once()
	local world = H.fresh(H.FRIDAY_14, { studio = false, jobId = "server-A" })
	local ann, c = H.ready(world, 101, "Ann")
	local Config = config(world)
	local Enum = Mock.Enum
	-- a product nobody knows: not processed, nothing granted
	local r0 = world:purchase(ann, 555, "receipt-0")
	Mock.step(0.5)
	T.eq(r0.decision, Enum.ProductPurchaseDecision.NotProcessedYet)
	Config.Shop.ProductCatalog[555] = { kind = "coins", seconds = 1800 }
	local coins = H.profile(world, ann).coins
	local r1 = world:purchase(ann, 555, "receipt-1")
	Mock.step(0.5)
	T.eq(r1.decision, Enum.ProductPurchaseDecision.PurchaseGranted)
	T.eq(H.profile(world, ann).coins, coins + 1800, "30 minutes of 1 coin a second")
	T.eq(H.state(c).coins, coins + 1800)
	T.ok(Mock.stores.PetTower_PlayerData_v1.u_101.data.purchases["receipt-1"], "saved with the grant before answering")
	T.eq(Mock.stores.PetTower_PlayerData_v1.u_101.data.coins, coins + 1800)
	-- Roblox asks again about the same receipt: already granted
	local r2 = world:purchase(ann, 555, "receipt-1")
	Mock.step(0.5)
	T.eq(r2.decision, Enum.ProductPurchaseDecision.PurchaseGranted)
	T.eq(H.profile(world, ann).coins, coins + 1800, "granted once")
	-- and again after a rejoin on another server
	world:shutdown()
	Mock.setTime(Mock.now + 30)
	local world2 = H.boot({ studio = false, jobId = "server-B" })
	local ann2 = H.join(world2, 101, "Ann")
	config(world2).Shop.ProductCatalog[555] = { kind = "coins", seconds = 1800 }
	local before = H.profile(world2, ann2).coins
	local r3 = world2:purchase(ann2, 555, "receipt-1")
	Mock.step(0.5)
	T.eq(r3.decision, Enum.ProductPurchaseDecision.PurchaseGranted)
	T.eq(H.profile(world2, ann2).coins, before, "still granted once")
	-- the save fails: the receipt is not acknowledged (Roblox will ask again)
	Mock.datastore.fail = function() return "DataStore request was throttled" end
	local r4 = world2:purchase(ann2, 555, "receipt-2")
	Mock.step(15)
	T.eq(r4.decision, Enum.ProductPurchaseDecision.NotProcessedYet)
	Mock.datastore.fail = nil
	-- a receipt for a player who is not here
	local r5 = { decision = nil }
	world2.server:run(function()
		r5.decision = world2.services.MarketplaceService.ProcessReceipt({ PlayerId = 999, PurchaseId = "x", ProductId = 555 })
	end)
	Mock.step(0.5)
	T.eq(r5.decision, Enum.ProductPurchaseDecision.NotProcessedYet)
	H.clean("receipts")
end

function tests.j02_shop_is_off_and_passes_apply_when_owned()
	local world = H.fresh()
	local Config = config(world)
	T.eq(Config.Shop.Approved, false, "nothing is for sale")
	Config.Shop.PassIds.CampPads8 = 7001
	Config.Shop.PassIds.DoubleCoins = 7002
	world.passes["101:7001"] = true
	local ann, c = H.join(world, 101, "Ann")
	local p = H.profile(world, ann)
	T.eq(#p.pads, 16, "the pad pass adds 8 pads")
	T.eq(p.passes.CampPads8, true)
	T.eq(p.passes.DoubleCoins, nil)
	T.eq(H.camp(world, ann).pads[16].Transparency, 0)
	-- bought in game
	world.passes["101:7002"] = true
	world.services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(ann, 7002, true)
	Mock.step(0.5)
	T.eq(p.passes.DoubleCoins, true)
	T.eq(c:last("State")[2].coinMult, 2)
	Config.Shop.PassIds.CampPads8, Config.Shop.PassIds.DoubleCoins = nil, nil
	H.clean("passes")
end

-- Debug, leaving, data store trouble ---------------------------------------------------------------------------
function tests.k01_debug_commands_are_ignored_in_a_live_game()
	local world = H.fresh(H.FRIDAY_14, { studio = false, jobId = "live-1" })
	local ann, c = H.ready(world, 101, "Ann")
	local p = H.profile(world, ann)
	local coins, pets = p.coins, #H.petParts(world, 1)
	c:fire("Debug", "coins", 1000000)
	c:fire("Debug", "level", 42)
	c:fire("Debug", "clear", 5)
	c:fire("Debug", "spawn", "Secret")
	c:fire("Debug", "wipe")
	Mock.step(1)
	T.eq(p.coins, coins)
	T.eq(p.starter.level, 1)
	T.eq(p.cleared, 0)
	T.eq(#H.petParts(world, 1), pets)
	for _, line in ipairs(Mock.prints) do T.no(string.find(line, "debug"), "no debug output in a live game") end
	H.clean("live debug")
	-- and they work in Studio
	local studio = H.fresh()
	local bea, cb = H.ready(studio, 102, "Bea")
	cb:fire("Debug", "coins", 1000)
	Mock.step(0.3)
	T.eq(H.profile(studio, bea).coins, 1050)
	cb:fire("Debug", "nonsense", 1)
	cb:fire("Debug", 5)
	Mock.step(0.3)
	H.clean("studio debug")
end

function tests.k02_leaving_mid_try_and_mid_showdown_does_not_error()
	local world = H.fresh()
	local ann, ca = H.ready(world, 101, "Ann")
	local bob, cb = H.ready(world, 102, "Bob")
	local cat, cc = H.ready(world, 103, "Cat")
	H.debug(ca, "level", 9)
	H.debug(cb, "level", 9)
	for _, pc in ipairs({ { ann, ca }, { bob, cb }, { cat, cc } }) do H.lift(world, pc[1], pc[2], 1) end
	-- Cat leaves in the middle of a try
	local rare = H.findPet(world, 1, "Rare", true)
	H.walkNear(world, cat, rare.Position, 4)
	cc:fire("TryStart", rare:GetAttribute("PetId"))
	Mock.step(0.3)
	T.ok(H.payload(cc, "TryBegin"))
	world:removePlayer(cat)
	Mock.step(10)
	H.clean("left mid-try")
	T.eq(H.svc(world, "PetService").tries[cat], nil)
	-- Ann and Bob start a Guardian showdown, Bob leaves in the middle
	toRing(world, ann, 1)
	Mock.step(0.3)
	toRing(world, bob, 1)
	Mock.step(3)
	world:removePlayer(bob)
	T.ok(H.waitFor(ca, "ShowdownEnd", 45), "the showdown still ends for Ann")
	H.clean("left mid-showdown")
	T.eq(H.svc(world, "ShowdownService").byPlayer[bob], nil)
end

function tests.k03_leaving_mid_wild_showdown_and_while_loading()
	local world = H.fresh()
	local ann, ca = H.ready(world, 101, "Ann")
	local bob, cb = H.ready(world, 102, "Bob")
	H.lift(world, ann, ca, 1)
	H.lift(world, bob, cb, 1)
	world:walkTo(ann, V3.new(-60, 403, 0))
	world:walkTo(bob, V3.new(-60, 403, 0))
	local ball, id = spawnWild(world, ca, "Legendary")
	ca:fire("WildJoin", id)
	cb:fire("WildJoin", id)
	Mock.step(2)
	world:removePlayer(bob)
	Mock.step(5)
	T.eq(H.payload(ca, "ShowdownState").count, 1, "Bob's team stepped out with him")
	H.clean("left mid wild showdown")
	world:removePlayer(ann)
	Mock.step(120)
	H.clean("everyone left")
	-- a player who leaves before the save has loaded
	local dee = world:addPlayer({ UserId = 104, Name = "Dee" })
	world:removePlayer(dee)
	Mock.step(10)
	T.eq(H.profile(world, dee), nil)
	T.eq(H.camp(world, dee), nil)
	T.eq(Mock.stores.PetTower_PlayerData_v1.u_104.lock, nil, "the lock taken while loading is given back")
	H.clean("left while loading")
	-- seven players fill the camps; they all leave; the camps are free again
	local seven = {}
	for i = 1, 7 do seven[i] = H.join(world, 300 + i, "S" .. i, 1) end
	Mock.step(5)
	for i = 1, 7 do T.ok(H.camp(world, seven[i]), "camp for player " .. i) end
	for i = 1, 7 do world:removePlayer(seven[i]) end
	Mock.step(5)
	H.clean("seven players")
end

function tests.k04_datastore_down()
	-- Studio without API access: play goes on in memory, with one warning
	Mock.reset(H.FRIDAY_14)
	Mock.datastore.fail = function() return "403: Studio access to APIs is not allowed" end
	local world = H.boot({ studio = true })
	T.eq(H.expectWarning("DataStore unavailable in Studio"), 1)
	local ann, c = H.ready(world, 101, "Ann")
	T.ok(H.profile(world, ann).starter, "the game is playable")
	world:removePlayer(ann)
	Mock.step(2)
	local again = H.join(world, 101, "Ann")
	T.ok(H.profile(world, again).starter, "kept for the session")
	H.clean("studio, no data store")
	-- a live server whose store is down: nobody gets a blank profile
	Mock.reset(H.FRIDAY_14)
	Mock.datastore.fail = function() return "502: API Services rejected request" end
	local live = H.boot({ studio = false, jobId = "live-1" })
	local bea, cb = H.join(live, 102, "Bea", 30)
	T.eq(H.profile(live, bea), nil, "no blank profile is handed out")
	T.eq(#live.kicks, 1)
	T.eq(H.count(cb, "State"), 0)
	H.clean("live, store down")
end

function tests.k05_analytics_calls_are_well_formed()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	Mock.step(30)
	c:fire("Collect")
	Mock.step(0.3)
	c:fire("Feed")
	Mock.step(0.3)
	local steps, sources, sinks = {}, 0, 0
	for _, e in ipairs(world.analytics) do
		if e.kind == "funnel" then steps[#steps + 1] = e.stepName
		elseif e.flow == "Source" then sources = sources + 1 T.eq(e.sku, "pads") T.eq(e.currency, "Coins") T.eq(e.transaction, "Gameplay")
		else sinks = sinks + 1 T.eq(e.sku, "feed") T.eq(e.amount, 10) end
	end
	T.eq(table.concat(steps, ","), "Joined,StarterChosen,FirstCatch,FirstPetPlaced")
	T.eq(sources, 1)
	T.eq(sinks, 1)
	Mock.step(600)
	T.eq(world.analytics[#world.analytics].stepName, "Session10Min")
	H.clean("analytics")
end

function tests.k06_camp_stations_buy_upgrades()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	H.debug(c, "coins", 10000)
	local camp = H.camp(world, ann)
	local p = H.profile(world, ann)
	H.walkToPart(world, ann, camp.PadPost)
	world:trigger(camp.PadPostPrompt, ann)
	Mock.step(0.3)
	T.eq(#p.pads, 12)
	T.eq(camp.pads[12].Transparency, 0, "the new pads show")
	T.eq(camp.pads[13].Transparency, 1)
	H.walkToPart(world, ann, camp.StackHook)
	world:trigger(camp.StackHookPrompt, ann)
	Mock.step(0.3)
	T.eq(c:last("State")[2].stackCap, 4)
	H.walkToPart(world, ann, camp.CharmBench)
	world:trigger(camp.CharmBenchPrompt, ann)
	Mock.step(0.3)
	T.eq(p.charm, 1, "the Floor 2 charm needs Floor 2")
	c:fire("Buy", "stack")
	c:fire("Buy", "nothing")
	c:fire("Buy")
	Mock.step(0.3)
	T.eq(c:last("State")[2].stackCap, 5)
	-- hearts, team, place, release
	c:fire("Heart", 1)
	Mock.step(0.3)
	T.eq(p.pets[1].hearts, 1)
	c:fire("Place", 1, 3)
	Mock.step(0.3)
	T.eq(p.pads[3].pet, 1)
	T.ok(camp.pads[3]:FindFirstChild("PadPet"))
	T.eq(camp.pads[1]:FindFirstChild("PadPet"), nil)
	c:fire("SetTeam")
	Mock.step(0.3)
	T.eq(#p.team, 0)
	c:fire("Release", 1)
	Mock.step(0.3)
	T.eq(#p.pets, 0)
	T.eq(camp.pads[3]:FindFirstChild("PadPet"), nil)
	c:fire("Heart", 99) c:fire("Place", 99, 1) c:fire("Place", 1, 99) c:fire("Release", "x") c:fire("SetTeam", "a", {})
	Mock.step(0.5)
	H.clean("camp stations")
end

-- More corners ---------------------------------------------------------------------------------------------
function tests.m01_a_player_in_a_wild_showdown_cannot_start_a_guardian_showdown()
	local world = H.fresh()
	local ann, ca = H.ready(world, 101, "Ann")
	local bob, cb = H.ready(world, 102, "Bob")
	H.debug(cb, "level", 12)
	H.lift(world, ann, ca, 1)
	H.lift(world, bob, cb, 1)
	-- Ann plays with a Legendary right next to the Guardian ring
	local ring = H.floor(world, 1).ring
	world:walkTo(ann, V3.new(ring.Position.X - 12, 403, ring.Position.Z))
	local ball, id = spawnWild(world, ca, "Legendary")
	ca:fire("WildJoin", id)
	Mock.step(1)
	local Showdown = H.svc(world, "ShowdownService")
	T.ok(Showdown.byPlayer[ann], "Ann is in the wild showdown")
	toRing(world, ann, 1)
	Mock.step(0.5)
	T.eq(Showdown.active[1], nil, "no Guardian showdown starts with nobody in it")
	-- so Bob, walking in 20 s later, gets a whole showdown, not the tail of an empty one
	Mock.step(20)
	cb:clear()
	toRing(world, bob, 1)
	Mock.step(0.1)
	local snap = H.payload(cb, "ShowdownState")
	T.ok(snap, "Bob's showdown starts")
	T.near(snap.start, Mock.now, 0.2, "it starts when he walks in")
	T.eq(snap.left > 700, true, "with a full meter")
	T.ok(H.waitFor(cb, "ShowdownEnd", 45))
	T.ok(H.payload(cb, "ShowdownEnd").won)
	H.clean("no empty showdown")
end

function tests.m02_seven_players_in_the_guardian_ring()
	local world = H.fresh()
	local players, clients = {}, {}
	for i = 1, 7 do
		players[i], clients[i] = H.ready(world, 400 + i, "S" .. i)
		H.lift(world, players[i], clients[i], 1)
	end
	for i = 1, 7 do clients[i]:clear() toRing(world, players[i], 1) Mock.step(0.3) end
	T.eq(H.payload(clients[7], "ShowdownState").count, 7)
	H.cheerUntil(world, clients, H.payload(clients[1], "ShowdownState"), "ShowdownEnd", 45)
	for i = 1, 7 do
		T.ok(H.payload(clients[i], "ShowdownEnd").won, "seven Lv 1 teams win together")
		T.eq(H.payload(clients[i], "ShowdownEnd").count, 7)
		T.eq(H.payload(clients[i], "ClipMoment").kind, "guardian7", "a moment worth a clip")
		T.eq(H.profile(world, players[i]).cleared, 1)
	end
	H.clean("seven in the ring")
end

function tests.m03_so_close_on_a_legendary_and_a_late_join()
	local world = H.fresh()
	local ann, ca = H.ready(world, 101, "Ann")
	local bob, cb = H.ready(world, 102, "Bob")
	H.debug(ca, "level", 12)
	H.lift(world, ann, ca, 1)
	H.lift(world, bob, cb, 1)
	world:walkTo(ann, V3.new(-60, 403, 0))
	world:walkTo(bob, V3.new(-60, 403, 0))
	local ball, id = spawnWild(world, ca, "Legendary")
	ca:clear() cb:clear()
	ca:fire("WildJoin", id)
	T.ok(H.waitFor(ca, "ShowdownEnd", 20))
	-- Bob asks after the meter is empty: too late, he did not play
	cb:fire("WildJoin", id)
	Mock.step(0.5)
	cb:fire("TryStart", id)
	Mock.step(0.5)
	T.eq(H.count(cb, "TryBegin"), 0)
	T.eq(H.svc(world, "ShowdownService").byPlayer[bob], nil)
	-- Ann misses the last ring of a Legendary: "so close"
	ca:fire("TryStart", id)
	Mock.step(0.05)
	local result = H.playTry(world, ca, { "Perfect", "Perfect", "Miss" })
	T.no(result.success)
	T.ok(result.lastBeatMiss)
	T.eq(H.payload(ca, "ClipMoment").kind, "so_close")
	T.eq(#H.profile(world, ann).stack, 0)
	-- after three failed tries in a row the rings slow down (assist) until two catches
	H.clean("so close")
end

function tests.m04_pending_choice_is_offered_again_after_a_rejoin()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	H.debug(c, "level", 12)
	H.lift(world, ann, c, 1)
	toRing(world, ann, 1)
	T.ok(H.waitFor(c, "ShowdownEnd", 45))
	world:removePlayer(ann) -- leaves without choosing
	Mock.step(2)
	local ann2, c2 = H.join(world, 101, "Ann")
	T.eq(H.payload(c2, "ChoicePrompt"), 1, "Share or Keep for Floor 1 is offered again")
	T.eq(ann2:GetAttribute("Side"), "")
	c2:fire("Choose", 1, "keep")
	Mock.step(0.3)
	T.eq(H.profile(world, ann2).floors["1"].choice, "keep")
	T.eq(H.count(c2, "ChoicePrompt"), 1, "nothing else is waiting")
	H.clean("pending choice")
end

function tests.m05_weekly_keep_is_silent()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	local bob, cb = H.ready(world, 102, "Bob")
	local ring = world.workspace.PetTowerWorld.WeeklyRing
	world:walkTo(ann, V3.new(ring.Position.X, 3, ring.Position.Z))
	world:walkTo(bob, V3.new(ring.Position.X + 5, 3, ring.Position.Z))
	world:touch(ring, ann)
	Mock.step(0.3)
	world:touch(ring, bob)
	Mock.step(0.3)
	local snap = H.payload(c, "ShowdownState")
	T.eq(snap.count, 2)
	H.cheerUntil(world, { c, cb }, snap, "ShowdownEnd", 45)
	T.ok(H.payload(c, "ShowdownEnd").won and H.payload(cb, "ShowdownEnd").won, "two players with Perfect cheers win")
	c:clear() cb:clear()
	cb:fire("ChooseWeekly", "keep")
	Mock.step(0.3)
	T.eq(cb:got("Coins")[1][2], "keep")
	T.eq(H.count(c, "Coins"), 0)
	T.eq(H.count(c, "Shared"), 0, "keeping is never announced")
	T.eq(H.count(cb, "Shared"), 0)
	T.eq(H.profile(world, bob).dusk, 1)
	T.eq(bob:GetAttribute("Side"), "dusk")
	-- a player who is in the weekly showdown cannot be pulled into another one, and riding away is harmless
	H.clean("weekly keep")
end

function tests.m06_auto_collect_pass_empties_the_pads()
	local world = H.fresh()
	local Config = config(world)
	Config.Shop.PassIds.AutoCollect = 7004
	world.passes["101:7004"] = true
	local ann, c = H.ready(world, 101, "Ann")
	T.eq(H.profile(world, ann).passes.AutoCollect, true)
	c:clear()
	Mock.step(11)
	local pops = c:got("Coins")
	T.ok(#pops >= 2, "the pads empty themselves every 5 s")
	T.eq(pops[1][2], "pads")
	Config.Shop.PassIds.AutoCollect = nil
	H.clean("auto collect")
end

function tests.m07_a_friend_in_the_server_gives_both_more_coins()
	local world = H.fresh()
	world.friends["101:102"] = true
	local ann, ca = H.ready(world, 101, "Ann")
	local bob, cb = H.ready(world, 102, "Bob")
	local cat, cc = H.ready(world, 103, "Cat")
	local Friends = H.svc(world, "FriendService")
	T.ok(Friends.are(101, 102) and Friends.are(102, 101))
	T.no(Friends.are(101, 103))
	T.near(cb:last("State")[2].coinMult, 1.2, 1e-9, "Bob has a friend here")
	T.eq(cc:last("State")[2].coinMult, 1)
	ca:fire("Collect")
	Mock.step(0.2)
	T.near(ca:last("State")[2].coinMult, 1.2, 1e-9, "and so has Ann")
	-- in a showdown a friend's cheer counts double
	H.debug(ca, "level", 8)
	H.debug(cb, "level", 8)
	H.lift(world, ann, ca, 1)
	H.lift(world, bob, cb, 1)
	toRing(world, ann, 1)
	Mock.step(0.3)
	toRing(world, bob, 1)
	Mock.step(0.3)
	local sd = H.svc(world, "ShowdownService").active[1]
	T.eq(sd.players[101].friend, true)
	T.eq(sd.players[102].friend, true)
	T.ok(H.waitFor(ca, "ShowdownEnd", 45))
	-- the friend leaves: the bonus goes with them
	world:removePlayer(bob)
	Mock.step(1)
	T.no(Friends.are(101, 102))
	ca:fire("Collect")
	Mock.step(0.2)
	T.eq(ca:last("State")[2].coinMult, 1)
	-- a friends check that fails is simply "not friends"
	world.friendError = "HTTP 429"
	local dan = H.join(world, 104, "Dan")
	T.no(Friends.are(101, 104))
	H.clean("friends")
end

function tests.m08_respawn_on_a_floor_brings_the_player_home()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	H.lift(world, ann, c, 1)
	T.eq(c:last("State")[2].floor, 1)
	world:walkTo(ann, V3.new(500, -400, 0)) -- fell off the edge
	world:spawnCharacter(ann)
	Mock.step(1)
	T.eq(ann:GetAttribute("Floor"), 0)
	T.near((H.pos(world, ann) - H.camp(world, ann).spawn.Position).Magnitude, 0, 0.01, "back at the camp spawn")
	T.ok(ann.Character:FindFirstChild("StarterPet"), "the starter is at the new character's side")
	c:fire("Collect")
	Mock.step(0.3)
	T.eq(c:last("State")[2].floor, 0, "the client is told the player is at camp")
	H.clean("respawn")
end

function tests.m09_debug_away_then_rejoin_shows_the_welcome_back()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	Mock.step(70)
	H.debug(c, "away", 16)
	H.debug(c, "egg")
	world:removePlayer(ann)
	Mock.step(2)
	local ann2, c2 = H.join(world, 101, "Ann")
	local w = H.payload(c2, "Welcome")
	T.ok(w.away >= 16 * 3600 and w.away < 16 * 3600 + 30, "away 16 hours, got " .. w.away)
	T.eq(w.chest, 3600)
	T.eq(w.rested, true)
	T.eq(w.journeyDay, 2, "16 hours before Friday 14:00 UTC was Thursday: a new day")
	T.eq(w.egg.state, "ready")
	-- the other debug commands
	H.debug(c2, "stack", 7)
	T.eq(c2:last("State")[2].stackCap, 10)
	H.debug(c2, "clear")
	T.eq(H.profile(world, ann2).cleared, 1)
	H.lift(world, ann2, c2, 1)
	H.debug(c2, "radiant")
	local radiant
	for _, ball in ipairs(H.petParts(world, 1)) do if ball:GetAttribute("Radiant") then radiant = ball end end
	T.ok(radiant and radiant:FindFirstChild("Pillar"), "a Radiant pet under a pillar")
	T.eq(radiant.Material, Mock.Enum.Material.Neon)
	H.debug(c2, "wipe")
	T.eq(H.profile(world, ann2).starter, nil)
	T.eq(H.state(c2).coins, 50)
	H.clean("debug commands")
end

function tests.m10_three_misses_turn_the_assist_on()
	local world = H.fresh()
	local ann, c = H.ready(world, 101, "Ann")
	H.lift(world, ann, c, 1)
	local tried = 0
	local last
	for _, ball in ipairs(H.petParts(world, 1)) do
		if tried < 4 and not ball:GetAttribute("NeedsPlay") and ball:GetAttribute("Rarity") == "Common" then
			H.walkNear(world, ann, ball.Position, 4)
			c:fire("TryStart", ball:GetAttribute("PetId"))
			Mock.step(0.6)
			last = H.payload(c, "TryBegin")
			tried = tried + 1
			if tried < 4 then T.no(H.playTry(world, c, { "Miss", "Miss", "Miss" }).success) end
		end
	end
	T.eq(tried, 4, "four Commons to try")
	T.near(last.ringTime, 1.2 * 1.2, 1e-9, "after three misses the rings run 20% slower")
	T.ok(H.playTry(world, c).success)
	H.clean("assist")
end

return tests
