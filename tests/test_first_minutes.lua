-- A scripted new player following bible B6, using only the server rules (no Studio). Times are the
-- B6 script's; the test checks the economy lets each step happen on time.
local Profile = require(Server.Core.Profile)
local TapCore = require(Server.Core.TapCore)
local SD = require(Server.Core.ShowdownCore)
local E = require(Shared.Config).Economy
local t = {}
local function catch(p, species, rarity, now, cannotFail)
	local tl = TapCore.issue({ rarity = rarity, floor = 1, charm = p.charm, cannotFail = cannotFail }, now)
	for i, beat in ipairs(tl.beats) do TapCore.tap(tl, i, beat + 0.03, now + beat + 0.08) end
	local r = TapCore.result(tl)
	if r.success then Profile.addCaught(p, species, rarity, false) end
	return r.success
end
function t.b6_script()
	local p = Profile.new(0)
	T.ok(Profile.chooseStarter(p, "Capling")) -- Leaf: no nature edge against Old Bramblehorn
	T.ok(catch(p, "Buttercub", "Common", 15, true)) -- 5-25 s: first Trust Tap
	Profile.deposit(p, 35) Profile.autoTeam(p) -- 25-45 s: onto a pad
	T.ok(catch(p, "Zipwing", "Rare", 65)) -- 45-75 s: the guaranteed Rare
	T.ok(catch(p, "Buttercub", "Common", 95))
	T.ok(catch(p, "Hopscotch", "Uncommon", 120))
	Profile.collect(p, 140) Profile.deposit(p, 140) Profile.autoTeam(p) -- 75-150 s: home
	local evolved
	while p.starter.level < 5 do
		local ok, r = Profile.feed(p)
		T.ok(ok, "can afford Lv " .. (p.starter.level + 1) .. " at 140 s with " .. p.coins .. " coins")
		evolved = r.evolvedTo
	end
	T.eq(evolved, 2) -- 150-180 s: the starter evolves
	-- by 5 min: feed with what the pads earn, then cheer up the Guardian
	Profile.collect(p, 250)
	while Profile.feed(p) do end
	local power = Profile.teamPower(p, "Leaf")
	local sd = SD.guardian(1, "Leaf", 255)
	SD.join(sd, 1, power, 255)
	for beat = 1, 39 do SD.cheer(sd, 1, beat + 0.1, 255 + beat + 0.15) end -- Good cheers only
	T.eq(SD.tick(sd, 295), "won", "Team Power " .. power .. " vs " .. E.GuardianPower[1])
	T.ok(Profile.clearFloor(p, 1))
	T.ok(Profile.canEnter(p, 2))
end
return t
