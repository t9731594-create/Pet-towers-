-- A small, honest stand-in for the Roblox engine, so the services and the client can run headless.
-- Only what the game code calls is here. Lua 5.1; loaded by the tests with
--   local Mock = runfile(ROOT .. "/tools/roblox_mock.lua")
--
-- What it models
--   * One fake clock (Mock.now, UTC seconds) behind os.time, os.clock, tick and workspace:GetServerTimeNow.
--   * A deterministic scheduler: task.spawn / defer / delay / wait run on coroutines; Mock.step(seconds)
--     advances the clock and runs what is due. Nothing runs by itself.
--   * Worlds (one fake server each) with a server realm and one client realm per connected player. Each
--     realm has its own module cache, as in Roblox. Workspace and ReplicatedStorage are shared objects
--     (replication is instant); instances a client creates are visible to that client only.
--   * Instances with a class table: reading or writing a member the class does not have raises
--     "X is not a valid member of Y", as Roblox does, and property values are type checked.
--   * RemoteEvents that deep-copy what is sent, refuse what Roblox would mangle (mixed or sparse tables,
--     functions), deliver on the next scheduler pass and record everything.
--   * DataStores in memory, shared by every world, that copy and validate values like the real store.
--
-- Every rule the mock enforces is also written to Mock.problems, because game code often wraps engine
-- calls in pcall. Uncaught errors in threads go to Mock.errors (the red lines of the Output window).
local Mock = {}
local unpack = unpack
local function pack(...) return { n = select("#", ...), ... } end

Mock.FRAME = 1 / 32 -- seconds between Heartbeat / RenderStepped frames
Mock.MIN_WAIT = 1 / 64 -- task.wait() with no argument
local SRC = ROOT .. "/src"

local heap, seq, deferred, deferHead, deferTail
local threadCtx = setmetatable({}, { __mode = "k" })

function Mock.reset(startTime)
	Mock.now = startTime or 1700000000
	Mock.t0 = Mock.now - 1000 -- os.clock() starts at 1000 s, like a server that has been up a while
	Mock.problems, Mock.errors, Mock.warnings, Mock.prints = {}, {}, {}, {}
	Mock.unknownEnums = {}
	Mock.stores = {} -- DataStore name -> { key -> value }
	Mock.datastore = { latency = 0.05, fail = nil, writes = 0 } -- fail(storeName, key) -> message to throw
	Mock.asyncLatency = 0.02 -- every other ...Async call yields this long
	Mock.worlds = {}
	Mock.ctx = nil -- { world, realm } of the running thread; nil = the test itself
	Mock.randState = 12345
	heap, seq, deferred, deferHead, deferTail = {}, 0, {}, 1, 0
end

local function problem(msg, level)
	Mock.problems[#Mock.problems + 1] = msg
	error(msg, (level or 1) + 1)
end
Mock.problem = problem

-- Scheduler ---------------------------------------------------------------------------------------
local function less(a, b) return a.at < b.at or (a.at == b.at and a.seq < b.seq) end
local function push(t)
	seq = seq + 1
	t.seq = seq
	local i = #heap + 1
	heap[i] = t
	while i > 1 do
		local parent = math.floor(i / 2)
		if less(heap[i], heap[parent]) then heap[i], heap[parent] = heap[parent], heap[i] i = parent else break end
	end
	return t
end
local function pop()
	local top, n = heap[1], #heap
	heap[1] = heap[n]
	heap[n] = nil
	n = n - 1
	local i = 1
	while true do
		local l, r, s = i * 2, i * 2 + 1, i
		if l <= n and less(heap[l], heap[s]) then s = l end
		if r <= n and less(heap[r], heap[s]) then s = r end
		if s == i then break end
		heap[i], heap[s] = heap[s], heap[i]
		i = s
	end
	return top
end
local function ctxDead(ctx)
	return ctx ~= nil and (ctx.world.dead or ctx.realm.dead)
end

local drive
drive = function(co, ...)
	local ctx = threadCtx[co]
	if ctxDead(ctx) then return end
	local prev = Mock.ctx
	Mock.ctx = ctx
	local r = pack(coroutine.resume(co, ...))
	Mock.ctx = prev
	if not r[1] then
		Mock.errors[#Mock.errors + 1] = tostring(r[2]) .. "\n" .. debug.traceback(co)
		return
	end
	if coroutine.status(co) == "dead" then return end
	if r[2] == "wait" then
		push({ at = Mock.now + r[3], co = co, started = Mock.now, ctx = ctx })
	elseif r[2] == "signal" then
		table.insert(r[3].waiters, co)
	elseif r[2] ~= "park" then
		Mock.errors[#Mock.errors + 1] = "thread yielded outside the scheduler (coroutine.yield in game code?)"
	end
end

local function spawnIn(ctx, fn, ...)
	if type(fn) == "thread" then drive(fn, ...) return fn end
	if type(fn) ~= "function" then problem("task.spawn: function or thread expected, got " .. type(fn), 3) end
	local co = coroutine.create(fn)
	threadCtx[co] = ctx
	drive(co, ...)
	return co
end
Mock.spawnIn = spawnIn

local function defer(ctx, fn, ...)
	deferTail = deferTail + 1
	deferred[deferTail] = { ctx = ctx, fn = fn, args = pack(...) }
end

function Mock.flush()
	while deferred[deferHead] do
		local d = deferred[deferHead]
		deferred[deferHead] = nil
		deferHead = deferHead + 1
		if not ctxDead(d.ctx) then spawnIn(d.ctx, d.fn, unpack(d.args, 1, d.args.n)) end
	end
end

-- Advance the fake clock, running every thread and timer that comes due on the way.
function Mock.step(seconds)
	local target = Mock.now + (seconds or 0)
	Mock.flush()
	while heap[1] and heap[1].at <= target do
		local t = pop()
		if not t.cancelled and not ctxDead(t.ctx) then
			if t.at > Mock.now then Mock.now = t.at end
			if t.co then drive(t.co, Mock.now - t.started)
			else spawnIn(t.ctx, t.fn, unpack(t.args, 1, t.args.n)) end
			Mock.flush()
		end
	end
	Mock.now = target
end

-- The clock may only jump while no server is running (a real clock never jumps under a live server).
function Mock.setTime(t)
	for _, w in ipairs(Mock.worlds) do
		if not w.dead then error("Mock.setTime: a world is still running; shut it down first", 2) end
	end
	if t < Mock.now then error("Mock.setTime: time cannot go backwards", 2) end
	Mock.t0 = Mock.t0 + (t - Mock.now)
	Mock.now = t
end

local function inThread() return Mock.ctx ~= nil and coroutine.running() ~= nil end
local function asyncYield(seconds)
	seconds = seconds or Mock.asyncLatency
	if seconds > 0 and inThread() then coroutine.yield("wait", seconds) end
end

-- pcall that lets the protected function yield, as Luau's does (Lua 5.1's cannot).
local function copcall(f, ...)
	if type(f) ~= "function" then return pcall(f, ...) end
	local co = coroutine.create(f)
	local function handle(ok, ...)
		if not ok then return false, ... end
		if coroutine.status(co) == "dead" then return true, ... end
		return handle(coroutine.resume(co, coroutine.yield(...)))
	end
	return handle(coroutine.resume(co, ...))
end

local task = {}
function task.spawn(fn, ...) return spawnIn(Mock.ctx, fn, ...) end
function task.defer(fn, ...)
	if type(fn) ~= "function" and type(fn) ~= "thread" then problem("task.defer: function expected", 2) end
	defer(Mock.ctx, fn, ...)
end
function task.delay(seconds, fn, ...)
	if type(fn) ~= "function" then problem("task.delay: function expected, got " .. type(fn), 2) end
	if seconds ~= nil and type(seconds) ~= "number" then problem("task.delay: number expected", 2) end
	return push({ at = Mock.now + math.max(seconds or 0, Mock.MIN_WAIT), fn = fn, args = pack(...), ctx = Mock.ctx })
end
function task.wait(seconds)
	if seconds ~= nil and type(seconds) ~= "number" then problem("task.wait: number expected, got " .. type(seconds), 2) end
	if not inThread() then error("task.wait called outside a thread", 2) end
	return coroutine.yield("wait", math.max(seconds or 0, Mock.MIN_WAIT))
end
function task.cancel(t) if type(t) == "table" then t.cancelled = true end end

-- Value types ---------------------------------------------------------------------------------------
local function typeofv(v)
	local t = type(v)
	if t ~= "table" then return t end
	local mt = getmetatable(v)
	return mt and rawget(mt, "_t") or "table"
end
Mock.typeof = typeofv
local function num(v, what, level)
	if v == nil then return 0 end
	if type(v) ~= "number" then problem(what .. ": number expected, got " .. typeofv(v), (level or 2) + 1) end
	return v
end

local Vector3 = {}
local V3 = { _t = "Vector3" }
local function v3(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V3) end
V3.__index = function(v, k)
	if k == "_t" then return "Vector3" end
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = v.Magnitude return v3(v.X / m, v.Y / m, v.Z / m) end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
	if k == "Cross" then return function(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end end
	if k == "Lerp" then return function(a, b, t) return a + (b - a) * t end end
	problem(tostring(k) .. " is not a valid member of Vector3", 2)
end
local function isV3(v) return typeofv(v) == "Vector3" end
V3.__add = function(a, b)
	if not isV3(a) or not isV3(b) then problem("Vector3 + " .. typeofv(isV3(a) and b or a), 2) end
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	if not isV3(a) or not isV3(b) then problem("Vector3 - " .. typeofv(isV3(a) and b or a), 2) end
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	if isV3(a) and isV3(b) then return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
	problem("Vector3 * " .. typeofv(isV3(a) and b or a), 2)
end
V3.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	if isV3(a) and isV3(b) then return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
	problem("Vector3 / " .. typeofv(b), 2)
end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return a.X .. ", " .. a.Y .. ", " .. a.Z end
function Vector3.new(x, y, z) return v3(num(x, "Vector3.new"), num(y, "Vector3.new"), num(z, "Vector3.new")) end
Vector3.zero, Vector3.one = v3(0, 0, 0), v3(1, 1, 1)

-- CFrame: position p and a row-major 3x3 rotation r (r[1..3] = first row).
local CFrame = {}
local CF = { _t = "CFrame" }
local function cf(p, r) return setmetatable({ p = p, r = r }, CF) end
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function rotate(r, v)
	return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function matmul(a, b)
	local o = {}
	for i = 0, 2 do
		for j = 1, 3 do
			o[i * 3 + j] = a[i * 3 + 1] * b[j] + a[i * 3 + 2] * b[3 + j] + a[i * 3 + 3] * b[6 + j]
		end
	end
	return o
end
local function transpose(r) return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] } end
local cfMethods = {}
function cfMethods.Inverse(c)
	local rt = transpose(c.r)
	return cf(-rotate(rt, c.p), rt)
end
function cfMethods.PointToWorldSpace(c, v) return rotate(c.r, v) + c.p end
function cfMethods.PointToObjectSpace(c, v)
	if not isV3(v) then problem("CFrame:PointToObjectSpace: Vector3 expected, got " .. typeofv(v), 2) end
	return rotate(transpose(c.r), v - c.p)
end
function cfMethods.ToWorldSpace(c, o) return c * o end
function cfMethods.ToObjectSpace(c, o) return c:Inverse() * o end
function cfMethods.Lerp(c, o, t) return cf(c.p + (o.p - c.p) * t, t < 0.5 and c.r or o.r) end
CF.__index = function(c, k)
	if k == "_t" then return "CFrame" end
	if k == "Position" then return c.p end
	if k == "X" or k == "Y" or k == "Z" then return c.p[k] end
	if k == "LookVector" then return v3(-c.r[3], -c.r[6], -c.r[9]) end
	if k == "RightVector" then return v3(c.r[1], c.r[4], c.r[7]) end
	if k == "UpVector" then return v3(c.r[2], c.r[5], c.r[8]) end
	if k == "Rotation" then return cf(v3(0, 0, 0), c.r) end
	if cfMethods[k] then return cfMethods[k] end
	problem(tostring(k) .. " is not a valid member of CFrame", 2)
end
CF.__mul = function(a, b)
	if typeofv(a) ~= "CFrame" then problem(typeofv(a) .. " * CFrame", 2) end
	if typeofv(b) == "CFrame" then return cf(rotate(a.r, b.p) + a.p, matmul(a.r, b.r)) end
	if isV3(b) then return rotate(a.r, b) + a.p end
	problem("CFrame * " .. typeofv(b), 2)
end
CF.__add = function(a, b)
	if typeofv(a) ~= "CFrame" or not isV3(b) then problem("CFrame + " .. typeofv(b), 2) end
	return cf(a.p + b, a.r)
end
CF.__sub = function(a, b)
	if typeofv(a) ~= "CFrame" or not isV3(b) then problem("CFrame - " .. typeofv(b), 2) end
	return cf(a.p - b, a.r)
end
CF.__eq = function(a, b)
	if not (a.p == b.p) then return false end
	for i = 1, 9 do if a.r[i] ~= b.r[i] then return false end end
	return true
end
function CFrame.lookAt(at, target, up)
	if not isV3(at) or not isV3(target) then problem("CFrame.lookAt: two Vector3 expected", 2) end
	up = up or v3(0, 1, 0)
	local d = target - at
	if d.Magnitude == 0 then return cf(at, IDENT) end
	local look = d.Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-9 then right = v3(1, 0, 0) else right = right.Unit end
	local up2 = right:Cross(look)
	return cf(at, { right.X, up2.X, -look.X, right.Y, up2.Y, -look.Y, right.Z, up2.Z, -look.Z })
end
function CFrame.new(a, b, c, ...)
	if a == nil then return cf(v3(0, 0, 0), IDENT) end
	if isV3(a) then
		if isV3(b) then return CFrame.lookAt(a, b) end
		if b ~= nil then problem("CFrame.new(Vector3, " .. typeofv(b) .. ")", 2) end
		return cf(a, IDENT)
	end
	if select("#", ...) > 0 then problem("CFrame.new with more than 3 numbers is not supported by the mock", 2) end
	return cf(v3(num(a, "CFrame.new"), num(b, "CFrame.new"), num(c, "CFrame.new")), IDENT)
end
function CFrame.Angles(rx, ry, rz)
	rx, ry, rz = num(rx, "CFrame.Angles"), num(ry, "CFrame.Angles"), num(rz, "CFrame.Angles")
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local X = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Y = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Z = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(v3(0, 0, 0), matmul(matmul(X, Y), Z))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
CFrame.identity = cf(v3(0, 0, 0), IDENT)

local function simple(tname, fields, methods)
	local mt = { _t = tname }
	mt.__index = function(_, k)
		if k == "_t" then return tname end
		if methods and methods[k] then return methods[k] end
		for _, f in ipairs(fields) do if f == k then return nil end end
		problem(tostring(k) .. " is not a valid member of " .. tname, 2)
	end
	mt.__eq = function(a, b)
		for _, f in ipairs(fields) do if rawget(a, f) ~= rawget(b, f) then return false end end
		return true
	end
	return mt
end

local Color3 = {}
local C3 = simple("Color3", { "R", "G", "B" }, {
	Lerp = function(a, b, t) return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end,
})
function Color3.new(r, g, b) return setmetatable({ R = num(r, "Color3.new"), G = num(g, "Color3.new"), B = num(b, "Color3.new") }, C3) end
function Color3.fromRGB(r, g, b) return Color3.new(num(r, "Color3.fromRGB") / 255, num(g, "Color3.fromRGB") / 255, num(b, "Color3.fromRGB") / 255) end

local Vector2 = {}
local V2 = simple("Vector2", { "X", "Y" })
V2.__index = function(v, k)
	if k == "_t" then return "Vector2" end
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y) end
	problem(tostring(k) .. " is not a valid member of Vector2", 2)
