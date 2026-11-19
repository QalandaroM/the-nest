-- Дом Хейлов: 2 этажа, 13 комнат, лестница в холле, запертая дверь в подвал.
-- Дом стоит в прямоугольнике x -54..54, z -36..36 (перед дома смотрит в -Z).
-- Комнат стало меньше: прачечная + задний коридор, детская + швейная,
-- комната Марты + её ванная — теперь по одной большой комнате.

local Kit = require(script.Parent.Kit)
local Decor = require(script.Parent.Decor)
local F = require(script.Parent.Furniture)
local Assets = require(script.Parent.Assets)

local M, C = Kit.M, Kit.C
local G, S, TOP = Kit.G, Kit.S, Kit.TOP
local box, wall, at, folder = Kit.box, Kit.wall, Kit.at, Kit.folder

local House = {}

local H1 = S - 1 - G -- высота стен 1 этажа (14)
local H2 = TOP - S -- высота стен 2 этажа (14)
local DOOR = 10.5 -- высота дверного проёма (было 9)
local WIDEN = 0.75 -- каждый проём шире на 0.75 с каждой стороны (было 4 studs, стало 5.5)

local PX, NX, PZ, NZ = Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1)

-- Дверь. opts.exact = не расширять (если рядом другая стена)
local function d(s1: number, s2: number, opts: { [string]: any }?)
	if not (opts and opts.exact) then
		s1, s2 = s1 - WIDEN, s2 + WIDEN
	end
	return { s1, s2, 0, DOOR, "door", opts }
end
local function win(s1: number, s2: number, kind: string)
	return { s1, s2, 3.5, 9.5, kind }
end

