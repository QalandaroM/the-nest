-- Атмосфера: немного гнили и мусора, паутина, слизь, свечи, декали на стенах
-- и вещи, от которых по-настоящему жутко: пауки на стенах, надписи кровью,
-- кукла лицом в угол, кровавый след волоком, рога на стене.
--
-- Все декали проверяются лучами (Kit.surfaceClear): они кладутся только на ровную
-- сплошную стену — не на двери, окна, мебель и не за угол в соседнюю комнату.

local Kit = require(script.Parent.Kit)
local Assets = require(script.Parent.Assets)
local F = require(script.Parent.Furniture)

local M, C = Kit.M, Kit.C
local newPart, disk = Kit.newPart, Kit.disk

local Decor = {}

local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- ось цилиндра вверх = плоский диск
local BLOOD = Color3.fromRGB(70, 8, 8)
local BLOOD_DRY = Color3.fromRGB(48, 12, 10)
local BONE = Color3.fromRGB(196, 186, 160)

local function noHit(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	return params
end

-- Луч упирается во что-то не дальше maxDist?
local function hits(from: Vector3, dir: Vector3, maxDist: number): boolean
	return workspace:Raycast(from, dir.Unit * maxDist, noHit()) ~= nil
end

---------------------------------------------------------------------
-- Выбор места на стене / потолке / полу
---------------------------------------------------------------------

-- Случайное место на одной из 4 стен комнаты, где прямоугольник w×h целиком на стене.
-- Возвращает точку на поверхности стены и нормаль (в комнату) или nil.
local function wallSpot(ix1: number, iz1: number, ix2: number, iz2: number, y: number, h: number, w: number, dh: number, yMin: number?, yMax: number?): (Vector3?, Vector3?)
	local rng = Kit.rng
	for _ = 1, 8 do
		local side = rng:NextInteger(1, 4)
		local lo = (yMin or 0) + dh / 2
		local hi = math.max(lo + 0.05, (yMax or h) - dh / 2)
		local wy = y + rng:NextNumber(lo, hi)
		local pos, normal
		if side == 1 or side == 2 then
			if iz2 - iz1 > w + 1 then
				local z = rng:NextNumber(iz1 + w / 2 + 0.3, iz2 - w / 2 - 0.3)
				pos, normal = side == 1 and Vector3.new(ix1, wy, z) or Vector3.new(ix2, wy, z), side == 1 and Vector3.new(1, 0, 0) or Vector3.new(-1, 0, 0)
			end
		elseif ix2 - ix1 > w + 1 then
			local x = rng:NextNumber(ix1 + w / 2 + 0.3, ix2 - w / 2 - 0.3)
			pos, normal = side == 3 and Vector3.new(x, wy, iz1) or Vector3.new(x, wy, iz2), side == 3 and Vector3.new(0, 0, 1) or Vector3.new(0, 0, -1)
		end
		if pos then
			local right, up = Kit.axes(normal)
			if Kit.surfaceClear(pos, normal, right, up, w, dh) then
				return pos, normal
			end
		end
	end
	return nil, nil
end

-- Место на потолке (квадрат size×size целиком на ровном потолке)
local function ceilingSpot(ix1: number, iz1: number, ix2: number, iz2: number, ceilY: number, size: number): Vector3?
	local rng = Kit.rng
	local n = Vector3.new(0, -1, 0)
	local right, up = Kit.axes(n)
	for _ = 1, 6 do
		local pos = Vector3.new(rng:NextNumber(ix1 + size / 2 + 0.5, math.max(ix1 + size / 2 + 0.6, ix2 - size / 2 - 0.5)), ceilY, rng:NextNumber(iz1 + size / 2 + 0.5, math.max(iz1 + size / 2 + 0.6, iz2 - size / 2 - 0.5)))
		if Kit.surfaceClear(pos, n, right, up, size, size) then
			return pos
		end
	end
	return nil
end

-- Высота пола в случайной точке комнаты (не на мебели, не на лестнице)
local function floorSpot(ix1: number, iz1: number, ix2: number, iz2: number, y: number): Vector3?
	local rng = Kit.rng
	for _ = 1, 6 do
		local x, z = rng:NextNumber(ix1 + 1.5, ix2 - 1.5), rng:NextNumber(iz1 + 1.5, iz2 - 1.5)
		local fy = Kit.floorAt(x, y, z)
		if fy then
			return Vector3.new(x, fy, z)
		end
	end
	return nil
end

---------------------------------------------------------------------
-- Паутина
---------------------------------------------------------------------

-- Паутина в углу под потолком. corner — точка угла под потолком,
-- into — направление в комнату (по диагонали), size — размер.
-- Паутина стоит поперёк угла так, что все её края внутри комнаты (раньше торчала сквозь стены).
function Decor.cornerWeb(parent: Instance, corner: Vector3, into: Vector3, size: number)
	local rng = Kit.rng
	local dir = Vector3.new(into.X, 0, into.Z).Unit
	-- край паутины по горизонтали ±size/2, поэтому центр не ближе size/2 к каждой стене
	local pos = corner + dir * (size / 2 * math.sqrt(2) * 0.72 + 0.25) - Vector3.new(0, size / 2 + 0.15, 0)
	-- обе стены и потолок рядом есть? (не дверной проём)
	if not hits(pos, Vector3.new(-into.X, 0, 0), size + 1) or not hits(pos, Vector3.new(0, 0, -into.Z), size + 1) or not hits(pos, Vector3.new(0, 1, 0), size) then
		return
	end
	local key = ({ "cornerWeb", "roundWeb", "tornWeb" })[rng:NextInteger(1, 3)]
	local holder = Assets.decal(parent, key, pos, dir, size, size, Color3.fromRGB(210, 210, 205), rng:NextNumber(0.15, 0.35), 0)
	if holder then
		local back = holder:FindFirstChildOfClass("Decal"):Clone()
		back.Face = Enum.NormalId.Back
		back.Parent = holder
	else
		-- запасной вариант: тонкие нити из деталей
		for i = 1, 5 do
			local a = (i / 5) * math.pi / 2
			local tip = corner + (dir * math.cos(a) * size * 0.7) - Vector3.new(0, math.sin(a) * size * 0.7, 0)
			local mid = (corner + tip) / 2
			newPart(parent, Vector3.new(0.04, 0.04, (tip - corner).Magnitude), CFrame.lookAt(mid, tip), C.web, M.fabric, { CanCollide = false, CanQuery = false, Transparency = 0.5, CastShadow = false })
		end
	end
end

---------------------------------------------------------------------
-- Слизь и свечи
---------------------------------------------------------------------

-- Лужа слизи из нескольких блестящих капель (pos — на полу)
function Decor.slimePuddle(parent: Instance, pos: Vector3, radius: number)
	local rng = Kit.rng
	for i = 1, rng:NextInteger(3, 6) do
		local off = Vector3.new(rng:NextNumber(-radius, radius), 0, rng:NextNumber(-radius, radius))
		local s = rng:NextNumber(0.8, radius)
		-- у каждой капли своя высота: не мерцают друг об друга
		Kit.blob(parent, CFrame.new(pos + off + Vector3.new(0, 0.04 + i * 0.012, 0)), Vector3.new(s, rng:NextNumber(0.15, 0.4), s * rng:NextNumber(0.6, 1.2)), rng:NextNumber() > 0.5 and C.slime or C.slimeDark, M.glass, {
			CanCollide = false,
			CanQuery = false,
			Transparency = 0.15,
			Reflectance = 0.15,
			CastShadow = false,
		})
	end
end

-- Подтёки слизи с потолка
function Decor.slimeDrips(parent: Instance, pos: Vector3, count: number)
	local rng = Kit.rng
	for _ = 1, count do
		local len = rng:NextNumber(0.8, 3.2)
		local p = pos + Vector3.new(rng:NextNumber(-1.5, 1.5), -len / 2, rng:NextNumber(-1.5, 1.5))
		Kit.blob(parent, CFrame.new(p), Vector3.new(0.35, len, 0.35), C.slimeDark, M.glass, { CanCollide = false, CanQuery = false, Transparency = 0.1, Reflectance = 0.2, CastShadow = false })
		Kit.blob(parent, CFrame.new(p - Vector3.new(0, len / 2, 0)), Vector3.new(0.5, 0.6, 0.5), C.slime, M.glass, { CanCollide = false, CanQuery = false, Transparency = 0.1, Reflectance = 0.2, CastShadow = false })
	end
end

-- Свеча (модель из Toolbox или своя) со слабым тёплым светом
function Decor.candle(parent: Instance, pos: Vector3, lit: boolean)
	local rng = Kit.rng
	local model = Assets.place(parent, "candle", CFrame.new(pos), rng:NextNumber(0.8, 1.3), rng:NextNumber(0, 360))
	local top: BasePart
	if model then
		top = Kit.newPart(model, Vector3.new(0.1, 0.1, 0.1), CFrame.new(pos + Vector3.new(0, 1.3, 0)), C.warm, M.neon, { Transparency = 1, CanCollide = false, Name = "Flame" })
	else
		Kit.cylinder(parent, CFrame.new(pos + Vector3.new(0, 0.5, 0)), 1, 0.4, Color3.fromRGB(200, 190, 160), M.smooth, { CanCollide = false })
		top = Kit.newPart(parent, Vector3.new(0.15, 0.3, 0.15), CFrame.new(pos + Vector3.new(0, 1.15, 0)), C.warm, M.neon, { CanCollide = false, Name = "Flame" })
	end
	if lit then
		local light = Kit.addLight(top, 0.7, 9, Color3.fromRGB(255, 160, 80))
		light.Name = "CandleLight"
		Kit.tag(top, "Candle")
	end
end

---------------------------------------------------------------------
-- Жуткие вещи
---------------------------------------------------------------------

-- Маленький паук. Клиент (Critters.client.luau) заставляет его ползать по стене.
-- pos — точка на поверхности, normal — нормаль поверхности (от стены).
function Decor.spider(parent: Instance, pos: Vector3, normal: Vector3)
	local rng = Kit.rng
	local model = Instance.new("Model")
	model.Name = "Spider"
	local right, up = Kit.axes(normal)
	local a = rng:NextNumber(0, math.pi * 2)
	local heading = right * math.cos(a) + up * math.sin(a)
	-- «вперёд» паука вдоль стены, «вверх» паука = от стены
	local base = CFrame.lookAt(pos + normal * 0.12, pos + normal * 0.12 + heading.Unit, normal)
	local s = rng:NextNumber(0.7, 1.15)
	local dark = Color3.fromRGB(18, 14, 12)
	local function bit(size: Vector3, off: CFrame, shape: Enum.PartType?): Part
		local p = newPart(model, size * s, base * off, dark, M.smooth, {
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		if shape then
			p.Shape = shape
		end
		return p
	end
	local body = bit(Vector3.new(0.32, 0.22, 0.42), CFrame.new(0, 0.05, 0.08 * s))
	body.Name = "Body"
	bit(Vector3.new(0.2, 0.16, 0.2), CFrame.new(0, 0.04, -0.2 * s), Enum.PartType.Ball)
	-- 8 тонких ножек
	for i = 1, 4 do
		for _, side in { -1, 1 } do
			local z = (-0.18 + i * 0.09) * s
			local ang = math.rad(side * (25 + i * 18))
			bit(Vector3.new(0.42, 0.035, 0.035), CFrame.new(side * 0.2 * s, 0, z) * CFrame.Angles(0, ang * 0.4, side * -0.35))
		end
	end
	model.PrimaryPart = body
	model:SetAttribute("Normal", normal)
	Kit.tag(model, "Spider")
	model.Parent = parent
	return model
end

-- Надпись на стене кровью / углём. SurfaceGui с LightInfluence = 1 — в темноте не светится.
function Decor.writing(parent: Instance, pos: Vector3, normal: Vector3, text: string, w: number, h: number)
	local rng = Kit.rng
	local holder = newPart(parent, Vector3.new(w, h, 0.05), CFrame.lookAt(pos + normal * 0.04, pos + normal * 2) * CFrame.Angles(0, 0, rng:NextNumber(-0.08, 0.08)), Color3.new(), M.smooth, {
		Name = "WallWriting",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- Front смотрит в комнату
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.Creepster
	label.TextColor3 = rng:NextNumber() > 0.3 and Color3.fromRGB(120, 10, 10) or Color3.fromRGB(30, 26, 24)
	label.TextTransparency = 0.12
	label.Parent = gui
	return holder
end

-- Тряпичная кукла. hanging = висит на верёвке с потолка, иначе сидит лицом в угол.
function Decor.doll(parent: Instance, o: CFrame, hanging: boolean?, ropeLen: number?)
	local model = Instance.new("Model")
	model.Name = "Doll"
	local dress = Color3.fromRGB(96, 70, 70)
	local skin = Color3.fromRGB(205, 190, 170)
	local props = { CanCollide = false, CastShadow = true }
	Kit.blob(model, o * CFrame.new(0, 0.55, 0), Vector3.new(0.9, 1.1, 0.7), dress, M.fabric, props)
	Kit.blob(model, o * CFrame.new(0, 1.35, 0), Vector3.new(0.62, 0.62, 0.6), skin, M.smooth, props)
	Kit.blob(model, o * CFrame.new(0, 1.5, 0.08), Vector3.new(0.7, 0.5, 0.62), Color3.fromRGB(30, 22, 18), M.fabric, props) -- волосы
	-- пустые чёрные глаза (смотрят в -Z)
	for _, x in { -0.12, 0.12 } do
		Kit.blob(model, o * CFrame.new(x, 1.38, -0.29), Vector3.new(0.1, 0.12, 0.06), Color3.new(0, 0, 0), M.smooth, props)
	end
	for _, x in { -0.42, 0.42 } do
		Kit.newPart(model, Vector3.new(0.18, 0.7, 0.18), o * CFrame.new(x, 0.65, 0) * CFrame.Angles(0, 0, x > 0 and 0.4 or -0.4), skin, M.smooth, props)
		Kit.newPart(model, Vector3.new(0.2, 0.2, 0.7), o * CFrame.new(x * 0.5, 0.1, -0.3), skin, M.smooth, props) -- ножки
	end
	if hanging then
		local len = ropeLen or 3
		Kit.newPart(model, Vector3.new(0.06, len, 0.06), o * CFrame.new(0, 1.75 + len / 2, 0), Color3.fromRGB(90, 80, 60), M.fabric, props)
	end
	model.Parent = parent
	return model
end

-- Кровавый след волоком: кто-то тащил тело
function Decor.bloodTrail(parent: Instance, from: Vector3, to: Vector3)
	local rng = Kit.rng
	local dist = (to - from).Magnitude
	local steps = math.max(3, math.floor(dist / 1.3))
	for i = 0, steps do
		local p = from:Lerp(to, i / steps) + Vector3.new(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3))
		local fy = Kit.floorAt(p.X, p.Y, p.Z)
		if fy then
			local d = disk(parent, CFrame.new(p.X, fy, p.Z) * FLAT, rng:NextNumber(0.6, 1.5), rng:NextNumber() > 0.4 and BLOOD or BLOOD_DRY, M.smooth, rng:NextNumber(0.05, 0.3))
			d.Name = "Blood"
		end
	end
end

-- Олений череп с рогами на стене — «трофей». Монстр выглядит так же…
function Decor.antlers(parent: Instance, pos: Vector3, normal: Vector3)
	local o = CFrame.lookAt(pos, pos + normal)
	local props = { CanCollide = false }
	Kit.newPart(parent, Vector3.new(1.6, 2, 0.3), o * CFrame.new(0, 0, -0.15), C.furnDark, M.wood, props) -- дощечка
	Kit.blob(parent, o * CFrame.new(0, 0.2, -0.6), Vector3.new(0.9, 0.9, 1), BONE, M.slate, props)
	Kit.blob(parent, o * CFrame.new(0, -0.35, -1.1) * CFrame.Angles(math.rad(-25), 0, 0), Vector3.new(0.5, 0.5, 1.2), BONE, M.slate, props)
	for _, x in { -0.18, 0.18 } do
		Kit.blob(parent, o * CFrame.new(x, 0.25, -1.05), Vector3.new(0.22, 0.24, 0.1), Color3.new(0, 0, 0), M.smooth, props)
	end
	for _, side in { -1, 1 } do
		local base = o * CFrame.new(side * 0.35, 0.6, -0.6)
		local beam = base * CFrame.Angles(0, 0, side * -0.55) * CFrame.new(0, 1.1, 0)
		Kit.newPart(parent, Vector3.new(0.18, 2.2, 0.18), beam, Color3.fromRGB(40, 32, 26), M.wood, props)
		for t = 1, 3 do
			Kit.newPart(parent, Vector3.new(0.12, 0.9, 0.12), beam * CFrame.new(0, -0.8 + t * 0.55, 0) * CFrame.Angles(0, 0, side * 0.9) * CFrame.new(0, 0.4, 0), Color3.fromRGB(40, 32, 26), M.wood, props)
		end
	end
end

local WRITINGS = { "ОНА ВНИЗУ", "НЕ СВЕТИ НА НЕЁ", "МАМА?", "ОНА СЛЫШИТ ШАГИ", "НЕ ОТКРЫВАЙ", "ЛИЛИ ВИДИТ ТЕБЯ", "ОДИН ИЗ ВАС", "ТИШЕ", "ОНА В СТЕНАХ" }

---------------------------------------------------------------------
-- Декали на стенах
---------------------------------------------------------------------
local WALL_DECALS = { "grimeDrip", "grime", "dirt", "smudge", "moldStreak", "waterStain", "crack", "scratch" }

local function wallDecal(parent: Instance, ix1: number, iz1: number, ix2: number, iz2: number, y: number, h: number, key: string?, color: Color3?)
	local rng = Kit.rng
	local w = rng:NextNumber(3, 6)
	local dh = w * rng:NextNumber(0.7, 1.2)
	local pos, normal = wallSpot(ix1, iz1, ix2, iz2, y, h, w, dh)
	if pos and normal then
		local k = key or WALL_DECALS[rng:NextInteger(1, #WALL_DECALS)]
		Assets.decal(parent, k, pos + normal * 0.03, normal, w, dh, color, rng:NextNumber(0.15, 0.45))
	end
end

---------------------------------------------------------------------
-- Полная «отделка» комнаты.
-- Комната от x1..x2, z1..z2 (линии стен), пол на высоте y, потолок через h.
-- opts: amount (сколько грязи), webs (паутина), slime (0..1), decals (на стенах),
--       candles, clutter (хлам у стен), spiders, creepy (жутких вещей), writing (своя надпись)
-- Вызывайте ПОСЛЕ мебели комнаты: декали обходят мебель.
---------------------------------------------------------------------
function Decor.dress(parent: Instance, x1: number, z1: number, x2: number, z2: number, y: number, h: number, opts: { [string]: any }?)
	local rng = Kit.rng
	local o = opts or {}
	local ix1, ix2, iz1, iz2 = x1 + 0.5, x2 - 0.5, z1 + 0.5, z2 - 0.5

	-- мебель из Toolbox не должна торчать сквозь стены
	Kit.keepInside(parent, ix1 + 0.05, iz1 + 0.05, ix2 - 0.05, iz2 - 0.05)

	-- мусора теперь в ~3 раза меньше: пара пятен, одна бумажка, иногда обломок доски
	local amount = math.ceil((o.amount or 4) / 3)
	for i = 1, amount do
		local spot = floorSpot(ix1, iz1, ix2, iz2, y)
		if spot then
			local color = rng:NextNumber() > 0.5 and C.stain or C.moldDark
			for _ = 1, 2 do
				local fy = Kit.floorAt(spot.X, y, spot.Z)
				if fy then
					disk(parent, CFrame.new(spot.X + rng:NextNumber(-0.8, 0.8), fy, spot.Z + rng:NextNumber(-0.8, 0.8)) * FLAT, rng:NextNumber(0.8, 2), color, M.slate, rng:NextNumber(0.5, 0.75))
				end
			end
		end
		local paper = floorSpot(ix1, iz1, ix2, iz2, y)
		if paper and i == 1 then
			newPart(parent, Vector3.new(1, 0.02, 1.35), CFrame.new(paper + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), C.paper, M.smooth, { CanCollide = false, CanQuery = false, CastShadow = false })
		end
		local board = floorSpot(ix1, iz1, ix2, iz2, y)
		if board and rng:NextNumber() < 0.35 then
			newPart(parent, Vector3.new(rng:NextNumber(1.5, 3.5), 0.22, rng:NextNumber(0.4, 0.7)), CFrame.new(board + Vector3.new(0, 0.13, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), C.furnDark, M.wood, { CanCollide = false, CanQuery = false })
		end
	end

	-- пятно протечки на потолке
	local stainSize = rng:NextNumber(4, 7)
	local ceil = ceilingSpot(ix1, iz1, ix2, iz2, y + h, stainSize)
	if ceil then
		Assets.decal(parent, "waterStain", ceil - Vector3.new(0, 0.03, 0), Vector3.new(0, -1, 0), stainSize, stainSize, nil, 0.3, rng:NextNumber(0, 360))
	end

	-- декали на стенах
	for _ = 1, o.decals or 2 do
		wallDecal(parent, ix1, iz1, ix2, iz2, y, h)
	end
	if (ix2 - ix1) > 12 and (iz2 - iz1) > 12 then
		local w = rng:NextNumber(4, 7)
		local pos, normal = wallSpot(ix1, iz1, ix2, iz2, y, h, w, w * 0.6, 0, w * 0.6)
		if pos and normal then
			Assets.decal(parent, "moldBottom", pos + normal * 0.03, normal, w, w * 0.6, Color3.fromRGB(120, 130, 90), 0.25)
		end
	end

	-- паутина в углах под потолком
	local corners = {
		{ Vector3.new(ix1, y + h, iz1), Vector3.new(1, 0, 1) },
		{ Vector3.new(ix2, y + h, iz1), Vector3.new(-1, 0, 1) },
		{ Vector3.new(ix1, y + h, iz2), Vector3.new(1, 0, -1) },
		{ Vector3.new(ix2, y + h, iz2), Vector3.new(-1, 0, -1) },
	}
	for i = 1, 4 do
		local j = rng:NextInteger(i, 4)
		corners[i], corners[j] = corners[j], corners[i]
	end
	for i = 1, math.min(o.webs or 2, 4) do
		Decor.cornerWeb(parent, corners[i][1], corners[i][2], rng:NextNumber(3, 5))
	end

	-- слизь
	if rng:NextNumber() < (o.slime or 0) then
		local spot = floorSpot(ix1, iz1, ix2, iz2, y)
		if spot then
			Decor.slimePuddle(parent, spot, rng:NextNumber(1.2, 2.2))
		end
		local drip = ceilingSpot(ix1, iz1, ix2, iz2, y + h, 3)
		if drip then
			Decor.slimeDrips(parent, drip, rng:NextInteger(3, 5))
		end
		local pos, normal = wallSpot(ix1, iz1, ix2, iz2, y, h, 4.5, 4.5, h - 5, h)
		if pos and normal then
			Assets.decal(parent, "slimeDrip", pos + normal * 0.03, normal, 4.5, 4.5, Color3.fromRGB(70, 90, 40), 0.25)
		end
	end

	-- свечи
	for _ = 1, o.candles or 0 do
		local spot = floorSpot(ix1, iz1, ix2, iz2, y)
		if spot then
			Decor.candle(parent, spot, true)
		end
	end

	-- пауки на стенах и потолке
	for _ = 1, o.spiders or 2 do
		if rng:NextNumber() < 0.75 then
			local pos, normal = wallSpot(ix1, iz1, ix2, iz2, y, h, 1.2, 1.2, 2, h - 0.5)
			if pos and normal then
				Decor.spider(parent, pos, normal)
			end
		else
			local pos = ceilingSpot(ix1, iz1, ix2, iz2, y + h, 1.2)
			if pos then
				Decor.spider(parent, pos, Vector3.new(0, -1, 0))
			end
		end
	end

	-- жуткие вещи (по одной на комнату, если не сказано иначе)
	local creepy = o.creepy or 1
	for _ = 1, creepy do
		local kind = rng:NextInteger(1, 5)
		if o.writing then
			kind = 1
		end
		if kind == 1 then
			local text = o.writing or WRITINGS[rng:NextInteger(1, #WRITINGS)]
			local w = math.clamp(#text * 0.35, 3, 7)
			local pos, normal = wallSpot(ix1, iz1, ix2, iz2, y, h, w, 1.8, 3, 8)
			if pos and normal then
				Decor.writing(parent, pos, normal, text, w, 1.8)
			end
			o.writing = nil
		elseif kind == 2 then
			-- кукла лицом в угол (или висит под потолком)
			if rng:NextNumber() < 0.5 then
				local c = corners[4]
				local p = c[1] + c[2] * 1.1
				local fy = Kit.floorAt(p.X, y, p.Z)
				if fy then
					Decor.doll(parent, CFrame.lookAt(Vector3.new(p.X, fy, p.Z), Vector3.new(c[1].X, fy, c[1].Z)))
				end
			else
				local pos = ceilingSpot(ix1, iz1, ix2, iz2, y + h, 1)
				if pos then
					Decor.doll(parent, CFrame.new(pos - Vector3.new(0, 5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), true, 3.2)
				end
			end
		elseif kind == 3 then
			local a = floorSpot(ix1, iz1, ix2, iz2, y)
			local b = floorSpot(ix1, iz1, ix2, iz2, y)
			if a and b and (a - b).Magnitude > 4 then
				Decor.bloodTrail(parent, a, b)
			end
		elseif kind == 4 then
			local pos, normal = wallSpot(ix1, iz1, ix2, iz2, y, h, 2.2, 3.2, 6, h - 1)
			if pos and normal then
				Decor.antlers(parent, pos, normal)
			end
		else
			-- кровавые царапины на стене
			wallDecal(parent, ix1, iz1, ix2, iz2, y, math.min(h, 7), "scratch", Color3.fromRGB(140, 20, 20))
		end
	end

	-- хлам у стен: теперь только иногда
	local clutter = o.clutter
	if clutter == nil then
		clutter = ((ix2 - ix1) + (iz2 - iz1)) > 40 and 1 or 0
	end
	for _ = 1, clutter do
		local side = rng:NextInteger(1, 4)
		local inset = rng:NextNumber(1.4, 2.2)
		local pos, face
		if side == 1 then
			pos, face = Vector3.new(ix1 + inset, y, rng:NextNumber(iz1 + 2, iz2 - 2)), Vector3.new(1, 0, 0)
		elseif side == 2 then
			pos, face = Vector3.new(ix2 - inset, y, rng:NextNumber(iz1 + 2, iz2 - 2)), Vector3.new(-1, 0, 0)
		elseif side == 3 then
			pos, face = Vector3.new(rng:NextNumber(ix1 + 2, ix2 - 2), y, iz1 + inset), Vector3.new(0, 0, 1)
		else
			pos, face = Vector3.new(rng:NextNumber(ix1 + 2, ix2 - 2), y, iz2 - inset), Vector3.new(0, 0, -1)
		end
		if Kit.floorAt(pos.X, y, pos.Z) then
			local o2 = CFrame.lookAt(pos, pos + face) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
			local kind = rng:NextInteger(1, 3)
			if kind == 1 then
				F.crate(parent, o2, true)
			elseif kind == 2 then
				-- старый чемодан
				Kit.piece(parent, o2, Vector3.new(0, 0.9, 0), Vector3.new(3, 1.8, 1), Color3.fromRGB(70, 44, 30), M.fabric)
				Kit.piece(parent, o2, Vector3.new(0, 1.95, 0), Vector3.new(0.9, 0.3, 0.2), C.furnDark, M.metal, { CanCollide = false })
			else
				-- стул, повёрнутый к стене
				F.chair(parent, CFrame.lookAt(pos, pos - face))
			end
		end
	end
	Kit.keepInside(parent, ix1 + 0.05, iz1 + 0.05, ix2 - 0.05, iz2 - 0.05)
end

return Decor
