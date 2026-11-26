-- Улица: земля, забор, деревья, дорога и лобби, уличный вход в подвал,
-- столб со щитком (питает свет в доме и проводку), сарай, машина, могилы.

local Kit = require(script.Parent.Kit)
local Decor = require(script.Parent.Decor)
local F = require(script.Parent.Furniture)

local M, C = Kit.M, Kit.C
local B = Kit.B
local box, wall, at, folder, newPart = Kit.box, Kit.wall, Kit.at, Kit.folder, Kit.newPart

local Exterior = {}

local NZ = Vector3.new(0, 0, -1)

local function deadTree(parent: Instance, x: number, z: number)
	local rng = Kit.rng
	local h = rng:NextNumber(16, 26)
	local d = rng:NextNumber(1.4, 2.4)
	Kit.cylinder(parent, CFrame.new(x, h / 2, z), h, d, C.bark, M.wood)
	for _ = 1, rng:NextInteger(3, 6) do
		local by = rng:NextNumber(h * 0.45, h * 0.9)
		local len = rng:NextNumber(4, 9)
		local cf = CFrame.new(x, by, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(30, 60))) * CFrame.new(len / 2, 0, 0)
		local p = newPart(parent, Vector3.new(len, d * 0.35, d * 0.35), cf, C.bark, M.wood)
		p.Shape = Enum.PartType.Cylinder
	end
end

local function pine(parent: Instance, x: number, z: number)
	local rng = Kit.rng
	local h = rng:NextNumber(24, 38)
	Kit.cylinder(parent, CFrame.new(x, h * 0.2, z), h * 0.4, 1.8, C.bark, M.wood)
	for i = 0, 3 do
		local t = i / 4
		local width = (1 - t) * rng:NextNumber(11, 15) + 2
		Kit.cylinder(parent, CFrame.new(x, h * (0.3 + t * 0.62), z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), h * 0.2, width, C.pine, M.grass)
	end
end

local function fence(parent: Instance, from: Vector3, to: Vector3)
	local rng = Kit.rng
	local dir = (to - from).Unit
	local length = (to - from).Magnitude
	local dd = 0
	while dd <= length do
		local roll = rng:NextNumber()
		if roll > 0.1 then
			local pos = from + dir * dd
			local h = rng:NextNumber(3.4, 4.2)
			local tilt = roll > 0.85 and rng:NextNumber(-0.5, 0.5) or rng:NextNumber(-0.05, 0.05)
			newPart(parent, Vector3.new(0.9, h, 0.25), CFrame.lookAt(pos, pos + dir) * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, h / 2, 0), Color3.fromRGB(110, 104, 92), M.wood)
		end
		dd += 1.6
	end
	for _, y in { 1.2, 2.9 } do
		local mid = (from + to) / 2 + Vector3.new(0, y, 0)
		newPart(parent, Vector3.new(0.3, 0.4, length), CFrame.lookAt(mid, to + Vector3.new(0, y, 0)), Color3.fromRGB(90, 84, 74), M.wood)
	end
end

-- Уличный вход в подвал: яма с лестницей, распахнутые створки люка
local function bulkhead(parent: Instance)
	local pit = folder(parent, "CellarEntrance")
	local z1, z2 = 22.5, 27.5
	-- бетонные стенки ямы (чуть выше земли — бортик)
	box(pit, -72, B - 1, z1 - 0.8, -54, 0.8, z1, C.concrete, M.concrete)
	box(pit, -72, B - 1, z2, -54, 0.8, z2 + 0.8, C.concrete, M.concrete)
	box(pit, -57, B - 1, z1, -54, B, z2, C.concrete, M.concrete) -- площадка внизу
	Kit.stairs(pit, Vector3.new(-56, B, 25), Vector3.new(-72, 0, 25), 4.6)
	-- створки люка, откинутые в стороны
	newPart(pit, Vector3.new(15, 0.35, 3), CFrame.new(-63, 1.1, 20.6) * CFrame.Angles(math.rad(-25), 0, 0), C.extWood, M.planks)
	newPart(pit, Vector3.new(15, 0.35, 3), CFrame.new(-63, 1.4, 29.4) * CFrame.Angles(math.rad(35), 0, 0), C.extWood, M.planks)
	-- ржавые петли и цепь
	for _, x in { -68, -58 } do
		box(pit, x - 0.3, 0.6, z1 - 1, x + 0.3, 1, z1 - 0.6, C.rust, M.rust)
	end
	Decor.slimePuddle(pit, Vector3.new(-56, B, 25), 1.5)