end
V2.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
	if type(a) == "number" then return Vector2.new(a * b.X, a * b.Y) end
	if type(b) == "number" then return Vector2.new(a.X * b, a.Y * b) end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
function Vector2.new(x, y) return setmetatable({ X = num(x, "Vector2.new"), Y = num(y, "Vector2.new") }, V2) end
Vector2.zero = Vector2.new(0, 0)

local UDim = {}
local UD = simple("UDim", { "Scale", "Offset" })
function UDim.new(s, o) return setmetatable({ Scale = num(s, "UDim.new"), Offset = num(o, "UDim.new") }, UD) end
local UDim2 = {}
local UD2 = simple("UDim2", { "X", "Y" })
UD2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
function UDim2.new(a, b, c, d)
	if typeofv(a) == "UDim" then
		if typeofv(b) ~= "UDim" then problem("UDim2.new(UDim, " .. typeofv(b) .. ")", 2) end
		return setmetatable({ X = a, Y = b }, UD2)
	end
	return setmetatable({ X = UDim.new(num(a, "UDim2.new"), num(b, "UDim2.new")), Y = UDim.new(num(c, "UDim2.new"), num(d, "UDim2.new")) }, UD2)
end
function UDim2.fromScale(x, y) return UDim2.new(num(x, "UDim2.fromScale"), 0, num(y, "UDim2.fromScale"), 0) end
function UDim2.fromOffset(x, y) return UDim2.new(0, num(x, "UDim2.fromOffset"), 0, num(y, "UDim2.fromOffset")) end

local TweenInfo = {}
local TI = simple("TweenInfo", { "Time", "EasingStyle", "EasingDirection", "RepeatCount", "Reverses", "DelayTime" })
local NumberRange = {}
local NR = simple("NumberRange", { "Min", "Max" })
function NumberRange.new(a, b)
	if type(a) ~= "number" then problem("NumberRange.new: number expected", 2) end
	if b ~= nil and type(b) ~= "number" then problem("NumberRange.new: number expected", 2) end
	if b and b < a then problem("NumberRange.new: max is below min", 2) end
	return setmetatable({ Min = a, Max = b or a }, NR)
end
local ColorSequence = {}
local CS = simple("ColorSequence", { "Keypoints" })
function ColorSequence.new(a, b)
	if typeofv(a) ~= "Color3" or (b ~= nil and typeofv(b) ~= "Color3") then problem("ColorSequence.new: Color3 expected, got " .. typeofv(a), 2) end
	return setmetatable({ Keypoints = { a, b or a } }, CS)
end
local NumberSequence = {}
local NS = simple("NumberSequence", { "Keypoints" })
function NumberSequence.new(a, b)
	if type(a) ~= "number" or (b ~= nil and type(b) ~= "number") then problem("NumberSequence.new: number expected, got " .. typeofv(a), 2) end
	return setmetatable({ Keypoints = { a, b or a } }, NS)
end

-- Enum: strict for the types listed here (a typo in an item name is an error), permissive for the rest.
local ENUMS = {
	Material = "Plastic SmoothPlastic Neon Wood WoodPlanks Marble Slate Concrete Granite Brick Pebble Cobblestone Metal Grass Sand Fabric Ice Glass ForceField Foil DiamondPlate CorrodedMetal",
	PartType = "Ball Block Cylinder Wedge CornerWedge",
	SurfaceType = "Smooth Glue Weld Studs Inlet Universal Hinge Motor SteppingMotor SmoothNoOutlines",
	Font = "FredokaOne SourceSans SourceSansBold SourceSansLight Gotham GothamBold GothamMedium GothamBlack Arial ArialBold Cartoon Code Fantasy LuckiestGuy Bangers FredokaOne Nunito BuilderSans BuilderSansBold Legacy Highway SciFi Antique Arcade",
	TextXAlignment = "Left Center Right",
	TextYAlignment = "Top Center Bottom",
	EasingStyle = "Linear Sine Back Quad Quart Quint Bounce Elastic Exponential Circular Cubic",
	EasingDirection = "In Out InOut",
	UserInputType = "MouseButton1 MouseButton2 MouseButton3 MouseWheel MouseMovement Touch Keyboard Focus Accelerometer Gyro Gamepad1 Gamepad2 Gamepad3 Gamepad4 TextInput InputMethod None",
	AnalyticsEconomyFlowType = "Sink Source",
	AnalyticsEconomyTransactionType = "IAP Shop Gameplay ContextualPurchase TimedReward Onboarding",
	ProductPurchaseDecision = "NotProcessedYet PurchaseGranted",
	SortOrder = "Name Custom LayoutOrder",
	ZIndexBehavior = "Global Sibling",
}
local EI = simple("EnumItem", { "Name", "Value", "EnumType" })
EI.__eq = nil
EI.__tostring = function(e) return "Enum." .. e.EnumType._name .. "." .. e.Name end
local enumTypes = {}
local function enumType(name)
	local t = enumTypes[name]
	if t then return t end
	local known
	if ENUMS[name] then
		known = {}
		for item in ENUMS[name]:gmatch("%S+") do known[item] = true end
	else
		Mock.unknownEnums[name] = true
	end
	local items, count = {}, 0
	t = setmetatable({ _name = name }, {
		_t = "Enum",
		__index = function(self, item)
			if item == "_t" then return "Enum" end
			if items[item] then return items[item] end
			if known and not known[item] then problem(tostring(item) .. " is not a valid member of \"Enum." .. name .. "\"", 2) end
			count = count + 1
			items[item] = setmetatable({ Name = item, Value = count, EnumType = self }, EI)
			return items[item]
		end,
	})
	enumTypes[name] = t
	return t
end
local Enum = setmetatable({}, { __index = function(_, name) return enumType(name) end })

function TweenInfo.new(t, style, dir, rep, rev, delay)
	if t ~= nil and type(t) ~= "number" then problem("TweenInfo.new: number expected for time", 2) end
	if style ~= nil and (typeofv(style) ~= "EnumItem" or style.EnumType ~= Enum.EasingStyle) then problem("TweenInfo.new: EasingStyle expected", 2) end
	if dir ~= nil and (typeofv(dir) ~= "EnumItem" or dir.EnumType ~= Enum.EasingDirection) then problem("TweenInfo.new: EasingDirection expected", 2) end
	return setmetatable({ Time = t or 1, EasingStyle = style or Enum.EasingStyle.Quad, EasingDirection = dir or Enum.EasingDirection.Out,
		RepeatCount = rep or 0, Reverses = rev or false, DelayTime = delay or 0 }, TI)
