-- Строит карту «Дом Хейлов» целиком из кода.
-- Запуск в Studio (Command Bar, в режиме редактирования):
--   require(game.ServerStorage.Tools.MapBuilder:Clone()).build()
-- Потом сохраните место (Ctrl+S). Отменить — Ctrl+Z.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local MapBuilder = {}

-- Высоты этажей (studs)
local G = 2 -- пол 1 этажа
local S = 15 -- пол 2 этажа
local TOP = 27 -- потолок 2 этажа
local B = -10 -- пол подвала
local WALL = 1 -- толщина стены

local rng = Random.new(1989)

-- Материал по имени; если в Studio его нет — запасной
local function mat(name: string, fallback: Enum.Material): Enum.Material
	local ok, result = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	if ok and result then
		return result
	end
	return fallback
end

local M = {
	planks = Enum.Material.WoodPlanks,
	wood = Enum.Material.Wood,
	plaster = mat("Plaster", Enum.Material.Concrete),
	concrete = Enum.Material.Concrete,
	stone = Enum.Material.Cobblestone,
	brick = Enum.Material.Brick,
	metal = Enum.Material.Metal,
	rust = Enum.Material.CorrodedMetal,
	fabric = Enum.Material.Fabric,
	glass = Enum.Material.Glass,
	neon = Enum.Material.Neon,
	smooth = Enum.Material.SmoothPlastic,
	slate = Enum.Material.Slate,
	grass = Enum.Material.Grass,
	mud = mat("Mud", Enum.Material.Slate),
	roof = mat("RoofShingles", Enum.Material.Slate),
	carpet = mat("Carpet", Enum.Material.Fabric),
	tiles = mat("CeramicTiles", Enum.Material.Slate),
	asphalt = mat("Asphalt", Enum.Material.Concrete),
}

local C = {
	extWood = Color3.fromRGB(78, 68, 56),
	trim = Color3.fromRGB(46, 35, 26),
	floor = Color3.fromRGB(64, 48, 34),
	plaster = Color3.fromRGB(108, 102, 88),
	plasterDark = Color3.fromRGB(86, 80, 68),
	stone = Color3.fromRGB(74, 72, 68),
	concrete = Color3.fromRGB(66, 66, 63),
	roof = Color3.fromRGB(40, 38, 38),
	furn = Color3.fromRGB(58, 40, 28),
	furnDark = Color3.fromRGB(38, 27, 20),
	fabric = Color3.fromRGB(72, 38, 32),
	cloth = Color3.fromRGB(140, 130, 110),
	paper = Color3.fromRGB(140, 130, 104),
	mold = Color3.fromRGB(36, 46, 30),
	moldDark = Color3.fromRGB(22, 26, 18),
	stain = Color3.fromRGB(48, 36, 24),
	grass = Color3.fromRGB(44, 50, 32),
	dirt = Color3.fromRGB(52, 44, 34),
	pine = Color3.fromRGB(26, 38, 28),
	bark = Color3.fromRGB(44, 36, 30),
	warm = Color3.fromRGB(255, 186, 112),
	cold = Color3.fromRGB(190, 210, 255),
	flesh = Color3.fromRGB(58, 32, 30),
	fleshDark = Color3.fromRGB(32, 22, 20),
	rust = Color3.fromRGB(96, 60, 38),
}

---------------------------------------------------------------------
-- Базовые помощники
---------------------------------------------------------------------

local function newPart(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- Деталь по двум углам (без поворота)
local function box(parent: Instance, x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, color: Color3, material: Enum.Material, props: { [string]: any }?): Part
	local size = Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(z2 - z1))
	local center = Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2)
	return newPart(parent, size, CFrame.new(center), color, material, props)
end

-- Деталь относительно точки мебели (origin — центр мебели на полу)
local function piece(parent: Instance, origin: CFrame, offset: Vector3, size: Vector3, color: Color3, material: Enum.Material, props: { [string]: any }?): Part
	return newPart(parent, size, origin * CFrame.new(offset), color, material, props)
end