function House.build(map: Instance, ctx: { [string]: Instance })
	local rng = Kit.rng
	local house = folder(map, "House")
	local shell = folder(house, "Shell")
	local f1 = folder(house, "GroundFloor")
	local f2 = folder(house, "SecondFloor")

	-------------------------------------------------------------------
	-- Полы, потолок, пояса
	-------------------------------------------------------------------
	Kit.ring(shell, -54, -36, 54, 36, 0, G, C.stone, M.stone)
	Kit.ring(shell, -54, -36, 54, 36, S - 1, S, C.trim, M.wood)
	Kit.ring(shell, -54, -36, 54, 36, TOP, TOP + 1, C.trim, M.wood)

	-- пол 1 этажа с дырой над лестницей в подвал (x -51..-34.5, z 7.5..13.5)
	box(shell, -54, G - 1, -36, 54, G, 7.5, C.floor, M.planks)
	box(shell, -54, G - 1, 13.5, 54, G, 36, C.floor, M.planks)
	box(shell, -54, G - 1, 7.5, -51, G, 13.5, C.floor, M.planks)
	box(shell, -34.5, G - 1, 7.5, 54, G, 13.5, C.floor, M.planks)

	-- пол 2 этажа с пустотой над холлом (x -10..10, z -36..10)
	box(shell, -54, S - 1, -36, -10, S, 10, C.floor, M.planks)
	box(shell, 10, S - 1, -36, 54, S, 10, C.floor, M.planks)
	box(shell, -54, S - 1, 10, 54, S, 36, C.floor, M.planks)

	box(shell, -54, TOP, -36, 54, TOP + 1, 36, C.plasterDark, M.plaster)

	-------------------------------------------------------------------
	-- Наружные стены
	-------------------------------------------------------------------
	wall(shell, "x", -36, -54.5, 54.5, G, H1, {
		win(-46, -42, "boarded"), win(-30, -26, "broken"),
		win(-9, -5, "glass"), d(-2, 2, { open = true, name = "FrontDoor" }), win(5, 9, "boarded"),
		win(22, 26, "glass"), win(38, 42, "boarded"),
	}, C.extWood, M.planks, -1)
	wall(shell, "x", 36, -54.5, 54.5, G, H1, {
		win(-46, -42, "boarded"), d(-3, 1, { name = "BackDoor" }), win(24, 28, "broken"), win(42, 46, "glass"),
	}, C.extWood, M.planks, 1)
	wall(shell, "z", -54, -35.5, 35.5, G, H1, {
		win(-26, -22, "glass"), win(-14, -10, "boarded"), win(-2, 2, "broken"), win(22, 26, "boarded"),
	}, C.extWood, M.planks, -1)
	wall(shell, "z", 54, -35.5, 35.5, G, H1, {
		win(-26, -22, "boarded"), win(-6, -2, "glass"), win(14, 18, "boarded"), win(28, 32, "broken"),
	}, C.extWood, M.planks, 1)

	wall(shell, "x", -36, -54.5, 54.5, S, H2, {
		win(-46, -42, "boarded"), win(-30, -26, "glass"), win(-7, -3, "broken"), win(3, 7, "glass"),
		win(22, 26, "boarded"), win(40, 44, "glass"),
	}, C.extWood, M.planks, -1)
	wall(shell, "x", 36, -54.5, 54.5, S, H2, {
		win(-46, -42, "boarded"), win(-26, -22, "glass"), win(-3, 1, "broken"), win(20, 24, "boarded"), win(42, 46, "glass"),
	}, C.extWood, M.planks, 1)
	wall(shell, "z", -54, -35.5, 35.5, S, H2, {
		win(-24, -20, "broken"), win(2, 6, "boarded"), win(24, 28, "glass"),
	}, C.extWood, M.planks, -1)
	wall(shell, "z", 54, -35.5, 35.5, S, H2, {
		win(-24, -20, "glass"), win(-10, -6, "boarded"), win(10, 14, "broken"), win(26, 30, "glass"),
	}, C.extWood, M.planks, 1)

	-------------------------------------------------------------------
	-- Внутренние стены 1 этажа
	-------------------------------------------------------------------
	-- стена между западным крылом и холлом; от z 14.5 её нет — прачечная и задний коридор одна комната
	wall(f1, "z", -14, -35.5, 14.5, G, H1, { d(-22, -18), d(2, 6) }, C.plaster, M.plaster)
	-- за дверью кладовой — летучие мыши
	wall(f1, "x", -4, -53.5, -14.5, G, H1, { d(-46, -42, { bats = true, open = false }), d(-26, -22) }, C.plaster, M.plaster)
	-- стена между кладовой/лестницей в подвал и столовой; дверь в подвал заперта на ключ
	wall(f1, "z", -34, -3.5, 13.5, G, H1, {
		d(0, 4),
		d(8, 13, { exact = true, locked = true, open = false, keyDoor = true, name = "BasementDoor", color = Color3.fromRGB(52, 30, 22) }),
	}, C.plaster, M.plaster)
	wall(f1, "x", 7, -53.5, -34.5, G, H1, nil, C.plasterDark, M.plaster) -- стенка лестничного колодца
	wall(f1, "x", 14, -53.5, -14.5, G, H1, { d(-24, -20) }, C.plaster, M.plaster)
	wall(f1, "x", 14, -13.5, 13.5, G, H1, { { -6, 6, 0, 11, "arch" } }, C.plaster, M.plaster)
	wall(f1, "z", 14, -35.5, 35.5, G, H1, { d(-13, -8), d(22, 26) }, C.plaster, M.plaster)
	wall(f1, "x", 6, 14.5, 53.5, G, H1, { d(30, 34) }, C.plaster, M.plaster)

	-------------------------------------------------------------------
	-- Внутренние стены 2 этажа
	-------------------------------------------------------------------
	-- детская и швейная теперь одна комната (стены по z = -4 нет), Марта и её ванная — тоже
	wall(f2, "z", -14, -35.5, 35.5, S, H2, { d(-24, -20), d(2, 6), d(22, 26) }, C.wallpaper, M.plaster)
	wall(f2, "x", 14, -53.5, -14.5, S, H2, nil, C.wallpaper, M.plaster)
	-- в кладовке и в гостевой — летучие мыши
	wall(f2, "z", 14, -35.5, 35.5, S, H2, { d(-24, -20), d(6, 10), d(26, 30, { bats = true, open = false }) }, C.wallpaper, M.plaster)
	wall(f2, "x", 0, 14.5, 53.5, S, H2, { d(42, 46, { bats = true, open = false }) }, C.wallpaper, M.plaster)
	wall(f2, "z", 32, 0.5, 35.5, S, H2, { d(30, 34) }, C.wallpaper, M.plaster)
	wall(f2, "x", 18, 14.5, 31.5, S, H2, nil, C.wallpaper, M.plaster)

	-------------------------------------------------------------------
	-- Крыша
	-------------------------------------------------------------------
	local roof = folder(house, "Roof")
	local rise = 14
	local ridge = TOP + 1 + rise
	for _, z in { -38, 38 } do
		local p = Kit.ramp(roof, Vector3.new(0, TOP + 1 - 2 * rise / 36, z), Vector3.new(0, ridge, 0), 112)
		p.Transparency = 0
		p.Color = C.roof
		p.Material = M.roof
		p.Name = "RoofSide"
	end
	for i = 0, rise - 1 do
		local halfW = 36 * (1 - (i + 0.5) / rise)
		for _, x in { -54, 54 } do
			box(roof, x - 0.5, TOP + 1 + i, -halfW, x + 0.5, TOP + 2 + i, halfW, C.extWood, M.planks)
		end
	end
	box(roof, 36, TOP + 1, -4, 41, ridge + 5, 1, Color3.fromRGB(80, 62, 52), M.brick) -- труба
	box(roof, 14, ridge - 4.2, -9, 22, ridge - 3.6, -4, Color3.fromRGB(10, 10, 10), M.smooth, { CanCollide = false }) -- дыра

	-------------------------------------------------------------------
	-- Крыльцо
	-------------------------------------------------------------------
	local porch = folder(house, "Porch")
	box(porch, -18, G - 1, -48, 18, G, -36.5, C.floor, M.planks)
	box(porch, -18, 0, -48, 18, G - 1, -47.6, C.trim, M.planks)
	box(porch, -5, 0, -50, 5, 1, -48, C.floor, M.planks)
	for _, x in { -17.5, -6, 6, 17.5 } do
		box(porch, x - 0.4, G, -47.9, x + 0.4, 15, -47.1, C.trim, M.wood)
	end
	Kit.newPart(porch, Vector3.new(38, 0.6, 14), CFrame.new(0, 15.4, -42.5) * CFrame.Angles(math.rad(-6), 0, 0), C.roof, M.roof)
	Kit.railing(porch, Vector3.new(-17.5, G, -47.5), Vector3.new(-6, G, -47.5), 3)
	Kit.railing(porch, Vector3.new(6, G, -47.5), Vector3.new(17.5, G, -47.5), 3)
	Kit.hangingLamp(porch, 0, 15, -42, 2, "powered", 1.1, 18)
	F.prop(porch, "rockingChair", at(-12, G, -41, Vector3.new(0.4, 0, -1)))
	Decor.cornerWeb(porch, Vector3.new(-17.4, 15, -47.4), Vector3.new(1, 0, 1), 4)
	Decor.cornerWeb(porch, Vector3.new(17.4, 15, -47.4), Vector3.new(-1, 0, 1), 3.5)

	local hideouts, notes, keySpawns = ctx.hideouts, ctx.notes, ctx.keySpawns

	local function note(name: string, pos: Vector3, text: string)
		local p = Kit.newPart(notes, Vector3.new(1, 0.05, 1.4), CFrame.new(pos + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), Color3.fromRGB(225, 215, 185), M.smooth, { Name = name, CanCollide = false })
		p:SetAttribute("Text", text)
	end

	-------------------------------------------------------------------
	-- 1 ЭТАЖ
	-------------------------------------------------------------------
	-- Холл (x -14..14, z -36..14), высотой в 2 этажа
	local hall = folder(f1, "Hall")
	Kit.stairs(hall, Vector3.new(5, G, -14), Vector3.new(5, S, 10), 6)
	Kit.railing(hall, Vector3.new(1.8, G + 1, -14), Vector3.new(1.8, S, 10), 3)
	Kit.railing(hall, Vector3.new(8.2, G + 1, -14), Vector3.new(8.2, S, 10), 3)
	Kit.railing(hall, Vector3.new(-10, S, -35.5), Vector3.new(-10, S, 10), 3)
	Kit.railing(hall, Vector3.new(10, S, -35.5), Vector3.new(10, S, 10), 3)
	Kit.railing(hall, Vector3.new(-10, S, 10), Vector3.new(1.8, S, 10), 3)
	-- люстра (горит только от щитка)
	local chandelier = F.prop(hall, "chandelier", CFrame.new(0, TOP - 5.5, -12), 5)
	local chLight = Kit.newPart(hall, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, TOP - 4.5, -12), C.warm, M.glass, { Transparency = 1, CanCollide = false, Name = "ChandelierLight" })
	Kit.addLight(chLight, 1.4, 34, C.warm).Enabled = false
	chLight:SetAttribute("OnColor", C.warm)
	Kit.tag(chLight, "PanelLight")
	if not chandelier then
		Kit.hangingLamp(hall, 0, TOP, -12, 6, "broken")
	else
		Kit.box(hall, -0.08, TOP - 1, -12.08, 0.08, TOP, -11.92, Color3.fromRGB(20, 20, 20), M.smooth, { CanCollide = false })
	end
	F.grandfatherClock(hall, at(-12.7, G, -28, PX)) -- свои часы с маятником (Toolbox-часы выглядели криво)
	F.prop(hall, "painting", at(-13.3, G + 6, -14, PX), 4.5)
	F.table(hall, at(-11.5, G, -6, PX), 3, 2, 3)
	Decor.candle(hall, Vector3.new(-11.5, G + 3, -6), true)
	F.crate(hall, at(10.5, G, -32))
	F.crate(hall, at(11, G, -28.5), true)
	Kit.chargePoint(hall, at(-13.25, G + 4, 8, PX))
	Decor.dress(hall, -14, -36, 14, 14, G, TOP - G, { amount = 8, webs = 4, decals = 5 })
	Kit.marker(hideouts, "Hideout_UnderStairs", Vector3.new(5, G, 6))
	note("Note_Hall", Vector3.new(-3, G, -30), "Кто бы ни читал это — уходите. Свет не включится сам. — Т.Х.")

	-- Кухня (x -54..-14, z -36..-4)
	local kitchen = folder(f1, "Kitchen")
	F.counter(kitchen, at(-52.25, G, -24, PX), 18)
	F.stove(kitchen, at(-52.2, G, -12.5, PX))
	F.fridge(kitchen, at(-52, G, -7, PX))
	F.table(kitchen, at(-34, G, -20), 7, 4, 3.2)
	F.chair(kitchen, at(-34, G, -23.4, PZ))
	F.chair(kitchen, at(-34, G, -16.6, NZ))
	F.chair(kitchen, at(-29.5, G, -20, NX))
	-- упавший стул
	local fallen = F.chair(kitchen, at(-39, G, -19, PX))
	if fallen then
		fallen:PivotTo(fallen:GetPivot() * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(85)))
	end
	F.cabinet(kitchen, at(-24, G, -34.6, PZ))
	Decor.candle(kitchen, Vector3.new(-33, G + 3.2, -19.5), true)
	Kit.hangingLamp(kitchen, -34, S - 1, -20, 4, "powered")
	Kit.chargePoint(kitchen, at(-30, G + 4, -4.75, NZ))
	Decor.dress(kitchen, -54, -36, -14, -4, G, H1, { amount = 7, webs = 3, decals = 4, slime = 0.3 })
	Kit.marker(hideouts, "Hideout_Kitchen", Vector3.new(-17, G, -33))
	Kit.marker(keySpawns, "Key_KitchenCounter", Vector3.new(-52.4, G + 3.5, -30), Vector3.new(1, 1, 1))

	-- Кладовая (x -54..-34, z -4..7)
	local pantry = folder(f1, "Pantry")
	F.shelf(pantry, at(-52.6, G, 1.5, PX), 9, 10, 1.8, 5)
	F.barrel(pantry, at(-37.5, G, -1))
	F.barrel(pantry, at(-40.5, G, -1.5))
	F.crate(pantry, at(-38, G, 4.5))
	Kit.hangingLamp(pantry, -44, S - 1, 1.5, 3, "powered", 0.8, 14)
	Decor.dress(pantry, -54, -4, -34, 7, G, H1, { amount = 4, webs = 3, decals = 3, slime = 0.5 })
	Kit.marker(hideouts, "Hideout_Pantry", Vector3.new(-37, G, -1))

	-- Лестничный колодец в подвал (x -54..-34, z 7..14)
	local stairwell = folder(f1, "BasementStairs")
	Decor.dress(stairwell, -54, 7, -34, 14, G, H1, { amount = 1, webs = 3, decals = 2 })

	-- Столовая (x -34..-14, z -4..14)
	local dining = folder(f1, "Dining")
	F.table(dining, at(-24, G, 5), 10, 4, 3.2)
	for i, x in { -28, -24, -20 } do
		F.chair(dining, at(x, G, 1.6, PZ))
		if i ~= 2 then
			F.chair(dining, at(x, G, 8.4, NZ))
		end
	end
	for _, x in { -27, -23, -21 } do
		Decor.candle(dining, Vector3.new(x, G + 3.2, 5 + rng:NextNumber(-0.8, 0.8)), x ~= -21)
	end
	F.cabinet(dining, at(-29, G, 12.9, NZ))
	F.prop(dining, "painting", at(-14.75, G + 6, 5, NX), 4)
	Kit.hangingLamp(dining, -24, S - 1, 5, 4, "powered")
	Decor.dress(dining, -34, -4, -14, 14, G, H1, { amount = 4, webs = 2, decals = 3 })
	note("Note_Dining", Vector3.new(-22, G + 3.2, 4), "Марта накрыла на четверых. Нас трое. — Т.Х.")

	-- Прачечная вместе с задним коридором (x -54..14, z 14..36)
	local laundry = folder(f1, "Laundry")
	for i = 0, 2 do
		Kit.piece(laundry, at(-50 + i * 4, G, 33.6, NZ), Vector3.new(0, 1.9, 0), Vector3.new(3.4, 3.8, 3), Color3.fromRGB(150, 146, 132), M.smooth)
		Kit.cylinder(laundry, at(-50 + i * 4, G, 33.6, NZ) * CFrame.new(0, 2.2, -1.52) * CFrame.Angles(math.pi / 2, 0, 0), 0.1, 2, Color3.fromRGB(40, 44, 44), M.glass)
	end
	F.shelf(laundry, at(-30, G, 34.6, NZ), 8, 8, 1.6, 4)
	F.barrel(laundry, at(-18, G, 32))
	F.crate(laundry, at(-18.5, G, 18))
	Kit.hangingLamp(laundry, -34, S - 1, 25, 3, "broken")
	Kit.marker(hideouts, "Hideout_Laundry", Vector3.new(-50, G, 18))

	-- бывший задний коридор (x -14..14): ящик, коробка, вешалка, задняя дверь
	local back = laundry -- задний коридор — часть прачечной
	F.crate(back, at(-10, G, 32))
	F.cardboard(back, at(10, G, 18))
	box(back, 11.5, G, 33.5, 12, G + 6, 34, C.trim, M.wood) -- вешалка
	Kit.hangingLamp(back, 0, S - 1, 25, 3, "powered", 0.9)
	Decor.dress(laundry, -54, 14, 14, 36, G, H1, { amount = 6, webs = 4, decals = 4, slime = 1, writing = "ОНА ВНИЗУ" })

	-- Гостиная (x 14..54, z -36..6)
	local living = folder(f1, "LivingRoom")
	F.fireplace(living, at(52.9, G, -15, NX))
	F.sofa(living, at(40, G, -15, PX))
	F.sofa(living, at(40, G, -28, PZ), true)
	F.prop(living, "piano", at(24, G, -33.8, PZ))
	F.prop(living, "tv", at(22, G, 3, NZ) * CFrame.new(0, 0, 0))
	F.prop(living, "rockingChair", at(46, G, -2, Vector3.new(-0.5, 0, -1)))
	box(living, 36, G, -22, 48, G + 0.06, -8, Color3.fromRGB(70, 34, 30), M.fabric, { CanCollide = false })
	Kit.hangingLamp(living, 34, S - 1, -15, 4, "powered")
	Decor.dress(living, 14, -36, 54, 6, G, H1, { amount = 8, webs = 3, decals = 5 })
	Kit.marker(hideouts, "Hideout_LivingRoom", Vector3.new(51, G, 3))
	Kit.marker(keySpawns, "Key_Piano", Vector3.new(24, G + 5.6, -33.8), Vector3.new(1, 1, 1))

	-- Библиотека (x 14..54, z 6..36)
	local library = folder(f1, "Library")
	F.bookshelf(library, at(52.6, G, 14, NX))
	F.bookshelf(library, at(52.6, G, 24, NX))
	F.bookshelf(library, at(19, G, 34.6, NZ), true)
	F.bookshelf(library, at(35, G, 34.6, NZ), true)
	F.desk(library, at(34, G, 18, NZ))
	F.chair(library, at(34, G, 21, NZ))
	Decor.candle(library, Vector3.new(31.8, G + 3.2, 18.8), true)
	Kit.hangingLamp(library, 34, S - 1, 20, 4, "powered")
	Decor.dress(library, 14, 6, 54, 36, G, H1, { amount = 9, webs = 4, decals = 4 })
	Kit.marker(keySpawns, "Key_LibraryDesk", Vector3.new(36, G + 3.2, 18.6), Vector3.new(1, 1, 1))
	note("Note_Library", Vector3.new(36, G + 3.25, 17.3), "Дневник Томаса: «Её ранит только оберег Марты. Я разделил его на три части: цепочку запер в сейфе в спальне, камень — в ящике у генератора (замок открывается только при токе), оправу Лили зарыла у могил. Соберите их на алтаре здесь, в библиотеке».")

	-------------------------------------------------------------------
	-- 2 ЭТАЖ
	-------------------------------------------------------------------
	local landing = folder(f2, "Landing")
	F.crate(landing, at(-11, S, 33))
	F.cardboard(landing, at(11, S, 33))
	Kit.hangingLamp(landing, 0, TOP, 24, 3, "powered", 1, 18)
	Kit.chargePoint(landing, at(6, S + 4, 35.25, NZ))
	Decor.dress(landing, -14, 10, 14, 36, S, H2, { amount = 4, webs = 2, decals = 3 })
	Kit.marker(hideouts, "Hideout_Landing", Vector3.new(-10, S, 32))

	-- Детская Лили вместе со швейным углом (x -54..-14, z -36..14)
	local kids = folder(f2, "KidsRoom")
	F.bed(kids, at(-49, S, -30, PX), true)
	F.prop(kids, "teddy", at(-50.5, S + 2, -29, PX))
	F.prop(kids, "rockingChair", at(-20, S, -9, Vector3.new(-1, 0, 1)))
	F.dresser(kids, at(-30, S, -34.8, PZ))
	Kit.piece(kids, at(-40, S, -34, PZ), Vector3.new(0, 1.2, 0), Vector3.new(4, 2.4, 2.4), Color3.fromRGB(110, 70, 50), M.wood) -- ящик с игрушками
	for _ = 1, 8 do
		Kit.newPart(kids, Vector3.new(1.2, 0.04, 1.6), CFrame.new(rng:NextNumber(-48, -20), S + 0.03, rng:NextNumber(-30, -8)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(170, 165, 150), M.smooth, { CanCollide = false })
	end
	Kit.hangingLamp(kids, -34, TOP, -20, 3, "powered", 0.9)
	Kit.marker(hideouts, "Hideout_KidsRoom", Vector3.new(-17, S, -33))
	Kit.marker(keySpawns, "Key_KidsDresser", Vector3.new(-30, S + 4.1, -34.8), Vector3.new(1, 1, 1))
	note("Note_KidsRoom", Vector3.new(-26, S, -14), "Рисунок Лили: «Большая мама живёт внизу. Она добрая, она обещала забрать маму к себе».")

	-- швейный угол (z -4..14) — с манекеном
	local sewing = kids -- швейный уголок в той же большой детской
	F.table(sewing, at(-44, S, 5), 6, 3, 3.2)
	local mq = at(-26, S, 4, NX)
	Kit.cylinder(sewing, mq * CFrame.new(0, 2, 0), 4, 0.3, C.furnDark, M.wood)
	Kit.blob(sewing, mq * CFrame.new(0, 5.2, 0), Vector3.new(2.2, 3.4, 1.4), Color3.fromRGB(150, 140, 120), M.fabric, { CanCollide = true })
	Kit.blob(sewing, mq * CFrame.new(0, 7.2, 0), Vector3.new(1, 1.2, 1), Color3.fromRGB(150, 140, 120), M.fabric, { CanCollide = false })
	for _ = 1, 2 do
		F.cardboard(sewing, at(rng:NextNumber(-52, -36), S, rng:NextNumber(-2, 12)))
	end
	Kit.hangingLamp(sewing, -34, TOP, 5, 3, "broken")
	Decor.dress(kids, -54, -36, -14, 14, S, H2, { amount = 6, webs = 4, decals = 4, slime = 0.3, creepy = 2, writing = "МАМА?" })
	Kit.marker(hideouts, "Hideout_Sewing", Vector3.new(-50, S, 10))

	-- Комната Марты вместе с её ванной (x -54..-14, z 14..36)
	local martha = folder(f2, "MarthaRoom")
	F.bed(martha, at(-24, S, 31, NZ))
	F.nightstand(martha, at(-30, S, 34.4, NZ))
	Decor.candle(martha, Vector3.new(-30, S + 2.4, 34.4), true)
	F.dresser(martha, at(-15.8, S, 17.5, NX))
	F.prop(martha, "painting", at(-24, S + 6, 35.25, NZ), 4)
	Kit.hangingLamp(martha, -24, TOP, 24, 3, "powered", 0.9)
	Kit.marker(keySpawns, "Key_MarthaNightstand", Vector3.new(-29.3, S + 2.4, 34.2), Vector3.new(1, 1, 1))
	note("Note_Martha", Vector3.new(-20, S, 28), "Марта: «В трубах что-то шевелится. Томас не верит».")

	-- ванный угол Марты (x -54..-34)
	local bath2 = martha -- ванная Марты — угол её комнаты
	box(bath2, -53.5, S, 14.5, -34.5, S + 0.06, 35.5, Color3.fromRGB(110, 108, 98), M.tiles, { CanCollide = false })
	F.bathtub(bath2, at(-44, S, 33.4, NZ))
	F.toilet(bath2, at(-52.6, S, 18, PX))
	F.sink(bath2, at(-44, S, 15.3, PZ))
	Decor.dress(martha, -54, 14, -14, 36, S, H2, { amount = 5, webs = 4, decals = 4, slime = 0.6 })
	Kit.marker(hideouts, "Hideout_Bathtub2", Vector3.new(-44, S + 1.2, 33.4))

	-- Спальня Томаса и Марты (x 14..54, z -36..0)
	local master = folder(f2, "MasterBedroom")
	F.bed(master, at(48, S, -18, NX))
	F.nightstand(master, at(52.3, S, -24, NX))
	F.nightstand(master, at(52.3, S, -12, NX))
	Decor.candle(master, Vector3.new(52.3, S + 2.4, -12), true)
	F.wardrobe(master, at(26, S, -34.4, PZ))
	F.dresser(master, at(22, S, -1.6, NZ))
	box(master, 36, S, -26, 46, S + 0.06, -10, Color3.fromRGB(80, 60, 44), M.fabric, { CanCollide = false })
	Kit.hangingLamp(master, 34, TOP, -18, 3, "powered")
	Decor.dress(master, 14, -36, 54, 0, S, H2, { amount = 5, webs = 3, decals = 4 })
	Kit.marker(hideouts, "Hideout_Wardrobe", Vector3.new(26, S, -30.5))
	Kit.marker(keySpawns, "Key_MasterDresser", Vector3.new(22, S + 4.1, -1.6), Vector3.new(1, 1, 1))

	-- Ванная (x 14..32, z 0..18)
	local bath = folder(f2, "Bathroom")
	box(bath, 14.5, S, 0.5, 31.5, S + 0.06, 17.5, Color3.fromRGB(110, 108, 98), M.tiles, { CanCollide = false })
	F.bathtub(bath, at(24, S, 15.4, NZ))
	F.toilet(bath, at(30.4, S, 2.6, PZ))
	F.sink(bath, at(20, S, 1.6, PZ))
	Decor.dress(bath, 14, 0, 32, 18, S, H2, { amount = 4, webs = 2, decals = 5, slime = 1 })
	Kit.marker(hideouts, "Hideout_Bathtub", Vector3.new(24, S + 1.2, 15.4))

	-- Кладовка (x 14..32, z 18..36)
	local closet = folder(f2, "Closet")
	F.shelf(closet, at(23, S, 34.6, NZ), 12, 10, 1.6, 5)
	F.cabinet(closet, at(30.6, S, 22, NX))
	for _ = 1, 2 do
		F.cardboard(closet, at(rng:NextNumber(16, 28), S, rng:NextNumber(20, 30)))
	end
	Kit.marker(hideouts, "Hideout_Closet", Vector3.new(17, S, 21))

	-- Гостевая (x 32..54, z 0..36) — самая заброшенная
	local guest = folder(f2, "GuestRoom")
	F.bed(guest, at(49, S, 22, NX), true)
	F.dresser(guest, at(43, S, 34.8, NZ))
	F.prop(guest, "painting", at(53.25, S + 6, 8, NX), 4)
	F.crate(guest, at(36, S, 4), true)
	Kit.hangingLamp(guest, 43, TOP, 18, 3, "broken")
	Decor.dress(guest, 32, 0, 54, 36, S, H2, { amount = 7, webs = 4, decals = 5, slime = 0.6, creepy = 2, spiders = 4 })
	Decor.dress(closet, 14, 18, 32, 36, S, H2, { amount = 3, webs = 4, decals = 3, spiders = 4 })

	-------------------------------------------------------------------
	-- Названия комнат (клиент показывает их, когда входишь)
	-------------------------------------------------------------------
	local z = ctx.zones
	Kit.zone(z, "Холл", -14, G, -36, 14, S, 14)
	Kit.zone(z, "Крыльцо", -18, G - 1, -48, 18, 15, -36)
	Kit.zone(z, "Кухня", -54, G, -36, -14, S - 1, -4)
	Kit.zone(z, "Кладовая", -54, G, -4, -34, S - 1, 7)
	Kit.zone(z, "Лестница в подвал", -54, G, 7, -34, S - 1, 14)
	Kit.zone(z, "Столовая", -34, G, -4, -14, S - 1, 14)
	Kit.zone(z, "Прачечная", -54, G, 14, 14, S - 1, 36)
	Kit.zone(z, "Гостиная", 14, G, -36, 54, S - 1, 6)
	Kit.zone(z, "Библиотека", 14, G, 6, 54, S - 1, 36)
	Kit.zone(z, "Второй этаж", -14, S, 10, 14, TOP, 36)
	Kit.zone(z, "Галерея", -14, S, -36, 14, TOP, 10)
	Kit.zone(z, "Детская Лили", -54, S, -36, -14, TOP, 14)
	Kit.zone(z, "Комната Марты", -54, S, 14, -14, TOP, 36)
	Kit.zone(z, "Спальня Томаса", 14, S, -36, 54, TOP, 0)
	Kit.zone(z, "Ванная", 14, S, 0, 32, TOP, 18)
	Kit.zone(z, "Кладовка", 14, S, 18, 32, TOP, 36)
	Kit.zone(z, "Гостевая", 32, S, 0, 54, TOP, 36)
end

return House
