-- Атмосфера и гниль: мусор, пятна, плесень, паутина, слизь, свечи, декали на стенах.

local Kit = require(script.Parent.Kit)
local Assets = require(script.Parent.Assets)
local F = require(script.Parent.Furniture)

local M, C = Kit.M, Kit.C
local newPart, disk = Kit.newPart, Kit.disk

local Decor = {}

local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- ось цилиндра вверх = плоский диск

-- Паутина, натянутая поперёк угла комнаты. corner — точка угла под потолком,
-- into — направление в комнату (по диагонали), size — размер паутины
function Decor.cornerWeb(parent: Instance, corner: Vector3, into: Vector3, size: number)
	local rng = Kit.rng
	local dir = Vector3.new(into.X, 0, into.Z).Unit
	local pos = corner + dir * size * 0.32 - Vector3.new(0, size * 0.3, 0)
	local normal = (dir + Vector3.new(0, -0.6, 0)).Unit
	local key = ({ "cornerWeb", "roundWeb", "tornWeb" })[rng:NextInteger(1, 3)]
	local holder = Assets.decal(parent, key, pos, normal, size, size, Color3.fromRGB(210, 210, 205), rng:NextNumber(0.1, 0.35), rng:NextNumber(0, 360))
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
			newPart(parent, Vector3.new(0.04, 0.04, (tip - corner).Magnitude), CFrame.lookAt(mid, tip), C.web, M.fabric, { CanCollide = false, Transparency = 0.5, CastShadow = false })
		end
	end
end

-- Лужа слизи из нескольких блестящих капель
function Decor.slimePuddle(parent: Instance, pos: Vector3, radius: number)
	local rng = Kit.rng
	for _ = 1, rng:NextInteger(4, 8) do
		local off = Vector3.new(rng:NextNumber(-radius, radius), 0, rng:NextNumber(-radius, radius))
		local s = rng:NextNumber(0.8, radius)
		Kit.blob(parent, CFrame.new(pos + off + Vector3.new(0, 0.05, 0)), Vector3.new(s, rng:NextNumber(0.15, 0.4), s * rng:NextNumber(0.6, 1.2)), rng:NextNumber() > 0.5 and C.slime or C.slimeDark, M.glass, {
			CanCollide = false,
			Transparency = 0.15,
			Reflectance = 0.15,
			CastShadow = false,
		})
	end
	Assets.decal(parent, "puddle", pos + Vector3.new(0, 0.04, 0), Vector3.new(0, 1, 0), radius * 3, radius * 2.2, Color3.fromRGB(60, 80, 30), 0.2, rng:NextNumber(0, 360))
end

-- Подтёки слизи с потолка
function Decor.slimeDrips(parent: Instance, pos: Vector3, count: number)
	local rng = Kit.rng
	for _ = 1, count do
		local len = rng:NextNumber(0.8, 3.2)
		local p = pos + Vector3.new(rng:NextNumber(-1.5, 1.5), -len / 2, rng:NextNumber(-1.5, 1.5))
		Kit.blob(parent, CFrame.new(p), Vector3.new(0.35, len, 0.35), C.slimeDark, M.glass, { CanCollide = false, Transparency = 0.1, Reflectance = 0.2, CastShadow = false })
		Kit.blob(parent, CFrame.new(p - Vector3.new(0, len / 2, 0)), Vector3.new(0.5, 0.6, 0.5), C.slime, M.glass, { CanCollide = false, Transparency = 0.1, Reflectance = 0.2, CastShadow = false })
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

-- Одна декаль на случайной стене комнаты
local WALL_DECALS = { "grimeDrip", "grime", "dirt", "smudge", "moldStreak", "waterStain", "crack", "scratch" }

