-- Headless stand-in for the Roblox instance tree, so modules can use
-- require(script.Parent.X) exactly as they do in Studio.
-- Mapping (same as default.project.json):
--   src/shared -> ReplicatedStorage.Shared      src/server -> ServerScriptService.Server
--   src/client -> StarterPlayer.StarterPlayerScripts.Client
local Inst = {}
Inst.__index = function(self, k)
	if k == "Parent" then return rawget(self, "_parent") end
	if k == "Name" then return rawget(self, "_name") end
	local kids = rawget(self, "_kids")
	if kids[k] then return kids[k] end
	if Inst[k] then return Inst[k] end
	error("no child '" .. tostring(k) .. "' under " .. rawget(self, "_name"), 2)
end
function Inst.FindFirstChild(self, k) return rawget(self, "_kids")[k] end
function Inst.WaitForChild(self, k) return self[k] end
function Inst.GetChildren(self)
	local out = {} for _, c in pairs(rawget(self, "_kids")) do out[#out + 1] = c end return out
end
local function new(name, parent, path)
	local i = setmetatable({ _name = name, _parent = parent, _kids = {}, _path = path }, Inst)
	if parent then rawget(parent, "_kids")[name] = i end
	return i
end
local function mount(dir, name, parent)
	local node = new(name, parent)
	for _, f in ipairs(LISTDIR(dir)) do
		local base = f:match("([^/]+)$")
		if base == "init.lua" or base == "init.server.lua" or base == "init.client.lua" then
			rawset(node, "_path", f)
		elseif base:match("%.lua$") then
			local n = base:gsub("%.server%.lua$", ""):gsub("%.client%.lua$", ""):gsub("%.lua$", "")
			new(n, node, f)
		else
			mount(f, base, node)
		end
	end
	return node
end
game = new("game")
local rs = new("ReplicatedStorage", game)
local sss = new("ServerScriptService", game)
mount(ROOT .. "/src/shared", "Shared", rs)
mount(ROOT .. "/src/server", "Server", sss)
local loaded = {}
local realRequire = require
function require(target)
	if type(target) ~= "table" then return realRequire(target) end
	local path = rawget(target, "_path")
	if not path then error("not a module: " .. rawget(target, "_name")) end
	if loaded[path] == nil then
		local fn, err = loadfile(path)
		if not fn then error(err) end
		setfenv(fn, setmetatable({ script = target }, { __index = _G }))
		loaded[path] = fn()
	end
	return loaded[path]
end
function runfile(path)
	local fn, err = loadfile(path)
	if not fn then error(err) end
	return fn()
end
Shared = rs.Shared
Server = sss.Server