-- Вертикальный цилиндр
local function cylinder(parent: Instance, cf: CFrame, height: number, diameter: number, color: Color3, material: Enum.Material, props: { [string]: any }?): Part
	local p = newPart(parent, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Эллипсоид (шар, который можно растянуть) — для наростов и коконов
local function blob(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = newPart(parent, size, cf, color, material, { CanCollide = false })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Точка на полу, «лицом» в сторону face
local function at(x: number, y: number, z: number, face: Vector3?): CFrame
	local pos = Vector3.new(x, y, z)
	return CFrame.lookAt(pos, pos + (face or Vector3.new(0, 0, -1)))
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Невидимый пандус под лестницей (по нему реально ходят)
local function ramp(parent: Instance, p1: Vector3, p2: Vector3, width: number)
	local length = (p2 - p1).Magnitude
	local cf = CFrame.lookAt(p1, p2) * CFrame.new(0, -0.5, -length / 2)
	newPart(parent, Vector3.new(width, 1, length), cf, C.trim, M.wood, { Transparency = 1, Name = "StairRamp" })
end

-- Перила от base1 до base2 (точки внизу), высотой h
local function railing(parent: Instance, base1: Vector3, base2: Vector3, h: number)
	local length = (base2 - base1).Magnitude
	local up = Vector3.new(0, h, 0)
	local mid = (base1 + base2) / 2 + up
	newPart(parent, Vector3.new(0.35, 0.3, length), CFrame.lookAt(mid, base2 + up), C.trim, M.wood)
	local count = math.max(1, math.floor(length / 1.6))
	for i = 0, count do
		-- некоторые столбики сгнили и выпали
		if i == 0 or i == count or rng:NextNumber() > 0.15 then
			local pos = base1:Lerp(base2, i / count)
			newPart(parent, Vector3.new(0.25, h, 0.25), CFrame.new(pos + up / 2), C.trim, M.wood)
		end
	end
end

---------------------------------------------------------------------
-- Стены с проёмами
---------------------------------------------------------------------

-- Заколоченное / грязное / разбитое окно
local function fillWindow(parent: Instance, axis: string, fixed: number, s1: number, s2: number, y1: number, y2: number, kind: string, out: number)
	local w = s2 - s1
	local mid = (s1 + s2) / 2
	local h = y2 - y1
	local function make(size: Vector3, y: number, sAt: number, offset: number, tilt: number, color: Color3, material: Enum.Material, props: { [string]: any }?)
		if axis == "x" then
			newPart(parent, size, CFrame.new(sAt, y, fixed + offset) * CFrame.Angles(0, 0, tilt), color, material, props)
		else
			newPart(parent, Vector3.new(size.Z, size.Y, size.X), CFrame.new(fixed + offset, y, sAt) * CFrame.Angles(tilt, 0, 0), color, material, props)
		end
	end
	if kind == "glass" or kind == "broken" then
		local glassH = kind == "broken" and h * 0.4 or h
		make(Vector3.new(w, glassH, 0.12), y1 + glassH / 2, mid, 0, 0, Color3.fromRGB(50, 60, 62), M.glass, { Transparency = 0.55 })
		-- рама крестом
		make(Vector3.new(0.25, h, 0.3), y1 + h / 2, mid, 0, 0, C.trim, M.wood)
		make(Vector3.new(w, 0.25, 0.3), y1 + h / 2, mid, 0, 0, C.trim, M.wood)
	end
	if kind == "boarded" or kind == "broken" then
		local boards = kind == "boarded" and 3 or 2
		for i = 1, boards do
			local y = y1 + h * i / (boards + 1)
			make(Vector3.new(w + 1.4, 0.7, 0.25), y, mid, out * 0.65, rng:NextNumber(-0.35, 0.35), C.extWood, M.planks)
		end
	end
	-- подоконник
	make(Vector3.new(w + 0.6, 0.25, 1.4), y1 - 0.12, mid, 0, 0, C.trim, M.wood)
end

-- Стена вдоль оси X (z = fixed) или Z (x = fixed), от a до b.
-- holes: { {s1, s2, низ, верх, вид} } — координаты вдоль стены, высота от пола.
-- вид: "door", "glass", "boarded", "broken" или nil (просто дыра)
local function wall(parent: Instance, axis: string, fixed: number, a: number, b: number, y0: number, h: number, holes: { any }?, color: Color3, material: Enum.Material, out: number?)
	local list = holes or {}
	table.sort(list, function(p, q)
		return p[1] < q[1]
	end)
	local half = WALL / 2
	local function seg(s1: number, s2: number, h1: number, h2: number)
		if s2 - s1 < 0.05 or h2 - h1 < 0.05 then
			return
		end
		if axis == "x" then
			box(parent, s1, y0 + h1, fixed - half, s2, y0 + h2, fixed + half, color, material)
		else
			box(parent, fixed - half, y0 + h1, s1, fixed + half, y0 + h2, s2, color, material)
		end
	end
	local cursor = a
	for _, hole in list do
		local s1, s2, bottom, top, kind = hole[1], hole[2], hole[3], hole[4], hole[5]
		seg(cursor, s1, 0, h)
		seg(s1, s2, 0, bottom)
		seg(s1, s2, top, h)
		cursor = s2
		if kind and kind ~= "door" then
			fillWindow(parent, axis, fixed, s1, s2, y0 + bottom, y0 + top, kind, out or 1)
		elseif kind == "door" then
			-- дверная коробка
			local frameH = top - bottom
			if axis == "x" then
				box(parent, s1 - 0.3, y0, fixed - 0.65, s1, y0 + frameH, fixed + 0.65, C.trim, M.wood)
				box(parent, s2, y0, fixed - 0.65, s2 + 0.3, y0 + frameH, fixed + 0.65, C.trim, M.wood)
				box(parent, s1 - 0.3, y0 + frameH, fixed - 0.65, s2 + 0.3, y0 + frameH + 0.4, fixed + 0.65, C.trim, M.wood)
			else
				box(parent, fixed - 0.65, y0, s1 - 0.3, fixed + 0.65, y0 + frameH, s1, C.trim, M.wood)
				box(parent, fixed - 0.65, y0, s2, fixed + 0.65, y0 + frameH, s2 + 0.3, C.trim, M.wood)
				box(parent, fixed - 0.65, y0 + frameH, s1 - 0.3, fixed + 0.65, y0 + frameH + 0.4, s2 + 0.3, C.trim, M.wood)
			end
		end
	end
	seg(cursor, b, 0, h)
end

-- Приоткрытая дверь (сквозь неё можно пройти)
local function openDoor(parent: Instance, hinge: Vector3, angle: number, axis: string)
	local base = axis == "x" and 0 or -math.pi / 2
	local cf = CFrame.new(hinge) * CFrame.Angles(0, base + angle, 0) * CFrame.new(1.9, 3.9, 0)
	newPart(parent, Vector3.new(3.8, 7.8, 0.25), cf, C.furnDark, M.planks, { CanCollide = false, Name = "Door" })
end

---------------------------------------------------------------------
-- Гниль: мусор, бумаги, плесень, пятна
---------------------------------------------------------------------

local function disk(parent: Instance, cf: CFrame, diameter: number, color: Color3, material: Enum.Material, transparency: number)
	local p = newPart(parent, Vector3.new(0.06, diameter, diameter * rng:NextNumber(0.6, 1)), cf, color, material, {
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Transparency = transparency,
	})
	p.Shape = Enum.PartType.Cylinder
end

-- Комната от x1..x2, z1..z2 (линии стен), пол на высоте y, потолок через h
local function decay(parent: Instance, x1: number, z1: number, x2: number, z2: number, y: number, h: number, amount: number)
	local ix1, ix2, iz1, iz2 = x1 + 0.5, x2 - 0.5, z1 + 0.5, z2 - 0.5
	local function rx()
		return rng:NextNumber(ix1 + 1, ix2 - 1)
	end
	local function rz()
		return rng:NextNumber(iz1 + 1, iz2 - 1)
	end
	local flat = CFrame.Angles(0, 0, math.pi / 2) -- ось цилиндра вверх = плоский диск

	for _ = 1, amount do
		-- обломки досок
		newPart(parent, Vector3.new(rng:NextNumber(1.5, 4.5), 0.22, rng:NextNumber(0.4, 0.8)), CFrame.new(rx(), y + 0.12, rz()) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.06, 0.06)), C.furnDark, M.wood, { CanCollide = false })
		-- бумаги
		newPart(parent, Vector3.new(1, 0.04, 1.35), CFrame.new(rx(), y + 0.03, rz()) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), C.paper, M.smooth, { CanCollide = false, CastShadow = false })
		-- тёмные пятна гнили на полу (несколько полупрозрачных кругов — неровный край)
		local sx, sz = rx(), rz()
		local color = rng:NextNumber() > 0.5 and C.stain or C.moldDark
		for _ = 1, 4 do
			disk(parent, CFrame.new(sx + rng:NextNumber(-1.2, 1.2), y + 0.03 + rng:NextNumber(0, 0.01), sz + rng:NextNumber(-1.2, 1.2)) * flat, rng:NextNumber(0.8, 2.4), color, M.slate, rng:NextNumber(0.45, 0.7))
		end
	end

	-- плесень на стенах, у пола и под потолком: пятно из кучки мелких кругов
	for _ = 1, amount + 1 do
		local side = rng:NextInteger(1, 4)
		local wy = rng:NextNumber() > 0.4 and y + rng:NextNumber(0.8, 3) or y + h - rng:NextNumber(0.8, 2.5)
		local color = rng:NextNumber() > 0.5 and C.mold or C.moldDark
		local along = (side <= 2) and rz() or rx()
		for k = 1, rng:NextInteger(4, 7) do
			local d = rng:NextNumber(0.6, 2.2)
			local da, dy = rng:NextNumber(-1.8, 1.8), rng:NextNumber(-1.2, 1.2)
			local t = rng:NextNumber(0.35, 0.65)
			local inset = 0.03 + k * 0.004 -- чтобы круги не мерцали друг в друге
			if side == 1 then
				disk(parent, CFrame.new(ix1 + inset, wy + dy, along + da), d, color, M.slate, t)
			elseif side == 2 then
				disk(parent, CFrame.new(ix2 - inset, wy + dy, along + da), d, color, M.slate, t)
			elseif side == 3 then
				disk(parent, CFrame.new(along + da, wy + dy, iz1 + inset) * CFrame.Angles(0, math.pi / 2, 0), d, color, M.slate, t)
			else
				disk(parent, CFrame.new(along + da, wy + dy, iz2 - inset) * CFrame.Angles(0, math.pi / 2, 0), d, color, M.slate, t)
			end
		end
	end

	-- пятно протечки на потолке
	local px, pz = rx(), rz()
	for _ = 1, 4 do
		disk(parent, CFrame.new(px + rng:NextNumber(-1.5, 1.5), y + h - 0.04, pz + rng:NextNumber(-1.5, 1.5)) * flat, rng:NextNumber(1, 3), C.stain, M.slate, rng:NextNumber(0.4, 0.65))
	end

	-- паутина в углу
	local cx = rng:NextNumber() > 0.5 and ix1 + 0.8 or ix2 - 0.8
	local cz = rng:NextNumber() > 0.5 and iz1 + 0.8 or iz2 - 0.8
	newPart(parent, Vector3.new(2.4, 0.05, 2.4), CFrame.new(cx, y + h - 0.9, cz) * CFrame.Angles(0.5, math.pi / 4, 0.3), Color3.fromRGB(170, 170, 165), M.fabric, {
		CanCollide = false,
		CanQuery = false,
		Transparency = 0.75,
		CastShadow = false,
	})
end

---------------------------------------------------------------------
-- Свет
---------------------------------------------------------------------

local function addLight(parent: Instance, brightness: number, range: number, color: Color3)
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = range
	light.Color = color
	light.Shadows = true
	light.Parent = parent
end

-- Лампа на проводе; on = false — разбитая и тёмная
local function hangingLamp(parent: Instance, x: number, ceilY: number, z: number, drop: number, on: boolean, brightness: number?, range: number?)
	local bulbY = ceilY - drop
	box(parent, x - 0.06, bulbY + 0.5, z - 0.06, x + 0.06, ceilY, z + 0.06, Color3.fromRGB(20, 20, 20), M.smooth, { CanCollide = false })
	cylinder(parent, CFrame.new(x, bulbY + 0.35, z), 0.5, 1.9, Color3.fromRGB(30, 30, 28), M.metal, { CanCollide = false })
	local bulb = newPart(parent, Vector3.new(0.7, 0.7, 0.7), CFrame.new(x, bulbY, z), on and C.warm or Color3.fromRGB(60, 58, 50), on and M.neon or M.glass, { CanCollide = false, Shape = Enum.PartType.Ball, Name = "Bulb" })
	if on then
		addLight(bulb, brightness or 1.2, range or 18, C.warm)
	end
end

local function tableLamp(parent: Instance, o: CFrame, on: boolean)
	piece(parent, o, Vector3.new(0, 0.1, 0), Vector3.new(0.8, 0.2, 0.8), C.furnDark, M.metal)
	piece(parent, o, Vector3.new(0, 0.7, 0), Vector3.new(0.15, 1.2, 0.15), C.furnDark, M.metal)
	local shade = cylinder(parent, o * CFrame.new(0, 1.5, 0), 0.9, 1.3, Color3.fromRGB(190, 160, 110), M.fabric, { CanCollide = false })
	if on then
		addLight(shade, 0.8, 11, C.warm)
	end
end

---------------------------------------------------------------------
-- Мебель (лицевая сторона смотрит в -Z мебели)
---------------------------------------------------------------------