local function wallDecal(parent: Instance, ix1: number, iz1: number, ix2: number, iz2: number, y: number, h: number, key: string?)
	local rng = Kit.rng
	local side = rng:NextInteger(1, 4)
	local w = rng:NextNumber(3, 7)
	local dh = w * rng:NextNumber(0.7, 1.3)
	local wy = y + rng:NextNumber(dh / 2, math.max(dh / 2 + 0.1, h - dh / 2))
	local pos, normal
	if side == 1 then
		pos, normal = Vector3.new(ix1 + 0.03, wy, rng:NextNumber(iz1 + w / 2, math.max(iz1 + w / 2 + 0.1, iz2 - w / 2))), Vector3.new(1, 0, 0)
	elseif side == 2 then
		pos, normal = Vector3.new(ix2 - 0.03, wy, rng:NextNumber(iz1 + w / 2, math.max(iz1 + w / 2 + 0.1, iz2 - w / 2))), Vector3.new(-1, 0, 0)
	elseif side == 3 then
		pos, normal = Vector3.new(rng:NextNumber(ix1 + w / 2, math.max(ix1 + w / 2 + 0.1, ix2 - w / 2)), wy, iz1 + 0.03), Vector3.new(0, 0, 1)
	else
		pos, normal = Vector3.new(rng:NextNumber(ix1 + w / 2, math.max(ix1 + w / 2 + 0.1, ix2 - w / 2)), wy, iz2 - 0.03), Vector3.new(0, 0, -1)
	end
	local k = key or WALL_DECALS[rng:NextInteger(1, #WALL_DECALS)]
	Assets.decal(parent, k, pos, normal, w, dh, nil, rng:NextNumber(0.15, 0.45))
end

-- Плесень у пола вдоль стен (декаль «снизу вверх»)
local function bottomMold(parent: Instance, ix1: number, iz1: number, ix2: number, iz2: number, y: number)
	local rng = Kit.rng
	local side = rng:NextInteger(1, 4)
	local w = rng:NextNumber(4, 8)
	local pos, normal
	local hgt = w * 0.6
	if side == 1 then
		pos, normal = Vector3.new(ix1 + 0.04, y + hgt / 2, rng:NextNumber(iz1 + w / 2, iz2 - w / 2)), Vector3.new(1, 0, 0)
	elseif side == 2 then
		pos, normal = Vector3.new(ix2 - 0.04, y + hgt / 2, rng:NextNumber(iz1 + w / 2, iz2 - w / 2)), Vector3.new(-1, 0, 0)
	elseif side == 3 then
		pos, normal = Vector3.new(rng:NextNumber(ix1 + w / 2, ix2 - w / 2), y + hgt / 2, iz1 + 0.04), Vector3.new(0, 0, 1)
	else
		pos, normal = Vector3.new(rng:NextNumber(ix1 + w / 2, ix2 - w / 2), y + hgt / 2, iz2 - 0.04), Vector3.new(0, 0, -1)
	end
	Assets.decal(parent, "moldBottom", pos, normal, w, hgt, Color3.fromRGB(120, 130, 90), 0.25)
end

-- Полная «отделка» комнаты гнилью.
-- Комната от x1..x2, z1..z2 (линии стен), пол на высоте y, потолок через h.
-- opts: amount (мусор), webs (паутина в углах), slime (0..1), decals (штук на стенах), candles
function Decor.dress(parent: Instance, x1: number, z1: number, x2: number, z2: number, y: number, h: number, opts: { [string]: any }?)
	local rng = Kit.rng
	local o = opts or {}
	local amount = o.amount or 4
	local ix1, ix2, iz1, iz2 = x1 + 0.5, x2 - 0.5, z1 + 0.5, z2 - 0.5
	local function rx()
		return rng:NextNumber(ix1 + 1.5, ix2 - 1.5)
	end
	local function rz()
		return rng:NextNumber(iz1 + 1.5, iz2 - 1.5)
	end

	for _ = 1, amount do
		-- обломки досок
		newPart(parent, Vector3.new(rng:NextNumber(1.5, 4.5), 0.22, rng:NextNumber(0.4, 0.8)), CFrame.new(rx(), y + 0.12, rz()) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.06, 0.06)), C.furnDark, M.wood, { CanCollide = false })
		-- бумаги
		newPart(parent, Vector3.new(1, 0.04, 1.35), CFrame.new(rx(), y + 0.03, rz()) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), C.paper, M.smooth, { CanCollide = false, CastShadow = false })
		-- пятна гнили на полу
		local sx, sz = rx(), rz()
		local color = rng:NextNumber() > 0.5 and C.stain or C.moldDark
		for _ = 1, 4 do
			disk(parent, CFrame.new(sx + rng:NextNumber(-1.2, 1.2), y + 0.03 + rng:NextNumber(0, 0.01), sz + rng:NextNumber(-1.2, 1.2)) * FLAT, rng:NextNumber(0.8, 2.4), color, M.slate, rng:NextNumber(0.45, 0.7))
		end
	end

	-- пятно протечки на потолке
	Assets.decal(parent, "waterStain", Vector3.new(rx(), y + h - 0.04, rz()), Vector3.new(0, -1, 0), rng:NextNumber(5, 9), rng:NextNumber(5, 9), nil, 0.3, rng:NextNumber(0, 360))

	-- декали на стенах
	for _ = 1, o.decals or 3 do
		wallDecal(parent, ix1, iz1, ix2, iz2, y, h)
	end
	if (ix2 - ix1) > 12 and (iz2 - iz1) > 12 then
		bottomMold(parent, ix1, iz1, ix2, iz2, y)
	end

	-- паутина в углах под потолком
	local corners = {
		{ Vector3.new(ix1, y + h, iz1), Vector3.new(1, 0, 1) },
		{ Vector3.new(ix2, y + h, iz1), Vector3.new(-1, 0, 1) },
		{ Vector3.new(ix1, y + h, iz2), Vector3.new(1, 0, -1) },
		{ Vector3.new(ix2, y + h, iz2), Vector3.new(-1, 0, -1) },
	}
	local webs = o.webs or 2
	for i = 1, 4 do
		local j = rng:NextInteger(i, 4)
		corners[i], corners[j] = corners[j], corners[i]
	end
	for i = 1, math.min(webs, 4) do
		Decor.cornerWeb(parent, corners[i][1], corners[i][2], rng:NextNumber(3.5, 6))
	end

	-- слизь
	local slime = o.slime or 0
	if rng:NextNumber() < slime then
		Decor.slimePuddle(parent, Vector3.new(rx(), y, rz()), rng:NextNumber(1.5, 2.8))
		Decor.slimeDrips(parent, Vector3.new(rx(), y + h, rz()), rng:NextInteger(3, 6))
		Assets.decal(parent, "slimeDrip", Vector3.new(ix1 + 0.05, y + h - 2.5, rz()), Vector3.new(1, 0, 0), 5, 5, Color3.fromRGB(70, 90, 40), 0.25)
	end

	-- свечи
	for _ = 1, o.candles or 0 do
		Decor.candle(parent, Vector3.new(rx(), y, rz()), true)
	end

	-- хлам у стен
	local clutter = o.clutter
	if clutter == nil then
		clutter = math.floor(((ix2 - ix1) + (iz2 - iz1)) / 12)
	end
	for _ = 1, clutter do
		local side = rng:NextInteger(1, 4)
		local inset = rng:NextNumber(1.4, 2.2)
		local pos, face
		if side == 1 then
			pos, face = Vector3.new(ix1 + inset, y, rz()), Vector3.new(1, 0, 0)
		elseif side == 2 then
			pos, face = Vector3.new(ix2 - inset, y, rz()), Vector3.new(-1, 0, 0)
		elseif side == 3 then
			pos, face = Vector3.new(rx(), y, iz1 + inset), Vector3.new(0, 0, 1)
		else
			pos, face = Vector3.new(rx(), y, iz2 - inset), Vector3.new(0, 0, -1)
		end
		local o2 = CFrame.lookAt(pos, pos + face) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
		local kind = rng:NextInteger(1, 6)
		if kind == 1 then
			F.cardboard(parent, o2)
			if rng:NextNumber() > 0.5 then
				F.cardboard(parent, o2 * CFrame.new(rng:NextNumber(-0.3, 0.3), 1.9, 0) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0))
			end
		elseif kind == 2 then
			F.crate(parent, o2, true)
		elseif kind == 3 then
			-- старый чемодан
			Kit.piece(parent, o2, Vector3.new(0, 0.9, 0), Vector3.new(3, 1.8, 1), Color3.fromRGB(70, 44, 30), M.fabric)
			Kit.piece(parent, o2, Vector3.new(0, 1.95, 0), Vector3.new(0.9, 0.3, 0.2), C.furnDark, M.metal, { CanCollide = false })
		elseif kind == 4 then
			-- стопка книг
			for i = 0, rng:NextInteger(2, 5) do
				Kit.piece(parent, o2 * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), Vector3.new(0, 0.2 + i * 0.4, 0), Vector3.new(1.4, 0.38, 1), Color3.fromRGB(rng:NextInteger(40, 100), rng:NextInteger(25, 60), rng:NextInteger(20, 50)), M.smooth, { CanCollide = false })
			end
		elseif kind == 5 then
			-- опрокинутое ржавое ведро
			Kit.newPart(parent, Vector3.new(1.4, 1.2, 1.2), o2 * CFrame.new(0, 0.6, 0), C.rust, M.rust, { Shape = Enum.PartType.Cylinder, CanCollide = false })
		else
			-- сломанный стул на боку
			local chair = F.chair(parent, o2)
			if chair then
				chair:PivotTo(chair:GetPivot() * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(85)))
			end
		end
	end
end

return Decor
