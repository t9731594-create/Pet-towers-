-- Greybox world built by code: hub, 7 camps, floors. Art replaces these parts later (M7); the names,
-- attributes and positions are what other services rely on.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local World = { camps = {}, floors = {}, BuiltFloors = 5 }

local RARITY_COLOR = {
	Common = Color3.fromRGB(170, 170, 170), Uncommon = Color3.fromRGB(90, 200, 90), Rare = Color3.fromRGB(70, 140, 255),
	Epic = Color3.fromRGB(170, 90, 230), Legendary = Color3.fromRGB(255, 200, 60), Secret = Color3.fromRGB(255, 120, 200),
}
World.RarityColor = RARITY_COLOR
World.NatureColor = { Ember = Color3.fromRGB(255, 120, 70), Tide = Color3.fromRGB(80, 170, 255), Leaf = Color3.fromRGB(110, 210, 90) }
local FLOOR_COLOR = {
	Color3.fromRGB(120, 200, 90), Color3.fromRGB(255, 150, 120), Color3.fromRGB(60, 150, 150),
	Color3.fromRGB(220, 235, 250), Color3.fromRGB(40, 50, 110),
}

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end
World.part = part

local function prompt(parent, action, key)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = ""
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Name = key
	pp.Parent = parent
	return pp
end

local function buildCamp(i, root)
	local angle = (i - 1) / 7 * math.pi * 2
	local center = Vector3.new(math.cos(angle) * 150, 0, math.sin(angle) * 150)
	local folder = Instance.new("Folder") folder.Name = "Camp" .. i folder.Parent = root
	local facing = CFrame.lookAt(center + Vector3.new(0, 3, 0), Vector3.new(0, 3, 0)) -- faces the tower
	local ground = part({ Name = "Ground", Size = Vector3.new(90, 1, 90), Position = center, Color = Color3.fromRGB(150, 205, 120) }, folder)
	local zone = part({ Name = "Zone", Size = Vector3.new(90, 12, 90), Position = center + Vector3.new(0, 6, 0), Transparency = 1, CanCollide = false }, folder)
	local camp = { index = i, center = center, folder = folder, ground = ground, zone = zone, pads = {}, pedestals = {}, owner = nil }
	camp.spawn = facing * CFrame.new(0, 0, 14)
	-- three starters on pedestals straight ahead of the spawn
	for s, species in ipairs(Config.Pets.StarterOrder) do
		local cf = facing * CFrame.new((s - 2) * 8, -1.5, -2)
		local ped = part({ Name = "Pedestal_" .. species, Size = Vector3.new(4, 2, 4), CFrame = cf, Color = Color3.fromRGB(235, 225, 200) }, folder)
		local ball = part({ Name = "Starter", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = cf * CFrame.new(0, 2.5, 0),
			Color = World.NatureColor[Config.Pets.Starters[species].nature], CanCollide = false }, ped)
		ped:SetAttribute("Species", species)
		camp.pedestals[species] = { ped = ped, ball = ball }
	end
	-- 24 pad spots in 3 rows behind the spawn; the first 8 show at the start
	for n = 1, 24 do
		local row, col = math.floor((n - 1) / 8), (n - 1) % 8
		local cf = facing * CFrame.new((col - 3.5) * 7, -2.4, 22 + row * 7)
		local pad = part({ Name = "Pad" .. n, Size = Vector3.new(5, 0.4, 5), CFrame = cf, Color = Color3.fromRGB(250, 235, 150), Transparency = n <= 8 and 0 or 1 }, folder)
		pad:SetAttribute("Pad", n)
		camp.pads[n] = pad
	end
	local function station(name, x, z, color, action)
		local st = part({ Name = name, Size = Vector3.new(5, 4, 5), CFrame = facing * CFrame.new(x, -0.5, z), Color = color }, folder)
		camp[name] = st
		camp[name .. "Prompt"] = prompt(st, action, name)
	end
	station("SnackTable", -22, 6, Color3.fromRGB(255, 170, 120), "Feed")
	station("CharmBench", -22, 16, Color3.fromRGB(190, 150, 255), "Charm")
	station("Lift", 22, 6, Color3.fromRGB(255, 240, 180), "Lift")
	station("EggNest", 22, 16, Color3.fromRGB(255, 250, 235), "Egg")
	station("Mailbox", 22, 26, Color3.fromRGB(150, 200, 255), "Mail")
	return camp
