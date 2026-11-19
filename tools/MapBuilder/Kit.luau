-- Общие помощники для постройки карты: детали, стены, двери, лестницы, перила.

local CollectionService = game:GetService("CollectionService")

local Kit = {}

-- Высоты этажей (studs)
Kit.G = 2 -- пол 1 этажа
Kit.S = 17 -- пол 2 этажа
Kit.TOP = 31 -- потолок 2 этажа
Kit.B = -12 -- пол подвала
Kit.WALL = 1 -- толщина стены

Kit.rng = Random.new(1989)

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

Kit.M = {
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
	tiles = mat("CeramicTiles", Enum.Material.Slate),
	asphalt = mat("Asphalt", Enum.Material.Concrete),
	foil = Enum.Material.Foil,
}

Kit.C = {
	extWood = Color3.fromRGB(78, 68, 56),
	trim = Color3.fromRGB(46, 35, 26),
	floor = Color3.fromRGB(64, 48, 34),
	plaster = Color3.fromRGB(108, 102, 88),
	plasterDark = Color3.fromRGB(86, 80, 68),
	wallpaper = Color3.fromRGB(92, 84, 66),
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
	slime = Color3.fromRGB(70, 86, 34),
	slimeDark = Color3.fromRGB(40, 50, 22),
	grass = Color3.fromRGB(44, 50, 32),
	dirt = Color3.fromRGB(52, 44, 34),
	pine = Color3.fromRGB(26, 38, 28),
	bark = Color3.fromRGB(44, 36, 30),
	warm = Color3.fromRGB(255, 186, 112),
	cold = Color3.fromRGB(190, 210, 255),
	flesh = Color3.fromRGB(58, 32, 30),
	fleshDark = Color3.fromRGB(32, 22, 20),
	rust = Color3.fromRGB(96, 60, 38),
	web = Color3.fromRGB(190, 190, 185),
}

local M, C = Kit.M, Kit.C

function Kit.tag(inst: Instance, name: string)
	CollectionService:AddTag(inst, name)
end

function Kit.newPart(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, props: { [string]: any }?): Part
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
local newPart = Kit.newPart

-- Деталь по двум углам (без поворота)
function Kit.box(parent: Instance, x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, color: Color3, material: Enum.Material, props: { [string]: any }?): Part
	local size = Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(z2 - z1))
	local center = Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2)
	return newPart(parent, size, CFrame.new(center), color, material, props)
end
local box = Kit.box

-- Деталь относительно точки мебели (origin — центр мебели на полу)
function Kit.piece(parent: Instance, origin: CFrame, offset: Vector3, size: Vector3, color: Color3, material: Enum.Material, props: { [string]: any }?): Part
	return newPart(parent, size, origin * CFrame.new(offset), color, material, props)
end

