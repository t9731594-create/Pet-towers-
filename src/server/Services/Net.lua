-- Creates the remotes and wraps every client call: rate limit, loaded profile, pcall.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RateLimit = require(script.Parent.Parent.Core.RateLimit)

local Net = { limiter = RateLimit.new(Remotes.C2S), events = {} }

function Net.init()
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName
	for name in pairs(Remotes.C2S) do
		local r = Instance.new("RemoteEvent") r.Name = name r.Parent = folder
		Net.events[name] = r
	end
	for _, name in ipairs(Remotes.S2C) do
		local r = Instance.new("RemoteEvent") r.Name = name r.Parent = folder
		Net.events[name] = r
	end
	folder.Parent = ReplicatedStorage
	game:GetService("Players").PlayerRemoving:Connect(function(player) Net.limiter:forget(player.UserId) end)
end

function Net.now() return workspace:GetServerTimeNow() end

-- handler(player, profile, ...). Data = the DataService (passed in to avoid a require cycle).
function Net.on(name, Data, handler)
	Net.events[name].OnServerEvent:Connect(function(player, ...)
		if not Net.limiter:allow(player.UserId, name, os.clock()) then return end
		local profile = Data.get(player)
		if not profile then return end
		local ok, err = pcall(handler, player, profile, ...)
		if not ok then warn("[PetTower] " .. name .. ": " .. tostring(err)) end
	end)
end

function Net.send(player, name, ...) Net.events[name]:FireClient(player, ...) end
function Net.all(name, ...) Net.events[name]:FireAllClients(...) end

return Net
