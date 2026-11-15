-- Runs every test file. python3 tools/lua.py tests/run.lua
local files = {}
for _, path in ipairs(LISTDIR(ROOT .. "/tests")) do
	local name = path:match("(test_[%w_]+)%.lua$")
	if name then files[#files + 1] = name end
end
local pass, fail = 0, 0
T = {}
function T.eq(a, b, msg)
	if a ~= b then error((msg or "eq") .. ": got " .. tostring(a) .. ", want " .. tostring(b), 2) end
end
function T.near(a, b, tol, msg)
	if math.abs(a - b) > (tol or 1e-6) then error((msg or "near") .. ": got " .. tostring(a) .. ", want " .. tostring(b), 2) end
end
function T.ok(v, msg) if not v then error(msg or "expected true", 2) end end
function T.no(v, msg) if v then error(msg or "expected false", 2) end end
for _, name in ipairs(files) do
	local path = ROOT .. "/tests/" .. name .. ".lua"
	local f = io.open(path)
	if f then
		f:close()
		local tests = runfile(path)
		local names = {}
		for n in pairs(tests) do names[#names + 1] = n end
		table.sort(names)
		for _, n in ipairs(names) do
			local ok, err = pcall(tests[n])
			if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. "." .. n .. ": " .. tostring(err)) end
		end
	end
end
print(string.format("tests: %d passed, %d failed", pass, fail))
if fail > 0 then error("tests failed") end
