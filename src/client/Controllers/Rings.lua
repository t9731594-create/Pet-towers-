-- Draws shrinking rings for a list of beat times and reports taps. Used by Trust Tap and by cheers.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Ui = require(script.Parent.Ui)

local Rings = {}
local HEART, START = 64, 320 -- px: the target ring and where a ring begins

-- opts: start (server time), beats = { seconds after start }, ringTime, color, onTap(offset), parent
function Rings.play(opts)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = opts.parent
	Ui.ring(holder, HEART, Color3.new(1, 1, 1), 8)
	local rings = {}
	for i, beat in ipairs(opts.beats) do
		local f, stroke = Ui.ring(holder, START, opts.color, 6)
		f.Visible = false
		rings[i] = { frame = f, stroke = stroke, beat = beat }
	end
	local self = { holder = holder, rings = rings, done = false }
	local conn = RunService.RenderStepped:Connect(function()
		local t = Ui.now() - opts.start
		for _, r in ipairs(rings) do
			local a = (t - (r.beat - opts.ringTime)) / opts.ringTime -- 0 at ring start, 1 on the beat
			if a >= 0 and a <= 1.25 and not r.hit then
				r.frame.Visible = true
				local d = START + (HEART - START) * math.min(a, 1.25)
				r.frame.Size = UDim2.fromOffset(d, d)
			else
				r.frame.Visible = r.hit == true and t < r.beat + 0.4
			end
		end
	end)
	local input = UserInputService.InputBegan:Connect(function(io, processed)
		if self.done then return end
		local kind = io.UserInputType
		if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 or io.KeyCode == Enum.KeyCode.Space or io.KeyCode == Enum.KeyCode.ButtonA then
			if processed and kind ~= Enum.UserInputType.Touch then return end
			opts.onTap(Ui.now() - opts.start)
		end
	end)
	function self.mark(i, grade)
		local r = rings[i]
		if r then r.hit = true r.stroke.Color = Ui.GradeColor[grade] or r.stroke.Color r.frame.Size = UDim2.fromOffset(HEART, HEART) end
	end
	function self.stop()
		self.done = true
		conn:Disconnect() input:Disconnect()
		holder:Destroy()
	end
	return self
end

return Rings
