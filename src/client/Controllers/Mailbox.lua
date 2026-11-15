-- Mailbox: "Day N of your climb", tomorrow's gift, the egg, and a box for codes. Warm, never urgent:
-- no timers are shown, only whether the egg is warming or ready.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)
local Ui = require(script.Parent.Ui)
local Mailbox = {}
function Mailbox.init()
	local gui = Ui.screen("Mailbox", 10)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5) panel.Position = UDim2.fromScale(0.5, 0.5) panel.Size = UDim2.fromOffset(360, 240)
	panel.BackgroundColor3 = Color3.fromRGB(45, 60, 85) panel.Visible = false panel.Parent = gui
	local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0.08, 0) pc.Parent = panel
	local day = Ui.label(panel, { Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(320, 50), Text = "" })
	local tomorrow = Ui.label(panel, { Position = UDim2.fromOffset(20, 68), Size = UDim2.fromOffset(320, 36), Text = "", TextColor3 = Color3.fromRGB(255, 225, 140) })
	local egg = Ui.label(panel, { Position = UDim2.fromOffset(20, 108), Size = UDim2.fromOffset(320, 36), Text = "" })
	local box = Instance.new("TextBox")
	box.Position = UDim2.fromOffset(20, 156) box.Size = UDim2.fromOffset(230, 56) box.PlaceholderText = "ABC123" box.Text = ""
	box.Font = Enum.Font.FredokaOne box.TextScaled = true box.ClearTextOnFocus = true box.Parent = panel
	local go = Instance.new("TextButton")
	go.Position = UDim2.fromOffset(262, 156) go.Size = UDim2.fromOffset(78, 56) go.Text = ">" go.Font = Enum.Font.FredokaOne go.TextScaled = true
	go.BackgroundColor3 = Color3.fromRGB(120, 210, 120) go.Parent = panel
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0) close.Position = UDim2.new(1, -8, 0, 8) close.Size = UDim2.fromOffset(48, 48) close.Text = "X"
	close.Font = Enum.Font.FredokaOne close.TextScaled = true close.BackgroundColor3 = Color3.fromRGB(240, 240, 240) close.Parent = panel
	close.Activated:Connect(function() panel.Visible = false end)
	go.Activated:Connect(function()
		if #box.Text > 0 then Remotes.get("RedeemCode"):FireServer(string.sub(box.Text, 1, 24)) box.Text = "" end
	end)
	Remotes.get("Mail").OnClientEvent:Connect(function(m)
		day.Text = "^ " .. m.journeyDay
		tomorrow.Text = "> +" .. m.tomorrow.minutes .. "m" .. (m.tomorrow.look and "  *" or "")
		egg.Text = m.egg.state == "ready" and "( ! )" or m.egg.state == "warming" and "( z )" or ""
		box.Visible = m.codes go.Visible = m.codes
		panel.Visible = true
	end)
end
return Mailbox
