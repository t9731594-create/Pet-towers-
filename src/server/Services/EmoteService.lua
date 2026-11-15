-- Six sticker emotes: a picture over your head. No text, works with chat off.
local Net = require(script.Parent.Net)
local Data = require(script.Parent.DataService)
local Emotes = {}
function Emotes.init()
	Net.on("Emote", Data, function(player, _, index)
		if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > 6 then return end
		Net.all("Emote", player.UserId, index)
	end)
end
return Emotes