end

-- Signals -------------------------------------------------------------------------------------------
local Signal = { _t = "RBXScriptSignal" }
Signal.__index = Signal
local Connection = { _t = "RBXScriptConnection" }
Connection.__index = Connection
function Connection:Disconnect()
	if not self.Connected then return end
	self.Connected = false
	local conns = self.signal.conns
	for i = #conns, 1, -1 do if conns[i] == self then table.remove(conns, i) end end
end
local function newSignal(name)
	return setmetatable({ name = name, conns = {}, waiters = {} }, Signal)
end
function Signal:Connect(fn)
	if type(fn) ~= "function" then problem(self.name .. ":Connect: function expected, got " .. typeofv(fn), 2) end
	local c = setmetatable({ Connected = true, fn = fn, ctx = Mock.ctx, signal = self }, Connection)
	table.insert(self.conns, c)
	if self.onConnect then self.onConnect(self) end
	return c
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...) c:Disconnect() return fn(...) end)
	return c
end
function Signal:Wait() return coroutine.yield("signal", self) end
-- Test side (and the mock itself): run every handler, each in its own thread, in the realm it was connected from.
function Signal:Fire(...)
	local list = {}
	for i, c in ipairs(self.conns) do list[i] = c end
	for _, c in ipairs(list) do
		if c.Connected and not ctxDead(c.ctx) then spawnIn(c.ctx, c.fn, ...) end
	end
	local waiters = self.waiters
	self.waiters = {}
	for _, co in ipairs(waiters) do drive(co, ...) end
end

-- Instances -----------------------------------------------------------------------------------------
local classes = {}
local InstMT = { _t = "Instance" }
local function isInst(v, className)
	if typeofv(v) ~= "Instance" then return false end
	return className == nil or v:IsA(className)
end
Mock.isInstance = isInst

-- spec: props = "Name:type Name:type", signals = "A B", realmSignals = "A B" (one per realm: client-side events)
local function defclass(name, super, spec)
	spec = spec or {}
	local sup = super and classes[super]
	if super and not sup then error("mock: unknown superclass " .. super) end
	local c = { name = name, super = sup, props = {}, signals = {}, realmSignals = {}, methods = {}, defaults = {}, get = {}, set = {},
		creatable = spec.creatable ~= false, service = spec.service }
	if sup then
		for _, k in ipairs({ "props", "signals", "realmSignals", "methods", "defaults", "get", "set" }) do
			for a, b in pairs(sup[k]) do c[k][a] = b end
		end
	end
	for pname, ptype in (spec.props or ""):gmatch("([%w_]+):([%w_:]+)") do c.props[pname] = ptype end
	for s in (spec.signals or ""):gmatch("%S+") do c.signals[s] = true end
	for s in (spec.realmSignals or ""):gmatch("%S+") do c.realmSignals[s] = true end
	for k, v in pairs(spec.defaults or {}) do c.defaults[k] = v end
	for k, v in pairs(spec.methods or {}) do c.methods[k] = v end
	for k, v in pairs(spec.get or {}) do c.get[k] = v end
	for k, v in pairs(spec.set or {}) do c.set[k] = v end
	classes[name] = c
	return c
end

local function fullName(inst)
	local parts = {}
	local i = inst
	while i do
		table.insert(parts, 1, rawget(i, "_name"))
		i = rawget(i, "_parent")
	end
	return table.concat(parts, ".")
end
Mock.fullName = fullName

local function visible(child)
	local l = rawget(child, "_local")
	return l == nil or Mock.ctx == nil or Mock.ctx.realm == l
end
local function findChild(inst, name)
	for _, c in ipairs(rawget(inst, "_kids")) do
		if rawget(c, "_name") == name and visible(c) then return c end
	end
end
local function getSignal(inst, name)
	local sigs = rawget(inst, "_signals")
	if not sigs[name] then sigs[name] = newSignal(rawget(inst, "_class").name .. "." .. name) end
	return sigs[name]
end
Mock.signalOf = getSignal
local function realmSignal(inst, name)
	local ctx = Mock.ctx
	if not ctx then problem(name .. " belongs to one realm: read it from a server or client thread", 3) end
	local store = ctx.realm.signals
	store[inst] = store[inst] or {}
	if not store[inst][name] then store[inst][name] = newSignal(rawget(inst, "_class").name .. "." .. name) end
	return store[inst][name]
end

local function checkType(want, v, what)
	if want == "any" then return v end
	local t = typeofv(v)
	if want == "string" then
		if t == "number" then return tostring(v) end -- Roblox turns a number into a string here
		if t ~= "string" then problem(what .. ": string expected, got " .. t, 4) end
	elseif want == "number" or want == "int" then
		if t ~= "number" then problem(what .. ": number expected, got " .. t, 4) end
		if v ~= v then problem(what .. ": NaN", 4) end
	elseif want == "boolean" or want == "function" then
		if t ~= want then problem(what .. ": " .. want .. " expected, got " .. t, 4) end
	elseif want == "Instance" or want:sub(1, 9) == "Instance:" then
		if v ~= nil and not isInst(v, want:sub(10) ~= "" and want:sub(10) or nil) then problem(what .. ": " .. want .. " expected, got " .. t, 4) end
	elseif want:sub(1, 5) == "Enum:" then
		if t ~= "EnumItem" or v.EnumType ~= Enum[want:sub(6)] then problem(what .. ": Enum." .. want:sub(6) .. " expected, got " .. (t == "EnumItem" and tostring(v) or t), 4) end
	elseif t ~= want then
		problem(what .. ": " .. want .. " expected, got " .. t, 4)
	end
	return v
end

local function fireChanged(inst, key)
	local sigs = rawget(inst, "_signals")
	if sigs.Changed then sigs.Changed:Fire(key) end
	if sigs["prop:" .. key] then sigs["prop:" .. key]:Fire() end
end

local function setParent(inst, parent)
	if rawget(inst, "_destroyed") and parent ~= nil then
		problem("The Parent property of " .. rawget(inst, "_name") .. " is locked, current parent: NULL, new parent " .. tostring(rawget(parent, "_name")), 3)
	end
	if parent ~= nil then
		if not isInst(parent) then problem("Parent: Instance expected, got " .. typeofv(parent), 3) end
		local p = parent
		while p do
			if p == inst then problem("Attempt to set parent of " .. rawget(inst, "_name") .. " to itself or a descendant", 3) end
			p = rawget(p, "_parent")
		end
	end
	local old = rawget(inst, "_parent")
	if old == parent then return end
	if old then
		local kids = rawget(old, "_kids")
		for i = #kids, 1, -1 do if kids[i] == inst then table.remove(kids, i) end end
		local sigs = rawget(old, "_signals")
		if sigs.ChildRemoved then sigs.ChildRemoved:Fire(inst) end
	end
	rawset(inst, "_parent", parent)
	if parent then
		table.insert(rawget(parent, "_kids"), inst)
		local sigs = rawget(parent, "_signals")
		if sigs.ChildAdded then sigs.ChildAdded:Fire(inst) end
	end
end

InstMT.__index = function(inst, k)
	if k == "_t" then return "Instance" end
	if k == "Parent" then return rawget(inst, "_parent") end
	if k == "Name" then return rawget(inst, "_name") end
	local class = rawget(inst, "_class")
	if k == "ClassName" then return class.name end
	if class.get[k] then return class.get[k](inst) end
	if class.props[k] then
		local v = rawget(inst, "_props")[k]
		if v == nil then return class.defaults[k] end
		return v
	end
	if class.signals[k] then return getSignal(inst, k) end
	if class.realmSignals[k] then return realmSignal(inst, k) end
	if class.methods[k] then return class.methods[k] end
	if type(k) == "string" then
		local child = findChild(inst, k)
		if child then return child end
	end
	problem(tostring(k) .. " is not a valid member of " .. class.name .. " \"" .. fullName(inst) .. "\"", 2)
end
InstMT.__newindex = function(inst, k, v)
	if k == "Parent" then setParent(inst, v) return end
	local class = rawget(inst, "_class")
	if k == "Name" then
		rawset(inst, "_name", checkType("string", v, class.name .. ".Name"))
		return
	end
	local want = class.props[k]
	if not want then
		problem(tostring(k) .. " is not a valid member of " .. class.name .. " \"" .. fullName(inst) .. "\"", 2)
	end
	if want:sub(1, 3) == "ro:" then problem("Unable to assign property " .. k .. ". Property is read only", 2) end
	if v == nil and want ~= "any" and want ~= "function" and want:sub(1, 8) ~= "Instance" then
		problem(class.name .. "." .. k .. ": " .. want .. " expected, got nil", 2)
	end
	v = checkType(want, v, class.name .. "." .. k)
	if class.set[k] then class.set[k](inst, v) else rawget(inst, "_props")[k] = v end
	fireChanged(inst, k)
end
InstMT.__tostring = function(inst) return rawget(inst, "_name") end

local function create(className, name)
	local class = classes[className]
	if not class then problem("Unable to create an Instance of type \"" .. tostring(className) .. "\"", 3) end
	local inst = { _class = class, _name = name or className, _kids = {}, _props = {}, _attrs = {}, _signals = {} }
	local ctx = Mock.ctx
	if ctx and ctx.realm.kind == "client" then inst._local = ctx.realm end
	return setmetatable(inst, InstMT)
end

local Instance = {}
function Instance.new(className, parent)
	local class = classes[className]
	if not class or not class.creatable or class.service then
		problem("Unable to create an Instance of type \"" .. tostring(className) .. "\"", 2)
	end
	local inst = create(className)
	if parent ~= nil then setParent(inst, parent) end
	return inst
end

local ATTR_TYPES = { string = true, boolean = true, number = true, Vector3 = true, Vector2 = true, CFrame = true, Color3 = true,
	UDim = true, UDim2 = true, NumberSequence = true, ColorSequence = true, NumberRange = true, EnumItem = true }
local function isA(class, name)
	while class do
		if class.name == name then return true end
		class = class.super
	end
	return false
end

local base = {}
function base.IsA(inst, name)
	if type(name) ~= "string" then problem("IsA: string expected", 2) end
	if not classes[name] then problem("IsA(\"" .. name .. "\"): the mock does not know this class", 2) end
	return isA(rawget(inst, "_class"), name)
end
function base.FindFirstChild(inst, name, recursive)
	if type(name) ~= "string" then
		if type(name) == "number" then name = tostring(name) else problem("FindFirstChild: string expected, got " .. typeofv(name), 2) end
	end
	local c = findChild(inst, name)
	if c or not recursive then return c end
	for _, kid in ipairs(rawget(inst, "_kids")) do
		if visible(kid) then
			c = base.FindFirstChild(kid, name, true)
			if c then return c end
		end
	end