local function makeTable(parent: Instance, o: CFrame, w: number, d: number, h: number)
	piece(parent, o, Vector3.new(0, h - 0.2, 0), Vector3.new(w, 0.4, d), C.furn, M.wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			piece(parent, o, Vector3.new(sx * (w / 2 - 0.35), (h - 0.4) / 2, sz * (d / 2 - 0.35)), Vector3.new(0.35, h - 0.4, 0.35), C.furnDark, M.wood)
		end
	end
end

local function chair(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 2.1, 0), Vector3.new(2, 0.3, 2), C.furn, M.wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			piece(parent, o, Vector3.new(sx * 0.8, 1, sz * 0.8), Vector3.new(0.25, 2, 0.25), C.furnDark, M.wood)
		end
	end
	piece(parent, o, Vector3.new(0, 3.5, 0.9), Vector3.new(2, 2.5, 0.25), C.furn, M.wood)
end

local function bed(parent: Instance, o: CFrame, w: number, l: number, blanket: Color3)
	piece(parent, o, Vector3.new(0, 0.7, 0), Vector3.new(w, 1, l), C.furnDark, M.wood)
	piece(parent, o, Vector3.new(0, 1.6, 0), Vector3.new(w - 0.4, 0.8, l - 0.4), C.cloth, M.fabric)
	piece(parent, o, Vector3.new(0, 2.25, l / 2 - 1.2), Vector3.new(w * 0.6, 0.5, 1.4), Color3.fromRGB(160, 150, 128), M.fabric)
	newPart(parent, Vector3.new(w - 0.1, 0.3, l * 0.55), o * CFrame.new(0.3, 2.15, -l / 5) * CFrame.Angles(0, math.rad(4), 0), blanket, M.fabric)
	piece(parent, o, Vector3.new(0, 2.2, l / 2), Vector3.new(w + 0.2, 4.4, 0.4), C.furn, M.wood)
	piece(parent, o, Vector3.new(0, 1.3, -l / 2), Vector3.new(w + 0.2, 2.6, 0.4), C.furn, M.wood)
end

local function wardrobe(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 4.5, 0), Vector3.new(5, 9, 2.4), C.furnDark, M.wood)
	piece(parent, o, Vector3.new(0, 9.15, 0), Vector3.new(5.4, 0.3, 2.7), C.furn, M.wood)
	piece(parent, o, Vector3.new(0, 4.6, -1.22), Vector3.new(0.08, 8, 0.05), Color3.fromRGB(15, 12, 10), M.smooth)
	piece(parent, o, Vector3.new(-0.4, 4.6, -1.3), Vector3.new(0.2, 0.8, 0.15), C.furn, M.metal)
	piece(parent, o, Vector3.new(0.4, 4.6, -1.3), Vector3.new(0.2, 0.8, 0.15), C.furn, M.metal)
	-- оторванная дверца стоит рядом
	newPart(parent, Vector3.new(2.4, 8, 0.25), o * CFrame.new(3.4, 4, -0.6) * CFrame.Angles(math.rad(6), math.rad(20), 0), C.furnDark, M.wood, { CanCollide = false })
end

local function nightstand(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 1.2, 0), Vector3.new(2, 2.4, 2), C.furn, M.wood)
	piece(parent, o, Vector3.new(0, 1.6, -1.02), Vector3.new(1.6, 0.06, 0.05), C.furnDark, M.smooth)
end

local function shelf(parent: Instance, o: CFrame, w: number, h: number, d: number, levels: number)
	piece(parent, o, Vector3.new(-w / 2, h / 2, 0), Vector3.new(0.3, h, d), C.furnDark, M.wood)
	piece(parent, o, Vector3.new(w / 2, h / 2, 0), Vector3.new(0.3, h, d), C.furnDark, M.wood)
	piece(parent, o, Vector3.new(0, h / 2, d / 2), Vector3.new(w, h, 0.2), C.furnDark, M.wood)
	for k = 0, levels do
		local y = h * k / levels
		piece(parent, o, Vector3.new(0, y + 0.12, 0), Vector3.new(w, 0.25, d), C.furn, M.wood)
		if k < levels then
			-- банки, книги, коробки
			local x = -w / 2 + 0.6
			while x < w / 2 - 0.6 do
				local kind = rng:NextInteger(1, 4)
				if kind == 1 then
					local hh = rng:NextNumber(0.8, 1.4)
					cylinder(parent, o * CFrame.new(x, y + 0.25 + hh / 2, 0), hh, 0.7, Color3.fromRGB(rng:NextInteger(50, 110), rng:NextInteger(60, 100), rng:NextInteger(30, 60)), M.glass, { Transparency = 0.25, CanCollide = false })
					x += 0.9
				elseif kind == 2 then
					local bh = rng:NextNumber(1.1, 1.7)
					piece(parent, o, Vector3.new(x, y + 0.25 + bh / 2, 0), Vector3.new(0.35, bh, d * 0.8), Color3.fromRGB(rng:NextInteger(40, 100), rng:NextInteger(25, 60), rng:NextInteger(20, 50)), M.smooth, { CanCollide = false })
					x += 0.4
				elseif kind == 3 then
					piece(parent, o, Vector3.new(x + 0.4, y + 0.7, 0), Vector3.new(1.2, 0.9, d * 0.7), Color3.fromRGB(120, 96, 66), M.fabric, { CanCollide = false })
					x += 1.4
				else
					x += 0.8 -- пустое место
				end
			end
		end
	end
end

local function sofa(parent: Instance, o: CFrame, w: number)
	piece(parent, o, Vector3.new(0, 0.8, 0), Vector3.new(w, 1.6, 3), C.fabric, M.fabric)
	piece(parent, o, Vector3.new(0, 2.5, 1.1), Vector3.new(w, 2.6, 0.8), C.fabric, M.fabric)
	piece(parent, o, Vector3.new(-w / 2 + 0.4, 1.8, 0), Vector3.new(0.8, 2, 3), C.fabric, M.fabric)
	piece(parent, o, Vector3.new(w / 2 - 0.4, 1.8, 0), Vector3.new(0.8, 2, 3), C.fabric, M.fabric)
	-- одна подушка порвана и валяется на полу
	piece(parent, o, Vector3.new(-w / 4, 1.8, -0.2), Vector3.new(w / 2 - 1, 0.5, 2.3), Color3.fromRGB(84, 46, 38), M.fabric)
	newPart(parent, Vector3.new(w / 2 - 1, 0.5, 2.3), o * CFrame.new(w / 4 + 0.5, 0.25, -2.6) * CFrame.Angles(0, math.rad(25), 0), Color3.fromRGB(84, 46, 38), M.fabric, { CanCollide = false })
end

local function counter(parent: Instance, o: CFrame, len: number)
	piece(parent, o, Vector3.new(0, 1.6, 0), Vector3.new(len, 3.2, 2.5), C.furnDark, M.wood)
	piece(parent, o, Vector3.new(0, 3.35, 0), Vector3.new(len + 0.2, 0.3, 2.7), Color3.fromRGB(70, 70, 66), M.slate)
	piece(parent, o, Vector3.new(0, 7.6, 0.55), Vector3.new(len, 2.6, 1.4), C.furnDark, M.wood)
	-- висящая на одной петле дверца шкафчика
	piece(parent, o, Vector3.new(len / 2 - 1, 6.9, -0.4), Vector3.new(1.8, 2.4, 0.15), C.furn, M.wood, { CanCollide = false })
end

local function stove(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 1.7, 0), Vector3.new(3, 3.4, 2.6), Color3.fromRGB(140, 134, 122), M.metal)
	piece(parent, o, Vector3.new(0, 1.5, -1.32), Vector3.new(2.4, 1.8, 0.06), Color3.fromRGB(25, 22, 20), M.smooth)
	for _, sx in { -0.7, 0.7 } do
		for _, sz in { -0.6, 0.6 } do
			cylinder(parent, o * CFrame.new(sx, 3.45, sz), 0.1, 0.9, Color3.fromRGB(20, 20, 20), M.metal)
		end
	end
end

local function fridge(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 3.5, 0), Vector3.new(3.4, 7, 3), Color3.fromRGB(168, 160, 136), M.smooth)
	piece(parent, o, Vector3.new(-1.3, 4.5, -1.6), Vector3.new(0.2, 2, 0.2), Color3.fromRGB(90, 90, 90), M.metal)
	piece(parent, o, Vector3.new(0, 4.9, -1.51), Vector3.new(3.4, 0.06, 0.05), Color3.fromRGB(60, 58, 50), M.smooth)
	-- ржавые потёки
	piece(parent, o, Vector3.new(0.6, 1.2, -1.51), Vector3.new(0.5, 2.2, 0.03), Color3.fromRGB(110, 70, 40), M.rust, { CanCollide = false })
end

local function fireplace(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 3.5, 0), Vector3.new(8, 7, 2), Color3.fromRGB(86, 66, 56), M.brick)
	piece(parent, o, Vector3.new(0, 1.9, -0.9), Vector3.new(4, 3.4, 0.3), Color3.fromRGB(10, 8, 8), M.smooth)
	piece(parent, o, Vector3.new(0, 5.6, -0.3), Vector3.new(9, 0.5, 2.6), C.furn, M.wood)
	piece(parent, o, Vector3.new(0, 9, 0.4), Vector3.new(3, 4, 1.2), Color3.fromRGB(80, 62, 52), M.brick)
	-- зола и тлеющие угли (единственный свет в гостиной)
	piece(parent, o, Vector3.new(0, 0.2, -1.3), Vector3.new(3.4, 0.4, 1.2), Color3.fromRGB(30, 28, 26), M.slate, { CanCollide = false })
	local ember = piece(parent, o, Vector3.new(0, 0.45, -0.7), Vector3.new(2.4, 0.3, 0.8), Color3.fromRGB(255, 90, 30), M.neon, { CanCollide = false, Name = "Embers" })
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 110, 50)
	glow.Brightness = 1.2
	glow.Range = 16
	glow.Shadows = true
	glow.Parent = ember
