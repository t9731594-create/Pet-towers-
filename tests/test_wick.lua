local Wick = require(Shared.Logic.WickLogic)
local Profile = require(Server.Core.Profile)
local t = {}
local function ctx(over)
	local c = { floor = 0, stackCount = 0, stackCap = 3, canFeed = false, teamPower = 5, guardianPower = 20, pillarOnFloor = false, eggReady = false }
	for k, v in pairs(over or {}) do c[k] = v end
	return c
end
function t.first_minutes_path()
	local p = Profile.new(0)
	T.eq(Wick.target(p, ctx()), "starter")
	Profile.chooseStarter(p, "Pandle")
	T.eq(Wick.target(p, ctx()), "firstPet")
	p.tutorial = 1
	T.eq(Wick.target(p, ctx({ stackCount = 1 })), "pads")
	T.eq(Wick.target(p, ctx()), "lift")
	T.eq(Wick.target(p, ctx({ floor = 1, pillarOnFloor = true })), "pillar")
	T.eq(Wick.target(p, ctx({ floor = 1 })), "pet")
	T.eq(Wick.target(p, ctx({ floor = 1, stackCount = 3 })), "liftHome")
	T.eq(Wick.target(p, ctx({ canFeed = true })), "snack")
	T.eq(Wick.target(p, ctx({ floor = 1, teamPower = 20 })), "guardian")
	T.eq(Wick.target(p, ctx({ eggReady = true })), "egg")
	T.eq(Wick.target(p, ctx({ pendingChoice = true })), nil)
end
function t.strong_team_is_not_sent_to_snack()
	local p = Profile.new(0) Profile.chooseStarter(p, "Pandle") p.tutorial = 1
	T.eq(Wick.target(p, ctx({ canFeed = true, teamPower = 25 })), "lift")
end
return t