end
function base.FindFirstChildOfClass(inst, className)
	for _, c in ipairs(rawget(inst, "_kids")) do
		if rawget(c, "_class").name == className and visible(c) then return c end
	end
end
function base.FindFirstChildWhichIsA(inst, className)
	for _, c in ipairs(rawget(inst, "_kids")) do
		if isA(rawget(c, "_class"), className) and visible(c) then return c end
	end
end
function base.FindFirstAncestorOfClass(inst, className)
	if type(className) ~= "string" then problem("FindFirstAncestorOfClass: string expected", 2) end
	local p = rawget(inst, "_parent")
	while p do
		if rawget(p, "_class").name == className then return p end
		p = rawget(p, "_parent")
	end
end
function base.FindFirstAncestorWhichIsA(inst, className)
	local p = rawget(inst, "_parent")
	while p do
		if isA(rawget(p, "_class"), className) then return p end
		p = rawget(p, "_parent")
	end
end
function base.FindFirstAncestor(inst, name)
	local p = rawget(inst, "_parent")
	while p do
		if rawget(p, "_name") == name then return p end
		p = rawget(p, "_parent")
	end
end
function base.WaitForChild(inst, name, timeout)
	if type(name) ~= "string" then problem("WaitForChild: string expected, got " .. typeofv(name), 2) end
	if timeout ~= nil and type(timeout) ~= "number" then problem("WaitForChild: number expected for the timeout", 2) end
	local waited = 0
	while true do
		local c = findChild(inst, name)
		if c then return c end
		if timeout and waited >= timeout then return nil end
		if not inThread() then problem("WaitForChild(\"" .. name .. "\") on " .. fullName(inst) .. " would wait (called outside a thread)", 2) end
		if not timeout and waited >= 5 then
			problem("Infinite yield possible on '" .. fullName(inst) .. ":WaitForChild(\"" .. name .. "\")'", 2)
		end
		coroutine.yield("wait", 0.05)
		waited = waited + 0.05
	end