end

local function bathtub(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 1.4, 0), Vector3.new(7, 2.4, 3.2), Color3.fromRGB(160, 154, 138), M.smooth)
	-- мутная вода
	piece(parent, o, Vector3.new(0, 2.5, 0), Vector3.new(6.2, 0.2, 2.4), Color3.fromRGB(38, 46, 30), M.glass, { Transparency = 0.15, CanCollide = false })
	for _, sx in { -3, 3 } do
		for _, sz in { -1.2, 1.2 } do
			piece(parent, o, Vector3.new(sx, 0.1, sz), Vector3.new(0.4, 0.2, 0.4), C.rust, M.rust)
		end
	end
end

local function toilet(parent: Instance, o: CFrame)
	cylinder(parent, o * CFrame.new(0, 0.7, 0), 1.4, 1.3, Color3.fromRGB(160, 154, 138), M.smooth)
	piece(parent, o, Vector3.new(0, 1.55, -0.2), Vector3.new(1.6, 0.4, 2.2), Color3.fromRGB(150, 144, 128), M.smooth)
	piece(parent, o, Vector3.new(0, 2.4, 1.1), Vector3.new(2, 2, 0.8), Color3.fromRGB(150, 144, 128), M.smooth)
end

local function sink(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 1.4, 0.3), Vector3.new(0.8, 2.8, 0.8), Color3.fromRGB(150, 144, 128), M.smooth)
	piece(parent, o, Vector3.new(0, 3, 0), Vector3.new(2.6, 0.6, 2), Color3.fromRGB(160, 154, 138), M.smooth)
	-- треснувшее зеркало
	piece(parent, o, Vector3.new(0, 5.5, 0.95), Vector3.new(2.2, 2.6, 0.1), Color3.fromRGB(70, 78, 80), M.glass, { Reflectance = 0.25, CanCollide = false })
end

local function desk(parent: Instance, o: CFrame)
	makeTable(parent, o, 6, 3, 3.2)
	piece(parent, o, Vector3.new(1.9, 1.5, 0), Vector3.new(2, 2.6, 2.6), C.furnDark, M.wood)
	-- пишущая машинка
	piece(parent, o, Vector3.new(-1, 3.5, 0.2), Vector3.new(1.8, 0.6, 1.4), Color3.fromRGB(30, 32, 30), M.metal)
	-- кипы бумаг
	for i = 1, 3 do
		piece(parent, o, Vector3.new(1.5 + rng:NextNumber(-0.3, 0.3), 3.05 + i * 0.12, rng:NextNumber(-0.6, 0.6)), Vector3.new(1, 0.1, 1.35), C.paper, M.smooth, { CanCollide = false })
	end
end

local function crate(parent: Instance, o: CFrame, size: number)
	piece(parent, o, Vector3.new(0, size / 2, 0), Vector3.new(size, size, size), Color3.fromRGB(100, 80, 58), M.planks)
end

local function cardboard(parent: Instance, o: CFrame)
	local s = rng:NextNumber(1.4, 2.4)
	piece(parent, o, Vector3.new(0, s / 2, 0), Vector3.new(s * 1.2, s, s), Color3.fromRGB(122, 98, 68), M.fabric)
end

---------------------------------------------------------------------
-- Улица
---------------------------------------------------------------------

local function deadTree(parent: Instance, x: number, z: number)
	local h = rng:NextNumber(14, 22)
	local d = rng:NextNumber(1.2, 2)
	cylinder(parent, CFrame.new(x, h / 2, z), h, d, C.bark, M.wood)
	for _ = 1, rng:NextInteger(3, 5) do
		local by = rng:NextNumber(h * 0.5, h * 0.9)
		local len = rng:NextNumber(4, 8)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local cf = CFrame.new(x, by, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(30, 60))) * CFrame.new(len / 2, 0, 0)
		local p = newPart(parent, Vector3.new(len, d * 0.35, d * 0.35), cf, C.bark, M.wood)
		p.Shape = Enum.PartType.Cylinder
	end
end

local function pine(parent: Instance, x: number, z: number)
	local h = rng:NextNumber(20, 32)
	cylinder(parent, CFrame.new(x, h * 0.2, z), h * 0.4, 1.6, C.bark, M.wood)
	local tiers = 4
	for i = 0, tiers - 1 do
		local t = i / tiers
		local width = (1 - t) * rng:NextNumber(10, 13) + 2
		cylinder(parent, CFrame.new(x, h * (0.3 + t * 0.62), z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), h * 0.2, width, C.pine, M.grass)
	end
end

-- Деревянный забор; часть досок выбита или покосилась
local function fence(parent: Instance, from: Vector3, to: Vector3, gapFrom: number?, gapTo: number?)
	local dir = (to - from).Unit
	local length = (to - from).Magnitude
	local d = 0
	while d <= length do
		local inGap = gapFrom and gapTo and d >= gapFrom and d <= gapTo
		local roll = rng:NextNumber()
		if not inGap and roll > 0.1 then
			local pos = from + dir * d
			local h = rng:NextNumber(3.4, 4.2)
			local tilt = roll > 0.85 and rng:NextNumber(-0.5, 0.5) or rng:NextNumber(-0.05, 0.05)
			local cf = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, h / 2, 0)
			newPart(parent, Vector3.new(0.9, h, 0.25), cf, Color3.fromRGB(110, 104, 92), M.wood)
		end
		d += 1.3
	end
	-- две поперечины
	for _, y in { 1.2, 2.9 } do
		local mid = (from + to) / 2 + Vector3.new(0, y, 0)
		if not gapFrom then
			newPart(parent, Vector3.new(0.3, 0.4, length), CFrame.lookAt(mid, to + Vector3.new(0, y, 0)) * CFrame.new(0, 0, 0), Color3.fromRGB(90, 84, 74), M.wood)
		end
	end
end

---------------------------------------------------------------------
-- Сборка карты
---------------------------------------------------------------------

