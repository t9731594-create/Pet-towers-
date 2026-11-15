-- Banners and the evolution moment (greybox: colour flash and a big icon line; no sentences).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local Ui = require(script.Parent.Ui)

local FX = {}

function FX.init()
	local gui = Ui.screen("FX", 8)
	local banner = Ui.label(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.new(0.6, 0, 0, 40), Text = "", Visible = false })
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1) flash.BackgroundColor3 = Color3.new(1, 1, 1) flash.BackgroundTransparency = 1 flash.BorderSizePixel = 0 flash.Parent = gui
	local function show(text, color, seconds)
		banner.Text = text
		banner.TextColor3 = color
		banner.Visible = true
		task.delay(seconds or 4, function() if banner.Text == text then banner.Visible = false end end)
	end
	FX.show = show
	Remotes.get("Banner").OnClientEvent:Connect(function(b)
		if b.kind == "pillar" then
			show("* " .. b.floor .. " *", Ui.RarityColor[b.rarity] or Color3.new(1, 1, 1), 6)
		elseif b.kind == "help" then
			show("?! " .. b.floor, Color3.fromRGB(255, 170, 90), 6)
		elseif b.kind == "relit" then
			show("^ " .. b.floor .. " ^", Color3.fromRGB(255, 225, 130), 4)
		end
	end)
	Remotes.get("Evolve").OnClientEvent:Connect(function()
		-- 2.5 s moment: flash now; fanfare and camera orbit arrive with the art and audio pass (M4 / M7).
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(2.5), { BackgroundTransparency = 1 }):Play()
	end)
end

return FX
