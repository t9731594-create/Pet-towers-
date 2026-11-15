-- Three bots play for 20 fake minutes through real clients: walk to pets (the client starts the tries),
-- tap on the rings with human timing, cheer, ride home, feed, try the Guardian. One of them leaves and
-- comes back. Nothing may error, break an engine rule or warn, and the saves must stay consistent.
-- Set the global SOAK_REPORT = true before running to print how much the bots did.
local H = runfile(ROOT .. "/tests/boot_helpers.lua")
local Mock = H.Mock
local V3 = Mock.Vector3
local Enum = Mock.Enum
local tests = {}

local function newBot(world, userId, name, species)
	local player, client = H.join(world, userId, name, 1)
	world:startClient(player)
	return { world = world, player = player, client = client, species = species, taps = {}, visited = {}, wait = 0, cheerBeat = 0, extra = {},
		Data = H.svc(world, "DataService"), Showdown = H.svc(world, "ShowdownService"), World = H.svc(world, "WorldService") }
end

local function act(bot, noise)
	local world, player, c = bot.world, bot.player, bot.client
	if not player.Parent or not world:root(player) then return end
	local p = bot.Data.get(player)
	if not p then return end
	-- what arrived since the last look: a new try means three taps to make; the last State's extras
	for _, e in ipairs(c.log) do
		if e.name == "TryBegin" then
			local try = e.args[1]
			for i, beat in ipairs(try.beats) do bot.taps[#bot.taps + 1] = try.start + beat + noise(i) end
		elseif e.name == "State" then
			bot.extra = e.args[2]
			bot.coinsSeen, bot.petsSeen = e.args[1].coins, #e.args[1].pets
		end
	end
	c.log = {}
	while bot.taps[1] and bot.taps[1] <= Mock.now do
		table.remove(bot.taps, 1)
		c:input(Enum.UserInputType.Touch)
	end
	-- cheers for the showdown this player is in
	local sd = bot.Showdown.byPlayer[player]
	if sd then
		local beat = math.floor(Mock.now - sd.start + 0.5)
		if beat ~= bot.cheerBeat and math.abs(Mock.now - sd.start - beat) < 0.06 then
			bot.cheerBeat = beat
			c:input(Enum.UserInputType.Touch)
		end
		return
	end
	if #bot.taps > 0 or Mock.now < bot.wait then return end
	local floor = player:GetAttribute("Floor") or 0
	local camp = bot.World.campOf(player)
	if not p.starter then
		H.walkToPart(world, player, camp.pedestals[bot.species].ped)
		world:touch(camp.pedestals[bot.species].ped, player)
		bot.wait = Mock.now + 1
	elseif p.tutorial < 1 then
		local ball = H.tutorialPart(world, player)
		if ball then H.walkNear(world, player, ball.Position, 4) end
		bot.wait = Mock.now + 2
	elseif floor == 0 then
		if #p.stack > 0 then
			H.walkToPart(world, player, camp.pads[1])
			world:touch(camp.pads[1], player)
			bot.wait = Mock.now + 1
		elseif p.coins >= (bot.extra.feedCost or math.huge) and p.starter.level < 14 then
			H.walkToPart(world, player, camp.SnackTable)
			world:trigger(camp.SnackTablePrompt, player)
			bot.wait = Mock.now + 0.5
		else
			H.walkToPart(world, player, camp.pads[1]) -- collect on the way out
			world:touch(camp.pads[1], player)
			H.walkToPart(world, player, camp.Lift)
			world:trigger(camp.LiftPrompt, player)
			bot.visited = {}
			bot.wait = Mock.now + 2
		end
	else
		local extra = bot.extra
		local fl = bot.World.floors[floor]
		if #p.stack >= extra.stackCap then
			H.walkToPart(world, player, fl.lift)
			world:trigger(fl.liftPrompt, player)
			bot.wait = Mock.now + 2
		elseif floor == p.cleared + 1 and extra.teamPower >= 22 and not bot.triedRing then
			bot.triedRing = Mock.now
			world:walkTo(player, V3.new(fl.ring.Position.X, fl.ring.Position.Y + 2.5, fl.ring.Position.Z))
			world:touch(fl.ring, player)
			bot.wait = Mock.now + 1
		else
			local best, bestD
			for _, ball in ipairs(H.petParts(world, floor)) do
				local id = ball:GetAttribute("PetId")
				if not bot.visited[id] then
					local d = (ball.Position - H.pos(world, player)).Magnitude
					if not bestD or d < bestD then best, bestD = ball, d end
				end
			end
			if best then
				bot.visited[best:GetAttribute("PetId")] = true
				H.walkNear(world, player, best.Position, 4)
				bot.wait = Mock.now + (best:GetAttribute("NeedsPlay") and 9 or 1.5)
			else
				H.walkToPart(world, player, fl.lift)
				world:trigger(fl.liftPrompt, player)
				bot.wait = Mock.now + 2
			end
		end
	end
end

function tests.a01_three_bots_play_for_20_minutes()
	local world = H.fresh(H.FRIDAY_14 + 5 * 3600, { studio = false, jobId = "soak-1" }) -- runs across a Secret chime or two
	world.friends["501:502"] = true
	local bots = { newBot(world, 501, "Ada", "Pandle"), newBot(world, 502, "Bo", "Narbub"), newBot(world, 503, "Cy", "Capling") }
	local seed = 7
	local function noise(i)
		seed = (seed * 1103515245 + 12345) % 2147483648
		return (seed / 2147483648 - 0.5) * 0.3 -- up to 150 ms early or late: Perfects, Goods and some Misses
	end
	local STEP, total = 0.05, 20 * 60
	local left = false
	for tick = 1, total / STEP do
		Mock.step(STEP)
		for _, bot in ipairs(bots) do act(bot, noise) end
		world.sent, world.received = {}, {} -- (the mock records everything; a long run does not need it)
		if #Mock.errors + #Mock.problems + #Mock.warnings > 0 then
			error("at " .. (tick * STEP) .. " s: " .. tostring(Mock.errors[1] or Mock.problems[1] or Mock.warnings[1]))
		end
		-- Bo leaves after 8 minutes and is back 30 s later
		if not left and tick * STEP >= 480 then
			left = true
			world:removePlayer(bots[2].player)
		elseif left == true and tick * STEP >= 510 then
			left = 2
			bots[2] = newBot(world, 502, "Bo", "Narbub")
		end
	end
	H.clean("soak")
	-- the bots really played
	local catches, levels, cleared = 0, 0, 0
	for _, bot in ipairs(bots) do
		local p = H.profile(world, bot.player)
		T.ok(p, bot.player.Name .. " is loaded")
		catches = catches + p.stats.catches
		levels = levels + p.starter.level
		cleared = cleared + p.cleared
		-- every pet is in exactly one place
		local where = {}
		for _, id in ipairs(p.stack) do where[id] = (where[id] or 0) + 1 end
		for _, id in ipairs(p.spare) do where[id] = (where[id] or 0) + 1 end
		for _, pad in ipairs(p.pads) do if pad.pet ~= 0 then where[pad.pet] = (where[pad.pet] or 0) + 1 end end
		for _, pet in ipairs(p.pets) do T.eq(where[pet.id], 1, "pet " .. pet.id .. " of " .. bot.player.Name .. " is in one place") end
		T.ok(p.coins >= 0)
		-- what the client last saw is what the server has
		T.ok(bot.coinsSeen and bot.coinsSeen <= p.coins and bot.petsSeen <= #p.pets, "the client's last state is not ahead of the server")
	end
	T.ok(catches >= 30, "the bots caught pets: " .. catches)
	T.ok(levels >= 12, "and fed their starters: " .. levels)
	if SOAK_REPORT then print(string.format("soak: %d catches, starter levels %d, floors cleared %d", catches, levels, cleared)) end
	-- the server closes: everything is saved and the locks are free
	world:shutdown()
	H.clean("shutdown")
	T.eq(world.closeStuck, 0)
	for _, id in ipairs({ 501, 502, 503 }) do
		local row = Mock.stores.PetTower_PlayerData_v1["u_" .. id]
		T.ok(row and row.data and row.lock == nil, "saved and released: " .. id)
	end
end

return tests