-- Вертикальный цилиндр
function Kit.cylinder(parent: Instance, cf: CFrame, height: number, diameter: number, color: Color3, material: Enum.Material, props: { [string]: any }?): Part
	local p = newPart(parent, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Эллипсоид — для наростов, слизи и коконов
function Kit.blob(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material, props: { [string]: any }?): Part
	local p = newPart(parent, size, cf, color, material, props or { CanCollide = false })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Точка на полу, «лицом» в сторону face
function Kit.at(x: number, y: number, z: number, face: Vector3?): CFrame
	local pos = Vector3.new(x, y, z)
	return CFrame.lookAt(pos, pos + (face or Vector3.new(0, 0, -1)))
end

function Kit.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Плоский диск (пятно)
function Kit.disk(parent: Instance, cf: CFrame, diameter: number, color: Color3, material: Enum.Material, transparency: number)
	local p = newPart(parent, Vector3.new(0.06, diameter, diameter * Kit.rng:NextNumber(0.6, 1)), cf, color, material, {
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Transparency = transparency,
	})
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Невидимый пандус под лестницей (по нему реально ходят)
function Kit.ramp(parent: Instance, p1: Vector3, p2: Vector3, width: number): Part
	local length = (p2 - p1).Magnitude
	local cf = CFrame.lookAt(p1, p2) * CFrame.new(0, -0.5, -length / 2)
	return newPart(parent, Vector3.new(width, 1, length), cf, C.trim, M.wood, { Transparency = 1, Name = "StairRamp" })
end

-- Лестница: ступени + невидимый пандус. top/bottom — точки на середине ширины.
function Kit.stairs(parent: Instance, bottom: Vector3, top: Vector3, width: number)
	local rise = top.Y - bottom.Y
	local flat = Vector3.new(top.X - bottom.X, 0, top.Z - bottom.Z)
	local steps = math.max(1, math.round(rise))
	local dir = flat.Unit
	local run = flat.Magnitude / steps
	for i = 1, steps do
		local center = bottom + dir * (run * (i - 0.5)) + Vector3.new(0, i - 0.5, 0)
		newPart(parent, Vector3.new(width, 1, run + 0.15), CFrame.lookAt(center, center + dir), C.floor, M.planks, { CanCollide = false })
	end
	Kit.ramp(parent, bottom, top, width)
end

-- Перила от base1 до base2 (точки внизу), высотой h
function Kit.railing(parent: Instance, base1: Vector3, base2: Vector3, h: number)
	local length = (base2 - base1).Magnitude
	local up = Vector3.new(0, h, 0)
	local mid = (base1 + base2) / 2 + up
	newPart(parent, Vector3.new(0.35, 0.3, length), CFrame.lookAt(mid, base2 + up), C.trim, M.wood)
	local count = math.max(1, math.floor(length / 1.6))
	for i = 0, count do
		-- некоторые столбики сгнили и выпали
		if i == 0 or i == count or Kit.rng:NextNumber() > 0.15 then
			local pos = base1:Lerp(base2, i / count)
			newPart(parent, Vector3.new(0.25, h, 0.25), CFrame.new(pos + up / 2), C.trim, M.wood)
		end
	end
end

---------------------------------------------------------------------
-- Окна и стены
---------------------------------------------------------------------

local function fillWindow(parent: Instance, axis: string, fixed: number, s1: number, s2: number, y1: number, y2: number, kind: string, out: number)
	local rng = Kit.rng
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
	-- подоконник и наличник
	make(Vector3.new(w + 0.6, 0.25, 1.4), y1 - 0.12, mid, 0, 0, C.trim, M.wood)
	make(Vector3.new(w + 0.6, 0.3, 1.2), y2 + 0.15, mid, 0, 0, C.trim, M.wood)
end

-- Дверь, которая открывается (логика — в Doors.server.luau)
-- hinge — где петли, closedCF — дверь в закрытом виде
function Kit.door(parent: Instance, closedCF: CFrame, hinge: Vector3, w: number, h: number, opts: { [string]: any }?)
	local o = opts or {}
	local panel = newPart(parent, Vector3.new(w, h, 0.3), closedCF, o.color or C.furnDark, M.planks, { Name = o.name or "Door" })
	-- ручка
	local knob = newPart(panel, Vector3.new(0.3, 0.3, 0.6), closedCF * CFrame.new((closedCF:PointToObjectSpace(hinge).X > 0 and -1 or 1) * (w / 2 - 0.5), -0.6, 0), Color3.fromRGB(120, 100, 60), M.metal, { CanCollide = false })
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = panel
	weld.Part1 = knob
	weld.Parent = panel
	knob.Anchored = false
	panel:SetAttribute("ClosedCFrame", closedCF)
	panel:SetAttribute("HingeLocal", closedCF:PointToObjectSpace(hinge))
	panel:SetAttribute("OpenSign", Kit.rng:NextNumber() > 0.5 and 1 or -1)
	panel:SetAttribute("Locked", o.locked == true)
	if o.keyDoor then
		panel:SetAttribute("KeyDoor", true)
	end
	Kit.tag(panel, "Door")
	-- некоторые двери стоят приоткрытыми
	local open = o.open
	if open == nil and not o.locked then
		open = Kit.rng:NextNumber() < 0.55
	end
	panel:SetAttribute("Open", open == true)
	if open then
		local hingeCF = CFrame.new(hinge)
		local angle = math.rad(85) * panel:GetAttribute("OpenSign")
		panel.CFrame = hingeCF * CFrame.Angles(0, angle, 0) * hingeCF:Inverse() * closedCF
	end
	return panel
end

-- Стена вдоль оси X (z = fixed) или Z (x = fixed), от a до b.
-- holes: { {s1, s2, низ, верх, вид, опции} } — координаты вдоль стены, высота от пола.
-- вид: "door" (рама + дверь), "arch" (только рама), "glass", "boarded", "broken" или nil (просто дыра)
function Kit.wall(parent: Instance, axis: string, fixed: number, a: number, b: number, y0: number, h: number, holes: { any }?, color: Color3, material: Enum.Material, out: number?)
	local list = holes or {}
	table.sort(list, function(p, q)
		return p[1] < q[1]
	end)
	local half = Kit.WALL / 2
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
	local function pt(s: number, y: number): Vector3
		return axis == "x" and Vector3.new(s, y, fixed) or Vector3.new(fixed, y, s)
	end
	local cursor = a
	for _, hole in list do
		local s1, s2, bottom, top, kind, opts = hole[1], hole[2], hole[3], hole[4], hole[5], hole[6]
		seg(cursor, s1, 0, h)
		seg(s1, s2, 0, bottom)
		seg(s1, s2, top, h)
		cursor = s2
		if kind == "door" or kind == "arch" then
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
			if kind == "door" then
				local w = s2 - s1 - 0.1
				local dh = frameH - 0.1
				local center = pt((s1 + s2) / 2, y0 + dh / 2 + 0.02)
				local rot = axis == "x" and CFrame.new() or CFrame.Angles(0, math.pi / 2, 0)
				Kit.door(parent, CFrame.new(center) * rot, pt(s1 + 0.05, y0 + dh / 2), w, dh, opts)
			end
		elseif kind then
			fillWindow(parent, axis, fixed, s1, s2, y0 + bottom, y0 + top, kind, out or 1)
		end
	end
	seg(cursor, b, 0, h)
end

-- Кольцо по периметру (фундамент, пояса между этажами)
function Kit.ring(parent: Instance, x1: number, z1: number, x2: number, z2: number, y1: number, y2: number, color: Color3, material: Enum.Material)
	box(parent, x1 - 0.5, y1, z1 - 0.5, x2 + 0.5, y2, z1 + 0.5, color, material)
	box(parent, x1 - 0.5, y1, z2 - 0.5, x2 + 0.5, y2, z2 + 0.5, color, material)
	box(parent, x1 - 0.5, y1, z1 + 0.5, x1 + 0.5, y2, z2 - 0.5, color, material)
	box(parent, x2 - 0.5, y1, z1 + 0.5, x2 + 0.5, y2, z2 - 0.5, color, material)
end

---------------------------------------------------------------------
-- Свет
---------------------------------------------------------------------

function Kit.addLight(parent: Instance, brightness: number, range: number, color: Color3, shadows: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = range
	light.Color = color
	light.Shadows = shadows ~= false
	light.Parent = parent
	return light
end

-- Лампа на проводе. powered = лампа от уличного щитка (сначала выключена).
-- broken = разбита и никогда не горит.
function Kit.hangingLamp(parent: Instance, x: number, ceilY: number, z: number, drop: number, mode: string, brightness: number?, range: number?)
	local bulbY = ceilY - drop
	box(parent, x - 0.06, bulbY + 0.5, z - 0.06, x + 0.06, ceilY, z + 0.06, Color3.fromRGB(20, 20, 20), M.smooth, { CanCollide = false })
	Kit.cylinder(parent, CFrame.new(x, bulbY + 0.35, z), 0.5, 1.9, Color3.fromRGB(30, 30, 28), M.metal, { CanCollide = false })
	local on = mode == "on"
	local bulb = newPart(parent, Vector3.new(0.7, 0.7, 0.7), CFrame.new(x, bulbY, z), on and C.warm or Color3.fromRGB(60, 58, 50), on and M.neon or M.glass, { CanCollide = false, Shape = Enum.PartType.Ball, Name = "Bulb" })
	if mode ~= "broken" then
		local light = Kit.addLight(bulb, brightness or 1.4, range or 28, C.warm)
		if mode == "powered" then
			light.Enabled = false
			bulb:SetAttribute("OnColor", C.warm)
			Kit.tag(bulb, "PanelLight")
		end
	end
	return bulb
end

-- Точка зарядки фонарика: распределительная коробка с торчащими проводами
function Kit.chargePoint(parent: Instance, cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "ChargePoint"
	model.Parent = parent
	local body = Kit.piece(model, cf, Vector3.new(0, 0, 0), Vector3.new(1.6, 2, 0.5), Color3.fromRGB(70, 72, 68), M.rust, { Name = "Box" })
	Kit.piece(model, cf, Vector3.new(0, 0, -0.27), Vector3.new(1.2, 1.4, 0.05), Color3.fromRGB(40, 40, 38), M.metal, { CanCollide = false })
	-- провода, свисающие из коробки
	for i, dx in { -0.4, 0, 0.45 } do
		local len = 1.2 + i * 0.5
		Kit.piece(model, cf, Vector3.new(dx, -1 - len / 2, -0.1), Vector3.new(0.12, len, 0.12), i == 2 and Color3.fromRGB(120, 30, 20) or Color3.fromRGB(20, 20, 20), M.smooth, { CanCollide = false })
	end
	-- провод вверх, к потолку
	Kit.piece(model, cf, Vector3.new(0, 4, 0.1), Vector3.new(0.15, 6, 0.15), Color3.fromRGB(20, 20, 20), M.smooth, { CanCollide = false })
	local spark = Instance.new("Attachment")
	spark.Name = "SparkPoint"
	spark.Position = Vector3.new(0.45, -1.8, -0.1)
	spark.Parent = body
	model.PrimaryPart = body
	Kit.tag(model, "ChargePoint")
	return model
end

-- Невидимая точка (тайник, место ключа и т.п.)
function Kit.marker(parent: Instance, name: string, pos: Vector3, size: Vector3?)
	return newPart(parent, size or Vector3.new(4, 1, 4), CFrame.new(pos + Vector3.new(0, 0.5, 0)), Color3.fromRGB(255, 0, 0), M.smooth, {
		Name = name,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
end

return Kit
