local DataCore = require(Server.Core.DataCore)
local Profile = require(Server.Core.Profile)
local t = {}
local function deep(v)
	if type(v) ~= "table" then return v end
	local c = {} for k, x in pairs(v) do c[k] = deep(x) end return c
end
local function fakeStore()
	local s = { rows = {}, failNext = 0, calls = 0 }
	function s:update(key, fn)
		self.calls = self.calls + 1
		if self.failNext > 0 then self.failNext = self.failNext - 1 error("store down") end
		local new = fn(deep(self.rows[key]))
		if new ~= nil then self.rows[key] = deep(new) end
	end
	return s
end
function t.rejoin_keeps_everything()
	local store, now = fakeStore(), 1000
	local a = DataCore.new(store, "job-A", function() return now end)
	local p = a:load("u1")
	Profile.chooseStarter(p, "Capling")
	Profile.addCaught(p, "Zipwing", "Rare", true)
	Profile.deposit(p, now)
	p.coins = 777
	Profile.clearFloor(p, 1)
	T.ok(a:save("u1", p, true))
	now = 2000
	local b = DataCore.new(store, "job-B", function() return now end)
	local q = b:load("u1")
	T.eq(q.coins, 777) T.eq(q.starter.species, "Capling") T.eq(q.pets[1].species, "Zipwing")
	T.ok(q.pets[1].radiant) T.eq(q.pads[1].pet, 1) T.eq(q.cleared, 1) T.ok(q.floors["1"].cleared)
end
function t.session_lock_blocks_second_server()
	local store, now = fakeStore(), 1000
	local a = DataCore.new(store, "job-A", function() return now end)
	local b = DataCore.new(store, "job-B", function() return now end)
	T.ok(a:load("u1"))
	local p, why = b:load("u1")
	T.no(p) T.eq(why, "locked")
	now = 1000 + 601 -- a crashed server's lock goes stale
	T.ok(b:load("u1"))
	local ok, reason = a:save("u1", Profile.new(now), false)
	T.no(ok) T.eq(reason, "lock_lost") -- the old server can no longer overwrite
end
function t.autosave_keeps_lock_fresh()
	local store, now = fakeStore(), 1000
	local a = DataCore.new(store, "job-A", function() return now end)
	local b = DataCore.new(store, "job-B", function() return now end)
	local p = a:load("u1")
	now = 1500 a:save("u1", p, false)
	now = 1700
	T.no(b:load("u1"))
end
function t.retries_then_fails_without_blank_profile()
	local store = fakeStore()
	local a = DataCore.new(store, "job-A", function() return 0 end)
	store.failNext = 2
	T.ok(a:load("u1"))
	store.failNext = 99
	local p, why = a:load("u2")
	T.no(p) T.eq(why, "error")
	local ok, reason = a:save("u1", Profile.new(0), false)
	T.no(ok) T.eq(reason, "error")
end
function t.upgrade_fills_new_fields()
	local old = { version = 1, coins = 5, settings = { music = 0 }, stats = { catches = 3 } }
	local p = DataCore.upgrade(old, 9)
	T.eq(p.coins, 5) T.eq(p.settings.music, 0) T.eq(p.settings.effects, 1)
	T.eq(p.stats.catches, 3) T.ok(p.stats.sources) T.eq(#p.pads, 8) T.eq(p.charm, 1)
end
function t.save_needs_lock()
	local a = DataCore.new(fakeStore(), "job-A", function() return 0 end)
	local ok, why = a:save("nobody", {}, false)
	T.no(ok) T.eq(why, "not_held")
end
return t
