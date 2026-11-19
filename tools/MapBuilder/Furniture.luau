-- Мебель. Сначала пробуем модель из Toolbox, если её нет — строим из деталей.
-- Лицевая сторона мебели смотрит в -Z (как LookVector у CFrame).

local Kit = require(script.Parent.Kit)
local Assets = require(script.Parent.Assets)

local M, C = Kit.M, Kit.C
local piece, newPart, cylinder = Kit.piece, Kit.newPart, Kit.cylinder

local F = {}

---------------------------------------------------------------------
-- Запасная мебель из деталей
---------------------------------------------------------------------

function F.table(parent: Instance, o: CFrame, w: number, d: number, h: number)
	piece(parent, o, Vector3.new(0, h - 0.2, 0), Vector3.new(w, 0.4, d), C.furn, M.wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			piece(parent, o, Vector3.new(sx * (w / 2 - 0.35), (h - 0.4) / 2, sz * (d / 2 - 0.35)), Vector3.new(0.35, h - 0.4, 0.35), C.furnDark, M.wood)
		end
	end
end

local function partChair(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 2.1, 0), Vector3.new(2, 0.3, 2), C.furn, M.wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			piece(parent, o, Vector3.new(sx * 0.8, 1, sz * 0.8), Vector3.new(0.25, 2, 0.25), C.furnDark, M.wood)
		end
	end
	piece(parent, o, Vector3.new(0, 3.5, 0.9), Vector3.new(2, 2.5, 0.25), C.furn, M.wood)
end

local function partBed(parent: Instance, o: CFrame, w: number, l: number, blanket: Color3)
	piece(parent, o, Vector3.new(0, 0.7, 0), Vector3.new(w, 1, l), C.furnDark, M.wood)
	piece(parent, o, Vector3.new(0, 1.6, 0), Vector3.new(w - 0.4, 0.8, l - 0.4), C.cloth, M.fabric)
	piece(parent, o, Vector3.new(0, 2.25, l / 2 - 1.2), Vector3.new(w * 0.6, 0.5, 1.4), Color3.fromRGB(160, 150, 128), M.fabric)
	newPart(parent, Vector3.new(w - 0.1, 0.3, l * 0.55), o * CFrame.new(0.3, 2.15, -l / 5) * CFrame.Angles(0, math.rad(4), 0), blanket, M.fabric)
	piece(parent, o, Vector3.new(0, 2.2, l / 2), Vector3.new(w + 0.2, 4.4, 0.4), C.furn, M.wood)
	piece(parent, o, Vector3.new(0, 1.3, -l / 2), Vector3.new(w + 0.2, 2.6, 0.4), C.furn, M.wood)
end

local function partWardrobe(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 4.5, 0), Vector3.new(5, 9, 2.4), C.furnDark, M.wood)
	piece(parent, o, Vector3.new(0, 9.15, 0), Vector3.new(5.4, 0.3, 2.7), C.furn, M.wood)
	piece(parent, o, Vector3.new(0, 4.6, -1.22), Vector3.new(0.08, 8, 0.05), Color3.fromRGB(15, 12, 10), M.smooth)
end

function F.nightstand(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 1.2, 0), Vector3.new(2, 2.4, 2), C.furn, M.wood)
	piece(parent, o, Vector3.new(0, 1.6, -1.02), Vector3.new(1.6, 0.06, 0.05), C.furnDark, M.smooth)
end

function F.shelf(parent: Instance, o: CFrame, w: number, h: number, d: number, levels: number)
	local rng = Kit.rng
	piece(parent, o, Vector3.new(-w / 2, h / 2, 0), Vector3.new(0.3, h, d), C.furnDark, M.wood)
	piece(parent, o, Vector3.new(w / 2, h / 2, 0), Vector3.new(0.3, h, d), C.furnDark, M.wood)
	piece(parent, o, Vector3.new(0, h / 2, d / 2), Vector3.new(w, h, 0.2), C.furnDark, M.wood)
	for k = 0, levels do
		local y = h * k / levels
		piece(parent, o, Vector3.new(0, y + 0.12, 0), Vector3.new(w, 0.25, d), C.furn, M.wood)
		if k < levels then
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
					x += 0.8
				end
			end
		end
	end
end

local function partSofa(parent: Instance, o: CFrame, w: number)
	piece(parent, o, Vector3.new(0, 0.8, 0), Vector3.new(w, 1.6, 3), C.fabric, M.fabric)
	piece(parent, o, Vector3.new(0, 2.5, 1.1), Vector3.new(w, 2.6, 0.8), C.fabric, M.fabric)
	piece(parent, o, Vector3.new(-w / 2 + 0.4, 1.8, 0), Vector3.new(0.8, 2, 3), C.fabric, M.fabric)
	piece(parent, o, Vector3.new(w / 2 - 0.4, 1.8, 0), Vector3.new(0.8, 2, 3), C.fabric, M.fabric)
end