local function buildExterior(map: Folder)
	local ext = folder(map, "Exterior")
	local trees = folder(ext, "Trees")

	-- Земля (вокруг дома, под домом — пол и подвал)
	local function ground(x1: number, z1: number, x2: number, z2: number)
		box(ext, x1, -1, z1, x2, 0, z2, C.grass, M.grass)
	end
	ground(-170, -170, 170, -24)
	ground(-170, 24, 170, 170)
	ground(-170, -24, -36, 24)
	ground(36, -24, 170, 24)

	-- Пятна грязи на траве
	for _ = 1, 30 do
		local x, z = rng:NextNumber(-60, 60), rng:NextNumber(-60, 60)
		if math.abs(x) > 40 or math.abs(z) > 38 then
			disk(ext, CFrame.new(x, 0.03, z) * CFrame.Angles(0, 0, math.pi / 2), rng:NextNumber(4, 10), C.dirt, M.mud, 0)
		end
	end

	-- Дорога и лобби
	box(ext, -170, 0, -88, 170, 0.06, -74, Color3.fromRGB(36, 36, 36), M.asphalt)
	local lobby = Instance.new("SpawnLocation")
	lobby.Name = "LobbySpawn"
	lobby.Anchored = true
	lobby.Neutral = true
	lobby.Size = Vector3.new(8, 0.4, 8)
	lobby.CFrame = CFrame.new(0, 0.26, -81)
	lobby.Color = Color3.fromRGB(40, 40, 40)
	lobby.Material = M.asphalt
	lobby.Duration = 0
	lobby.Parent = workspace

	-- Дорожка к крыльцу (часть камней пропала)
	for z = -72, -38, 2.2 do
		if rng:NextNumber() > 0.15 then
			box(ext, -2 + rng:NextNumber(-0.3, 0.3), 0, z, 2 + rng:NextNumber(-0.3, 0.3), 0.15, z + 1.8, C.stone, M.stone)
		end
	end

	-- Забор с воротами
	local fences = folder(ext, "Fence")
	fence(fences, Vector3.new(-60, 0, -62), Vector3.new(-4, 0, -62))
	fence(fences, Vector3.new(4, 0, -62), Vector3.new(60, 0, -62))
	fence(fences, Vector3.new(60, 0, -62), Vector3.new(60, 0, 60))
	fence(fences, Vector3.new(60, 0, 60), Vector3.new(-60, 0, 60))
	fence(fences, Vector3.new(-60, 0, 60), Vector3.new(-60, 0, -62))
	-- столбы ворот и упавшая створка
	box(fences, -4.6, 0, -62.6, -3.4, 6, -61.4, C.trim, M.wood)
	box(fences, 3.4, 0, -62.6, 4.6, 6, -61.4, C.trim, M.wood)
	newPart(fences, Vector3.new(3.6, 0.3, 4), CFrame.new(6, 0.2, -65) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(100, 94, 84), M.wood, { CanCollide = false })

	-- Почтовый ящик
	box(ext, 7.8, 0, -63.8, 8.2, 3.6, -63.4, C.trim, M.wood)
	box(ext, 7.3, 3.6, -64.3, 8.7, 4.6, -62.6, Color3.fromRGB(80, 50, 40), M.rust)

	-- Деревья: мёртвые во дворе, ёлки вокруг
	for _, pos in { { -45, -40 }, { 44, -46 }, { -40, 40 }, { 30, 45 }, { -52, 0 }, { 50, -10 } } do
		deadTree(trees, pos[1], pos[2])
	end
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(70, 140)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		if z > -70 or math.abs(x) > 20 then -- не ставим на дорогу перед воротами
			if not (z < -72 and z > -90) then
				pine(trees, x, z)
			end
		end
	end

	-- Невидимые стены по краю карты
	for _, b in { { -150, -150, 150, -149 }, { -150, 149, 150, 150 }, { -150, -150, -149, 150 }, { 149, -150, 150, 150 } } do
		box(ext, b[1], 0, b[2], b[3], 60, b[4], C.grass, M.smooth, { Transparency = 1, Name = "Boundary" })
	end

	-- Точка старта выживших — у ворот
	newPart(workspace, Vector3.new(6, 1, 6), CFrame.new(0, 0.5, -68), C.stone, M.smooth, {
		Name = "SurvivorSpawn",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
end

local function buildHouse(map: Folder, hideouts: Folder, fuses: Folder, notes: Folder)
	local house = folder(map, "House")
	local shell = folder(house, "Shell")
	local f1 = folder(house, "GroundFloor")
	local f2 = folder(house, "SecondFloor")

	-- Фундамент (кольцом, чтобы не перекрыть подвал) и пояса между этажами
	for _, y in { { 0, G, C.stone, M.stone }, { S - 1, S, C.trim, M.wood }, { TOP, TOP + 1, C.trim, M.wood } } do
		local y1, y2, color, material = y[1], y[2], y[3], y[4]
		box(shell, -36.5, y1, -24.5, 36.5, y2, -23.5, color, material)
		box(shell, -36.5, y1, 23.5, 36.5, y2, 24.5, color, material)
		box(shell, -36.5, y1, -23.5, -35.5, y2, 23.5, color, material)
		box(shell, 35.5, y1, -23.5, 36.5, y2, 23.5, color, material)
	end

	-- Пол 1 этажа (с дырой над лестницей в подвал)
	box(shell, -36, G - 1, -24, 36, G, 18, C.floor, M.planks)
	box(shell, -36, G - 1, 23, 36, G, 24, C.floor, M.planks)
	box(shell, -36, G - 1, 18, -33, G, 23, C.floor, M.planks)
	box(shell, -15, G - 1, 18, 36, G, 23, C.floor, M.planks)

	-- Пол 2 этажа (дыра над холлом x -8..8, z -24..8)
	box(shell, -36, S - 1, -24, -8, S, 8, C.floor, M.planks)
	box(shell, 8, S - 1, -24, 36, S, 8, C.floor, M.planks)
	box(shell, -36, S - 1, 8, 36, S, 24, C.floor, M.planks)
	-- сгнившие доски на галерее (тёмные, чуть просевшие)
	box(shell, -11, S - 0.05, -14, -9, S + 0.02, -9, Color3.fromRGB(34, 26, 20), M.wood, { CanCollide = false })

	-- Потолок 2 этажа
	box(shell, -36, TOP, -24, 36, TOP + 1, 24, C.plasterDark, M.plaster)

	local h1 = S - 1 - G -- высота стен 1 этажа
	local h2 = TOP - S -- высота стен 2 этажа

	-- Наружные стены 1 этажа
	wall(shell, "x", -24, -36.5, 36.5, G, h1, {
		{ -28, -24, 3.5, 8.5, "boarded" },
		{ -20, -16, 3.5, 8.5, "broken" },
		{ -2, 2, 0, 8, "door" },
		{ -8, -5, 3.5, 9, "glass" },
		{ 5, 8, 3.5, 9, "boarded" },
		{ 18, 22, 3.5, 8.5, "boarded" },
		{ 26, 30, 3.5, 8.5, "glass" },
	}, C.extWood, M.planks, -1)
	wall(shell, "x", 24, -36.5, 36.5, G, h1, {
		{ -28, -24, 3.5, 8.5, "boarded" },
		{ -3, 1, 0, 8, "door" },
		{ 22, 26, 3.5, 8.5, "broken" },
	}, C.extWood, M.planks, 1)
	wall(shell, "z", -36, -23.5, 23.5, G, h1, {
		{ -16, -12, 3.5, 8.5, "glass" },
		{ 12, 16, 3.5, 8.5, "boarded" },
	}, C.extWood, M.planks, -1)
	wall(shell, "z", 36, -23.5, 23.5, G, h1, {
		{ -18, -14, 3.5, 8.5, "boarded" },
		{ 12, 16, 3.5, 8.5, "broken" },
	}, C.extWood, M.planks, 1)

	-- Наружные стены 2 этажа
	wall(shell, "x", -24, -36.5, 36.5, S, h2, {
		{ -28, -24, 3.5, 8.5, "boarded" },
		{ -6, -2, 3.5, 9, "broken" },
		{ 2, 6, 3.5, 9, "glass" },
		{ 22, 26, 3.5, 8.5, "glass" },
	}, C.extWood, M.planks, -1)
	wall(shell, "x", 24, -36.5, 36.5, S, h2, {
		{ -28, -24, 3.5, 8.5, "boarded" },
		{ -3, 1, 3.5, 8.5, "glass" },
		{ 26, 29, 4, 8, "boarded" },
	}, C.extWood, M.planks, 1)
	wall(shell, "z", -36, -23.5, 23.5, S, h2, {
		{ -14, -10, 3.5, 8.5, "broken" },
	}, C.extWood, M.planks, -1)
	wall(shell, "z", 36, -23.5, 23.5, S, h2, {
		{ -16, -12, 3.5, 8.5, "glass" },
		{ 14, 17, 4, 8, "boarded" },
	}, C.extWood, M.planks, 1)

	-- Внутренние стены 1 этажа
	wall(f1, "z", -12, -23.5, 23.5, G, h1, { { -6, -2, 0, 8, "door" }, { 15, 19, 0, 8, "door" } }, C.plaster, M.plaster)
	wall(f1, "x", 6, -35.5, -12.5, G, h1, { { -20, -16, 0, 8, "door" } }, C.plaster, M.plaster)
	wall(f1, "z", 12, -23.5, 23.5, G, h1, { { -8, -3, 0, 8, "door" }, { 16, 20, 0, 8, "door" } }, C.plaster, M.plaster)
	wall(f1, "x", 12, -11.5, 11.5, G, h1, { { -5, 5, 0, 10 } }, C.plaster, M.plaster)

	-- Внутренние стены 2 этажа
	wall(f2, "z", -12, -23.5, 23.5, S, h2, { { -12, -8, 0, 8, "door" }, { 14, 18, 0, 8, "door" } }, C.plaster, M.plaster)
	wall(f2, "x", 6, -35.5, -12.5, S, h2, nil, C.plaster, M.plaster)
	wall(f2, "z", 12, -23.5, 23.5, S, h2, { { -12, -8, 0, 8, "door" }, { 14, 18, 0, 8, "door" } }, C.plaster, M.plaster)
	wall(f2, "x", 6, 12.5, 35.5, S, h2, nil, C.plaster, M.plaster)

	-- Приоткрытые двери
	openDoor(shell, Vector3.new(-2, G, -24), math.rad(-70), "x")
	openDoor(f1, Vector3.new(-12, G, 15), math.rad(50), "z")
	openDoor(f2, Vector3.new(12, S, -12), math.rad(-60), "z")
	openDoor(f2, Vector3.new(-12, S, 14), math.rad(70), "z")

	-------------------------------------------------------------------
	-- Крыша
	-------------------------------------------------------------------
	local roof = folder(house, "Roof")
	local ridge = TOP + 1 + 11
	ramp(roof, Vector3.new(0, TOP + 1 - 2 * 11 / 24, -26), Vector3.new(0, ridge, 0), 76)
	ramp(roof, Vector3.new(0, TOP + 1 - 2 * 11 / 24, 26), Vector3.new(0, ridge, 0), 76)
	for _, p in roof:GetChildren() do
		if p:IsA("BasePart") then
			p.Transparency = 0
			p.Color = C.roof
			p.Material = M.roof
			p.Name = "RoofSide"
		end
	end
	-- фронтоны ступеньками из досок
	for i = 0, 10 do
		local halfW = 24 * (1 - (i + 0.5) / 11)
		for _, x in { -36, 36 } do
			box(roof, x - 0.5, TOP + 1 + i, -halfW, x + 0.5, TOP + 2 + i, halfW, C.extWood, M.planks)
		end
	end
	-- дыра в крыше
	box(roof, 14, ridge - 3, -6, 20, ridge - 2.4, -3, Color3.fromRGB(10, 10, 10), M.smooth, { CanCollide = false })
	-- труба
	box(roof, 31, TOP + 1, -2, 35, ridge + 4, 2, Color3.fromRGB(80, 62, 52), M.brick)

	-------------------------------------------------------------------
	-- Крыльцо
	-------------------------------------------------------------------
	local porch = folder(house, "Porch")
	box(porch, -14, G - 1, -34, 14, G, -24.5, C.floor, M.planks)
	box(porch, -14, 0, -34, 14, G - 1, -33.6, C.trim, M.planks)
	box(porch, -4, 0, -36, 4, 1, -34, C.floor, M.planks)
	for _, x in { -13.5, -5, 5, 13.5 } do
		box(porch, x - 0.4, G, -33.9, x + 0.4, 13, -33.1, C.trim, M.wood)
	end
	newPart(porch, Vector3.new(30, 0.6, 12), CFrame.new(0, 13.4, -29.5) * CFrame.Angles(math.rad(-6), 0, 0), C.roof, M.roof)
	railing(porch, Vector3.new(-13.5, G, -33.5), Vector3.new(-5, G, -33.5), 3)
	railing(porch, Vector3.new(5, G, -33.5), Vector3.new(13.5, G, -33.5), 3)
	-- сломанная доска перил висит
	newPart(porch, Vector3.new(0.35, 0.3, 6), CFrame.new(9, G + 1.8, -33.5) * CFrame.Angles(0.5, math.pi / 2, 0), C.trim, M.wood, { CanCollide = false })
	hangingLamp(porch, 0, 13, -29, 2, true, 1.1, 16)
	-- старое кресло-качалка
	chair(porch, at(-9, G, -28, Vector3.new(0.4, 0, -1)))

	-------------------------------------------------------------------
	-- Холл (x -12..12, z -24..12), высота в два этажа
	-------------------------------------------------------------------
	local hall = folder(f1, "Hall")
	-- лестница: от z = -10 (1 этаж) до z = 8 (2 этаж), x 2..7.5
	local steps = S - G
	local run = 18 / steps
	for i = 1, steps do
		local z1 = -10 + (i - 1) * run
		box(hall, 2, G + i - 1, z1, 7.5, G + i, z1 + run + 0.2, C.floor, M.planks, { CanCollide = false })
	end
	ramp(hall, Vector3.new(4.75, G, -10), Vector3.new(4.75, S, 8), 5.5)
	railing(hall, Vector3.new(1.8, G + 1, -10), Vector3.new(1.8, S, 8), 3)
	railing(hall, Vector3.new(7.7, G + 1, -10), Vector3.new(7.7, S, 8), 3)
	-- перила галерей
	railing(hall, Vector3.new(-8, S, -23.5), Vector3.new(-8, S, 8), 3)
	railing(hall, Vector3.new(8, S, -23.5), Vector3.new(8, S, 8), 3)
	railing(hall, Vector3.new(-8, S, 8), Vector3.new(2, S, 8), 3)
	hangingLamp(hall, 0, TOP, -8, 6, true, 1.3, 26)
	makeTable(hall, at(-10, G, -14, Vector3.new(1, 0, 0)), 3, 2, 3)
	cardboard(hall, at(-9, G, -21))
	cardboard(hall, at(-6.5, G, -21.5))
	crate(hall, at(9.5, G, -21), 2.5)
	decay(hall, -12, -24, 12, 12, G, TOP - G, 6)

	-- Задний коридор (x -12..12, z 12..24)
	local back = folder(f1, "BackCorridor")
	cardboard(back, at(-9, G, 22))
	cardboard(back, at(9, G, 14))
	box(back, 9.5, G, 21.5, 10, G + 6, 22, C.trim, M.wood) -- вешалка
	decay(back, -12, 12, 12, 24, G, S - 1 - G, 3)

	-------------------------------------------------------------------
	-- Кухня (x -36..-12, z -24..6)
	-------------------------------------------------------------------
	local kitchen = folder(f1, "Kitchen")
	counter(kitchen, at(-34.25, G, -15, Vector3.new(1, 0, 0)), 14)
	stove(kitchen, at(-34.2, G, -5.5, Vector3.new(1, 0, 0)))
	fridge(kitchen, at(-34, G, 3.2, Vector3.new(1, 0, 0)))
	makeTable(kitchen, at(-24, G, -12), 6, 4, 3.2)
	chair(kitchen, at(-24, G, -15.2, Vector3.new(0, 0, 1)))
	chair(kitchen, at(-24, G, -8.8, Vector3.new(0, 0, -1)))
	chair(kitchen, at(-20, G, -12, Vector3.new(-1, 0, 0)))
	-- упавший стул
	chair(kitchen, at(-29, G + 1, -11, Vector3.new(1, 0, 0)) * CFrame.Angles(0, 0, math.rad(90)))
	piece(kitchen, at(-24, G, -12), Vector3.new(0, 3.4, 0), Vector3.new(1.4, 0.4, 1.4), Color3.fromRGB(150, 140, 110), M.smooth, { CanCollide = false })
	hangingLamp(kitchen, -24, S - 1, -12, 4, true, 1.1, 18)
	decay(kitchen, -36, -24, -12, 6, G, S - 1 - G, 5)

	-------------------------------------------------------------------
	-- Кладовая (x -36..-12, z 6..24) со спуском в подвал
	-------------------------------------------------------------------
	local pantry = folder(f1, "Pantry")
	shelf(pantry, at(-34.6, G, 11, Vector3.new(1, 0, 0)), 8, 9, 1.6, 4)
	piece(pantry, at(-14.5, G, 8.5, Vector3.new(-1, 0, 0)), Vector3.new(0, 1.9, 0), Vector3.new(3, 3.8, 3), Color3.fromRGB(150, 146, 132), M.smooth)
	railing(pantry, Vector3.new(-33, G, 18), Vector3.new(-15.5, G, 18), 3)
	railing(pantry, Vector3.new(-33, G, 18), Vector3.new(-33, G, 23.4), 3)
	hangingLamp(pantry, -24, S - 1, 12, 3, false)
	decay(pantry, -36, 6, -12, 24, G, S - 1 - G, 4)

	-------------------------------------------------------------------
	-- Гостиная (x 12..36, z -24..24)
	-------------------------------------------------------------------
	local living = folder(f1, "LivingRoom")
	fireplace(living, at(34.9, G, 0, Vector3.new(-1, 0, 0)))
	sofa(living, at(22, G, 0, Vector3.new(1, 0, 0)), 9)
	sofa(living, at(28, G, -10, Vector3.new(0, 0, 1)), 4)
	makeTable(living, at(28, G, 0), 3, 5, 1.8)
	box(living, 23, G, -6, 33, G + 0.06, 6, Color3.fromRGB(70, 34, 30), M.fabric, { CanCollide = false })
	shelf(living, at(30, G, -22.6, Vector3.new(0, 0, 1)), 7, 9, 1.6, 4)
	-- старый телевизор
	piece(living, at(18, G, -21.5, Vector3.new(0.3, 0, 1)), Vector3.new(0, 1.2, 0), Vector3.new(4, 2.4, 2.4), C.furnDark, M.wood)
	piece(living, at(18, G, -21.5, Vector3.new(0.3, 0, 1)), Vector3.new(0, 3.6, 0), Vector3.new(3.4, 2.6, 2.6), Color3.fromRGB(40, 38, 34), M.smooth)
	piece(living, at(18, G, -21.5, Vector3.new(0.3, 0, 1)), Vector3.new(0, 3.6, -1.31), Vector3.new(2.6, 2, 0.05), Color3.fromRGB(20, 24, 24), M.glass)
	hangingLamp(living, 26, S - 1, 0, 3, false) -- лампа разбита
	decay(living, 12, -24, 36, 24, G, S - 1 - G, 7)

	-------------------------------------------------------------------
	-- 2 этаж
	-------------------------------------------------------------------
	-- Коридор и галереи
	local landing = folder(f2, "Landing")
	cardboard(landing, at(-10, S, 22))
	crate(landing, at(10, S, 22), 2)
	hangingLamp(landing, 0, TOP, 16, 3, true, 0.9, 16)
	decay(landing, -12, 8, 12, 24, S, h2, 3)

	-- Спальня Томаса и Марты (x 12..36, z -24..6)
	local bedroom = folder(f2, "Bedroom")
	bed(bedroom, at(31, S, -10, Vector3.new(-1, 0, 0)), 6, 8, Color3.fromRGB(84, 36, 32))
	nightstand(bedroom, at(34.3, S, -15, Vector3.new(-1, 0, 0)))
	nightstand(bedroom, at(34.3, S, -5, Vector3.new(-1, 0, 0)))
	tableLamp(bedroom, at(34.3, S + 2.4, -5), true)
	wardrobe(bedroom, at(24, S, -22.4, Vector3.new(0, 0, 1)))
	box(bedroom, 18, S, -16, 28, S + 0.06, -4, Color3.fromRGB(80, 60, 44), M.fabric, { CanCollide = false })
	decay(bedroom, 12, -24, 36, 6, S, h2, 5)

	-- Детская Лили (x -36..-12, z -24..6)
	local kids = folder(f2, "KidsRoom")
	bed(kids, at(-32, S, -17, Vector3.new(1, 0, 0)), 4, 6, Color3.fromRGB(70, 60, 90))
	piece(kids, at(-20, S, -21.5), Vector3.new(0, 1.2, 0), Vector3.new(4, 2.4, 2.4), Color3.fromRGB(110, 70, 50), M.wood)
	-- кукла без головы
	piece(kids, at(-27, S, -3), Vector3.new(0, 0.6, 0), Vector3.new(0.8, 1.2, 0.5), Color3.fromRGB(150, 110, 110), M.fabric, { CanCollide = false })
	-- рисунки на полу
	for _ = 1, 6 do
		newPart(kids, Vector3.new(1.2, 0.04, 1.6), CFrame.new(rng:NextNumber(-30, -16), S + 0.03, rng:NextNumber(-20, 2)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(200, 196, 180), M.smooth, { CanCollide = false })
	end
	decay(kids, -36, -24, -12, 6, S, h2, 4)

	-- Ванная (x 12..36, z 6..24)
	local bath = folder(f2, "Bathroom")
	box(bath, 12.5, S, 6.5, 35.5, S + 0.06, 23.5, Color3.fromRGB(110, 108, 98), M.tiles, { CanCollide = false })
	bathtub(bath, at(30, S, 21.6, Vector3.new(0, 0, -1)))
	toilet(bath, at(20, S, 22.4, Vector3.new(0, 0, -1)))
	sink(bath, at(34.8, S, 10, Vector3.new(-1, 0, 0)))
	decay(bath, 12, 6, 36, 24, S, h2, 7) -- ванная гниёт сильнее всего
	decay(bath, 12, 6, 36, 24, S, h2, 3)

	-- Кабинет Томаса (x -36..-12, z 6..24)
	local study = folder(f2, "Study")
	desk(study, at(-28, S, 22, Vector3.new(0, 0, -1)))
	chair(study, at(-28, S, 19.3, Vector3.new(0, 0, 1)))
	shelf(study, at(-31, S, 7.4, Vector3.new(0, 0, 1)), 7, 10, 1.6, 5)
	shelf(study, at(-22, S, 7.4, Vector3.new(0, 0, 1)), 7, 10, 1.6, 5)
	tableLamp(study, at(-25.6, S + 3.2, 22.6), false)
	-- стопки бумаг на полу
	for i = 1, 4 do
		piece(study, at(-17, S, 12 + i * 1.6), Vector3.new(0, 0.4 * i * 0.4, 0), Vector3.new(1.2, 0.32 * i, 1.5), C.paper, M.smooth)
	end
	decay(study, -36, 6, -12, 24, S, h2, 5)

	-------------------------------------------------------------------
	-- Тайники для коконов
	-------------------------------------------------------------------
	local function hideout(name: string, x: number, y: number, z: number)
		newPart(hideouts, Vector3.new(4, 1, 4), CFrame.new(x, y + 0.5, z), Color3.fromRGB(255, 0, 0), M.smooth, {
			Name = name,
			Transparency = 1,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})
	end
	hideout("Hideout_Kitchen", -16, G, 2)
	hideout("Hideout_UnderStairs", 4.75, G, 4)
	hideout("Hideout_LivingRoom", 33, G, 20)
	hideout("Hideout_Wardrobe", 24, S, -19.5)
	hideout("Hideout_Bathtub", 30, S + 1.5, 21.6)
	hideout("Hideout_KidsRoom", -16, S, -21)
	hideout("Hideout_Study", -15, S, 22)

	-------------------------------------------------------------------
	-- Предохранители (4 в доме, 5-й в сарае)
	-------------------------------------------------------------------
	local function fuse(name: string, x: number, y: number, z: number)
		local p = cylinder(fuses, CFrame.new(x, y + 0.6, z), 1.2, 0.5, Color3.fromRGB(190, 80, 30), M.metal, { CanCollide = false })
		p.Name = name
	end
	fuse("Fuse_Kitchen", -34.5, G + 3.5, -19)
	fuse("Fuse_LivingRoom", 34.3, G + 5.85, 3)
	fuse("Fuse_Bedroom", 34.3, S + 2.4, -15)
	fuse("Fuse_Study", -30.6, S + 3.2, 21.6)

	-------------------------------------------------------------------
	-- Записки (позже можно показывать текст при нажатии)
	-------------------------------------------------------------------
	local function note(name: string, x: number, y: number, z: number, text: string)
		local p = newPart(notes, Vector3.new(1, 0.05, 1.4), CFrame.new(x, y + 0.03, z) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), Color3.fromRGB(225, 215, 185), M.smooth, { Name = name, CanCollide = false })
		p:SetAttribute("Text", text)
	end
	note("Note_Hall", -2, G, -18, "Кто бы ни читал это — уходите. Свет не включится сам. — Т.Х.")
	note("Note_KidsRoom", -24, S, -8, "Рисунок Лили: «Большая мама живёт внизу. Она добрая, она обещала забрать маму к себе».")
	note("Note_Study", -27, S + 3.25, 21.6, "Дневник Томаса: «Пять предохранителей. Она утащила их в свои норы. Прожекторы готовы — нужен только ток».")
	note("Note_Bathroom", 16, S, 12, "Марта: «В трубах что-то шевелится. Томас не верит».")
end

local function buildBasement(map: Folder, hideouts: Folder, notes: Folder)
	local base = folder(map, "Basement")
	local top = G - 1 -- низ пола 1 этажа
	local h = top - B

	box(base, -36, B - 1, -6, 0, B, 24, C.concrete, M.concrete)
	wall(base, "z", -36, -6.5, 24.5, B, h, nil, C.concrete, M.concrete)
	wall(base, "z", 0, -6.5, 24.5, B, h, nil, C.concrete, M.concrete)
	wall(base, "x", -6, -35.5, -0.5, B, h, nil, C.concrete, M.concrete)
	wall(base, "x", 24, -35.5, -0.5, B, h, nil, C.concrete, M.concrete)
	wall(base, "x", 8, -35.5, -0.5, B, h, { { -10, -5, 0, 8, "door" } }, Color3.fromRGB(80, 74, 66), M.brick)

	-- Лестница из кладовой: от x = -15 (наверху) до x = -33 (внизу)
	local steps = G - B
	local run = 18 / steps
	for i = 1, steps do
		local x2 = -15 - (i - 1) * run
		box(base, x2 - run - 0.2, G - i, 18.2, x2, G - i + 1, 22.8, C.floor, M.planks, { CanCollide = false })
	end
	ramp(base, Vector3.new(-15, G, 20.5), Vector3.new(-33, B, 20.5), 4.6)
	railing(base, Vector3.new(-15, G, 18.1), Vector3.new(-33, B + 1, 18.1), 3)

	-------------------------------------------------------------------
	-- Генераторная (z -6..8)
	-------------------------------------------------------------------
	local gen = folder(base, "GeneratorRoom")
	local o = at(-24, B, 0, Vector3.new(1, 0, 0))
	-- рама генератора
	for _, sx in { -2.4, 2.4 } do
		for _, sz in { -1.6, 1.6 } do
			piece(gen, o, Vector3.new(sx, 2, sz), Vector3.new(0.3, 4, 0.3), Color3.fromRGB(30, 30, 30), M.rust)
		end
	end
	piece(gen, o, Vector3.new(0, 4, 0), Vector3.new(5.1, 0.3, 3.5), Color3.fromRGB(30, 30, 30), M.rust)
	piece(gen, o, Vector3.new(0, 0.4, 0), Vector3.new(5.1, 0.3, 3.5), Color3.fromRGB(30, 30, 30), M.rust)
	piece(gen, o, Vector3.new(0.4, 2, 0), Vector3.new(3.6, 2.6, 2.6), Color3.fromRGB(140, 30, 26), M.metal, { Name = "Generator" })
	piece(gen, o, Vector3.new(-1.6, 1.8, 0), Vector3.new(1.2, 1.8, 2), Color3.fromRGB(25, 25, 25), M.metal)
	piece(gen, o, Vector3.new(0, 3.55, 0), Vector3.new(3, 0.6, 2.4), Color3.fromRGB(150, 34, 28), M.metal)
	-- кабели от генератора к щитку
	box(gen, -35.6, B + 0.05, -0.2, -26, B + 0.25, 0.2, Color3.fromRGB(15, 15, 15), M.smooth, { CanCollide = false })
	box(gen, -35.6, B + 0.05, -0.2, -35.4, B + 4, 0.2, Color3.fromRGB(15, 15, 15), M.smooth, { CanCollide = false })

	-- Щиток для 5 предохранителей
	local fuseBox = Instance.new("Model")
	fuseBox.Name = "FuseBox"
	fuseBox.Parent = base
	local fo = at(-35.2, B + 3.5, 0, Vector3.new(1, 0, 0))
	piece(fuseBox, fo, Vector3.new(0, 1.75, 0), Vector3.new(3, 3.5, 0.6), Color3.fromRGB(90, 92, 88), M.rust, { Name = "Body" })
	for i = 1, 5 do
		local slot = piece(fuseBox, fo, Vector3.new(-1.2 + (i - 1) * 0.6, 1.75, -0.32), Vector3.new(0.35, 1.3, 0.1), Color3.fromRGB(15, 15, 15), M.smooth, { CanCollide = false })
		slot.Name = `Slot{i}`
	end
	-- открытая дверца щитка
	piece(fuseBox, fo, Vector3.new(-2.3, 1.75, -1), Vector3.new(0.1, 3.4, 2), Color3.fromRGB(80, 82, 78), M.rust, { CanCollide = false })

	-- Бойлер, трубы, полки
	cylinder(gen, CFrame.new(-4, B + 3.5, -2.5), 7, 3, Color3.fromRGB(105, 68, 44), M.rust)
	for _, z in { -4, -2.8, 6 } do
		local p = newPart(gen, Vector3.new(35, 0.6, 0.6), CFrame.new(-18, top - 0.8, z), Color3.fromRGB(80, 60, 45), M.rust, { CanCollide = false })
		p.Shape = Enum.PartType.Cylinder
	end
	shelf(gen, at(-14, B, -5.1, Vector3.new(0, 0, 1)), 6, 7, 1.4, 3)
	crate(gen, at(-31, B, 5.5), 2.5)
	crate(gen, at(-31, B, 5.5) * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0.4, 0), 1.6)
	-- лужа
	disk(gen, CFrame.new(-12, B + 0.04, 3) * CFrame.Angles(0, 0, math.pi / 2), 6, Color3.fromRGB(30, 38, 38), M.glass, 0.55)

	-- Лампа дневного света (холодная, мигает в будущем)
	box(gen, -21, top - 0.6, 1.6, -15, top - 0.4, 2.4, Color3.fromRGB(40, 40, 40), M.metal, { CanCollide = false })
	local tube = box(gen, -20.6, top - 0.9, 1.8, -15.4, top - 0.6, 2.2, C.cold, M.neon, { CanCollide = false, Name = "Tube" })
	local light = Instance.new("PointLight")
	light.Color = C.cold
	light.Brightness = 0.9
	light.Range = 20
	light.Shadows = true
	light.Parent = tube

	decay(gen, -36, -6, 0, 8, B, h, 4)

	-- Тут появляется монстр
	newPart(workspace, Vector3.new(4, 1, 4), CFrame.new(-10, B + 0.5, 2), C.concrete, M.smooth, {
		Name = "MonsterSpawn",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	-------------------------------------------------------------------
	-- Гнездо (z 8..24)
	-------------------------------------------------------------------
	local nest = folder(base, "Nest")
	-- наросты на полу, стенах и потолке
	for _ = 1, 26 do
		local x, z = rng:NextNumber(-12, -1.5), rng:NextNumber(13, 23.5)
		local size = Vector3.new(rng:NextNumber(1.5, 4), rng:NextNumber(1, 3), rng:NextNumber(1.5, 4))
		local y = rng:NextNumber() > 0.3 and B + size.Y * 0.3 or top - size.Y * 0.3
		blob(nest, CFrame.new(x, y, z), size, rng:NextNumber() > 0.5 and C.flesh or C.fleshDark, rng:NextNumber() > 0.5 and M.mud or M.slate)
	end
	-- тяжи от пола до потолка
	for _ = 1, 7 do
		local x, z = rng:NextNumber(-11, -2), rng:NextNumber(14, 23)
		cylinder(nest, CFrame.new(x, (B + top) / 2, z) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)), h, rng:NextNumber(0.2, 0.5), C.fleshDark, M.mud, { CanCollide = false })
	end
	-- старые пустые коконы (лопнувшие)
	for i = 1, 3 do
		local cf = CFrame.new(-4 - i * 2.4, B + 1.2, 21.5 - i * 0.6) * CFrame.Angles(math.rad(rng:NextNumber(70, 90)), rng:NextNumber(-0.4, 0.4), 0)
		blob(nest, cf, Vector3.new(2.6, 6, 2.6), Color3.fromRGB(96, 88, 78), M.fabric)
		blob(nest, cf * CFrame.new(0, 0, -1.15), Vector3.new(1.4, 4, 0.6), Color3.fromRGB(14, 10, 10), M.smooth)
	end
	-- тёмная лужа под гнездом
	disk(nest, CFrame.new(-7, B + 0.04, 19) * CFrame.Angles(0, 0, math.pi / 2), 11, Color3.fromRGB(40, 16, 14), M.glass, 0.35)
	-- слабое багровое свечение гнезда
	local core = blob(nest, CFrame.new(-7, B + 1, 20.5), Vector3.new(2.5, 1.6, 2.5), Color3.fromRGB(120, 24, 20), M.neon)
	core.Name = "NestCore"
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(170, 30, 25)
	glow.Brightness = 0.9
	glow.Range = 14
	glow.Parent = core
	cardboard(nest, at(-26, B, 11))
	cardboard(nest, at(-29, B, 10))
	crate(nest, at(-22, B, 12), 3)
	decay(nest, -36, 8, 0, 24, B, h, 4)

	-- Тайники в подвале
	local function hideout(name: string, x: number, y: number, z: number)
		newPart(hideouts, Vector3.new(4, 1, 4), CFrame.new(x, y + 0.5, z), Color3.fromRGB(255, 0, 0), M.smooth, {
			Name = name,
			Transparency = 1,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})
	end
	hideout("Hideout_Nest", -7, B, 17)
	hideout("Hideout_Generator", -30, B, -3)

	local p = newPart(notes, Vector3.new(1, 0.05, 1.4), CFrame.new(-14, B + 0.03, 15), Color3.fromRGB(225, 215, 185), M.smooth, { Name = "Note_Basement", CanCollide = false })
	p:SetAttribute("Text", "Последняя страница дневника: «Она внутри одного из нас. Я слышу, как она шевелится у меня под рёбрами».")
end

local function buildShed(map: Folder, hideouts: Folder, fuses: Folder)
	local shed = folder(map, "Shed")
	local x1, x2, z1, z2 = 44, 56, 8, 20
	box(shed, x1, 0, z1, x2, 0.3, z2, C.floor, M.planks)
	wall(shed, "x", z1, x1 - 0.5, x2 + 0.5, 0.3, 8, { { 49, 51, 3, 5.5, "boarded" } }, C.extWood, M.planks, -1)
	wall(shed, "x", z2, x1 - 0.5, x2 + 0.5, 0.3, 8, nil, C.extWood, M.planks, 1)
	wall(shed, "z", x1, z1 + 0.5, z2 - 0.5, 0.3, 8, { { 12, 16, 0, 7, "door" } }, C.extWood, M.planks, -1)
	wall(shed, "z", x2, z1 + 0.5, z2 - 0.5, 0.3, 8, nil, C.extWood, M.planks, 1)
	newPart(shed, Vector3.new(14, 0.5, 14), CFrame.new(50, 8.6, 14) * CFrame.Angles(0, 0, math.rad(8)), C.roof, M.roof)
	-- верстак
	makeTable(shed, at(54, 0.3, 14, Vector3.new(-1, 0, 0)), 6, 2.6, 3.4)
	shelf(shed, at(50, 0.3, 19.2, Vector3.new(0, 0, -1)), 6, 6, 1.4, 3)
	decay(shed, x1, z1, x2, z2, 0.3, 7.7, 3)

	newPart(hideouts, Vector3.new(4, 1, 4), CFrame.new(47, 0.8, 10.5), Color3.fromRGB(255, 0, 0), M.smooth, {
		Name = "Hideout_Shed",
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
	local p = cylinder(fuses, CFrame.new(54, 0.3 + 3.4 + 0.6, 15.5), 1.2, 0.5, Color3.fromRGB(190, 80, 30), M.metal, { CanCollide = false })
	p.Name = "Fuse_Shed"
end

-- Удаляем старую версию карты
local function clearOld()
	for _, name in { "Map", "Hideouts", "Fuses", "MonsterSpawn", "SurvivorSpawn", "LobbySpawn", "Baseplate" } do
		local old = workspace:FindFirstChild(name)
		while old do
			old:Destroy()
			old = workspace:FindFirstChild(name)
		end
	end
end

function MapBuilder.build(): string
	rng = Random.new(1989) -- каждый раз одна и та же карта

	local recording: string? = nil
	pcall(function()
		recording = ChangeHistoryService:TryBeginRecording("Build THE NEST map")
	end)

	clearOld()

	local map = folder(workspace, "Map")
	local hideouts = folder(workspace, "Hideouts")
	local fuses = folder(workspace, "Fuses")
	local notes = folder(map, "Notes")

	buildExterior(map)
	buildHouse(map, hideouts, fuses, notes)
	buildBasement(map, hideouts, notes)
	buildShed(map, hideouts, fuses)

	if recording then
		pcall(function()
			ChangeHistoryService:FinishRecording(recording :: string, Enum.FinishRecordingOperation.Commit)
		end)
	end

	local count = 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	local result = `THE NEST: карта построена. Деталей: {count}, тайников: {#hideouts:GetChildren()}, предохранителей: {#fuses:GetChildren()}`
	print(result)
	return result
end

return MapBuilder
