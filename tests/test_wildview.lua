local V = require(Shared.Logic.WildView)
local E = require(Shared.Config).Economy
local t = {}
function t.join_reach_inside_server_distance()
	T.ok(V.joinReach() < E.Wild.JoinDistance)
	T.ok(V.joinReach() > E.Tap.MaxDistance, "a ring opens before the try distance")
end
function t.should_join()
	T.ok(V.shouldJoin(5, true, false, false))
	T.ok(V.shouldJoin(V.joinReach(), true, nil, nil))
	T.no(V.shouldJoin(V.joinReach() + 0.01, true, false, false), "too far")
	T.no(V.shouldJoin(E.Wild.JoinDistance, true, false, false), "margin")
	T.no(V.shouldJoin(5, false, false, false), "no play needed")
	T.no(V.shouldJoin(5, nil, false, false), "attribute missing")
	T.no(V.shouldJoin(5, true, true, false), "already in")
	T.no(V.shouldJoin(5, true, false, true), "in a try")
	T.no(V.shouldJoin(nil, true, false, false), "no distance")
	T.no(V.shouldJoin(0 / 0, true, false, false), "nan")
end
function t.pick_join_nearest()
	local c = { { id = 1, distance = 12, needsPlay = true }, { id = 2, distance = 6, needsPlay = true }, { id = 3, distance = 2, needsPlay = false } }
	T.eq(V.pickJoin(c, {}, false), 2)
	T.eq(V.pickJoin(c, { [2] = true }, false), 1)
	T.eq(V.pickJoin(c, { [1] = true, [2] = true }, false), nil)
	T.eq(V.pickJoin(c, {}, true), nil)
	T.eq(V.pickJoin({}, {}, false), nil)
	T.eq(V.pickJoin({ { id = 9, distance = 500, needsPlay = true } }, {}, false), nil)
end
function t.forget()
	T.no(V.shouldForget(10, false))
	T.no(V.shouldForget(E.Wild.JoinDistance + V.ForgetMargin, false))
	T.ok(V.shouldForget(E.Wild.JoinDistance + V.ForgetMargin + 1, false))
	T.no(V.shouldForget(500, true), "ring on screen")
	T.ok(V.shouldForget(nil, false), "pet gone")
end
function t.ring_scale()
	T.eq(V.ringScale("guardian"), 1)
	T.eq(V.ringScale(nil), 1)
	T.ok(V.ringScale("wild") < 1)
	T.ok(64 * V.ringScale("wild") >= 32, "heart ring still easy to see")
end
function t.prompt()
	T.ok(V.shouldPrompt(2, 2, false, false, false))
	T.no(V.shouldPrompt(2, 3, false, false, false), "other floor")
	T.no(V.shouldPrompt(nil, nil, false, false, false), "no floor")
	T.no(V.shouldPrompt(2, 2, true, false, false), "already in")
	T.no(V.shouldPrompt(2, 2, false, true, false), "shown once")
	T.no(V.shouldPrompt(2, 2, false, false, true), "in a try")
	T.ok(V.PromptSeconds <= 10)
end
function t.arrow()
	T.near(V.arrowAngle(0, -5), -90) -- ahead: points up
	T.near(V.arrowAngle(5, 0), 0) -- right
	T.near(V.arrowAngle(0, 5), 90) -- behind: points down
	T.near(math.abs(V.arrowAngle(-5, 0)), 180) -- left
	T.near(V.arrowAngle(0, 0), -90)
end
function t.beat_window()
	local a, b = V.beatWindow(0, 1, 30)
	T.eq(a, 1) T.eq(b, 30)
	a, b = V.beatWindow(125.4, 1, 30)
	T.eq(a, 125) T.eq(b, 154)
	a, b = V.beatWindow(-2, 1)
	T.eq(a, 1) T.eq(b, V.BeatWindow)
	a, b = V.beatWindow(7, 2, 10)
	T.eq(a, 3) T.eq(b, 12)
end
function t.refill()
	T.no(V.needsRefill(10, 30, 1))
	T.no(V.needsRefill(27, 30, 1))
	T.ok(V.needsRefill(27.5, 30, 1))
	-- a refilled window always reaches past the old one
	local _, last = V.beatWindow(27.5, 1, 30)
	T.ok(last > 30)
	T.no(V.needsRefill(27.5, last, 1))
end
function t.capture()
	T.ok(V.captureAllowed({ IsContentSharingAllowed = true }))
	T.no(V.captureAllowed({ IsContentSharingAllowed = false }))
	T.no(V.captureAllowed({}), "field missing")
	T.no(V.captureAllowed(nil), "policy call failed")
	T.no(V.captureAllowed("yes"))
	T.no(V.captureAllowed({ IsContentSharingAllowed = "true" }))
	T.no(V.captureAllowed({ IsContentSharingAllowed = true, IsSubjectToChinaPolicies = true }))
