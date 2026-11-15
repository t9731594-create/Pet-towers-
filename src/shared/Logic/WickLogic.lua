-- Wick the guide: what to point at right now. Light and faces only, never text. Pure logic.
-- ctx = { floor = current floor (0 = camp), stackCount, stackCap, canFeed (coins >= feed cost),
--         teamPower, guardianPower (of the next floor to clear), pillarOnFloor (bool), eggReady (bool),
--         pendingChoice (bool), builtFloors }
local Wick = {}

function Wick.target(p, ctx)
	if not p.starter then return "starter" end
	if p.tutorial < 1 then return "firstPet" end
	if ctx.pendingChoice then return nil end -- the choice buttons speak for themselves
	if ctx.floor == 0 then
		if ctx.stackCount > 0 then return "pads" end
		if ctx.eggReady then return "egg" end
		if ctx.canFeed and ctx.teamPower < ctx.guardianPower then return "snack" end
		return "lift"
	end
	if ctx.stackCount >= ctx.stackCap then return "liftHome" end
	if ctx.pillarOnFloor then return "pillar" end
	local nextFloor = p.cleared + 1
	if ctx.floor == nextFloor and ctx.teamPower >= ctx.guardianPower then return "guardian" end
	return "pet"
end

-- Wick's face: a small set of moods the client draws.
function Wick.mood(result)
	if result == "catch" then return "happy" end
	if result == "perfect" then return "wow" end
	if result == "miss" then return "oops" end
	if result == "welcome" then return "wave" end
	return "calm"
end

return Wick
