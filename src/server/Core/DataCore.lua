-- Session-locked saving over an injected store, so it can be tested without Roblox.
-- store:update(key, fn) must behave like DataStore:UpdateAsync (fn gets the old value, returns the new
-- one, or nil to cancel) and may throw. clock() returns seconds. sleep(n) waits.
local Profile = require(script.Parent.Profile)
local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local D = require(Shared.Config).Economy.Data

local DataCore = {}
DataCore.__index = DataCore

function DataCore.new(store, jobId, clock, sleep)
	return setmetatable({ store = store, jobId = jobId, clock = clock, sleep = sleep or function() end, held = {} }, DataCore)
end

-- Fill in fields added since the save was written; step the version up one migration at a time.
DataCore.Migrations = {} -- [fromVersion] = function(data) ... end
local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
			reconcile(data[k], v)
		end
	end
end
function DataCore.upgrade(data, now)
	data.version = data.version or 1
	while data.version < Profile.Version do
		local step = DataCore.Migrations[data.version]
		if step then step(data) end
		data.version = data.version + 1
	end
	reconcile(data, Profile.new(now))
	return data
end

function DataCore:_retry(fn)
	local lastErr
	for attempt = 1, D.Retries do
		local ok, a, b = pcall(fn)
		if ok then return true, a, b end
		lastErr = a
		self.sleep(attempt * 2)
	end
	return false, lastErr
end

-- Load and take the lock. Returns profile, or nil + reason ("locked" = another server holds it;
-- "error" = the store failed: never hand out a blank profile in that case).
function DataCore:load(key)
	local now = self.clock()
	local result, reason
	local ok = self:_retry(function()
		result, reason = nil, nil
		self.store:update(key, function(old)
			old = old or { data = nil, lock = nil }
			local lock = old.lock
			if lock and lock.job ~= self.jobId and now - lock.t < D.LockStaleSeconds then
				reason = "locked"
				return nil
			end
			local data = old.data and DataCore.upgrade(old.data, now) or Profile.new(now)
			result = data
			return { data = data, lock = { job = self.jobId, t = now } }
		end)
	end)
	if not ok then return nil, "error" end
	if not result then return nil, reason or "error" end
	self.held[key] = true
	return result
end

-- Save. release = true gives the lock back (player left). Refuses to write if the lock was lost.
function DataCore:save(key, data, release)
	if not self.held[key] then return false, "not_held" end
	local now = self.clock()
	local lost = false
	local ok = self:_retry(function()
		lost = false
		self.store:update(key, function(old)
			if old and old.lock and old.lock.job ~= self.jobId then
				lost = true
				return nil
			end
			return { data = data, lock = (not release) and { job = self.jobId, t = now } or nil }
		end)
	end)
	if lost then self.held[key] = nil return false, "lock_lost" end
	if not ok then return false, "error" end
	if release then self.held[key] = nil end
	return true
end

return DataCore