end

local function buildFloor(f, root)
	local center = Vector3.new(0, 400 * f, 0)
	local folder = Instance.new("Folder") folder.Name = "Floor" .. f folder.Parent = root
	local floor = { index = f, center = center, folder = folder, size = 220 }
	floor.ground = part({ Name = "Ground", Size = Vector3.new(220, 2, 220), Position = center, Color = FLOOR_COLOR[f]:Lerp(Color3.new(0.5, 0.5, 0.5), 0.6) }, folder)
	floor.fullColor = FLOOR_COLOR[f]
	floor.spawn = CFrame.new(center + Vector3.new(0, 4, 90))
	floor.lift = part({ Name = "Lift", Size = Vector3.new(10, 1, 10), Position = center + Vector3.new(0, 1.5, 100), Color = Color3.fromRGB(255, 240, 180) }, folder)
	floor.liftPrompt = prompt(floor.lift, "Home", "Lift")
	floor.ring = part({ Name = "GuardianRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 50, 50),
		CFrame = CFrame.new(center + Vector3.new(0, 1.6, -75)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = World.NatureColor[Config.Pets.Guardians[f].nature], Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false }, folder)
	floor.guardian = part({ Name = "Guardian", Shape = Enum.PartType.Ball, Size = Vector3.new(28, 28, 28), Position = center + Vector3.new(0, 15, -95),
		Color = Color3.fromRGB(120, 120, 130) }, folder)
	floor.lantern = part({ Name = "Lantern", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), Position = center + Vector3.new(0, 36, -95),
		Color = Color3.fromRGB(90, 90, 90), Material = Enum.Material.Neon }, folder)
	floor.pets = Instance.new("Folder") floor.pets.Name = "Pets" floor.pets.Parent = folder
	return floor
end

function World.init()
	local root = Instance.new("Folder") root.Name = "PetTowerWorld" root.Parent = workspace
	part({ Name = "Hub", Size = Vector3.new(160, 1, 160), Position = Vector3.new(0, 0, 0), Color = Color3.fromRGB(225, 215, 190) }, root)
	part({ Name = "Tower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(300, 40, 40), CFrame = CFrame.new(0, 150, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(250, 240, 215) }, root)
	for i = 1, 7 do World.camps[i] = buildCamp(i, root) end
	for f = 1, World.BuiltFloors do World.floors[f] = buildFloor(f, root) end
	World.tutorialPets = Instance.new("Folder") World.tutorialPets.Name = "TutorialPets" World.tutorialPets.Parent = root
end

function World.claimCamp(player)
	for _, camp in ipairs(World.camps) do
		if not camp.owner then camp.owner = player return camp end
	end
end
function World.campOf(player)
	for _, camp in ipairs(World.camps) do if camp.owner == player then return camp end end
end
function World.freeCamp(player)
	local camp = World.campOf(player)
	if camp then camp.owner = nil end
	return camp
end

-- A greybox pet: a ball in its rarity colour. Returns the part.
function World.petBall(species, rarity, radiant, size)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(size, size, size)
	ball.Color = RARITY_COLOR[rarity] or RARITY_COLOR.Common
	ball.Material = radiant and Enum.Material.Neon or Enum.Material.SmoothPlastic
	ball.TopSurface = Enum.SurfaceType.Smooth
	ball.BottomSurface = Enum.SurfaceType.Smooth
	ball.Name = species
	ball:SetAttribute("Species", species)
	ball:SetAttribute("Rarity", rarity)
	ball:SetAttribute("Radiant", radiant)
	return ball
end
World.RaritySize = { Common = 2, Uncommon = 2.5, Rare = 3, Epic = 3.5, Legendary = 4, Secret = 4.5 }

function World.relight(f)
	local floor = World.floors[f]
	if not floor then return end
	floor.ground.Color = floor.fullColor
	floor.lantern.Color = Color3.fromRGB(255, 220, 120)
	floor.guardian.Color = Color3.fromRGB(255, 235, 170)
end

return World
