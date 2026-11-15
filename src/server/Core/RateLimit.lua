-- Token bucket per player per remote. No Roblox APIs.
local RateLimit = {}
RateLimit.__index = RateLimit
-- rules: name -> { rate = tokens per second, burst = bucket size }
function RateLimit.new(rules) return setmetatable({ rules = rules, buckets = {}, flags = {} }, RateLimit) end
function RateLimit:allow(userId, name, now)
	local rule = self.rules[name] or self.rules.default
	local key = userId .. ":" .. name
	local b = self.buckets[key]
	if not b then b = { tokens = rule.burst, t = now } self.buckets[key] = b end
	b.tokens = math.min(rule.burst, b.tokens + (now - b.t) * rule.rate)
	b.t = now
	if b.tokens < 1 then
		self.flags[userId] = (self.flags[userId] or 0) + 1 -- flagged for review, never auto-banned
		return false
	end
	b.tokens = b.tokens - 1
	return true
end
function RateLimit:forget(userId)
	local prefix = userId .. ":"
	for key in pairs(self.buckets) do
		if key:sub(1, #prefix) == prefix then self.buckets[key] = nil end
	end
end
return RateLimit