end
function t.forget_retries_an_ask_that_brought_no_ring()
	T.no(V.shouldForget(10, false, 1))
	T.no(V.shouldForget(10, false, V.RetrySeconds))
	T.ok(V.shouldForget(10, false, V.RetrySeconds + 0.1))
	T.no(V.shouldForget(10, true, 500), "ring on screen: the ask worked")
	T.no(V.shouldForget(10, false, nil))
end
function t.snapshot_role()
	-- the server sends the wild snapshot to the whole floor
	T.eq(V.snapshotRole(true, true, false), "ring")
	T.eq(V.snapshotRole(true, true, nil), "ring")
	T.eq(V.snapshotRole(nil, false, nil), "icon", "bystander")
	T.eq(V.snapshotRole(nil, true, nil), "icon", "asked but the server did not let us in: no ring")
	T.eq(V.snapshotRole(false, true, nil), "icon")
	T.eq(V.snapshotRole(true, false, nil), "none", "stepped out: a late copy never re-opens the ring")
	T.eq(V.snapshotRole(true, true, true), "none", "over")
	T.eq(V.snapshotRole(nil, false, true), "none", "over: no icon either")
	T.eq(V.snapshotRole("yes", true, nil), "icon", "only a real true counts")
	T.eq(V.snapshotRole(1, true, nil), "icon")
end
function t.only_ring_blocks_trust_tap()
	-- Showdown.lua calls begin() (which blocks Trust Tap) only for "ring"
	local rings = 0
	for _, mine in ipairs({ true, false }) do
		for _, asked in ipairs({ true, false }) do
			for _, done in ipairs({ true, false }) do
				if V.snapshotRole(mine, asked, done) == "ring" then
					rings = rings + 1
					T.ok(mine and asked and not done)
				end
			end
		end
	end
	T.eq(rings, 1)
end
function t.end_means()
	T.eq(V.endMeans({ kind = "wild", petId = 1, floor = 1, won = false, left = true }), "stepped_out")
	T.eq(V.endMeans({ kind = "wild", petId = 1, floor = 1, won = false }), "pet_left")
	T.eq(V.endMeans({ kind = "wild", petId = 1, floor = 1, won = true }), "won")
	T.eq(V.endMeans({ won = false, left = 12 }), "pet_left", "the old `left` number is not a walk-away")
	T.eq(V.endMeans(nil), "pet_left")
end
function t.secret_banner_only_when_no_pillar_banner()
	T.ok(V.secretBanner(nil), "arrived mid-visit: no pillar banner came")
	T.no(V.secretBanner(0))
	T.no(V.secretBanner(1.2))
	T.no(V.secretBanner(V.PillarBannerSeconds))
	T.ok(V.secretBanner(V.PillarBannerSeconds + 1), "an old banner from an earlier visit")
	T.ok(V.secretBanner(-1))
end
function t.glow_at()
	local p, s = V.glowAt("glow", 1000, 1180, 940, 60)
	T.near(p, 0) T.near(s, 60)
	p, s = V.glowAt("glow", 1000, 1180, 985, 60) -- lantern loaded 45 s into the glow
	T.near(p, 0.75) T.near(s, 15)
	p, s = V.glowAt("glow", 1000, 1180, 900, 60) -- clock a little off: never below 0
	T.near(p, 0) T.near(s, 60)
	p, s = V.glowAt("glow", 1000, 1180, 1010, 60) -- the chime has rung, "here" not heard yet
	T.near(p, 1) T.near(s, 0)
	p, s = V.glowAt("here", 1000, 1180, 1100, 60)
	T.near(p, 1) T.near(s, 0)
	p, s = V.glowAt("here", 1000, 1180, 1180 + V.ChimeForgetSeconds, 60) -- a kept pet may stay a little
	T.near(p, 1)
	T.eq(V.glowAt("here", 1000, 1180, 1181 + V.ChimeForgetSeconds, 60), nil, "long over, no gone heard")
	T.eq(V.glowAt("glow", 1000, 1180, 1181 + V.ChimeForgetSeconds, 60), nil)
	T.eq(V.glowAt("gone", 1000, 1180, 1100, 60), nil)
	T.eq(V.glowAt("glow", nil, nil, 1100, 60), nil)
	p = V.glowAt("here", nil, nil, 1100, 60)
	T.near(p, 1)
end
return t