function F.counter(parent: Instance, o: CFrame, len: number)
	piece(parent, o, Vector3.new(0, 1.6, 0), Vector3.new(len, 3.2, 2.5), C.furnDark, M.wood)
	piece(parent, o, Vector3.new(0, 3.35, 0), Vector3.new(len + 0.2, 0.3, 2.7), Color3.fromRGB(70, 70, 66), M.slate)
	piece(parent, o, Vector3.new(0, 7.6, 0.55), Vector3.new(len, 2.6, 1.4), C.furnDark, M.wood)
	-- висящая на одной петле дверца
	piece(parent, o, Vector3.new(len / 2 - 1, 6.9, -0.4), Vector3.new(1.8, 2.4, 0.15), C.furn, M.wood, { CanCollide = false })
	-- раковина с грязной водой
	piece(parent, o, Vector3.new(-len / 4, 3.42, 0), Vector3.new(2.4, 0.1, 1.6), Color3.fromRGB(30, 34, 26), M.glass, { Transparency = 0.2 })
end

local function partStove(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 1.7, 0), Vector3.new(3, 3.4, 2.6), Color3.fromRGB(140, 134, 122), M.metal)
	piece(parent, o, Vector3.new(0, 1.5, -1.32), Vector3.new(2.4, 1.8, 0.06), Color3.fromRGB(25, 22, 20), M.smooth)
end

local function partFridge(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 3.5, 0), Vector3.new(3.4, 7, 3), Color3.fromRGB(168, 160, 136), M.smooth)
	piece(parent, o, Vector3.new(-1.3, 4.5, -1.6), Vector3.new(0.2, 2, 0.2), Color3.fromRGB(90, 90, 90), M.metal)
end

function F.fireplace(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 3.5, 0), Vector3.new(8, 7, 2), Color3.fromRGB(86, 66, 56), M.brick)
	piece(parent, o, Vector3.new(0, 1.9, -0.9), Vector3.new(4, 3.4, 0.3), Color3.fromRGB(10, 8, 8), M.smooth)
	piece(parent, o, Vector3.new(0, 5.6, -0.3), Vector3.new(9, 0.5, 2.6), C.furn, M.wood)
	piece(parent, o, Vector3.new(0, 10, 0.4), Vector3.new(3, 6, 1.2), Color3.fromRGB(80, 62, 52), M.brick)
	piece(parent, o, Vector3.new(0, 0.2, -1.3), Vector3.new(3.4, 0.4, 1.2), Color3.fromRGB(30, 28, 26), M.slate, { CanCollide = false })
	local ember = piece(parent, o, Vector3.new(0, 0.45, -0.7), Vector3.new(2.4, 0.3, 0.8), Color3.fromRGB(255, 90, 30), M.neon, { CanCollide = false, Name = "Embers" })
	Kit.addLight(ember, 1.2, 18, Color3.fromRGB(255, 110, 50))
	Kit.tag(ember, "Candle") -- тлеет и мигает как свеча
end

local function partBathtub(parent: Instance, o: CFrame)
	local enamel = Color3.fromRGB(160, 154, 138)
	piece(parent, o, Vector3.new(0, 0.9, 0), Vector3.new(6.6, 1.2, 3), enamel, M.smooth)
	-- бортики
	piece(parent, o, Vector3.new(0, 2.1, -1.4), Vector3.new(7, 1.4, 0.4), enamel, M.smooth)
	piece(parent, o, Vector3.new(0, 2.1, 1.4), Vector3.new(7, 1.4, 0.4), enamel, M.smooth)
	piece(parent, o, Vector3.new(-3.3, 2.1, 0), Vector3.new(0.4, 1.4, 2.4), enamel, M.smooth)
	piece(parent, o, Vector3.new(3.3, 2.1, 0), Vector3.new(0.4, 1.4, 2.4), enamel, M.smooth)
	-- мутная вода
	piece(parent, o, Vector3.new(0, 2.3, 0), Vector3.new(6.2, 0.15, 2.4), Color3.fromRGB(38, 46, 30), M.glass, { Transparency = 0.15, CanCollide = false })
	-- ржавые потёки и ножки
	piece(parent, o, Vector3.new(1.2, 1.6, -1.62), Vector3.new(0.5, 1.6, 0.04), Kit.C.rust, M.rust, { CanCollide = false })
	for _, sx in { -2.9, 2.9 } do
		for _, sz in { -1.1, 1.1 } do
			piece(parent, o, Vector3.new(sx, 0.15, sz), Vector3.new(0.45, 0.3, 0.45), Kit.C.rust, M.rust)
		end
	end
	-- кран
	piece(parent, o, Vector3.new(3.1, 3.1, 0), Vector3.new(0.3, 0.9, 0.3), Color3.fromRGB(110, 105, 95), M.metal, { CanCollide = false })
end

function F.toilet(parent: Instance, o: CFrame)
	cylinder(parent, o * CFrame.new(0, 0.7, 0), 1.4, 1.3, Color3.fromRGB(160, 154, 138), M.smooth)
	piece(parent, o, Vector3.new(0, 1.55, -0.2), Vector3.new(1.6, 0.4, 2.2), Color3.fromRGB(150, 144, 128), M.smooth)
	piece(parent, o, Vector3.new(0, 2.4, 1.1), Vector3.new(2, 2, 0.8), Color3.fromRGB(150, 144, 128), M.smooth)
