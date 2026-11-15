-- Roblox friends in the same server: +20% coins for both, doubled cheers in a showdown.
local Players = game:GetService("Players")
local E = require(game:GetService("ReplicatedStorage").Shared.Config).Economy
local Friends = { pairs = {} } -- "low:high" -> true

local function key(a, b) if a > b then a, b = b, a end return a .. ":" .. b end

local function check(player, other)
	local ok, are = pcall(function() return player:IsFriendsWithAsync(other.UserId) end)
	Friends.pairs[key(player.UserId, other.UserId)] = (ok and are) or nil
	if ok and are and Friends.onFriends then Friends.onFriends(player, other) end
end

function Friends.are(a, b) return Friends.pairs[key(a, b)] == true end
function Friends.hasFriendHere(player)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and Friends.are(player.UserId, other.UserId) then return true end
	end
	return false
end
function Friends.coinMult(player)
	return Friends.hasFriendHere(player) and (1 + E.FriendCoinBonus) or 1
end

function Friends.init()
	Players.PlayerAdded:Connect(function(player)
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then task.spawn(check, player, other) end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local id = tostring(player.UserId)
		for k in pairs(Friends.pairs) do
			local a, b = k:match("^(%d+):(%d+)$")
			if a == id or b == id then Friends.pairs[k] = nil end
		end
	end)
end

return Friends
