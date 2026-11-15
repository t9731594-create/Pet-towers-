-- Client entry point (greybox UI, M1-M3). Phone first: landscape, big targets, icons and numbers.
local Controllers = script.Parent.Controllers
local order = { "HUD", "TrustTap", "Showdown", "FX", "WildShowdown", "Secret", "Wick", "Choice", "Welcome", "Emotes" }
for _, name in ipairs(order) do
	local module = Controllers:FindFirstChild(name)
	if module then
		local ok, err = pcall(function() require(module).init() end)
		if not ok then warn("[PetTower] controller " .. name .. ": " .. tostring(err)) end
	end
end
