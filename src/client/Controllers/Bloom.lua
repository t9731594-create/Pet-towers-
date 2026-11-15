-- A floor starts dim and washed out and blooms to full colour when YOU have relit its lantern.
-- Done on this client only (a colour effect), so each player sees their own tower.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local HUD = require(script.Parent.HUD)
local Bloom = {}
function Bloom.init()
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "FloorBloom" effect.Saturation = 0 effect.Brightness = 0 effect.Parent = Lighting
	local shown
	local function update()
		local p = HUD.state
		if not p then return end
		local floor = Players.LocalPlayer:GetAttribute("Floor") or 0
		local f = p.floors[tostring(floor)]
		local dim = floor > 0 and not (f and f.cleared)
		if dim == shown then return end
		local first = shown == nil
		shown = dim
		local goal = { Saturation = dim and -0.65 or 0, Brightness = dim and -0.08 or 0 }
		-- the bloom itself (dim -> colour) takes 2 s; going dim is instant
		TweenService:Create(effect, TweenInfo.new((dim or first) and 0 or 2), goal):Play()
	end
	HUD.onState(update)
	Players.LocalPlayer:GetAttributeChangedSignal("Floor"):Connect(update)
end
return Bloom
