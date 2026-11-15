-- Sound hooks for every moment in bible B11. Plays nothing until Config.Sounds has approved ids.
-- Separate music and effects volumes come from the player's settings.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Sounds = require(Shared.Config).Sounds
local HUD = require(script.Parent.HUD)

local Audio = { music = 1, effects = 1, current = nil }

function Audio.play(id, volume)
	if not id or id == "" or Audio.effects <= 0 then return end
	local s = Instance.new("Sound")
	s.SoundId = id s.Volume = (volume or 0.6) * Audio.effects s.Parent = SoundService
	s.Ended:Connect(function() s:Destroy() end)
	s:Play()
end
function Audio.setMusic(id)
	if Audio.current and Audio.current.SoundId == id then return end
	if Audio.current then Audio.current:Destroy() Audio.current = nil end
	if not id or id == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = id s.Looped = true s.Volume = 0.35 * Audio.music s.Parent = SoundService -- music sits under effects
	s:Play()
	Audio.current = s
end

function Audio.init()
	HUD.onState(function(p, extra)
		Audio.music, Audio.effects = p.settings.music, p.settings.effects
		if Audio.current then Audio.current.Volume = 0.35 * Audio.music end
		local floor = extra and extra.floor or 0
		Audio.setMusic(floor > 0 and Sounds.Music.floors[floor] or Sounds.Music.hub)
	end)
	Remotes.get("TryGrade").OnClientEvent:Connect(function(beat, grade) if grade ~= "Miss" then Audio.play(Sounds.Ring[beat]) end end)
	Remotes.get("TryEnd").OnClientEvent:Connect(function(r) Audio.play(r.success and Sounds.Catch or (r.lastBeatMiss and Sounds.Bolt or nil)) end)
	Remotes.get("Evolve").OnClientEvent:Connect(function() Audio.play(Sounds.Evolve, 0.8) end)
	Remotes.get("Coins").OnClientEvent:Connect(function() Audio.play(Sounds.Coin, 0.3) end)
	Remotes.get("Welcome").OnClientEvent:Connect(function() Audio.play(Sounds.Welcome) end)
	Remotes.get("SecretChime").OnClientEvent:Connect(function(c) if c.phase == "glow" then Audio.play(Sounds.Chime) end end)
	Remotes.get("ShowdownState").OnClientEvent:Connect(function() Audio.setMusic(Sounds.Music.showdown) end)
	Remotes.get("ShowdownEnd").OnClientEvent:Connect(function(r)
		if r.won and r.kind == "guardian" then Audio.play(Sounds.Relight, 0.8) end
		Audio.current = Audio.current -- floor music returns on the next State push
		if Audio.current then Audio.current:Destroy() Audio.current = nil end
	end)
end

return Audio
