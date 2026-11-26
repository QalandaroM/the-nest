-- Подвал: x -54..10, z -36..36, пол на высоте B.
-- Вход 1: лестница из дома (дверь наверху заперта на ключ).
-- Вход 2: уличный люк с лестницей у левой стены дома (x -54, z 23..27).

local Kit = require(script.Parent.Kit)
local Decor = require(script.Parent.Decor)
local F = require(script.Parent.Furniture)

local M, C = Kit.M, Kit.C
local G, B = Kit.G, Kit.B
local box, wall, at, folder = Kit.box, Kit.wall, Kit.at, Kit.folder

local Basement = {}

local TOPY = G - 1 -- потолок подвала = низ пола 1 этажа
local H = TOPY - B

local PX, NX, PZ, NZ = Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1)

-- Дверь: проём шире и выше, чем раньше (5.5 × 10.5). opts.exact — не расширять
local function d(s1: number, s2: number, opts: { [string]: any }?)
	if not (opts and opts.exact) then
		s1, s2 = s1 - 0.75, s2 + 0.75
	end
	return { s1, s2, 0, 10.5, "door", opts }
end

-- Лампа дневного света (холодная, от щитка)
local function tubeLamp(parent: Instance, x: number, z: number, alongX: boolean, mode: string)
	local len = 6
	local sx, sz = alongX and len or 0.8, alongX and 0.8 or len
	box(parent, x - sx / 2, TOPY - 0.6, z - sz / 2, x + sx / 2, TOPY - 0.4, z + sz / 2, Color3.fromRGB(40, 40, 40), M.metal, { CanCollide = false })
	local tube = box(parent, x - sx / 2 + 0.3, TOPY - 0.9, z - sz / 2 + 0.3, x + sx / 2 - 0.3, TOPY - 0.6, z + sz / 2 - 0.3, Color3.fromRGB(60, 62, 66), M.glass, { CanCollide = false, Name = "Tube" })
	if mode ~= "broken" then
		local light = Kit.addLight(tube, 0.9, 22, C.cold)
		light.Enabled = false
		tube:SetAttribute("OnColor", C.cold)
		Kit.tag(tube, "PanelLight")
	end
end

local function pipe(parent: Instance, a: Vector3, b: Vector3, dia: number)
	local len = (b - a).Magnitude
	local p = Kit.newPart(parent, Vector3.new(len, dia, dia), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), C.rust, M.rust, { CanCollide = false })
	p.Shape = Enum.PartType.Cylinder
end

