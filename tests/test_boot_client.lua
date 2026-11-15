-- Boots src/client/Main.client.lua as a fake LocalPlayer against tools/roblox_mock.lua, next to the real
-- server, and plays through the screen: walking up to pets, taps, cheers, buttons. Then every
-- server-to-client remote is fired with realistic payloads.
local H = runfile(ROOT .. "/tests/boot_helpers.lua")
local Mock = H.Mock
local V3 = Mock.Vector3
local Enum = Mock.Enum
local tests = {}

local SCREENS = { "HUD", "TrustTap", "Showdown", "FX", "WildShowdown", "Secret", "Choice", "Welcome", "Emotes", "Week", "IndexBoard",
	"Settings", "Debug", "Team", "Closet", "Mailbox" }

local function start(opts)
	local world = H.fresh(nil, opts)
	local ann, c = H.join(world, 101, "Ann", 1)
	world:startClient(ann)
	Mock.step(5)
	return world, ann, c
end
local function remotes(world)
	return world.server:call(world.server.env.require, world.services.ReplicatedStorage.Shared.Net.Remotes)
end
local function toRing(world, player, f)
	local ring = H.floor(world, f).ring
	world:walkTo(player, V3.new(ring.Position.X, ring.Position.Y + 2.5, ring.Position.Z))
	world:touch(ring, player)
end
-- Tap the screen at the moment of each beat (start + beat seconds).
local function tapAt(c, start, beat)
	Mock.step(start + beat - Mock.now)
	return c:input(Enum.UserInputType.Touch)
end

