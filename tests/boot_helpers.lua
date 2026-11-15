-- Shared by test_boot_server.lua and test_boot_client.lua: boots the real server (and client) against
-- tools/roblox_mock.lua and plays like a player would: walk, touch, trigger prompts, fire remotes.
local Mock = runfile(ROOT .. "/tools/roblox_mock.lua")
local H = { Mock = Mock }
local V3 = Mock.Vector3

H.FRIDAY_14 = 19678 * 86400 + 14 * 3600 -- Friday 17 Nov 2023, 14:00 UTC: the merchant is closed
H.SATURDAY_06 = H.FRIDAY_14 + 16 * 3600 -- 16 hours later: a new UTC day, a Saturday

-- Nothing red or yellow in the Output window, and no engine rule broken.
function H.clean(what)
	local function check(list, kind)
		if #list > 0 then
			error((what or "run") .. ": " .. #list .. " " .. kind .. ", first: " .. tostring(list[1]), 3)
		end
	end
	check(Mock.errors, "script error(s)")
	check(Mock.problems, "engine rule(s) broken")
	check(Mock.warnings, "warning(s)")
end
-- Take the expected warnings out (pattern), so H.clean can check the rest.
function H.expectWarning(pattern)
	local kept, found = {}, 0
	for _, w in ipairs(Mock.warnings) do
		if string.find(w, pattern) then found = found + 1 else kept[#kept + 1] = w end
	end
	Mock.warnings = kept
	return found
end

function H.boot(opts)
	local world = Mock.newWorld(opts)
	world:startServer()
	Mock.step(1)
	return world
end
function H.fresh(startTime, opts)
	Mock.reset(startTime or H.FRIDAY_14)
	return H.boot(opts)
end
function H.join(world, userId, name, wait)
	local player, client = world:addPlayer({ UserId = userId, Name = name, DisplayName = name })
	Mock.step(wait or 5) -- load, character, welcome, week
	return player, client
end
function H.svc(world, name) return world.server:require("Services", name) end
function H.core(world, name) return world.server:require("Core", name) end
function H.profile(world, player) return H.svc(world, "DataService").get(player) end
function H.camp(world, player) return H.svc(world, "WorldService").campOf(player) end
function H.floor(world, f) return H.svc(world, "WorldService").floors[f] end
function H.pos(world, player) return world:root(player).Position end

function H.count(client, name) return #client:got(name) end
-- The last payload (first argument) the client was sent under `name`.
function H.payload(client, name)
	local args = client:last(name)
	return args and args[1]
end
function H.state(client) return H.payload(client, "State") end
function H.banners(client, kind)
	local out = {}
	for _, args in ipairs(client:got("Banner")) do
		if args[1].kind == kind then out[#out + 1] = args[1] end
	end
	return out
end

-- Stand at a part (on top of / inside it, at walking height).
function H.walkToPart(world, player, part)
	world:walkTo(player, V3.new(part.Position.X, part.Position.Y + part.Size.Y / 2 + 2.9, part.Position.Z))
end
function H.walkNear(world, player, position, dx)
	world:walkTo(player, V3.new(position.X + (dx or 0), position.Y, position.Z))
end

function H.chooseStarter(world, player, species)
	local camp = H.camp(world, player)
	local ped = camp.pedestals[species or "Pandle"].ped
	world:walkTo(player, V3.new(ped.Position.X, 3, ped.Position.Z))
	world:touch(ped, player)
	Mock.step(0.6)
end

-- Play a whole try with the given grades ("Perfect" | "Good" | "Miss" | "skip" per beat; default all Perfect).
-- The try must have begun (TryBegin received). Returns the TryEnd payload.
function H.playTry(world, client, grades)
	local try = H.payload(client, "TryBegin")
	if not try then error("playTry: no TryBegin was received", 2) end
	local shift = { Perfect = 0, Good = 0.15, Miss = 0.4 }
	local ends = H.count(client, "TryEnd")
	for i, beat in ipairs(try.beats) do
		local g = grades and grades[i] or "Perfect"
		if g ~= "skip" then
			local at = try.start + beat + shift[g]
			Mock.step(at - Mock.now)
			client:fire("Tap", i, Mock.now - try.start)
		end
	end
	local waited = 0
	while H.count(client, "TryEnd") == ends and waited < 10 do Mock.step(0.25) waited = waited + 0.25 end
	return H.payload(client, "TryEnd")
end

function H.tutorialPart(world, player)
	local folder = world.workspace.PetTowerWorld.TutorialPets
	for _, ball in ipairs(folder:GetChildren()) do
		if ball:GetAttribute("PetId") == -player.UserId then return ball end
	end
end
-- Walk up to the personal first pet and catch it.
function H.tutorialCatch(world, player, client)
	local ball = H.tutorialPart(world, player)
	if not ball then error("no tutorial pet for " .. player.Name, 2) end
	H.walkNear(world, player, ball.Position, 4)
	client:fire("TryStart", -player.UserId)
	Mock.step(0.1)
	return H.playTry(world, client)
end
-- Walk onto the first pad: the stack lands on the pads.
function H.deposit(world, player)
	local camp = H.camp(world, player)
	H.walkToPart(world, player, camp.pads[1])
	world:touch(camp.pads[1], player)
	Mock.step(0.6)
end
-- A player who has done the first minute: starter, first catch, pet on a pad.
function H.ready(world, userId, name, species)
	local player, client = H.join(world, userId, name)
	H.chooseStarter(world, player, species)
	H.tutorialCatch(world, player, client)
	H.deposit(world, player)
	return player, client
end
function H.debug(client, command, arg)
	client:fire("Debug", command, arg)
	Mock.step(0.25)
end
function H.lift(world, player, client, f)
	client:fire("Lift", f)
	Mock.step(2.1) -- also lets the Lift remote's rate limit (one every 2 s) refill
end
-- Every wild pet part on a floor, as a client sees them.
function H.petParts(world, f)
	return world.workspace.PetTowerWorld["Floor" .. f].Pets:GetChildren()
end
-- pillar = true: only a pet under a pillar of light (the guaranteed Rare, not a Rare that spawned by itself)
function H.findPet(world, f, rarity, pillar)
	for _, ball in ipairs(H.petParts(world, f)) do
		if ball:GetAttribute("Rarity") == rarity and (not pillar or ball:FindFirstChild("Pillar")) then return ball end
	end
end
-- Send a cheer on every beat until `name` arrives (or `limit` seconds pass). snap = the ShowdownState payload.
function H.cheerUntil(world, clients, snap, name, limit)
	local first = clients[1]
	local before = H.count(first, name)
	local beat = math.floor(Mock.now - snap.start) + 1
	local t = 0
	while H.count(first, name) == before and t < (limit or 60) do
		local at = snap.start + beat
		if at > Mock.now then Mock.step(at - Mock.now) end
		for _, c in ipairs(clients) do c:fire("Cheer", Mock.now - snap.start) end
		Mock.step(0.3)
		beat = beat + 1
		t = t + 1
	end
end
function H.waitFor(client, name, limit, before)
	before = before or H.count(client, name)
	local t = 0
	while H.count(client, name) == before and t < (limit or 60) do Mock.step(0.25) t = t + 0.25 end
	return H.count(client, name) > before
end

return H
