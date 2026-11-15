-- Shop button. Shows nothing at all unless the owner has approved prices (Config.Shop.Approved) and
-- pass ids exist, and never in a player's first 5 minutes. Nothing interrupts play to sell.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Ui = require(script.Parent.Ui)
local HUD = require(script.Parent.HUD)
local Shop = {}
function Shop.init()
	if not Config.Shop.Approved or next(Config.Shop.PassIds) == nil then return end
	local gui = Ui.screen("Shop", 10)
	local open = Instance.new("TextButton")
	open.AnchorPoint = Vector2.new(1, 0) open.Position = UDim2.new(1, -12, 0, 128) open.Size = UDim2.fromOffset(56, 56)
	open.Text = "$" open.Font = Enum.Font.FredokaOne open.TextScaled = true open.BackgroundColor3 = Color3.fromRGB(190, 240, 190) open.Visible = false open.Parent = gui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5) panel.Position = UDim2.fromScale(0.5, 0.5) panel.Size = UDim2.fromOffset(4 * 110 + 10, 130)
	panel.BackgroundColor3 = Color3.fromRGB(45, 65, 50) panel.Visible = false panel.Parent = gui
	local buttons = {}
	for i, pass in ipairs(Config.Shop.Passes) do
		local id = Config.Shop.PassIds[pass.key]
		if id then
			local b = Instance.new("TextButton")
			b.Position = UDim2.fromOffset(10 + (i - 1) * 110, 15) b.Size = UDim2.fromOffset(100, 100)
			b.Text = pass.key .. "\nR$ " .. pass.robux b.Font = Enum.Font.FredokaOne b.TextScaled = true b.Parent = panel
			b.Activated:Connect(function() MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, id) end)
			buttons[pass.key] = b
		end
	end
	open.Activated:Connect(function() panel.Visible = not panel.Visible end)
	HUD.onState(function(p)
		open.Visible = os.time() - p.firstJoin >= Config.Economy.ShopButtonAfterSeconds
		for key, b in pairs(buttons) do b.Visible = not p.passes[key] end
	end)
end
return Shop
