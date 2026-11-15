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
return t
