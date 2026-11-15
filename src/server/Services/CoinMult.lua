-- The one coin multiplier: friend in the server, rested bonus, index sets, 2x pass.
local ReturnCore = require(script.Parent.Parent.Core.ReturnCore)
local Friends = require(script.Parent.FriendService)
return function(player, profile)
	return ReturnCore.coinMult(profile, os.time(), { friend = Friends.hasFriendHere(player) })
end