function tests.a01_client_starts_every_controller()
	local world, ann, c = start()
	H.clean("client start")
	for _, name in ipairs(SCREENS) do
		T.ok(H.gui(ann, name), "controller " .. name .. " made its screen")
		T.eq(H.gui(ann, name).ClassName, "ScreenGui")
	end
	T.eq(H.gui(ann, "Shop"), nil, "the shop shows nothing until prices are approved")
	-- every server-to-client remote has a listener on this client
	local R = remotes(world)
	for _, name in ipairs(R.S2C) do
		local sigs = c.signals[world:remote(name)]
		T.ok(sigs and sigs.OnClientEvent and #sigs.OnClientEvent.conns > 0, "someone listens to " .. name)
	end
	-- the state that was sent before the scripts were running still arrived
	T.eq(H.gui(ann, "HUD").Coins.Text, "50")
	T.eq(H.gui(ann, "HUD").Floor.Text, "1")
	T.eq(H.gui(ann, "HUD").Feed.Text, "", "no starter yet")
	-- Wick points at the starter pedestals
	local flame, beam
	for _, child in ipairs(world.workspace:GetChildren()) do if child.Name == "Wick" then flame = child end end
	T.ok(flame, "Wick is in the world")
	T.near((flame.Position - H.pos(world, ann)).Magnitude, 4.47, 0.1, "Wick floats by the player")
	T.eq(flame.Beam.Enabled, true, "the beam points at something")
	-- the server does not see what this client made
	local seen = false
	world.server:run(function() seen = world.workspace:FindFirstChild("Wick") ~= nil end)
	T.no(seen, "client-made parts stay on the client")
	Mock.step(120)
	H.clean("two idle minutes")
end

function tests.a02_client_in_a_live_game_has_no_debug_panel()
	local world, ann, c = start({ studio = false, jobId = "live-1" })
	T.eq(H.gui(ann, "Debug"), nil)
	T.ok(H.gui(ann, "HUD"))
	H.clean("live client")
end

function tests.b01_walk_up_and_trust_tap_through_the_screen()
	local world, ann, c = start()
	H.chooseStarter(world, ann)
	T.eq(H.gui(ann, "HUD").Feed.Text, "Lv 1  >  10")
	T.ok(H.button(ann, "Team", "x3").Visible, "the team button shows once there is a starter")
	local ball = H.tutorialPart(world, ann)
	-- far away: the client asks for nothing
	Mock.step(1)
	T.eq(#H.heard(world, ann, "TryStart"), 0)
	H.walkNear(world, ann, ball.Position, 4)
	Mock.step(0.5)
	local asked = H.heard(world, ann, "TryStart")
	T.eq(#asked, 1, "walking up starts the try by itself, once")
	T.eq(asked[1][1], -101)
	local try = H.payload(c, "TryBegin")
	T.ok(try, "the server began the try")
	local holder = H.gui(ann, "TrustTap").Frame
	T.eq(#holder:GetChildren(), 4, "the heart and three rings")
	for i, beat in ipairs(try.beats) do
		T.eq(tapAt(c, try.start, beat), 1, "one tap listener")
		local taps = H.heard(world, ann, "Tap")
		T.eq(#taps, i, "tap " .. i .. " was sent")
		T.eq(taps[i][1], i, "with its beat number")
		T.near(taps[i][2], beat, 1e-6, "and the time since the try began")
	end
	Mock.step(0.5)
	local result = H.payload(c, "TryEnd")
	T.ok(result and result.success and result.perfectAll, "three Perfects through the screen")
	local word
	for _, d in ipairs(H.gui(ann, "TrustTap"):GetChildren()) do if d:IsA("TextLabel") then word = d end end
	T.eq(word.Text, "PERFECT x3")
	T.eq(H.gui(ann, "TrustTap"):FindFirstChild("Frame"), nil, "the rings are gone")
	T.eq(#H.profile(world, ann).stack, 1)
	-- taps after the try go nowhere
	c:input(Enum.UserInputType.Touch)
	T.eq(#H.heard(world, ann, "Tap"), 3)
	Mock.step(2)
	T.eq(word.Visible, false)
	-- mouse and keyboard taps count, a click the UI already used does not
	H.clean("trust tap")
end

function tests.b02_keyboard_mouse_and_late_taps()
	local world, ann, c = start()
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c) -- by hand, so the client has no try of its own for it
	H.deposit(world, ann)
	H.lift(world, ann, c, 1)
	local rare = H.findPet(world, 1, "Rare", true)
	H.walkNear(world, ann, rare.Position, 4)
	Mock.step(0.5)
	local try = H.payload(c, "TryBegin")
	T.eq(try.petId, rare:GetAttribute("PetId"), "the client walked up to the Rare and asked")
	-- ring 1 with the mouse; a click on a button (processed) is not a tap
	Mock.step(try.start + try.beats[1] - Mock.now)
	local base = #H.heard(world, ann, "Tap") -- the three taps of the tutorial try
	c:input(Enum.UserInputType.MouseButton1, nil, true)
	T.eq(#H.heard(world, ann, "Tap"), base, "a click the UI used is not a tap")
	c:input(Enum.UserInputType.MouseButton1)
	T.eq(#H.heard(world, ann, "Tap"), base + 1)
	-- ring 2 is missed altogether; ring 3 with the space bar
	Mock.step(try.start + try.beats[3] - Mock.now)
	c:input(Enum.UserInputType.Keyboard, Enum.KeyCode.Space)
	local taps = H.heard(world, ann, "Tap")
	T.eq(#taps, base + 2)
	T.eq(taps[base + 2][1], 3, "the client skips the ring whose time has passed")
	Mock.step(1)
	local grades = c:got("TryGrade")
	T.eq(grades[#grades][1], 3)
	T.eq(grades[#grades][2], "Perfect")
	T.ok(H.payload(c, "TryEnd").success, "a Rare needs two hits with one Perfect")
	-- other keys do nothing
	T.eq(c:input(Enum.UserInputType.Keyboard, Enum.KeyCode.W), 0, "no listener is left after the try")
	H.clean("inputs")
end

function tests.c01_guardian_showdown_cheer_and_share_through_the_screen()
	local world, ann, c = start()
	local bob, cb = H.ready(world, 102, "Bob")
	world:startClient(bob)
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c)
	H.deposit(world, ann)
	H.press(H.button(ann, "Debug", "Lv5"))
	Mock.step(0.3)
	T.eq(H.profile(world, ann).starter.level, 5, "the debug panel works")
	H.debug(c, "level", 9) -- Team Power about 31: Old Bramblehorn's 800 takes about 25 s
	H.lift(world, ann, c, 1)
	toRing(world, ann, 1)
	Mock.step(0.1)
	local snap = H.payload(c, "ShowdownState")
	local gui = H.gui(ann, "Showdown")
	local bar
	for _, d in ipairs(gui:GetChildren()) do if d:IsA("Frame") and d:FindFirstChildOfClass("TextLabel") then bar = d end end
	T.ok(bar and bar.Visible, "the meter shows")
	T.eq(bar.TextLabel.Text, "x1")
	-- cheer on beat 1
	T.ok(tapAt(c, snap.start, 1) >= 1)
	local cheers = H.heard(world, ann, "Cheer")
	T.eq(#cheers, 1, "the tap was sent as a cheer")
	T.near(cheers[1][1], 1, 1e-6, "with the time since the showdown began")
	Mock.step(0.1)
	T.eq(H.payload(c, "CheerGrade"), "Perfect")
	T.eq(#H.heard(world, ann, "Tap"), 3, "a cheer is not a Trust Tap (three taps from the tutorial only)")
	T.ok(H.waitFor(c, "ShowdownEnd", 45))
	T.ok(H.payload(c, "ShowdownEnd").won)
	Mock.step(0.1)
	T.eq(bar.Visible, false, "the meter goes away")
	-- the two big buttons come 2.5 s later
	local share = H.button(ann, "Choice", "o o o")
	T.no(H.shown(share), "not yet")
	Mock.step(3)
	T.ok(H.shown(share), "Share and Keep are offered")
	H.press(share)
	Mock.step(0.3)
	local chose = H.heard(world, ann, "Choose")
	T.eq(#chose, 1)
	T.eq(chose[1][1], 1)
	T.eq(chose[1][2], "share")
	T.eq(H.profile(world, ann).floors["1"].choice, "share")
	T.no(H.shown(share))
	-- everyone sees who shared
	local function banner(player)
		for _, d in ipairs(H.gui(player, "FX"):GetChildren()) do if d:IsA("TextLabel") then return d end end
	end
	T.eq(banner(bob).Text, "Ann  o o o")
	T.ok(banner(bob).Visible)
	T.eq(H.gui(bob, "HUD").Coins.Text, tostring(H.profile(world, bob).coins), "Bob's coins went up on his HUD")
	H.clean("guardian through the screen")
end

function tests.c02_lost_showdown_shows_the_help_button()
	local world, ann, c = start()
	local bob, cb = H.join(world, 102, "Bob", 1)
	world:startClient(bob)
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c)
	H.deposit(world, ann)
	H.lift(world, ann, c, 1)
	toRing(world, ann, 1)
	T.ok(H.waitFor(c, "ShowdownEnd", 45))
	Mock.step(0.1)
	local help = H.button(ann, "Showdown", "?!")
	T.ok(H.shown(help), "the help button shows after a loss")
	H.press(help)
	Mock.step(0.5)
	T.eq(#H.heard(world, ann, "CallHelp"), 1)
	T.eq(#world.prompts, 1, "the invite prompt is offered")
	T.eq(world.prompts[1].kind, "invite")
	local function banner(player)
		for _, d in ipairs(H.gui(player, "FX"):GetChildren()) do if d:IsA("TextLabel") then return d end end
	end
	T.eq(banner(bob).Text, "?! 1", "the banner reaches the other player")
	T.no(H.shown(help))
	H.clean("help button")
end

function tests.c03_wild_showdown_through_the_screen()
	local world, ann, c = start()
	local bob, cb = H.ready(world, 102, "Bob")
	world:startClient(bob)
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c)
	H.deposit(world, ann)
	H.debug(c, "level", 8)
	H.lift(world, ann, c, 1)
	H.lift(world, bob, cb, 1)
	world:walkTo(ann, V3.new(-60, 403, 0))
	world:walkTo(bob, V3.new(-60, 403, 60)) -- same floor, well away from the pet
	local before = {}
	for _, ball in ipairs(H.petParts(world, 1)) do before[ball] = true end
	H.press(H.button(ann, "Debug", "Epic")) -- 12 studs from Ann
	Mock.step(0.5)
	local ball
	for _, b in ipairs(H.petParts(world, 1)) do if not before[b] then ball = b end end
	local id = ball:GetAttribute("PetId")
	-- within reach: the client steps in by itself, and does not ask for a catch try yet
	local joins = H.heard(world, ann, "WildJoin")
	T.eq(#joins, 1, "walked up: joined by itself")
	T.eq(joins[1][1], id)
	local tries = #H.heard(world, ann, "TryStart")
	local snap = H.payload(c, "ShowdownState")
	T.ok(snap and snap.mine, "the server says we are in")
	local stage = H.gui(ann, "Showdown").Frame
	T.eq(stage.UIScale.Scale, 0.6, "a small ring for a wild showdown")
	-- Bob is on the floor but far away: he gets the join icon, not a ring
	Mock.step(0.5)
	local icon
	for _, d in ipairs(H.gui(bob, "WildShowdown"):GetChildren()) do if d:IsA("TextButton") and d:FindFirstChildOfClass("TextLabel") then icon = d end end
	T.ok(icon and icon.Visible, "the far player sees the join icon")
	T.eq(#H.heard(world, bob, "WildJoin"), 0)
	-- cheer
	local beat = math.floor(Mock.now - snap.start) + 1
	tapAt(c, snap.start, beat)
	Mock.step(0.1)
	T.eq(H.payload(c, "CheerGrade"), "Perfect")
	T.ok(H.waitFor(c, "ShowdownEnd", 20))
	T.ok(H.payload(c, "ShowdownEnd").won)
	T.eq(#H.heard(world, ann, "TryStart"), tries, "12 studs away: no try yet")
	-- walk up: the catch try starts by itself, with slower rings
	H.walkNear(world, ann, ball.Position, 4)
	local count = H.count(c, "TryBegin")
	Mock.step(0.5)
	T.eq(H.count(c, "TryBegin"), count + 1, "the friendly try began")
	local try = H.payload(c, "TryBegin")
	T.near(try.ringTime, 0.78, 1e-9)
	for _, b in ipairs(try.beats) do tapAt(c, try.start, b) end
	Mock.step(0.5)
	T.ok(H.payload(c, "TryEnd").success, "caught through the screen")
	T.eq(H.payload(c, "TryEnd").rarity, "Epic")
	-- Bob never asked for anything
	T.eq(#H.heard(world, bob, "WildJoin"), 0)
	Mock.step(10)
	T.no(icon.Visible, "the icon hides by itself")
	H.clean("wild through the screen")
end

function tests.c04_walking_away_closes_the_wild_ring_and_walking_back_reopens_it()
	local world, ann, c = start()
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c)
	H.deposit(world, ann)
	H.lift(world, ann, c, 1)
	world:walkTo(ann, V3.new(-60, 403, 0))
	H.press(H.button(ann, "Debug", "Legend"))
	Mock.step(1)
	T.eq(#H.heard(world, ann, "WildJoin"), 1)
	local stage = H.gui(ann, "Showdown").Frame
	T.eq(#stage:GetChildren(), 2, "the ring holder is up (and the UIScale)")
	world:walkTo(ann, V3.new(60, 403, 0))
	Mock.step(3)
	T.eq(H.payload(c, "ShowdownEnd").left, true)
	T.eq(#stage:GetChildren(), 1, "the ring closed")
	world:walkTo(ann, V3.new(-60, 403, 0))
	Mock.step(1)
	T.eq(#H.heard(world, ann, "WildJoin"), 2, "walking back joins again")
	T.eq(#stage:GetChildren(), 2, "the ring is back")
	H.clean("leash through the screen")
end

function tests.d01_buttons_send_the_right_remotes()
	local world, ann, c = start()
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c)
	H.deposit(world, ann)
	H.debug(c, "coins", 100000)
	-- settings
	local gear = H.button(ann, "Settings", "=")
	H.press(gear)
	H.press(H.button(ann, "Settings", "O+"))
	Mock.step(0.3)
	T.eq(H.profile(world, ann).settings.tapAssist, true)
	H.press(H.button(ann, "Settings", "~"))
	Mock.step(0.3)
	T.eq(H.profile(world, ann).settings.music, 0)
	H.press(H.button(ann, "Settings", "LO"))
	Mock.step(0.3)
	T.eq(H.profile(world, ann).settings.lowGraphics, true)
	T.eq(world.services.Lighting.GlobalShadows, false)
	-- emotes
	H.press(H.button(ann, "Emotes", ":)"))
	H.press(H.button(ann, "Emotes", "<3"))
	Mock.step(0.3)
	T.eq(H.heard(world, ann, "Emote")[1][1], 2)
	T.ok(ann.Character.Head:FindFirstChild("Sticker"), "the sticker floats over the sender's head")
	T.eq(ann.Character.Head.Sticker.TextLabel.Text, "<3")
	Mock.step(4)
	T.eq(ann.Character.Head:FindFirstChild("Sticker"), nil, "and goes away")
	-- team screen: heart, take off the team, release
	H.press(H.button(ann, "Team", "x3"))
	local tile
	for _, d in ipairs(H.gui(ann, "Team"):GetDescendants()) do if d:IsA("TextButton") and d.Parent:IsA("ScrollingFrame") then tile = d end end
	T.ok(tile, "the camp pet has a tile")
	H.press(tile)
	H.press(H.button(ann, "Team", "+<3"))
	Mock.step(0.3)
	T.eq(H.profile(world, ann).pets[1].hearts, 1)
	H.press(H.button(ann, "Team", "bye"))
	Mock.step(0.3)
	T.eq(#H.profile(world, ann).pets, 1, "a team pet cannot be released")
	-- index board, mailbox and closet open from the camp
	local camp = H.camp(world, ann)
	H.walkToPart(world, ann, camp.IndexBoard)
	world:trigger(camp.IndexBoardPrompt, ann)
	Mock.step(0.3)
	local board = H.gui(ann, "IndexBoard").TextButton
	T.ok(board.Visible)
	T.eq(board.TextLabel.Text, "2 / 28")
	H.press(board)
	T.no(board.Visible)
	H.walkToPart(world, ann, camp.Mailbox)
	world:trigger(camp.MailboxPrompt, ann)
	Mock.step(0.3)
	local mail = H.gui(ann, "Mailbox").Frame
	T.ok(mail.Visible)
	T.eq(mail.TextBox.Visible, false, "no code box while there are no codes")
	H.press(H.button(ann, "Mailbox", "X"))
	H.profile(world, ann).looks.aura_spark = true
	H.walkToPart(world, ann, camp.Closet)
	world:trigger(camp.ClosetPrompt, ann)
	Mock.step(0.3)
	H.press(H.button(ann, "Closet", "aura_s"))
	Mock.step(0.3)
	T.eq(H.profile(world, ann).equipped.aura, "aura_spark")
	-- every debug button
	for _, text in ipairs({ "+10K", "+10M", "Lv5", "Lv25", "Lv42", "Clear", "Radiant", "Away16h", "Egg", "Stack10" }) do
		H.press(H.button(ann, "Debug", text))
		Mock.step(0.3)
	end
	T.eq(H.profile(world, ann).starter.level, 42)
	T.eq(H.profile(world, ann).cleared, 1)
	T.eq(H.gui(ann, "HUD").Floor.Text, "2")
	-- Lv 42: Dawn or Dusk is offered; the cleared floor's Share / Keep comes after
	local dawn = H.button(ann, "Choice", "o o o")
	T.ok(H.shown(dawn), "the form choice shows")
	H.press(dawn)
	Mock.step(0.3)
	T.eq(H.profile(world, ann).starter.form, "dawn")
	T.eq(H.heard(world, ann, "ChooseForm")[1][1], "dawn")
	H.clean("buttons")
end

function tests.d02_merchant_tray_on_a_saturday()
	Mock.reset(H.SATURDAY_06)
	local world = H.boot()
	local ann, c = H.join(world, 101, "Ann", 1)
	world:startClient(ann)
	Mock.step(5)
	H.chooseStarter(world, ann)
	H.debug(c, "coins", 5000)
	local tray = H.gui(ann, "Week").Frame
	T.no(tray.Visible, "the tray shows only at the merchant")
	local merchant = world.workspace.PetTowerWorld.Merchant
	T.eq(merchant.Transparency, 0, "the merchant is here on a Saturday")
	world:walkTo(ann, merchant.Position + V3.new(8, 0, 0))
	Mock.step(1)
	T.ok(tray.Visible, "walk up: three buttons")
	local buttons = {}
	for _, d in ipairs(tray:GetChildren()) do if d:IsA("TextButton") then buttons[#buttons + 1] = d end end
	T.eq(#buttons, 3)
	T.eq(buttons[2].Text, "@\n900")
	H.press(buttons[2])
	Mock.step(0.5)
	T.eq(#H.profile(world, ann).pets, 1, "bought the Rare")
	T.eq(buttons[2].BackgroundTransparency, 0.7, "shown as bought")
	T.eq(world.workspace.PetTowerWorld.DawnDuskScale.Tally.Label.Text, "0  |  0")
	H.clean("merchant tray")
end

-- Every server-to-client remote with realistic payloads (shapes as the server tests saw them sent) ---------------
function tests.e01_every_server_to_client_remote()
	local world, ann, c = start()
	local bob = H.join(world, 102, "Bob", 1)
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c)
	H.deposit(world, ann)
	H.lift(world, ann, c, 1)
	local now = Mock.now
	local state = Mock.wireCopy(H.profile(world, ann), "remote", "state")
	local extra = { teamPower = 5, income = 1, stackCap = 3, feedCost = 10, coinMult = 1.2, index = { 2, 28 }, floor = 1 }
	local payloads = {
		State = { { state, extra } },
		TryBegin = { { { petId = 100001, start = now, beats = { 1.2, 2.65, 4.1 }, ringTime = 1.2, rarity = "Common" } } },
		TryGrade = { { 1, "Perfect" }, { 2, "Good" }, { 3, "Miss" }, { 9, "Perfect" } },
		TryEnd = {
			{ { success = true, hits = 3, perfects = 3, grades = { "Perfect", "Perfect", "Perfect" }, lastBeatMiss = false, perfectAll = true, species = "Sunflion", rarity = "Legendary", radiant = false, petId = 4 } },
			{ { success = false, hits = 2, perfects = 1, grades = { "Perfect", "Good", "Miss" }, lastBeatMiss = true, perfectAll = false, species = "Lanternlamb", rarity = "Secret", radiant = false } },
			{ { success = false, hits = 0, perfects = 0, grades = { "Miss", "Miss", "Miss" }, lastBeatMiss = false, perfectAll = false, species = "Buttercub", rarity = "Common", radiant = true } },
		},
		Evolve = { { { species = "Pandle", stage = 2 } }, { { species = "Pandle", stage = 4, form = "dusk" } } },
		Banner = { { { kind = "pillar", floor = 1, rarity = "Legendary", radiant = false } }, { { kind = "pillar", floor = 2, rarity = "Common", radiant = true } },
			{ { kind = "pillar", floor = 1, rarity = "Secret", radiant = false } }, { { kind = "help", floor = 1, userId = 102 } }, { { kind = "relit", floor = 3 } },
			{ { kind = "something_new", floor = 1 } } },
		ShowdownState = {
			{ { floor = 1, kind = "guardian", start = now, ends = now + 40, meter = 800, left = 512.5, count = 2 } },
			{ { floor = 0, kind = "weekly", start = now, ends = now + 40, meter = 1740, left = 1000, count = 1 } },
			{ { floor = 1, kind = "wild", start = now - 30, meter = 200, left = 120, count = 1, petId = 100055, rarity = "Legendary" } },
			{ { floor = 1, kind = "wild", start = now - 30, meter = 200, left = 0, count = 1, petId = 100055, rarity = "Legendary", mine = true } },
		},
		ShowdownEnd = {
			{ { floor = 1, won = true, firstClear = true, kind = "guardian", count = 2 } }, { { floor = 1, won = false, firstClear = false, kind = "guardian", count = 1 } },
			{ { kind = "weekly", floor = 0, won = true, firstClear = true } },
			{ { kind = "wild", petId = 100055, floor = 1, won = true } }, { { kind = "wild", petId = 100056, floor = 1, won = false } },
			{ { kind = "wild", petId = 100057, floor = 1, won = false, left = true } },
		},
		CheerGrade = { { "Perfect" }, { "Good" }, { "Miss" } },
		Coins = { { 30, "pads" }, { 1234567, "share" }, { 60, "helper" } },
		SecretChime = { { { floor = 1, phase = "glow", at = now + 30, leaves = now + 210 } }, { { floor = 1, phase = "here", at = now, leaves = now + 180 } },
			{ { floor = 1, phase = "gone", at = now, leaves = now + 180 } }, { { floor = 4, phase = "glow", at = now + 60, leaves = now + 240 } },
			{ { floor = 4, phase = "here", at = now + 60, leaves = now + 240 } } },
		Welcome = {
			{ { away = 57600, chest = 3600, rested = true, newDay = true, journeyDay = 2, ladderCoins = 360, tomorrow = { minutes = 7, look = "aura_spark" }, egg = { state = "ready", readyAt = now - 100 } } },
			{ { away = 0, chest = 0, rested = false, newDay = false, journeyDay = 1, tomorrow = { minutes = 6 }, egg = { state = "none" } } },
			{ { away = 0, chest = 0, rested = false, newDay = true, journeyDay = 3, look = "aura_spark", tomorrow = { minutes = 8 }, egg = { state = "warming", readyAt = now + 100 } } },
		},
		ChoicePrompt = { { 1 } },
		Shared = { { { userId = 102, name = "Bob" } } },
		EggHatched = { { { species = "Zipwing", rarity = "Rare", radiant = false } } },
		Emote = { { 102, 1 }, { 101, 6 }, { 999, 2 }, { 102, 7 } },
		Week = { { { week = 2811, guardian = "Dozy the Pillow Dragon", merchantOpen = true,
			items = { { slot = 1, kind = "look", id = "trail_star", price = 1200, bought = false }, { slot = 2, kind = "pet", id = "Zipwing", rarity = "Rare", price = 900, bought = true },
				{ slot = 3, kind = "decor", id = "decor_kite", price = 600, bought = false } },
			tally = { dawn = 12, dusk = 7 }, lastLeader = "dusk", trim = false, monument = { ["1"] = { "Ann", "Bob" }, ["2"] = { "Cat" }, ["3"] = {} } } },
			{ { week = 2811, guardian = "Honk the Clockwork Goose", merchantOpen = false, items = {}, tally = { dawn = 0, dusk = 0 }, trim = true, monument = {} } } },
		WeeklyChoice = { {} },
		Index = { { H.core(world, "Profile") and world.server:require("Services", "SettingsService") and
			world.server:call(world.server.env.require, world.services.ReplicatedStorage.Shared.Logic.IndexView).build(H.profile(world, ann), 5) } },
		Mail = { { { journeyDay = 2, tomorrow = { minutes = 7, look = "aura_spark" }, egg = { state = "ready", readyAt = now }, codes = true } },
			{ { journeyDay = 9, tomorrow = { minutes = 10 }, egg = { state = "none" }, codes = false } } },
		Closet = { { { looks = { "aura_spark", "trail_star", "weekly_3" }, equipped = { aura = "aura_spark" } } }, { { looks = {}, equipped = {} } } },
		ClipMoment = { { { kind = "wild_legendary", floor = 1 } }, { { kind = "perfect3", floor = 1 } }, { { kind = "dawn_dusk", floor = 0 } }, { { kind = "secret", floor = 3 } } },
	}
	local R = remotes(world)
	local fired = 0
	for _, name in ipairs(R.S2C) do
		T.ok(payloads[name], "a payload for " .. name)
		for i, args in ipairs(payloads[name]) do
			H.send(world, ann, name, unpack(args))
			Mock.step(0.1)
			H.clean(name .. " payload " .. i)
			fired = fired + 1
		end
		Mock.step(1.5)
		H.clean(name .. " after a moment")
	end
	T.ok(fired >= 50, "fired " .. fired .. " payloads")
	Mock.step(60) -- timers, tweens and banners run out
	H.clean("a minute later")
	-- what a few of them left on the screen
	T.eq(H.gui(ann, "Mailbox").Frame.TextLabel.Text, "^ 9")
	T.eq(world.workspace.PetTowerWorld.Monument.Names.Label.Text, "")
	T.ok(H.gui(ann, "Closet").TextButton.Visible)
	-- the capture button was offered for the moment on this floor and is gone again
	local capture = H.button(ann, "WildShowdown", "\240\159\147\183")
	T.no(capture.Visible)
	H.send(world, ann, "ClipMoment", { kind = "wild_legendary", floor = 1 })
	Mock.step(0.2)
	T.ok(capture.Visible, "offered where the platform allows it")
	H.press(capture)
	Mock.step(0.2)
	T.eq(world.prompts[#world.prompts].kind, "saveCapture")
	-- where sharing is not allowed nothing is offered (a new client, so the policy is asked again)
	world.policy.IsContentSharingAllowed = false
	world:startClient(bob)
	Mock.step(3)
	H.send(world, bob, "ClipMoment", { kind = "secret" })
	Mock.step(0.2)
	T.no(H.button(bob, "WildShowdown", "\240\159\147\183").Visible)
	H.clean("captures")
end

function tests.e02_secret_glow_and_banner_on_the_lantern()
	local world, ann, c = start()
	local lantern = world.workspace.PetTowerWorld.Floor1.Lantern
	local color, size = lantern.Color, lantern.Size
	H.send(world, ann, "SecretChime", { floor = 1, phase = "glow", at = Mock.now + 30, leaves = Mock.now + 210 })
	Mock.step(0.2)
	local light = lantern:FindFirstChild("SecretGlow")
	T.ok(light, "the lantern glows")
	T.near(light.Brightness, 3, 0.05, "half way up: the chime began 30 s ago")
	T.ok(lantern:FindFirstChild("SecretHalo") and lantern:FindFirstChild("SecretSparkles"))
	Mock.step(31)
	T.eq(light.Brightness, 6, "full glow when the pet appears")
	H.send(world, ann, "SecretChime", { floor = 1, phase = "here", at = Mock.now, leaves = Mock.now + 180 })
	Mock.step(2)
	local banner
	for _, d in ipairs(H.gui(ann, "Secret"):GetChildren()) do if d:IsA("TextLabel") then banner = d end end
	T.ok(banner.Visible, "no pillar banner came: the Secret banner shows")
	T.eq(banner.Text, "o * 1 * o")
	H.send(world, ann, "SecretChime", { floor = 1, phase = "gone", at = Mock.now, leaves = Mock.now })
	Mock.step(0.2)
	T.eq(lantern:FindFirstChild("SecretGlow"), nil, "the glow is taken away")
	T.eq(lantern:FindFirstChild("SecretHalo"), nil)
	T.eq(lantern.Color, color, "the lantern itself was never touched")
	T.eq(lantern.Size, size)
	-- with the pillar banner first, the Secret banner stays away
	Mock.step(10)
	T.no(banner.Visible)
	H.send(world, ann, "Banner", { kind = "pillar", floor = 2, rarity = "Secret", radiant = false })
	H.send(world, ann, "SecretChime", { floor = 2, phase = "here", at = Mock.now, leaves = Mock.now + 180 })
	Mock.step(2)
	T.no(banner.Visible, "one banner, not two")
	H.clean("secret glow")
end

function tests.e03_floor_bloom_follows_this_players_clears()
	local world, ann, c = start()
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c)
	H.deposit(world, ann)
	H.debug(c, "level", 12)
	local effect
	for _, d in ipairs(world.services.Lighting:GetChildren()) do if d.Name == "FloorBloom" then effect = d end end
	T.ok(effect, "the colour effect exists")
	Mock.step(0.5)
	T.eq(effect.Saturation, 0, "full colour at camp")
	H.lift(world, ann, c, 1)
	T.eq(effect.Saturation, -0.65, "an unlit floor is washed out")
	toRing(world, ann, 1)
	T.ok(H.waitFor(c, "ShowdownEnd", 45))
	Mock.step(2.5)
	T.eq(effect.Saturation, 0, "the floor blooms when its lantern is relit")
	H.clean("bloom")
end

-- Corners ----------------------------------------------------------------------------------------------------
local function clientConfig(world, player)
	local realm = world:client(player)
	return realm:call(realm.env.require, world.services.ReplicatedStorage.Shared.Config)
end

function tests.f01_sounds_play_once_ids_are_filled_in()
	local world = H.fresh()
	local ann, c = H.join(world, 101, "Ann", 1)
	local Config = clientConfig(world, ann) -- this client's own copy of the config, before its scripts run
	local S = Config.Sounds
	S.Music.hub, S.Music.showdown = "rbxassetid://1", "rbxassetid://2"
	for i = 1, 5 do S.Music.floors[i] = "rbxassetid://1" .. i end
	for i = 1, 3 do S.Ring[i] = "rbxassetid://2" .. i end
	S.Catch, S.Bolt, S.Evolve, S.Relight, S.Welcome, S.Coin, S.Chime = "rbxassetid://31", "rbxassetid://32", "rbxassetid://33", "rbxassetid://34",
		"rbxassetid://35", "rbxassetid://36", "rbxassetid://37"
	world:startClient(ann)
	Mock.step(5)
	local sounds = world.services.SoundService
	local function playing(id)
		local n = 0
		for _, snd in ipairs(sounds:GetChildren()) do if snd.SoundId == id then n = n + 1 end end
		return n
	end
	T.eq(playing("rbxassetid://1"), 1, "hub music")
	T.ok(playing("rbxassetid://35") >= 1, "the welcome sound")
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c)
	T.eq(playing("rbxassetid://21") + playing("rbxassetid://22") + playing("rbxassetid://23"), 3, "three ring notes")
	T.eq(playing("rbxassetid://31"), 1, "the catch sound")
	H.deposit(world, ann)
	H.debug(c, "level", 9)
	H.lift(world, ann, c, 1)
	T.eq(playing("rbxassetid://11"), 1, "Floor 1 music")
	T.eq(playing("rbxassetid://1"), 0, "the hub music stopped")
	local ring = H.floor(world, 1).ring
	world:walkTo(ann, V3.new(ring.Position.X, ring.Position.Y + 2.5, ring.Position.Z))
	world:touch(ring, ann)
	Mock.step(5)
	T.eq(playing("rbxassetid://2"), 1, "one showdown track, not one per meter update")
	T.eq(playing("rbxassetid://11"), 0)
	T.ok(H.waitFor(c, "ShowdownEnd", 45))
	Mock.step(1)
	T.eq(playing("rbxassetid://34"), 1, "the relight sound")
	T.eq(playing("rbxassetid://2"), 0)
	T.eq(playing("rbxassetid://11"), 1, "the floor music is back")
	-- music off in the settings: silence
	H.press(H.button(ann, "Settings", "="))
	H.press(H.button(ann, "Settings", "~"))
	Mock.step(0.5)
	local music
	for _, snd in ipairs(sounds:GetChildren()) do if snd.SoundId == "rbxassetid://11" then music = snd end end
	T.eq(music.Volume, 0)
	-- a sound that ends is cleaned up
	local n = #sounds:GetChildren()
	for _, snd in ipairs(sounds:GetChildren()) do if not snd.Looped then Mock.signalOf(snd, "Ended"):Fire() end end
	Mock.flush()
	T.ok(#sounds:GetChildren() < n)
	T.eq(#sounds:GetChildren(), 1, "only the music is left")
	H.clean("sounds")
end

function tests.f02_shop_button_only_when_approved_and_after_five_minutes()
	local world = H.fresh()
	local ann, c = H.join(world, 101, "Ann", 1)
	local Config = clientConfig(world, ann)
	Config.Shop.Approved = true
	Config.Shop.PassIds.DoubleCoins = 7002
	Config.Shop.PassIds.AutoCollect = 7004
	world:startClient(ann)
	Mock.step(5)
	local open = H.button(ann, "Shop", "$")
	T.no(open.Visible, "nothing is sold in the first five minutes")
	Mock.step(300)
	c:fire("Collect") -- any state push
	H.chooseStarter(world, ann)
	T.ok(open.Visible, "the shop button shows after five minutes")
	H.press(open)
	local pass = H.button(ann, "Shop", "DoubleCoins\nR$ 399")
	T.ok(H.shown(pass))
	H.press(pass)
	T.eq(world.prompts[#world.prompts].kind, "pass")
	T.eq(world.prompts[#world.prompts].id, 7002)
	T.eq(world.prompts[#world.prompts].player, ann)
	H.clean("shop")
end

function tests.f03_keep_team_and_code_buttons()
	local world, ann, c = start()
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c)
	H.deposit(world, ann)
	H.debug(c, "level", 12)
	H.lift(world, ann, c, 1)
	-- catch the Rare so there are two camp pets
	local rare = H.findPet(world, 1, "Rare", true)
	H.walkNear(world, ann, rare.Position, 4)
	Mock.step(0.5)
	local try = H.payload(c, "TryBegin")
	for _, b in ipairs(try.beats) do tapAt(c, try.start, b) end
	Mock.step(0.5)
	T.ok(H.payload(c, "TryEnd").success)
	toRing(world, ann, 1)
	T.ok(H.waitFor(c, "ShowdownEnd", 45))
	Mock.step(3)
	H.press(H.button(ann, "Choice", "O"))
	Mock.step(0.3)
	T.eq(H.heard(world, ann, "Choose")[1][2], "keep")
	T.eq(H.profile(world, ann).floors["1"].choice, "keep")
	H.lift(world, ann, c, 0)
	T.eq(#H.profile(world, ann).team, 2)
	-- team screen: take pet 2 off by putting pet 1 on alone, then release pet 2
	H.press(H.button(ann, "Team", "x3"))
	local tiles = {}
	for _, d in ipairs(H.gui(ann, "Team"):GetDescendants()) do if d:IsA("TextButton") and d.Parent:IsA("ScrollingFrame") then tiles[#tiles + 1] = d end end
	T.eq(#tiles, 2, "two camp pets, two tiles")
	H.press(tiles[1])
	local x3
	for _, d in ipairs(H.gui(ann, "Team"):GetDescendants()) do if d:IsA("TextButton") and d.Text == "x3" and d.Parent:IsA("Frame") then x3 = d end end
	H.press(x3)
	Mock.step(0.6)
	local sent = H.heard(world, ann, "SetTeam")
	T.eq(#sent, 1)
	T.eq(sent[1][1], 1)
	T.eq(sent[1][2], 2, "the other team pet stays on")
	T.eq(#H.profile(world, ann).team, 2)
	-- the mailbox code box
	clientConfig(world, ann) -- (codes are a server matter; the server says whether the box shows)
	local config = world.server:call(world.server.env.require, world.services.ReplicatedStorage.Shared.Config)
	config.Codes.TOWER = { seconds = 60 }
	local camp = H.camp(world, ann)
	H.walkToPart(world, ann, camp.Mailbox)
	world:trigger(camp.MailboxPrompt, ann)
	Mock.step(0.3)
	local mail = H.gui(ann, "Mailbox").Frame
	T.ok(mail.TextBox.Visible, "the code box shows when codes exist")
	local coins = H.profile(world, ann).coins
	mail.TextBox.Text = "tower"
	H.press(H.button(ann, "Mailbox", ">"))
	Mock.step(0.3)
	T.eq(H.heard(world, ann, "RedeemCode")[1][1], "tower")
	T.ok(H.profile(world, ann).coins > coins, "the code paid out")
	T.eq(mail.TextBox.Text, "")
	H.press(H.button(ann, "Mailbox", ">")) -- empty box: nothing is sent
	T.eq(#H.heard(world, ann, "RedeemCode"), 1)
	config.Codes.TOWER = nil
	H.clean("keep, team, code")
end

function tests.f04_long_wild_showdown_refills_the_cheer_rings()
	local world, ann, c = start()
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c)
	H.deposit(world, ann)
	H.lift(world, ann, c, 1)
	world:walkTo(ann, V3.new(-60, 403, 0))
	H.press(H.button(ann, "Debug", "Legend")) -- Lv 1 team: about 31 s of play
	Mock.step(1)
	local snap = H.payload(c, "ShowdownState")
	T.ok(snap and snap.mine)
	local stage = H.gui(ann, "Showdown").Frame
	local holder = stage.Frame
	Mock.step(28.3) -- fewer than 3 s of rings left: the next 30 are drawn
	T.ok(stage.Frame ~= holder, "a new set of rings was drawn")
	T.eq(#stage:GetChildren(), 2, "and the old set is gone")
	-- cheering still works after the refill
	local beat = math.floor(Mock.now - snap.start) + 1
	tapAt(c, snap.start, beat)
	Mock.step(0.1)
	T.eq(H.payload(c, "CheerGrade"), "Perfect")
	T.ok(H.waitFor(c, "ShowdownEnd", 15), "the meter empties")
	T.ok(H.payload(c, "ShowdownEnd").won)
	Mock.step(0.2)
	T.eq(#stage:GetChildren(), 1, "the ring closed")
	H.clean("refill")
end

function tests.f05_a_full_stack_does_not_use_up_the_try_on_a_pet()
	local world, ann, c = start()
	H.chooseStarter(world, ann)
	H.tutorialCatch(world, ann, c)
	H.deposit(world, ann)
	H.lift(world, ann, c, 1)
	-- fill the stack (3) by hand
	local p = H.profile(world, ann)
	local Profile = H.core(world, "Profile")
	for _ = 1, 3 do Profile.addCaught(p, "Buttercub", "Common", false) end
	c:fire("Collect") -- any state push
	Mock.step(0.3)
	T.eq(#H.state(c).stack, 3)
	local rare = H.findPet(world, 1, "Rare", true)
	local id = rare:GetAttribute("PetId")
	local asks = #H.heard(world, ann, "TryStart")
	H.walkNear(world, ann, rare.Position, 4)
	Mock.step(1)
	T.eq(#H.heard(world, ann, "TryStart"), asks, "with a full stack the client does not ask (the server would refuse)")
	-- ride home, put the pets down, come back: the Rare can still be tried
	H.lift(world, ann, c, 0)
	T.eq(#p.stack, 0)
	H.lift(world, ann, c, 1)
	H.walkNear(world, ann, rare.Position, 4)
	Mock.step(0.5)
	local heard = H.heard(world, ann, "TryStart")
	T.eq(heard[#heard][1], id, "now the client asks")
	T.eq(H.payload(c, "TryBegin").petId, id, "and the try begins")
	H.clean("full stack")
end

function tests.f06_wick_points_at_the_next_thing_to_do()
	local world, ann, c = start()
	local anchor
	for _, child in ipairs(world.workspace:GetChildren()) do
		if child.Name == "Part" and child:FindFirstChildOfClass("Attachment") then anchor = child end
	end
	T.ok(anchor, "the beam's far end")
	local function pointsAt(part, what)
		Mock.step(0.6)
		T.near((anchor.Position - (part.Position + V3.new(0, 3, 0))).Magnitude, 0, 0.01, "Wick points at " .. what)
	end
	local camp = H.camp(world, ann)
	pointsAt(camp.pedestals.Narbub.ped, "the middle pedestal")
	H.chooseStarter(world, ann)
	pointsAt(H.tutorialPart(world, ann), "the first pet")
	H.tutorialCatch(world, ann, c)
	pointsAt(camp.pads[1], "the pads, with a pet on the head")
	H.deposit(world, ann)
	pointsAt(camp.SnackTable, "the Snack Table while a level can be bought and the team is too weak for the Guardian")
	H.debug(c, "level", 12)
	pointsAt(camp.Lift, "the lift once the team is strong enough")
	H.lift(world, ann, c, 1)
	pointsAt(H.findPet(world, 1, "Rare", true), "the pet under the pillar")
	local rare = H.findPet(world, 1, "Rare", true)
	H.debug(c, "stack", 0)
	local p = H.profile(world, ann)
	local Profile = H.core(world, "Profile")
	for _ = 1, 3 do Profile.addCaught(p, "Buttercub", "Common", false) end
	c:fire("Collect")
	pointsAt(H.floor(world, 1).lift, "the lift home when the stack is full")
	H.clean("wick")
end

return tests
