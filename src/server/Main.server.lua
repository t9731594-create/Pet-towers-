-- Server entry point. Order matters: remotes, data, world, then the services that use them.
local Services = script.Parent.Services
local Net = require(Services.Net)
Net.init()
local World = require(Services.WorldService)
World.init()
require(Services.FriendService).init()
require(Services.PetService).init()
require(Services.CampService).init()
require(Services.FloorService).init()
require(Services.ShowdownService).init()
-- optional services added by later features
for _, name in ipairs({ "WildShowdownService", "SecretService", "ReturnService", "ChoiceService", "ShopService", "AnalyticsService", "EmoteService" }) do
	local module = Services:FindFirstChild(name)
	if module then require(module).init() end
end
require(Services.DataService).init() -- last: players start loading once everything is listening
print("[PetTower] server ready")