end
function base.GetChildren(inst)
	local out = {}
	for _, c in ipairs(rawget(inst, "_kids")) do if visible(c) then out[#out + 1] = c end end
	return out
end
function base.GetDescendants(inst)
	local out = {}
	local function walk(i)
		for _, c in ipairs(rawget(i, "_kids")) do
			if visible(c) then out[#out + 1] = c walk(c) end
		end
	end
	walk(inst)
	return out
end
function base.IsDescendantOf(inst, other)
	local p = rawget(inst, "_parent")
	while p do
		if p == other then return true end
		p = rawget(p, "_parent")
	end
	return false
end
function base.Destroy(inst)
	if rawget(inst, "_destroyed") then return end
	local sigs = rawget(inst, "_signals")
	if sigs.Destroying then sigs.Destroying:Fire() end
	setParent(inst, nil)
	rawset(inst, "_destroyed", true)
	for _, s in pairs(sigs) do
		for _, c in ipairs(s.conns) do c.Connected = false end
		s.conns = {}
	end
	local kids = rawget(inst, "_kids")
	for i = #kids, 1, -1 do if kids[i] then base.Destroy(kids[i]) end end
end
function base.ClearAllChildren(inst)
	local kids = rawget(inst, "_kids")
	for i = #kids, 1, -1 do if kids[i] then base.Destroy(kids[i]) end end
end
function base.SetAttribute(inst, name, value)
	if type(name) ~= "string" then problem("SetAttribute: string expected for the name, got " .. typeofv(name), 2) end
	if #name == 0 or #name > 100 or name:find("[^%w_]") or name:sub(1, 3) == "RBX" then
		problem("SetAttribute: \"" .. name .. "\" is not a valid attribute name", 2)
	end
	if value ~= nil and not ATTR_TYPES[typeofv(value)] then
		problem("SetAttribute(\"" .. name .. "\"): " .. typeofv(value) .. " is not a supported attribute type", 2)
	end
	local attrs = rawget(inst, "_attrs")
	if attrs[name] == value then return end
	attrs[name] = value
	local sigs = rawget(inst, "_signals")
	if sigs.AttributeChanged then sigs.AttributeChanged:Fire(name) end
	if sigs["attr:" .. name] then sigs["attr:" .. name]:Fire() end
end
function base.GetAttribute(inst, name)
	if type(name) ~= "string" then problem("GetAttribute: string expected, got " .. typeofv(name), 2) end
	return rawget(inst, "_attrs")[name]
end
function base.GetAttributes(inst)
	local out = {}
	for k, v in pairs(rawget(inst, "_attrs")) do out[k] = v end
	return out
end
function base.GetAttributeChangedSignal(inst, name)
	if type(name) ~= "string" then problem("GetAttributeChangedSignal: string expected", 2) end
	return getSignal(inst, "attr:" .. name)
end
function base.GetPropertyChangedSignal(inst, name)
	if not rawget(inst, "_class").props[name] and name ~= "Parent" and name ~= "Name" then
		problem(tostring(name) .. " is not a valid property name.", 2)
	end
	return getSignal(inst, "prop:" .. name)
end
function base.GetFullName(inst) return fullName(inst) end

defclass("Instance", nil, { props = "Archivable:boolean",
	signals = "ChildAdded ChildRemoved Destroying AttributeChanged Changed AncestryChanged DescendantAdded DescendantRemoving",
	methods = base, creatable = false })
defclass("Folder", "Instance")
defclass("Configuration", "Instance")
defclass("LuaSourceContainer", "Instance", { creatable = false })
defclass("ModuleScript", "LuaSourceContainer")
defclass("Script", "LuaSourceContainer", { props = "Enabled:boolean" })
defclass("LocalScript", "Script")
defclass("ValueBase", "Instance", { creatable = false })
defclass("IntValue", "ValueBase", { props = "Value:int", defaults = { Value = 0 } })
defclass("NumberValue", "ValueBase", { props = "Value:number", defaults = { Value = 0 } })
defclass("StringValue", "ValueBase", { props = "Value:string", defaults = { Value = "" } })
defclass("BoolValue", "ValueBase", { props = "Value:boolean", defaults = { Value = false } })
defclass("RemoteEvent", "Instance") -- methods and events are added further down
defclass("Humanoid", "Instance", { props = "Health:number MaxHealth:number WalkSpeed:number JumpPower:number HipHeight:number DisplayName:string",
	signals = "Died Running Jumping", defaults = { Health = 100, MaxHealth = 100, WalkSpeed = 16 } })

defclass("PVInstance", "Instance", { creatable = false })
local GREY = Color3.fromRGB(163, 162, 165)
defclass("BasePart", "PVInstance", { creatable = false,
	props = "Anchored:boolean CanCollide:boolean CanTouch:boolean CanQuery:boolean CastShadow:boolean Massless:boolean Locked:boolean "
		.. "Size:Vector3 Position:Vector3 CFrame:CFrame Orientation:Vector3 Color:Color3 Material:Enum:Material Transparency:number "
		.. "Reflectance:number TopSurface:Enum:SurfaceType BottomSurface:Enum:SurfaceType AssemblyLinearVelocity:Vector3",
	signals = "Touched TouchEnded",
	defaults = { Anchored = false, CanCollide = true, CanTouch = true, CanQuery = true, CastShadow = true, Massless = false,
		Size = v3(4, 1, 2), Transparency = 0, Reflectance = 0, Color = GREY },
	get = {
		CFrame = function(inst) return rawget(inst, "_props").CFrame or CFrame.identity end,
		Position = function(inst) return (rawget(inst, "_props").CFrame or CFrame.identity).p end,
	},
	set = {
		Position = function(inst, v)
			local props = rawget(inst, "_props")
			props.CFrame = cf(v, (props.CFrame or CFrame.identity).r)
		end,
		Size = function(inst, v)
			-- the engine keeps every axis at 0.001 or more
			rawget(inst, "_props").Size = v3(math.max(v.X, 0.001), math.max(v.Y, 0.001), math.max(v.Z, 0.001))
		end,
	},
	methods = {
		GetPivot = function(inst) return inst.CFrame end,
		PivotTo = function(inst, c) inst.CFrame = c end,
	} })
defclass("Part", "BasePart", { props = "Shape:Enum:PartType" })
defclass("MeshPart", "BasePart", { creatable = false })
defclass("Model", "PVInstance", { props = "PrimaryPart:Instance:BasePart WorldPivot:CFrame", methods = {
	GetPivot = function(inst)
		local pp = inst.PrimaryPart
		if pp then return pp.CFrame end
		return rawget(inst, "_props").WorldPivot or CFrame.identity
	end,
	PivotTo = function(inst, target)
		if typeofv(target) ~= "CFrame" then problem("PivotTo: CFrame expected, got " .. typeofv(target), 2) end
		local delta = target * inst:GetPivot():Inverse()
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then rawget(d, "_props").CFrame = delta * d.CFrame end
		end
		rawget(inst, "_props").WorldPivot = target
	end,
} })
defclass("Camera", "Instance", { props = "CFrame:CFrame FieldOfView:number ViewportSize:Vector2 CameraSubject:Instance",
	defaults = { CFrame = CFrame.identity, FieldOfView = 70, ViewportSize = Vector2.new(667, 375) } })
defclass("Attachment", "Instance", { props = "Position:Vector3 CFrame:CFrame Visible:boolean" })
defclass("WeldConstraint", "Instance", { props = "Part0:Instance:BasePart Part1:Instance:BasePart Enabled:boolean" })
defclass("ProximityPrompt", "Instance", {
	props = "ActionText:string ObjectText:string HoldDuration:number MaxActivationDistance:number RequiresLineOfSight:boolean Enabled:boolean KeyboardKeyCode:Enum:KeyCode",
	signals = "Triggered TriggerEnded PromptShown PromptHidden PromptButtonHoldBegan PromptButtonHoldEnded",
	defaults = { MaxActivationDistance = 10, HoldDuration = 0, Enabled = true, RequiresLineOfSight = true } })
defclass("Light", "Instance", { creatable = false, props = "Color:Color3 Brightness:number Enabled:boolean Shadows:boolean" })
defclass("PointLight", "Light", { props = "Range:number" })
defclass("Beam", "Instance", { props = "Attachment0:Instance:Attachment Attachment1:Instance:Attachment Width0:number Width1:number "
	.. "FaceCamera:boolean Color:ColorSequence Transparency:NumberSequence Enabled:boolean LightEmission:number Segments:int",
	defaults = { Enabled = true } })
defclass("ParticleEmitter", "Instance", { props = "Color:ColorSequence LightEmission:number Size:NumberSequence Lifetime:NumberRange "
	.. "Speed:NumberRange SpreadAngle:Vector2 Rate:number Enabled:boolean Transparency:NumberSequence", defaults = { Rate = 20, Enabled = true } })
defclass("Sound", "Instance", { props = "SoundId:string Volume:number Looped:boolean PlaybackSpeed:number IsPlaying:ro:boolean",
	signals = "Ended Played Stopped", defaults = { SoundId = "", Volume = 0.5, Looped = false },
	methods = { Play = function() end, Stop = function() end, Pause = function() end } })
defclass("PostEffect", "Instance", { creatable = false, props = "Enabled:boolean" })
defclass("ColorCorrectionEffect", "PostEffect", { props = "Saturation:number Brightness:number Contrast:number TintColor:Color3",
	defaults = { Saturation = 0, Brightness = 0, Contrast = 0 } })

-- GUI
defclass("GuiBase2d", "Instance", { creatable = false, props = "AbsoluteSize:ro:Vector2 AbsolutePosition:ro:Vector2",
	defaults = { AbsoluteSize = Vector2.new(0, 0), AbsolutePosition = Vector2.new(0, 0) } })
defclass("LayerCollector", "GuiBase2d", { creatable = false, props = "Enabled:boolean ResetOnSpawn:boolean ZIndexBehavior:Enum:ZIndexBehavior",
	defaults = { Enabled = true, ResetOnSpawn = true } })
defclass("ScreenGui", "LayerCollector", { props = "DisplayOrder:int IgnoreGuiInset:boolean", defaults = { DisplayOrder = 0, IgnoreGuiInset = false } })
defclass("BillboardGui", "LayerCollector", { props = "Size:UDim2 StudsOffset:Vector3 MaxDistance:number AlwaysOnTop:boolean Adornee:Instance LightInfluence:number" })
defclass("GuiObject", "GuiBase2d", { creatable = false,
	props = "AnchorPoint:Vector2 Position:UDim2 Size:UDim2 BackgroundColor3:Color3 BackgroundTransparency:number BorderSizePixel:int "
		.. "Visible:boolean ZIndex:int LayoutOrder:int Rotation:number Active:boolean ClipsDescendants:boolean Selectable:boolean",
	signals = "InputBegan InputEnded MouseEnter MouseLeave",
	defaults = { Visible = true, BackgroundTransparency = 0, Rotation = 0, Active = false, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(163, 162, 165), AnchorPoint = Vector2.new(0, 0) } })
defclass("Frame", "GuiObject")
defclass("ScrollingFrame", "GuiObject", { props = "CanvasSize:UDim2 ScrollBarThickness:int CanvasPosition:Vector2 ScrollingEnabled:boolean" })
local TEXT = "Text:string Font:Enum:Font TextColor3:Color3 TextScaled:boolean TextSize:number TextStrokeTransparency:number TextStrokeColor3:Color3 "
	.. "TextTransparency:number TextXAlignment:Enum:TextXAlignment TextYAlignment:Enum:TextYAlignment TextWrapped:boolean RichText:boolean"
local TEXT_DEFAULTS = { Text = "", TextColor3 = Color3.fromRGB(27, 42, 53), TextTransparency = 0, TextStrokeTransparency = 1, TextScaled = false }
defclass("TextLabel", "GuiObject", { props = TEXT, defaults = TEXT_DEFAULTS })
defclass("GuiButton", "GuiObject", { creatable = false, props = "AutoButtonColor:boolean Modal:boolean",
	signals = "Activated MouseButton1Click MouseButton1Down MouseButton1Up", defaults = { Active = true, AutoButtonColor = true } })
defclass("TextButton", "GuiButton", { props = TEXT, defaults = TEXT_DEFAULTS })
defclass("ImageButton", "GuiButton", { props = "Image:string ImageColor3:Color3 ImageTransparency:number" })
defclass("ImageLabel", "GuiObject", { props = "Image:string ImageColor3:Color3 ImageTransparency:number" })
defclass("TextBox", "GuiObject", { props = TEXT .. " PlaceholderText:string ClearTextOnFocus:boolean MultiLine:boolean TextEditable:boolean",
	signals = "FocusLost Focused", defaults = TEXT_DEFAULTS })
defclass("UIBase", "Instance", { creatable = false })
defclass("UICorner", "UIBase", { props = "CornerRadius:UDim" })
defclass("UIStroke", "UIBase", { props = "Thickness:number Color:Color3 Transparency:number Enabled:boolean",
	defaults = { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0 } })
defclass("UIScale", "UIBase", { props = "Scale:number", defaults = { Scale = 1 } })
defclass("UIGridLayout", "UIBase", { props = "CellSize:UDim2 CellPadding:UDim2 AbsoluteContentSize:ro:Vector2 SortOrder:Enum:SortOrder",
	defaults = { AbsoluteContentSize = Vector2.new(0, 0) } })
defclass("UIListLayout", "UIBase", { props = "Padding:UDim AbsoluteContentSize:ro:Vector2 SortOrder:Enum:SortOrder",
	defaults = { AbsoluteContentSize = Vector2.new(0, 0) } })
defclass("PlayerGui", "Instance", { creatable = false })
defclass("PlayerScripts", "Instance", { creatable = false })
defclass("Backpack", "Instance", { creatable = false })

-- What may cross a RemoteEvent or go into a DataStore -------------------------------------------------
-- mode "remote": value types and instances pass; "store": only what JSON can hold.
local function wireCopy(v, mode, where, seen)
	local t = type(v)
	if t == "nil" or t == "boolean" or t == "string" then return v end
	if t == "number" then
		if mode == "store" and (v ~= v or v == math.huge or v == -math.huge) then
			problem(where .. ": NaN / infinity cannot be saved in a DataStore", 4)
		end
		return v
	end
	if t == "function" or t == "thread" or t == "userdata" then
		problem(where .. ": a " .. t .. " cannot be sent (Roblox would deliver nil)", 4)
	end
	local rt = typeofv(v)
	if rt ~= "table" then
		if mode == "store" then problem(where .. ": a " .. rt .. " cannot be saved in a DataStore", 4) end
		if rt == "Instance" and rawget(v, "_local") then return nil end -- a client-only instance arrives as nil
		return v
	end
	if getmetatable(v) ~= nil then problem(where .. ": a table with a metatable loses it on the way", 4) end
	seen = seen or {}
	if seen[v] then problem(where .. ": a table that contains itself cannot be sent", 4) end
	seen[v] = true
	local count, strings = 0, 0
	for k in pairs(v) do
		count = count + 1
		if type(k) == "string" then
			strings = strings + 1
		elseif type(k) ~= "number" then
			problem(where .. ": table key of type " .. typeofv(k) .. " (keys must be strings, or 1..n)", 4)
		end
	end
	local out = {}
	if strings == count then
		for k, x in pairs(v) do out[k] = wireCopy(x, mode, where .. "." .. k, seen) end
	elseif strings == 0 and #v == count then
		for i = 1, count do out[i] = wireCopy(v[i], mode, where .. "[" .. i .. "]", seen) end
	elseif strings == 0 then
		problem(where .. ": array with gaps or number keys that are not 1..n (Roblox would drop or rename entries)", 4)
	else
		problem(where .. ": table with both string and number keys (Roblox would drop one kind)", 4)
	end
	seen[v] = nil
	return out
end
local function wireArgs(args, where)
	local out = { n = args.n }
	for i = 1, args.n do out[i] = wireCopy(args[i], "remote", where .. " arg " .. i) end
	return out
end
Mock.wireCopy = wireCopy

local function requireServer(what, level)
	local ctx = Mock.ctx
	if ctx and ctx.realm.kind ~= "server" then problem(what .. " can only be used on the server", (level or 2) + 1) end
end
local function requireClient(what, level)
	local ctx = Mock.ctx
	if not ctx or ctx.realm.kind ~= "client" then problem(what .. " can only be used from a client", (level or 2) + 1) end
	return ctx
end
local function worldOf(inst)
	local w = rawget(inst, "_world")
	local p = inst
	while not w and p do
		p = rawget(p, "_parent")
		w = p and rawget(p, "_world")
	end
	return w
end

-- RemoteEvent
do
	local c = classes.RemoteEvent
	c.get.OnServerEvent = function(inst)
		requireServer("OnServerEvent", 3)
		return getSignal(inst, "OnServerEvent")
	end
	c.get.OnClientEvent = function(inst)
		local ctx = requireClient("OnClientEvent", 3)
		local sig = realmSignal(inst, "OnClientEvent")
		if not sig.onConnect then
			local realm = ctx.realm
			sig.onConnect = function() defer({ world = ctx.world, realm = realm }, function() realm:flushRemote(inst) end) end
		end
		return sig
	end
	c.methods.FireServer = function(inst, ...)
		local ctx = requireClient("FireServer")
		local name = rawget(inst, "_name")
		local args = wireArgs(pack(...), "FireServer " .. name)
		local player = ctx.realm.player
		local world = ctx.world
		table.insert(world.received, { name = name, player = player, args = args })
		defer(nil, function()
			if rawget(player, "_parent") then getSignal(inst, "OnServerEvent"):Fire(player, unpack(args, 1, args.n)) end
		end)
	end
	local function send(inst, player, args)
		local world = worldOf(inst)
		local name = rawget(inst, "_name")
		local copy = wireArgs(args, "FireClient " .. name)
		table.insert(world.sent, { name = name, player = player, args = copy, at = Mock.now })
		local client = world.clients[player]
		if client then
			defer(nil, function() client:deliver(inst, copy) end)
		end
	end
	c.methods.FireClient = function(inst, player, ...)
		requireServer("FireClient")
		if not isInst(player, "Player") then problem("FireClient: player argument must be a Player object", 2) end
		if not rawget(player, "_parent") then return end -- the player has left: nothing is sent
		send(inst, player, pack(...))
	end
	c.methods.FireAllClients = function(inst, ...)
		requireServer("FireAllClients")
		local args = pack(...)
		for _, player in ipairs(worldOf(inst).players) do send(inst, player, args) end
	end
end

-- Services ------------------------------------------------------------------------------------------
defclass("ServiceProvider", "Instance", { creatable = false })
defclass("DataModel", "ServiceProvider", { creatable = false, props = "JobId:ro:string PlaceId:ro:int GameId:ro:int PlaceVersion:ro:int",
	signals = "Loaded", methods = {
		GetService = function(inst, name)
			if type(name) ~= "string" then problem("GetService: string expected", 2) end
			local w = rawget(inst, "_world")
			local s = w.services[name]
			if not s then problem("'" .. name .. "' is not a valid Service name (or the mock does not have it)", 2) end
			return s
		end,
		BindToClose = function(inst, fn)
			requireServer("BindToClose")
			if type(fn) ~= "function" then problem("BindToClose: function expected", 2) end
			table.insert(rawget(inst, "_world").closers, { fn = fn, ctx = Mock.ctx })
		end,
		IsLoaded = function() return true end,
	} })
defclass("Workspace", "Model", { creatable = false, service = true, props = "CurrentCamera:Instance:Camera StreamingEnabled:boolean Gravity:number",
	methods = { GetServerTimeNow = function() return Mock.now end } })
defclass("ReplicatedStorage", "Instance", { creatable = false, service = true })
defclass("ServerScriptService", "Instance", { creatable = false, service = true })
defclass("ServerStorage", "Instance", { creatable = false, service = true })
defclass("StarterPlayer", "Instance", { creatable = false, service = true })
defclass("StarterPlayerScripts", "Instance", { creatable = false })
defclass("StarterGui", "Instance", { creatable = false, service = true })
defclass("Lighting", "Instance", { creatable = false, service = true,
	props = "GlobalShadows:boolean Brightness:number ClockTime:number Ambient:Color3 OutdoorAmbient:Color3", defaults = { GlobalShadows = true } })
defclass("SoundService", "Instance", { creatable = false, service = true })
defclass("RunService", "Instance", { creatable = false, service = true, signals = "Stepped", realmSignals = "Heartbeat RenderStepped PreRender PostSimulation",
	methods = {
		IsStudio = function(inst) return worldOf(inst).studio end,
		IsServer = function() return not Mock.ctx or Mock.ctx.realm.kind == "server" end,
		IsClient = function() return Mock.ctx ~= nil and Mock.ctx.realm.kind == "client" end,
		IsRunning = function() return true end,
	} })
defclass("UserInputService", "Instance", { creatable = false, service = true, realmSignals = "InputBegan InputEnded InputChanged TouchTap",
	props = "TouchEnabled:ro:boolean KeyboardEnabled:ro:boolean MouseEnabled:ro:boolean GamepadEnabled:ro:boolean",
	defaults = { TouchEnabled = true, KeyboardEnabled = false, MouseEnabled = false, GamepadEnabled = false } })

local Tween = { _t = "Tween" }
Tween.__index = Tween
local TWEENABLE = { number = true, int = true, Vector3 = true, Vector2 = true, CFrame = true, Color3 = true, UDim2 = true, UDim = true, boolean = true }
function Tween:Play()
	if self.playing then return end
	self.playing = true
	self.run = (self.run or 0) + 1
	local run = self.run
	push({ at = Mock.now + self.info.DelayTime + self.info.Time, ctx = Mock.ctx, args = pack(), fn = function()
		if self.run ~= run or not self.playing then return end
		self.playing = false
		for k, v in pairs(self.goals) do self.instance[k] = v end
		self.Completed:Fire()
	end })
end
function Tween:Cancel() self.playing = false end
function Tween:Pause() self.playing = false end
function Tween:Destroy() self.playing = false end
defclass("TweenService", "Instance", { creatable = false, service = true, methods = {
	Create = function(_, inst, info, goals)
		if not isInst(inst) then problem("TweenService:Create: Instance expected, got " .. typeofv(inst), 2) end
		if typeofv(info) ~= "TweenInfo" then problem("TweenService:Create: TweenInfo expected, got " .. typeofv(info), 2) end
		if typeofv(goals) ~= "table" then problem("TweenService:Create: table of goals expected", 2) end
		local class = rawget(inst, "_class")
		for k, v in pairs(goals) do
			local want = class.props[k]
			if not want then problem("TweenService:Create: no property named '" .. tostring(k) .. "' on a " .. class.name, 2) end
			if not TWEENABLE[want] then problem("TweenService:Create: property '" .. k .. "' (" .. want .. ") cannot be tweened", 2) end
			if typeofv(v) ~= (want == "int" and "number" or want) then
				problem("TweenService:Create: property '" .. k .. "' wants " .. want .. ", got " .. typeofv(v), 2)
			end
		end
		return setmetatable({ instance = inst, info = info, goals = goals, Completed = newSignal("Tween.Completed") }, Tween)
	end,
} })
defclass("Debris", "Instance", { creatable = false, service = true, methods = {
	AddItem = function(_, inst, life)
		if not isInst(inst) then problem("Debris:AddItem: Instance expected, got " .. typeofv(inst), 2) end
		if life ~= nil and type(life) ~= "number" then problem("Debris:AddItem: number expected", 2) end
		push({ at = Mock.now + (life or 10), ctx = Mock.ctx, args = pack(), fn = function() base.Destroy(inst) end })
	end,
} })

-- DataStoreService: one memory table per store name, shared by every world (like the cloud).
local function storeObject(name)
	Mock.stores[name] = Mock.stores[name] or {}
	local rows = Mock.stores[name]
	local ds = { _t = "DataStore", Name = name }
	local function guard(key, op)
		requireServer("DataStore:" .. op, 3)
		if type(key) ~= "string" or #key == 0 or #key > 50 then problem("DataStore:" .. op .. ": the key must be a string of 1 to 50 characters", 3) end
		asyncYield(Mock.datastore.latency)
		local why = Mock.datastore.fail and Mock.datastore.fail(name, key, op)
		if why then error(why, 0) end
	end
	function ds.UpdateAsync(_, key, fn)
		guard(key, "UpdateAsync")
		if type(fn) ~= "function" then problem("UpdateAsync: function expected", 2) end
		local new = fn(wireCopy(rows[key], "store", "DataStore " .. name .. " read"), {})
		if new == nil then return nil end
		rows[key] = wireCopy(new, "store", "DataStore " .. name .. " key " .. key)
		Mock.datastore.writes = Mock.datastore.writes + 1
		return wireCopy(rows[key], "store", "read")
	end
	function ds.GetAsync(_, key)
		guard(key, "GetAsync")
		return wireCopy(rows[key], "store", "read")
	end
	function ds.SetAsync(_, key, value)
		guard(key, "SetAsync")
		if value == nil then problem("SetAsync: nil cannot be stored", 2) end
		rows[key] = wireCopy(value, "store", "DataStore " .. name .. " key " .. key)
		Mock.datastore.writes = Mock.datastore.writes + 1
	end
	function ds.RemoveAsync(_, key)
		guard(key, "RemoveAsync")
		local old = rows[key]
		rows[key] = nil
		return old
	end
	return setmetatable(ds, { __index = function(_, k) problem(tostring(k) .. " is not a valid member of DataStore", 2) end })
end
defclass("DataStoreService", "Instance", { creatable = false, service = true, methods = {
	GetDataStore = function(_, name, scope)
		requireServer("GetDataStore")
		if type(name) ~= "string" or #name == 0 or #name > 50 then problem("GetDataStore: the name must be a string of 1 to 50 characters", 2) end
		if scope ~= nil and type(scope) ~= "string" then problem("GetDataStore: the scope must be a string", 2) end
		return storeObject(name)
	end,
} })

local function countArgs(max, ...)
	local n = select("#", ...)
	while n > 0 and select(n, ...) == nil do n = n - 1 end
	return n <= max
end
defclass("AnalyticsService", "Instance", { creatable = false, service = true, methods = {
	LogOnboardingFunnelStepEvent = function(inst, player, step, stepName, customFields, ...)
		requireServer("LogOnboardingFunnelStepEvent")
		local what = "LogOnboardingFunnelStepEvent"
		if not countArgs(0, ...) then problem(what .. ": too many arguments", 2) end
		if not isInst(player, "Player") then problem(what .. ": Player expected, got " .. typeofv(player), 2) end
		if type(step) ~= "number" or step ~= math.floor(step) or step < 1 then problem(what .. ": step must be a whole number from 1, got " .. tostring(step), 2) end
		if stepName ~= nil and type(stepName) ~= "string" then problem(what .. ": stepName must be a string, got " .. typeofv(stepName), 2) end
		if customFields ~= nil and type(customFields) ~= "table" then problem(what .. ": customFields must be a table", 2) end
		table.insert(worldOf(inst).analytics, { kind = "funnel", player = player, step = step, stepName = stepName })
	end,
	LogEconomyEvent = function(inst, player, flowType, currencyType, amount, endingBalance, transactionType, itemSku, customFields, ...)
		requireServer("LogEconomyEvent")
		local what = "LogEconomyEvent"
		if not countArgs(0, ...) then problem(what .. ": too many arguments", 2) end
		if not isInst(player, "Player") then problem(what .. ": Player expected, got " .. typeofv(player), 2) end
		if typeofv(flowType) ~= "EnumItem" or flowType.EnumType ~= Enum.AnalyticsEconomyFlowType then
			problem(what .. ": flowType must be an Enum.AnalyticsEconomyFlowType, got " .. typeofv(flowType), 2)
		end
		if type(currencyType) ~= "string" then problem(what .. ": currencyType must be a string, got " .. typeofv(currencyType), 2) end
		if type(amount) ~= "number" or amount ~= amount or amount < 0 then problem(what .. ": amount must be a number of 0 or more, got " .. tostring(amount), 2) end
		if type(endingBalance) ~= "number" or endingBalance ~= endingBalance or endingBalance < 0 then
			problem(what .. ": endingBalance must be a number of 0 or more, got " .. tostring(endingBalance), 2)
		end
		if type(transactionType) ~= "string" then problem(what .. ": transactionType must be a string, got " .. typeofv(transactionType), 2) end
		if itemSku ~= nil and type(itemSku) ~= "string" then problem(what .. ": itemSku must be a string, got " .. typeofv(itemSku), 2) end
		if customFields ~= nil and type(customFields) ~= "table" then problem(what .. ": customFields must be a table", 2) end
		table.insert(worldOf(inst).analytics, { kind = "economy", player = player, flow = flowType.Name, currency = currencyType, amount = amount,
			balance = endingBalance, transaction = transactionType, sku = itemSku })
	end,
} })
defclass("MarketplaceService", "Instance", { creatable = false, service = true, props = "ProcessReceipt:function",
	signals = "PromptGamePassPurchaseFinished PromptProductPurchaseFinished PromptPurchaseFinished", methods = {
		UserOwnsGamePassAsync = function(inst, userId, passId)
			if type(userId) ~= "number" or type(passId) ~= "number" then problem("UserOwnsGamePassAsync: two numbers expected", 2) end
			asyncYield()
			return worldOf(inst).passes[userId .. ":" .. passId] == true
		end,
		PromptGamePassPurchase = function(inst, player, passId)
			if not isInst(player, "Player") or type(passId) ~= "number" then problem("PromptGamePassPurchase: (Player, number) expected", 2) end
			table.insert(worldOf(inst).prompts, { kind = "pass", player = player, id = passId })
		end,
		PromptProductPurchase = function(inst, player, productId)
			if not isInst(player, "Player") or type(productId) ~= "number" then problem("PromptProductPurchase: (Player, number) expected", 2) end
			table.insert(worldOf(inst).prompts, { kind = "product", player = player, id = productId })
		end,
	} })
defclass("SocialService", "Instance", { creatable = false, service = true, methods = {
	CanSendGameInviteAsync = function(inst, player)
		requireClient("CanSendGameInviteAsync")
		if not isInst(player, "Player") then problem("CanSendGameInviteAsync: Player expected", 2) end
		asyncYield()
		return worldOf(inst).canInvite
	end,
	PromptGameInvite = function(inst, player)
		requireClient("PromptGameInvite")
		if not isInst(player, "Player") then problem("PromptGameInvite: Player expected", 2) end
		table.insert(worldOf(inst).prompts, { kind = "invite", player = player })
	end,
} })
defclass("PolicyService", "Instance", { creatable = false, service = true, methods = {
	GetPolicyInfoForPlayerAsync = function(inst, player)
		if not isInst(player, "Player") then problem("GetPolicyInfoForPlayerAsync: Player expected", 2) end
		asyncYield()
		local w = worldOf(inst)
		if w.policyError then error(w.policyError, 0) end
		local out = {}
		for k, v in pairs(w.policy) do out[k] = v end
		return out
	end,
} })
defclass("CaptureService", "Instance", { creatable = false, service = true, methods = {
	CaptureScreenshot = function(inst, onReady)
		requireClient("CaptureScreenshot")
		if type(onReady) ~= "function" then problem("CaptureScreenshot: function expected", 2) end
		local w = worldOf(inst)
		table.insert(w.prompts, { kind = "capture" })
		defer(Mock.ctx, onReady, "rbxtemp://mock-capture-" .. #w.prompts)
	end,
	PromptSaveCapturesToGallery = function(inst, captures, onResult)
		requireClient("PromptSaveCapturesToGallery")
		if type(captures) ~= "table" or type(captures[1]) ~= "string" then problem("PromptSaveCapturesToGallery: a list of content ids expected", 2) end
		if type(onResult) ~= "function" then problem("PromptSaveCapturesToGallery: function expected", 2) end
		table.insert(worldOf(inst).prompts, { kind = "saveCapture", captures = captures })
	end,
} })

defclass("Player", "Instance", { creatable = false,
	props = "UserId:ro:int DisplayName:ro:string Character:Instance:Model AccountAge:ro:int",
	signals = "CharacterAdded CharacterRemoving", methods = {
		Kick = function(inst, message)
			requireServer("Player:Kick")
			if message ~= nil and type(message) ~= "string" then problem("Kick: string expected", 2) end
			local w = worldOf(inst) or rawget(inst, "_home")
			table.insert(w.kicks, { player = inst, message = message })
			defer(nil, function() w:removePlayer(inst) end)
		end,
		IsFriendsWithAsync = function(inst, userId)
			if type(userId) ~= "number" then problem("IsFriendsWithAsync: number expected, got " .. typeofv(userId), 2) end
			asyncYield()
			local w = rawget(inst, "_home")
			if w.friendError then error(w.friendError, 0) end
			local a, b = inst.UserId, userId
			if a > b then a, b = b, a end
			return w.friends[a .. ":" .. b] == true
		end,
		RequestStreamAroundAsync = function(inst, position, timeout)
			if not isV3(position) then problem("RequestStreamAroundAsync: Vector3 expected, got " .. typeofv(position), 2) end
			if timeout ~= nil and type(timeout) ~= "number" then problem("RequestStreamAroundAsync: number expected for the timeout", 2) end
			asyncYield()
		end,
	} })
defclass("Players", "Instance", { creatable = false, service = true, props = "MaxPlayers:ro:int LocalPlayer:ro:Instance",
	signals = "PlayerAdded PlayerRemoving",
	get = { LocalPlayer = function() return Mock.ctx and Mock.ctx.realm.player or nil end },
	methods = {
		GetPlayers = function(inst)
			local out = {}
			for i, p in ipairs(worldOf(inst).players) do out[i] = p end
			return out
		end,
		GetPlayerByUserId = function(inst, userId)
			if type(userId) ~= "number" then problem("GetPlayerByUserId: number expected, got " .. typeofv(userId), 2) end
			for _, p in ipairs(worldOf(inst).players) do if p.UserId == userId then return p end end
		end,
		GetPlayerFromCharacter = function(inst, model)
			if model ~= nil and not isInst(model) then problem("GetPlayerFromCharacter: Instance expected, got " .. typeofv(model), 2) end
			for _, p in ipairs(worldOf(inst).players) do if rawget(p, "_props").Character == model then return p end end
		end,
	} })

-- Realms: the globals a script sees ---------------------------------------------------------------------
local function random(m, n)
	Mock.randState = (Mock.randState * 1103515245 + 12345) % 2147483648
	local r = Mock.randState / 2147483648
	if m == nil then return r end
	if type(m) ~= "number" or (n ~= nil and type(n) ~= "number") then problem("math.random: number expected", 2) end
	if n == nil then m, n = 1, m end
	if m ~= math.floor(m) or n ~= math.floor(n) then problem("math.random: whole numbers expected, got " .. m .. ", " .. n, 2) end
	if m > n then problem("math.random: interval is empty", 2) end
	return m + math.floor(r * (n - m + 1))
end
local function extend(lib, extra)
	local out = {}
	for k, v in pairs(lib) do out[k] = v end
	for k, v in pairs(extra) do out[k] = v end
	return out
end
local mathLib = extend(math, {
	random = random,
	randomseed = function() end,
	clamp = function(x, lo, hi)
		if type(x) ~= "number" or type(lo) ~= "number" or type(hi) ~= "number" then problem("math.clamp: three numbers expected", 2) end
		if lo > hi then problem("math.clamp: max must be greater than or equal to min", 2) end
		return x < lo and lo or (x > hi and hi or x)
	end,
	round = function(x) return math.floor(x + 0.5) end,
	sign = function(x) return x > 0 and 1 or (x < 0 and -1 or 0) end,
})
local tableLib = extend(table, {
	find = function(t, v, init) for i = init or 1, #t do if t[i] == v then return i end end end,
	clear = function(t) for k in pairs(t) do t[k] = nil end end,
	create = function(n, v) local t = {} for i = 1, n do t[i] = v end return t end,
	unpack = unpack, pack = pack,
	clone = function(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end,
})
local stringLib = extend(string, {
	split = function(s, sep)
		local out = {}
		for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = piece end
		return out
	end,
})
getmetatable("").__index = stringLib -- so ("x"):split(",") works; the extra functions do no harm elsewhere
local osLib = {
	time = function(t)
		if t ~= nil then return os.time(t) end
		return math.floor(Mock.now)
	end,
	clock = function() return Mock.now - Mock.t0 end,
	date = os.date, difftime = os.difftime,
}

local Realm = {}
Realm.__index = Realm
local function say(list, ...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
	list[#list + 1] = table.concat(parts, " ")
	if Mock.echo then print(list[#list]) end
end

local function newRealm(world, kind, player)
	local realm = setmetatable({ world = world, kind = kind, player = player, modules = {}, loading = {}, signals = {}, log = {}, pending = {} }, Realm)
	realm.ctx = { world = world, realm = realm }
	local env = {
		game = world.game, workspace = world.workspace, Instance = Instance, Enum = Enum, task = task,
		Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Vector2 = Vector2, UDim = UDim, UDim2 = UDim2, TweenInfo = TweenInfo,
		ColorSequence = ColorSequence, NumberSequence = NumberSequence, NumberRange = NumberRange,
		math = mathLib, table = tableLib, string = stringLib, os = osLib, pcall = copcall, typeof = typeofv,
		tick = function() return Mock.now end, time = function() return Mock.now - Mock.t0 end,
		print = function(...) say(Mock.prints, ...) end,
		warn = function(...) say(Mock.warnings, ...) end,
	}
	env.require = function(module)
		if not isInst(module, "ModuleScript") then
			problem("require: ModuleScript expected, got " .. (isInst(module) and module.ClassName or typeofv(module)), 2)
		end
		if realm.modules[module] ~= nil then return realm.modules[module] end
		if realm.loading[module] then problem("Requested module was required recursively: " .. fullName(module), 2) end
		realm.loading[module] = true
		local value = realm:load(module)
		realm.loading[module] = nil
		if value == nil then problem("Module code did not return exactly one value: " .. fullName(module), 2) end
		realm.modules[module] = value
		return value
	end
	env._G = env
	realm.env = setmetatable(env, { __index = _G })
	return realm
end
function Realm:load(scriptInst, ...)
	local path = rawget(scriptInst, "_path")
	if not path then problem("the mock has no source for " .. fullName(scriptInst), 3) end
	local fn, err = loadfile(path)
	if not fn then error(err, 0) end
	setfenv(fn, setmetatable({ script = scriptInst }, { __index = self.env }))
	return fn(...)
end
-- Run fn in this realm (as a thread, so it may yield). Returns the thread.
function Realm:run(fn, ...) return spawnIn(self.ctx, fn, ...) end
-- Run fn in this realm and return what it returned (it must not yield).
function Realm:call(fn, ...)
	local out
	self:run(function(...) out = pack(fn(...)) end, ...)
	if not out then error("Realm:call: the function yielded or failed: " .. tostring(Mock.errors[#Mock.errors]), 2) end
	return unpack(out, 1, out.n)
end
function Realm:require(...)
	local node = self.root
	for _, name in ipairs({ ... }) do node = findChild(node, name) or error("no module " .. name, 2) end
	return self:call(self.env.require, node)
end
function Realm:runScript(scriptInst) return self:run(function() self:load(scriptInst) end) end

-- client side ----------------------------------------------------------------------------------------
function Realm:deliver(remote, args)
	if self.dead then return end
	local name = rawget(remote, "_name")
	self.log[#self.log + 1] = { name = name, args = args, at = Mock.now }
	local sig = self.signals[remote] and self.signals[remote].OnClientEvent
	if sig and #sig.conns > 0 then
		sig:Fire(unpack(args, 1, args.n))
	else
		self.pending[remote] = self.pending[remote] or {}
		table.insert(self.pending[remote], args) -- Roblox queues events until the first handler connects
	end
end
function Realm:flushRemote(remote)
	local queue = self.pending[remote]
	if not queue then return end
	self.pending[remote] = nil
	local sig = self.signals[remote].OnClientEvent
	for _, args in ipairs(queue) do sig:Fire(unpack(args, 1, args.n)) end
end
-- Send a remote exactly as a LocalScript would.
function Realm:fire(name, ...)
	local remote = self.world:remote(name)
	local args = pack(...)
	self:run(function() remote:FireServer(unpack(args, 1, args.n)) end)
	Mock.flush()
end
-- Everything this client was sent under `name`: a list of argument lists.
function Realm:got(name)
	local out = {}
	for _, e in ipairs(self.log) do if e.name == name then out[#out + 1] = e.args end end
	return out
end
function Realm:last(name)
	for i = #self.log, 1, -1 do if self.log[i].name == name then return self.log[i].args end end
end
function Realm:clear() self.log = {} end
function Realm:input(inputType, keyCode, processed)
	local sig = self.signals[self.world.services.UserInputService]
	sig = sig and sig.InputBegan
	if not sig then return 0 end
	local io = { UserInputType = inputType or Enum.UserInputType.Touch, KeyCode = keyCode or Enum.KeyCode.Unknown,
		Position = v3(300, 200, 0), UserInputState = Enum.UserInputState.Begin }
	local n = #sig.conns
	sig:Fire(io, processed or false)
	Mock.flush()
	return n
end

-- Worlds ---------------------------------------------------------------------------------------------
local World = {}
World.__index = World

local function mount(world, dir, name, parent)
	local node = create("Folder", name)
	for _, f in ipairs(LISTDIR(dir)) do
		local baseName = f:match("([^/]+)$")
		if baseName == "init.lua" then
			rawset(node, "_class", classes.ModuleScript)
			rawset(node, "_path", f)
		elseif baseName:match("%.server%.lua$") then
			local s = create("Script", (baseName:gsub("%.server%.lua$", "")))
			rawset(s, "_path", f)
			setParent(s, node)
		elseif baseName:match("%.client%.lua$") then
			local s = create("LocalScript", (baseName:gsub("%.client%.lua$", "")))
			rawset(s, "_path", f)
			setParent(s, node)
		elseif baseName:match("%.lua$") then
			local s = create("ModuleScript", (baseName:gsub("%.lua$", "")))
			rawset(s, "_path", f)
			setParent(s, node)
		else
			mount(world, f, baseName, node)
		end
	end
	if parent then setParent(node, parent) end
	return node
end

local SERVICES = { "Workspace", "Players", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterPlayer", "StarterGui", "Lighting",
	"SoundService", "RunService", "UserInputService", "TweenService", "Debris", "DataStoreService", "AnalyticsService", "MarketplaceService",
	"SocialService", "PolicyService", "CaptureService" }

-- opts: studio (bool, default true), jobId (string; "" in Studio), src (other source root)
function Mock.newWorld(opts)
	opts = opts or {}
	local world = setmetatable({
		studio = opts.studio ~= false, players = {}, clients = {}, services = {}, closers = {},
		sent = {}, received = {}, analytics = {}, prompts = {}, kicks = {},
		friends = {}, passes = {}, canInvite = true, policy = { IsContentSharingAllowed = true, IsSubjectToChinaPolicies = false },
	}, World)
	local game = create("DataModel", "Game")
	rawset(game, "_world", world)
	rawget(game, "_props").JobId = opts.jobId or (world.studio and "" or "job-" .. (#Mock.worlds + 1))
	rawget(game, "_props").PlaceId = 1
	world.game = game
	for _, name in ipairs(SERVICES) do
		local s = create(name, name)
		rawset(s, "_world", world)
		setParent(s, game)
		world.services[name] = s
	end
	world.workspace = world.services.Workspace
	local camera = create("Camera", "Camera")
	setParent(camera, world.workspace)
	rawget(world.workspace, "_props").CurrentCamera = camera
	local src = opts.src or SRC
	mount(world, src .. "/shared", "Shared", world.services.ReplicatedStorage)
	local sps = create("StarterPlayerScripts", "StarterPlayerScripts")
	setParent(sps, world.services.StarterPlayer)
	world.src = src
	world.server = newRealm(world, "server")
	world.server.root = mount(world, src .. "/server", "Server", world.services.ServerScriptService)
	-- frames: Heartbeat on the server and every client, RenderStepped on clients, only while something listens
	local function frame()
		if world.dead then return end
		local busy = false
		local function fire(realm)
			local sigs = realm.signals[world.services.RunService]
			if not sigs or realm.dead then return end
			for name, sig in pairs(sigs) do
				if #sig.conns > 0 then
					busy = true
					if name ~= "RenderStepped" and name ~= "PreRender" or realm.kind == "client" then sig:Fire(Mock.FRAME) end
				end
			end
		end
		fire(world.server)
		for _, c in pairs(world.clients) do fire(c) end
		world.frames = busy
		if busy then push({ at = Mock.now + Mock.FRAME, fn = frame, args = pack() }) end
	end
	world.kick = function()
		if not world.frames then
			world.frames = true
			push({ at = Mock.now + Mock.FRAME, fn = frame, args = pack() })
		end
	end
	Mock.worlds[#Mock.worlds + 1] = world
	return world
end

-- Frame signals start the frame timer when something connects.
do
	local rs = classes.RunService
	for name in pairs(rs.realmSignals) do
		rs.get[name] = function(inst)
			if (name == "RenderStepped" or name == "PreRender") and Mock.ctx and Mock.ctx.realm.kind ~= "client" then
				problem("RunService." .. name .. " can only be used from a LocalScript", 3)
			end
			local sig = realmSignal(inst, name)
			local world = worldOf(inst)
			sig.onConnect = function() world.kick() end
			return sig
		end
	end
end

function World:startServer()
	local main = findChild(self.server.root, "Main")
	self.server:runScript(main)
	Mock.flush()
	return self
end
function World:remote(name)
	local folder = findChild(self.services.ReplicatedStorage, "PetTowerRemotes")
	local r = folder and findChild(folder, name)
	if not r then error("no remote named " .. tostring(name), 2) end
	return r
end

local function buildCharacter(world, player)
	local model = create("Model", rawget(player, "_name"))
	local hrp = create("Part", "HumanoidRootPart")
	rawget(hrp, "_props").Size = v3(2, 2, 1)
	rawget(hrp, "_props").CFrame = CFrame.new(0, 100, 0)
	setParent(hrp, model)
	local head = create("Part", "Head")
	rawget(head, "_props").Size = v3(1.2, 1.2, 1.2)
	rawget(head, "_props").CFrame = CFrame.new(0, 101.6, 0)
	setParent(head, model)
	setParent(create("Humanoid", "Humanoid"), model)
	rawget(model, "_props").PrimaryPart = hrp
	return model
end
function World:spawnCharacter(player)
	if not rawget(player, "_parent") then return end
	local old = rawget(player, "_props").Character
	if old then
		getSignal(player, "CharacterRemoving"):Fire(old)
		base.Destroy(old)
	end
	local model = buildCharacter(self, player)
	rawget(player, "_props").Character = model
	setParent(model, self.workspace)
	getSignal(player, "CharacterAdded"):Fire(model)
	Mock.flush()
	return model
end
-- info: UserId, Name, DisplayName, character (false = do not spawn one)
function World:addPlayer(info)
	local player = create("Player", info.Name or ("Player" .. info.UserId))
	rawset(player, "_home", self)
	local props = rawget(player, "_props")
	props.UserId = info.UserId
	props.DisplayName = info.DisplayName or info.Name or ("Player" .. info.UserId)
	props.AccountAge = 100
	setParent(create("PlayerGui", "PlayerGui"), player)
	setParent(create("PlayerScripts", "PlayerScripts"), player)
	setParent(create("Backpack", "Backpack"), player)
	setParent(player, self.services.Players)
	self.players[#self.players + 1] = player
	self.clients[player] = newRealm(self, "client", player)
	getSignal(self.services.Players, "PlayerAdded"):Fire(player)
	Mock.flush()
	if info.character ~= false then
		push({ at = Mock.now + 0.1, args = pack(), fn = function() self:spawnCharacter(player) end })
	end
	return player, self.clients[player]
end
function World:client(player) return self.clients[player] end
function World:removePlayer(player)
	if not rawget(player, "_parent") then return end
	getSignal(self.services.Players, "PlayerRemoving"):Fire(player)
	for i = #self.players, 1, -1 do if self.players[i] == player then table.remove(self.players, i) end end
	local ch = rawget(player, "_props").Character
	local client = self.clients[player]
	if client then client.dead = true end
	self.clients[player] = nil
	setParent(player, nil)
	if ch then base.Destroy(ch) end
	Mock.flush()
end
-- Mount src/client under the player's PlayerScripts and run Main.client.lua there.
function World:startClient(player)
	local realm = self.clients[player]
	local scripts = findChild(player, "PlayerScripts")
	realm.root = mount(self, self.src .. "/client", "Client", scripts)
	realm:runScript(findChild(realm.root, "Main"))
	Mock.flush()
	return realm
end

-- Moving and touching, as a player would -----------------------------------------------------------------
function World:root(player)
	local ch = rawget(player, "_props").Character
	return ch and findChild(ch, "HumanoidRootPart")
end
function World:walkTo(player, position)
	local ch = rawget(player, "_props").Character
	if not ch then error("walkTo: " .. player.Name .. " has no character", 2) end
	local hrp = findChild(ch, "HumanoidRootPart")
	ch:PivotTo(cf(position, hrp.CFrame.r))
end
-- Is the character (a box about 4 x 5 x 4 studs around the root part) touching the part?
function World:overlaps(player, part)
	local hrp = self:root(player)
	if not hrp then return false end
	local l = part.CFrame:PointToObjectSpace(hrp.Position)
	local s = part.Size
	return math.abs(l.X) <= s.X / 2 + 3 and math.abs(l.Y) <= s.Y / 2 + 3 and math.abs(l.Z) <= s.Z / 2 + 3
end
-- Fire part.Touched with the player's root part. The character must really be at the part.
function World:touch(part, player)
	if not self:overlaps(player, part) then
		error("touch: " .. player.Name .. " at (" .. tostring(self:root(player) and self:root(player).Position) .. ") is not touching "
			.. fullName(part) .. " at (" .. tostring(part.Position) .. ")", 2)
	end
	if part.CanTouch == false then error("touch: " .. fullName(part) .. " has CanTouch off", 2) end
	getSignal(part, "Touched"):Fire(self:root(player))
	Mock.flush()
end
-- Trigger a ProximityPrompt. The player must be within its MaxActivationDistance.
function World:trigger(prompt, player)
	local hrp = self:root(player)
	local at = prompt.Parent
	local d = (at.Position - hrp.Position).Magnitude - math.max(at.Size.X, at.Size.Z) / 2
	if d > prompt.MaxActivationDistance then
		error("trigger: " .. player.Name .. " is " .. math.floor(d) .. " studs from " .. fullName(prompt) .. " (max " .. prompt.MaxActivationDistance .. ")", 2)
	end
	getSignal(prompt, "Triggered"):Fire(player)
	Mock.flush()
end
-- A developer product purchase: calls MarketplaceService.ProcessReceipt on the server. Returns { decision = EnumItem } once it answers.
function World:purchase(player, productId, purchaseId)
	local out = {}
	local callback = rawget(self.services.MarketplaceService, "_props").ProcessReceipt
	if not callback then error("no ProcessReceipt callback is set", 2) end
	self.server:run(function()
		out.decision = callback({ PlayerId = player.UserId, PurchaseId = purchaseId, ProductId = productId, CurrencySpent = 0, PlaceIdWherePurchased = 1 })
	end)
	return out
end
function World:sentTo(player, name)
	local out = {}
	for _, e in ipairs(self.sent) do
		if e.name == name and (player == nil or e.player == player) then out[#out + 1] = e end
	end
	return out
end
-- Close the server: BindToClose callbacks run (30 s at most), players leave, then nothing of this world runs again.
function World:shutdown()
	local waiting = 0
	for _, c in ipairs(self.closers) do
		waiting = waiting + 1
		spawnIn(c.ctx, function() c.fn() waiting = waiting - 1 end)
	end
	local t = 0
	while waiting > 0 and t < 30 do Mock.step(0.5) t = t + 0.5 end
	self.closeSeconds, self.closeStuck = t, waiting
	for i = #self.players, 1, -1 do self:removePlayer(self.players[i]) end
	Mock.step(1)
	self.dead = true
end

Mock.Vector3, Mock.CFrame, Mock.Color3, Mock.Enum, Mock.Instance, Mock.UDim2, Mock.task = Vector3, CFrame, Color3, Enum, Instance, UDim2, task
Mock.reset()
return Mock