function Basement.build(map: Instance, ctx: { [string]: Instance })
	local rng = Kit.rng
	local base = folder(map, "Basement")
	local hideouts, notes = ctx.hideouts, ctx.notes

	-- Пол и стены
	box(base, -54, B - 1, -36, 10, B, 36, C.concrete, M.concrete)
	wall(base, "z", -54, -36.5, 36.5, B, H, { d(23, 27, { exact = true, name = "CellarDoor", open = false }) }, C.concrete, M.concrete)
	wall(base, "z", 10, -36.5, 36.5, B, H, nil, C.concrete, M.concrete)
	wall(base, "x", -36, -53.5, 9.5, B, H, nil, C.concrete, M.concrete)
	wall(base, "x", 36, -53.5, 9.5, B, H, nil, C.concrete, M.concrete)
	wall(base, "x", 14, -53.5, -34.5, B, H, { d(-46, -42) }, Color3.fromRGB(80, 74, 66), M.brick)
	wall(base, "z", -34, -3.5, 35.5, B, H, { d(2, 6), d(26, 30, { bats = true, open = false }) }, Color3.fromRGB(80, 74, 66), M.brick)
	wall(base, "x", -4, -53.5, 9.5, B, H, { d(-46, -42), d(-6, -2) }, Color3.fromRGB(80, 74, 66), M.brick)
	wall(base, "z", -20, -35.5, -4.5, B, H, { d(-22, -18) }, Color3.fromRGB(80, 74, 66), M.brick)

	-- Лестница из дома: сверху x -34.5 (уровень 1 этажа), внизу x -51
	Kit.stairs(base, Vector3.new(-51, B, 10.5), Vector3.new(-34.5, G, 10.5), 5)
	Kit.railing(base, Vector3.new(-36, TOPY - 0.6, 7.9), Vector3.new(-51, B + 1, 7.9), 3)

	-- Трубы под потолком
	for _, z in { -20, -6, 20 } do
		pipe(base, Vector3.new(-53, TOPY - 1, z), Vector3.new(9, TOPY - 1, z), 0.7)
	end
	pipe(base, Vector3.new(-2, TOPY - 1.6, -35), Vector3.new(-2, TOPY - 1.6, 35), 0.5)

	-------------------------------------------------------------------
	-- A: нижний холл у лестницы (x -54..-34, z -4..14)
	-------------------------------------------------------------------
	local lower = folder(base, "LowerHall")
	F.barrel(lower, at(-38, B, -1))
	F.crate(lower, at(-52, B, -1.5))
	tubeLamp(lower, -44, 2, true, "powered")
	Decor.dress(lower, -54, -4, -34, 14, B, H, { amount = 4, webs = 4, decals = 4, slime = 0.5 })

	-------------------------------------------------------------------
	-- B: угольная (x -54..-34, z 14..36) с выходом на улицу
	-------------------------------------------------------------------
	local coal = folder(base, "CoalRoom")
	for _ = 1, 14 do
		Kit.newPart(coal, Vector3.new(rng:NextNumber(1, 2.5), rng:NextNumber(0.6, 1.6), rng:NextNumber(1, 2.5)), CFrame.new(rng:NextNumber(-52, -44), B + 0.4, rng:NextNumber(30, 35)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), rng:NextNumber(0, 1)), Color3.fromRGB(22, 22, 22), M.slate)
	end
	F.crate(coal, at(-37, B, 33))
	F.barrel(coal, at(-37.5, B, 17.5))
	-- лопата у стены
	Kit.newPart(coal, Vector3.new(0.2, 5, 0.2), CFrame.new(-36, B + 2.4, 24) * CFrame.Angles(0, 0, 0.25), C.furn, M.wood, { CanCollide = false })
	tubeLamp(coal, -44, 25, false, "broken")
	Decor.dress(coal, -54, 14, -34, 36, B, H, { amount = 4, webs = 3, decals = 4 })
	Kit.marker(hideouts, "Hideout_CoalRoom", Vector3.new(-49, B, 17))

	-------------------------------------------------------------------
	-- C: склад (x -34..10, z -4..36)
	-------------------------------------------------------------------
	local storage = folder(base, "Storage")
	for _, z in { 6, 16, 26 } do
		F.shelf(storage, at(-22, B, z, NZ), 10, 8, 1.6, 4)
		F.shelf(storage, at(-6, B, z, NZ), 10, 8, 1.6, 4)
	end
	-- старая мебель под простынями
	for _, pos in { Vector3.new(4, B, 30), Vector3.new(-28, B, 32), Vector3.new(4, B, 4) } do
		Kit.blob(storage, CFrame.new(pos + Vector3.new(0, 2, 0)), Vector3.new(4.5, 4, 3.5), Color3.fromRGB(150, 146, 134), M.fabric, { CanCollide = true })
	end
	F.crate(storage, at(-30, B, 1))
	F.crate(storage, at(-30, B, 1) * CFrame.new(0, 3, 0))
	F.barrel(storage, at(7, B, 16))
	Kit.chargePoint(storage, at(9.25, B + 4, 21, NX))
	tubeLamp(storage, -14, 11, true, "powered")
	tubeLamp(storage, -14, 30, true, "powered")
	Decor.dress(storage, -34, -4, 10, 36, B, H, { amount = 6, webs = 4, decals = 5, slime = 0.4 })
	Kit.marker(hideouts, "Hideout_Storage", Vector3.new(-31, B, 33))

	-------------------------------------------------------------------
	-- E: генераторная (x -20..10, z -36..-4)
	-------------------------------------------------------------------
	local gen = folder(base, "GeneratorRoom")
	local o = at(-4, B, -22, PX)
	for _, sx in { -2.4, 2.4 } do
		for _, sz in { -1.6, 1.6 } do
			Kit.piece(gen, o, Vector3.new(sx, 2, sz), Vector3.new(0.3, 4, 0.3), Color3.fromRGB(30, 30, 30), M.rust)
		end
	end
	Kit.piece(gen, o, Vector3.new(0, 4, 0), Vector3.new(5.1, 0.3, 3.5), Color3.fromRGB(30, 30, 30), M.rust)
	Kit.piece(gen, o, Vector3.new(0, 0.4, 0), Vector3.new(5.1, 0.3, 3.5), Color3.fromRGB(30, 30, 30), M.rust)
	Kit.piece(gen, o, Vector3.new(0.4, 2, 0), Vector3.new(3.6, 2.6, 2.6), Color3.fromRGB(140, 30, 26), M.metal, { Name = "Generator" })
	Kit.piece(gen, o, Vector3.new(-1.6, 1.8, 0), Vector3.new(1.2, 1.8, 2), Color3.fromRGB(25, 25, 25), M.metal)
	Kit.piece(gen, o, Vector3.new(0, 3.55, 0), Vector3.new(3, 0.6, 2.4), Color3.fromRGB(150, 34, 28), M.metal)

	-- кабель от генератора к ящику Томаса (сам ящик строит Quest.luau)
	box(gen, 1, B + 0.05, -22.2, 6, B + 0.25, -21.8, Color3.fromRGB(15, 15, 15), M.smooth, { CanCollide = false })

	Kit.cylinder(gen, CFrame.new(-16, B + 3.5, -32), 7, 3, C.rust, M.rust) -- бойлер
	F.shelf(gen, at(-6, B, -35.1, PZ), 6, 7, 1.4, 3)
	F.barrel(gen, at(6, B, -33))
	F.barrel(gen, at(3, B, -34))
	local puddle = Kit.disk(gen, CFrame.new(-10, B, -12) * CFrame.Angles(0, 0, math.pi / 2), 6, Color3.fromRGB(52, 60, 58), M.smooth, 0.45)
	puddle.Reflectance = 0.35
	tubeLamp(gen, -5, -18, true, "powered")
	Decor.dress(gen, -20, -36, 10, -4, B, H, { amount = 4, webs = 3, decals = 4 })

	Kit.newPart(workspace, Vector3.new(4, 1, 4), CFrame.new(-12, B + 0.5, -10), C.concrete, M.smooth, {
		Name = "MonsterSpawn",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	Kit.marker(hideouts, "Hideout_Generator", Vector3.new(-10, B, -32))

	-------------------------------------------------------------------
	-- D: гнездо (x -54..-20, z -36..-4)
	-------------------------------------------------------------------
	local nest = folder(base, "Nest")
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-52, -24), rng:NextNumber(-34, -10)
		local size = Vector3.new(rng:NextNumber(1.5, 4.5), rng:NextNumber(1, 3.2), rng:NextNumber(1.5, 4.5))
		local y = rng:NextNumber() > 0.3 and B + size.Y * 0.3 or TOPY - size.Y * 0.3
		Kit.blob(nest, CFrame.new(x, y, z), size, rng:NextNumber() > 0.5 and C.flesh or C.fleshDark, rng:NextNumber() > 0.5 and M.mud or M.slate)
	end
	for _ = 1, 12 do
		local x, z = rng:NextNumber(-50, -26), rng:NextNumber(-32, -10)
		Kit.cylinder(nest, CFrame.new(x, (B + TOPY) / 2, z) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)), H, rng:NextNumber(0.2, 0.5), C.fleshDark, M.mud, { CanCollide = false })
	end
	for i = 1, 5 do
		local cf = CFrame.new(-50 + i * 4, B + 1.2, -30 + rng:NextNumber(-2, 2)) * CFrame.Angles(math.rad(rng:NextNumber(70, 90)), rng:NextNumber(-0.4, 0.4), 0)
		Kit.blob(nest, cf, Vector3.new(2.6, 6, 2.6), Color3.fromRGB(96, 88, 78), M.fabric)
		Kit.blob(nest, cf * CFrame.new(0, 0, -1.15), Vector3.new(1.4, 4, 0.6), Color3.fromRGB(14, 10, 10), M.smooth)
	end
	for _ = 1, 4 do
		Decor.slimePuddle(nest, Vector3.new(rng:NextNumber(-50, -26), B, rng:NextNumber(-32, -10)), rng:NextNumber(2, 3.5))
		Decor.slimeDrips(nest, Vector3.new(rng:NextNumber(-50, -26), TOPY, rng:NextNumber(-32, -10)), 5)
	end
	local core = Kit.blob(nest, CFrame.new(-38, B + 1, -22), Vector3.new(3, 2, 3), Color3.fromRGB(120, 24, 20), M.neon)
	core.Name = "NestCore"
	Kit.addLight(core, 1, 18, Color3.fromRGB(170, 30, 25))
	-- кости и олений череп — «трапеза» Матки
	for _ = 1, 10 do
		Kit.newPart(nest, Vector3.new(rng:NextNumber(1, 2.2), 0.25, 0.25), CFrame.new(rng:NextNumber(-50, -26), B + 0.14, rng:NextNumber(-32, -10)) * CFrame.Angles(0, rng:NextNumber(0, 3.14), 0), Color3.fromRGB(196, 186, 160), M.slate, { CanCollide = false })
	end
	Decor.dress(nest, -54, -36, -20, -4, B, H, { amount = 3, webs = 4, decals = 4, slime = 1, creepy = 2, spiders = 5 })

	-- Названия комнат
	local z = ctx.zones
	Kit.zone(z, "Подвал", -54, B, -4, -34, G - 1, 14)
	Kit.zone(z, "Угольная", -54, B, 14, -34, G - 1, 36)
	Kit.zone(z, "Склад", -34, B, -4, 10, G - 1, 36)
	Kit.zone(z, "Генераторная", -20, B, -36, 10, G - 1, -4)
	Kit.zone(z, "Гнездо", -54, B, -36, -20, G - 1, -4)
	Kit.marker(hideouts, "Hideout_Nest", Vector3.new(-38, B, -18))

	local p = Kit.newPart(notes, Vector3.new(1, 0.05, 1.4), CFrame.new(-24, B + 0.03, -8), Color3.fromRGB(225, 215, 185), M.smooth, { Name = "Note_Basement", CanCollide = false })
	p:SetAttribute("Text", "Последняя страница дневника: «Она внутри одного из нас. Я слышу, как она шевелится у меня под рёбрами».")
end

return Basement