end

-- Столб со щитком. Логика — в PowerPanel.server.luau
local function powerPole(parent: Instance)
	local x, z = -30, 62
	local pole = folder(parent, "PowerPole")
	Kit.cylinder(pole, CFrame.new(x, 9, z), 18, 1.2, C.bark, M.wood)
	box(pole, x - 4, 16.2, z - 0.25, x + 4, 16.7, z + 0.25, C.bark, M.wood)
	for _, dx in { -3.5, 0, 3.5 } do
		Kit.cylinder(pole, CFrame.new(x + dx, 17.1, z), 0.8, 0.35, Color3.fromRGB(90, 110, 100), M.glass)
	end
	-- провода к дому (провисают)
	local function cable(a: Vector3, b: Vector3)
		newPart(pole, Vector3.new(0.12, 0.12, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(15, 15, 15), M.smooth, { CanCollide = false })
	end
	local top, mid, house = Vector3.new(x, 17.2, z), Vector3.new(-38, 20.5, 49), Vector3.new(-46, 27, 36.6)
	cable(top, mid)
	cable(mid, house)
	cable(top + Vector3.new(3.5, 0, 0), mid + Vector3.new(1.5, -0.6, 0))
	cable(mid + Vector3.new(1.5, -0.6, 0), house + Vector3.new(2, -0.5, 0))

	-- фонарь на столбе (тоже от щитка)
	local lamp = newPart(pole, Vector3.new(1.2, 0.6, 1.2), CFrame.new(x, 15.4, z - 1.2), Color3.fromRGB(60, 58, 50), M.glass, { CanCollide = false, Name = "YardLamp" })
	local light = Kit.addLight(lamp, 1.2, 40, C.warm)
	light.Enabled = false
	lamp:SetAttribute("OnColor", C.warm)
	Kit.tag(lamp, "PanelLight")

	-- сам щиток
	local panel = Instance.new("Model")
	panel.Name = "PowerPanel"
	panel.Parent = parent
	local o = at(x, 4.5, z - 1.2, NZ)
	local body = Kit.piece(panel, o, Vector3.new(0, 2, 0), Vector3.new(3, 4, 1.2), Color3.fromRGB(78, 82, 76), M.rust, { Name = "Box" })
	Kit.piece(panel, o, Vector3.new(0, 2, -0.62), Vector3.new(2.4, 3.2, 0.05), Color3.fromRGB(30, 30, 28), M.metal, { CanCollide = false })
	for i = 1, 4 do
		Kit.piece(panel, o, Vector3.new(-0.9 + (i - 1) * 0.6, 2.6, -0.66), Vector3.new(0.3, 0.7, 0.08), Color3.fromRGB(20, 20, 20), M.smooth, { CanCollide = false })
	end
	-- приоткрытая дверца
	Kit.newPart(panel, Vector3.new(3, 4, 0.12), o * CFrame.new(1.5, 2, -0.62) * CFrame.Angles(0, math.rad(-70), 0) * CFrame.new(1.5, 0, 0), Color3.fromRGB(70, 74, 68), M.rust, { CanCollide = false, Name = "PanelDoor" })
	local status = Kit.piece(panel, o, Vector3.new(0, 4.3, -0.3), Vector3.new(0.45, 0.45, 0.45), Color3.fromRGB(180, 20, 20), M.neon, { CanCollide = false, Shape = Enum.PartType.Ball, Name = "StatusLight" })
	Kit.addLight(status, 0.6, 6, Color3.fromRGB(255, 40, 30), false)
	local spark = Instance.new("Attachment")
	spark.Name = "SparkPoint"
	spark.Position = Vector3.new(0, 0.6, -0.7)
	spark.Parent = body
	-- торчащие провода снизу
	for i, dx in { -0.8, 0.2, 0.9 } do
		Kit.piece(panel, o, Vector3.new(dx, -0.6 - i * 0.3, -0.3), Vector3.new(0.12, 1.2 + i * 0.6, 0.12), i == 2 and Color3.fromRGB(150, 30, 20) or Color3.fromRGB(20, 20, 20), M.smooth, { CanCollide = false })
	end
	panel.PrimaryPart = body
	Kit.tag(panel, "PowerPanel")

	-- зарядка фонарика прямо у столба
	Kit.chargePoint(pole, at(x, 2.6, z - 0.85, NZ))
end

local function car(parent: Instance, x: number, z: number, yaw: number)
	local m = folder(parent, "OldCar")
	local o = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
	Kit.piece(m, o, Vector3.new(0, 2.2, 0), Vector3.new(7, 2.4, 15), Color3.fromRGB(90, 54, 36), M.rust)
	Kit.piece(m, o, Vector3.new(0, 4.2, 1), Vector3.new(6.4, 2, 7), Color3.fromRGB(80, 48, 32), M.rust)
	Kit.piece(m, o, Vector3.new(0, 4.2, -2.55), Vector3.new(5.8, 1.6, 0.1), Color3.fromRGB(30, 36, 36), M.glass, { Transparency = 0.4 })
	for _, sx in { -3.3, 3.3 } do
		for _, sz in { -4.8, 4.8 } do
			local w = Kit.newPart(m, Vector3.new(1, 2.6, 2.6), o * CFrame.new(sx, 1.1, sz), Color3.fromRGB(20, 20, 20), M.slate)
			w.Shape = Enum.PartType.Cylinder
		end
	end
	-- капот открыт
	Kit.newPart(m, Vector3.new(6.6, 0.2, 4), o * CFrame.new(0, 3.6, -6.6) * CFrame.Angles(math.rad(50), 0, 0), Color3.fromRGB(86, 52, 34), M.rust)
end

function Exterior.build(map: Instance, ctx: { [string]: Instance })
	local rng = Kit.rng
	local ext = folder(map, "Exterior")
	local trees = folder(ext, "Trees")

	-- Земля (с вырезами под дом и уличный вход в подвал)
	local function ground(x1: number, z1: number, x2: number, z2: number)
		box(ext, x1, -1, z1, x2, 0, z2, C.grass, M.grass)
	end
	ground(-220, -220, 220, -36)
	ground(-220, 36, 220, 220)
	ground(54, -36, 220, 36)
	ground(-220, -36, -54, 22.5)
	ground(-220, 27.5, -54, 36)
	ground(-220, 22.5, -72, 27.5)

	for _ = 1, 50 do
		local x, z = rng:NextNumber(-88, 88), rng:NextNumber(-92, 88)
		if math.abs(x) > 58 or math.abs(z) > 52 then
			Kit.disk(ext, CFrame.new(x, 0, z) * CFrame.Angles(0, 0, math.pi / 2), rng:NextNumber(4, 11), C.dirt, M.mud, 0)
		end
	end

	-- Дорога и лобби
	box(ext, -220, 0, -118, 220, 0.06, -104, Color3.fromRGB(36, 36, 36), M.asphalt)
	local lobby = Instance.new("SpawnLocation")
	lobby.Name = "LobbySpawn"
	lobby.Anchored = true
	lobby.Neutral = true
	lobby.Size = Vector3.new(8, 0.4, 8)
	lobby.CFrame = CFrame.new(0, 0.26, -111)
	lobby.Color = Color3.fromRGB(40, 40, 40)
	lobby.Material = M.asphalt
	lobby.Duration = 0
	lobby.Parent = workspace

	newPart(workspace, Vector3.new(6, 1, 6), CFrame.new(0, 0.5, -100), C.stone, M.smooth, {
		Name = "SurvivorSpawn",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	-- Дорожка к крыльцу
	for z = -102, -51, 2.2 do
		if rng:NextNumber() > 0.15 then
			box(ext, -2.5 + rng:NextNumber(-0.3, 0.3), 0, z, 2.5 + rng:NextNumber(-0.3, 0.3), 0.15, z + 1.8, C.stone, M.stone)
		end
	end

	-- Забор с воротами
	local fences = folder(ext, "Fence")
	fence(fences, Vector3.new(-90, 0, -95), Vector3.new(-5, 0, -95))
	fence(fences, Vector3.new(5, 0, -95), Vector3.new(90, 0, -95))
	fence(fences, Vector3.new(90, 0, -95), Vector3.new(90, 0, 90))
	fence(fences, Vector3.new(90, 0, 90), Vector3.new(-90, 0, 90))
	fence(fences, Vector3.new(-90, 0, 90), Vector3.new(-90, 0, -95))
	box(fences, -5.6, 0, -95.6, -4.4, 6, -94.4, C.trim, M.wood)
	box(fences, 4.4, 0, -95.6, 5.6, 6, -94.4, C.trim, M.wood)
	newPart(fences, Vector3.new(4.6, 0.3, 4), CFrame.new(7, 0.2, -98) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(100, 94, 84), M.wood, { CanCollide = false })
	box(ext, 8.8, 0, -97.8, 9.2, 3.6, -97.4, C.trim, M.wood)
	box(ext, 8.3, 3.6, -98.3, 9.7, 4.6, -96.6, Color3.fromRGB(80, 50, 40), M.rust)

	-- Деревья
	for _, pos in { { -70, -60 }, { 66, -70 }, { -60, 60 }, { 44, 66 }, { -80, 0 }, { 76, -10 }, { 70, 70 }, { -76, -86 } } do
		deadTree(trees, pos[1], pos[2])
	end
	for _ = 1, 60 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(105, 200)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		if not (z < -100 and z > -122) then
			pine(trees, x, z)
		end
	end

	-- Невидимые стены по краю карты
	for _, b in { { -205, -205, 205, -204 }, { -205, 204, 205, 205 }, { -205, -205, -204, 205 }, { 204, -205, 205, 205 } } do
		box(ext, b[1], 0, b[2], b[3], 60, b[4], C.grass, M.smooth, { Transparency = 1, Name = "Boundary" })
	end

	bulkhead(ext)
	powerPole(ext)
	car(ext, 60, -62, 25)

	-- Семейные могилы на заднем дворе
	local graves = folder(ext, "Graves")
	for i, name in { "Thomas", "Martha", "Lily", "?" } do
		local gx = 38 + i * 5
		local tilt = rng:NextNumber(-0.15, 0.15)
		newPart(graves, Vector3.new(3, 3.6, 0.7), CFrame.new(gx, 1.6, 72) * CFrame.Angles(tilt, 0, tilt * 0.5), Color3.fromRGB(90, 90, 86), M.slate, { Name = `Grave_{name}` })
		local mound = box(graves, gx - 1.3, 0, 72.6, gx + 1.3, 0.25, 77, C.dirt, M.mud, { CanCollide = false })
		mound.Name = `Mound_{name}`
	end

	-- Сарай
	local shed = folder(ext, "Shed")
	local x1, x2, z1, z2 = 60, 72, 30, 42
	box(shed, x1, 0, z1, x2, 0.3, z2, C.floor, M.planks)
	wall(shed, "x", z1, x1 - 0.5, x2 + 0.5, 0.3, 8, { { 65, 67, 3, 5.5, "boarded" } }, C.extWood, M.planks, -1)
	wall(shed, "x", z2, x1 - 0.5, x2 + 0.5, 0.3, 8, nil, C.extWood, M.planks, 1)
	wall(shed, "z", x1, z1 + 0.5, z2 - 0.5, 0.3, 8, { { 34, 38, 0, 7, "door", { bats = true, open = false } } }, C.extWood, M.planks, -1)
	wall(shed, "z", x2, z1 + 0.5, z2 - 0.5, 0.3, 8, nil, C.extWood, M.planks, 1)
	newPart(shed, Vector3.new(14, 0.5, 14), CFrame.new(66, 8.6, 36) * CFrame.Angles(0, 0, math.rad(8)), C.roof, M.roof)
	F.table(shed, at(70, 0.3, 36, Vector3.new(-1, 0, 0)), 6, 2.6, 3.4)
	F.shelf(shed, at(66, 0.3, 41.2, NZ), 6, 6, 1.4, 3)
	F.barrel(shed, at(62, 0.3, 32))
	Decor.dress(shed, x1, z1, x2, z2, 0.3, 7.7, { amount = 3, webs = 3, decals = 2 })
	Kit.marker(ctx.hideouts, "Hideout_Shed", Vector3.new(63, 0.3, 40))

	-- Названия мест
	local z = ctx.zones
	Kit.zone(z, "Сарай", x1, 0, z1, x2, 9, z2)
	Kit.zone(z, "Могилы Хейлов", 36, 0, 66, 66, 10, 82)
	Kit.zone(z, "Задний двор", -90, 0, 36, 90, 30, 90)
	Kit.zone(z, "Двор", -90, 0, -95, 90, 30, -36)
	Kit.zone(z, "Дорога", -220, 0, -125, 220, 30, -95)
end

return Exterior
