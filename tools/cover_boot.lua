-- Which lines of the Roblox-facing code did the boot tests run?   python3 tools/lua.py tools/cover_boot.lua
-- Runs tests/test_boot_server.lua and tests/test_boot_client.lua with a line hook on every game thread
-- and lists, per file under src/server/Services, src/server/Main and src/client, the lines that never ran.
-- A rough count: "lines" are source lines that are not blank, not a comment, and not a bare end / else /
-- function header. The soak test is left out (it is slow under the hook and adds no new lines).
-- Takes about a minute and a half (the hook looks up the source file on every line).
T = {}
function T.eq(a, b, msg) if a ~= b then error((msg or "eq") .. ": got " .. tostring(a) .. ", want " .. tostring(b), 2) end end
function T.near(a, b, tol, msg) if math.abs(a - b) > (tol or 1e-6) then error((msg or "near") .. ": got " .. tostring(a) .. ", want " .. tostring(b), 2) end end
function T.ok(v, msg) if not v then error(msg or "expected true", 2) end end
function T.no(v, msg) if v then error(msg or "expected false", 2) end end

local hits = {}
local getinfo = debug.getinfo
local function hook(_, line)
	local src = getinfo(2, "S").source
	local h = hits[src]
	if not h then h = {} hits[src] = h end
	h[line] = true
end
local realRunfile = runfile
function runfile(path)
	local value = realRunfile(path)
	if path:find("roblox_mock") then value.lineHook = hook end
	return value
end
local failed = 0
for _, file in ipairs({ "tests/test_boot_server.lua", "tests/test_boot_client.lua" }) do
	local tests = realRunfile(ROOT .. "/" .. file)
	for name, fn in pairs(tests) do
		local ok, err = pcall(fn)
		if not ok then failed = failed + 1 print("FAIL " .. name .. ": " .. tostring(err)) end
	end
end
local SKIP = { ["end"] = true, ["end)"] = true, ["end,"] = true, ["}"] = true, ["})"] = true, ["},"] = true, ["else"] = true }
local rows, total, covered = {}, 0, 0
for src, h in pairs(hits) do
	if src:find("/src/server/Services/", 1, true) or src:find("/src/server/Main", 1, true) or src:find("/src/client/", 1, true) then
		local n, miss = 0, {}
		for line in io.lines(src:sub(2)) do
			n = n + 1
			local text = line:gsub("^%s+", "")
			if text ~= "" and text:sub(1, 2) ~= "--" and not SKIP[text] and not text:match("^local function") and not text:match("^function") then
				total = total + 1
				if h[n] then covered = covered + 1 else miss[#miss + 1] = n end
			end
		end
		rows[#rows + 1] = src:match("src/.*") .. ": " .. (#miss > 0 and ("not run: " .. table.concat(miss, " ")) or "every line ran")
	end
end
table.sort(rows)
for _, row in ipairs(rows) do print(row) end
print(string.format("cover_boot: %d of %d lines ran (%d test failures)", covered, total, failed))