end

function F.sink(parent: Instance, o: CFrame)
	piece(parent, o, Vector3.new(0, 1.4, 0.3), Vector3.new(0.8, 2.8, 0.8), Color3.fromRGB(150, 144, 128), M.smooth)
	piece(parent, o, Vector3.new(0, 3, 0), Vector3.new(2.6, 0.6, 2), Color3.fromRGB(160, 154, 138), M.smooth)
	piece(parent, o, Vector3.new(0, 5.5, 0.95), Vector3.new(2.2, 2.6, 0.1), Color3.fromRGB(70, 78, 80), M.glass, { Reflectance = 0.25, CanCollide = false })
end

function F.desk(parent: Instance, o: CFrame)
	local rng = Kit.rng
	F.table(parent, o, 6, 3, 3.2)
	piece(parent, o, Vector3.new(1.9, 1.5, 0), Vector3.new(2, 2.6, 2.6), C.furnDark, M.wood)
	piece(parent, o, Vector3.new(-1, 3.5, 0.2), Vector3.new(1.8, 0.6, 1.4), Color3.fromRGB(30, 32, 30), M.metal)
	for i = 1, 3 do
		piece(parent, o, Vector3.new(1.5 + rng:NextNumber(-0.3, 0.3), 3.05 + i * 0.12, rng:NextNumber(-0.6, 0.6)), Vector3.new(1, 0.1, 1.35), C.paper, M.smooth, { CanCollide = false })
	end
end

function F.cardboard(parent: Instance, o: CFrame)
	local s = Kit.rng:NextNumber(1.4, 2.4)
	piece(parent, o, Vector3.new(0, s / 2, 0), Vector3.new(s * 1.2, s, s), Color3.fromRGB(122, 98, 68), M.fabric)
end

---------------------------------------------------------------------
-- Модель из Toolbox или запасная
---------------------------------------------------------------------

local function try(parent: Instance, key: string, o: CFrame, height: number?, yaw: number?, fallback: (() -> ())?)
	local model = Assets.place(parent, key, o, height, yaw)
	if not model and fallback then
		fallback()
	end
	return model
end

function F.bed(parent: Instance, o: CFrame, small: boolean?)
	return try(parent, small and "bedSmall" or "bed", o, nil, nil, function()
		partBed(parent, o, small and 4 or 6, small and 6 or 8, Color3.fromRGB(84, 36, 32))
	end)
end

function F.chair(parent: Instance, o: CFrame)
	return try(parent, "chair", o, nil, nil, function()
		partChair(parent, o)
	end)
end

function F.wardrobe(parent: Instance, o: CFrame)
	return try(parent, "wardrobe", o, nil, nil, function()
		partWardrobe(parent, o)
	end)
end

function F.sofa(parent: Instance, o: CFrame, dirty: boolean?)
	return try(parent, dirty and "couchDirty" or "couch", o, nil, nil, function()
		partSofa(parent, o, 8)
	end)
end

function F.stove(parent: Instance, o: CFrame)
	return try(parent, "stove", o, nil, nil, function()
		partStove(parent, o)
	end)
end

function F.fridge(parent: Instance, o: CFrame)
	return try(parent, "fridge", o, nil, nil, function()
		partFridge(parent, o)
	end)
end

function F.bathtub(parent: Instance, o: CFrame)
	return try(parent, "bathtub", o, nil, nil, function()
		partBathtub(parent, o)
	end)
end

function F.bookshelf(parent: Instance, o: CFrame, small: boolean?)
	return try(parent, small and "bookshelfSmall" or "bookshelf", o, nil, nil, function()
		F.shelf(parent, o, 7, small and 8 or 10, 1.6, 5)
	end)
end

function F.dresser(parent: Instance, o: CFrame)
	return try(parent, "dresser", o, nil, nil, function()
		piece(parent, o, Vector3.new(0, 2, 0), Vector3.new(5, 4, 2), C.furn, M.wood)
	end)
end

function F.cabinet(parent: Instance, o: CFrame)
	return try(parent, "cabinet", o, nil, nil, function()
		F.shelf(parent, o, 4, 6, 1.6, 3)
	end)
end

function F.crate(parent: Instance, o: CFrame, broken: boolean?)
	return try(parent, broken and "crateBroken" or "crate", o, Kit.rng:NextNumber(2.4, 3.4), Kit.rng:NextNumber(0, 360), function()
		piece(parent, o, Vector3.new(0, 1.5, 0), Vector3.new(3, 3, 3), Color3.fromRGB(100, 80, 58), M.planks)
	end)
end

function F.barrel(parent: Instance, o: CFrame)
	return try(parent, "barrel", o, nil, Kit.rng:NextNumber(0, 360), function()
		cylinder(parent, o * CFrame.new(0, 2, 0), 4, 2.6, Color3.fromRGB(90, 66, 44), M.wood)
	end)
end

-- Декор без запасного варианта (если не загрузился — просто нет)
function F.prop(parent: Instance, key: string, o: CFrame, height: number?, yaw: number?)
	return Assets.place(parent, key, o, height, yaw)
end

return F
