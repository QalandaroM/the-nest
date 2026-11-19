-- Внешний вид монстра (по мокапу «4 стороны»): олений череп с трещинами и чёрными рогами,
-- красные глаза, голые рёбра и позвоночник, мох с черепами и шипами на плечах,
-- длинные тонкие руки с когтями-серпами, рваная набедренная повязка, ноги с когтями.
--
-- MonsterModel.dress(character) — «надевает» облик на персонажа игрока (R15 или R6):
--   настоящие части тела становятся невидимыми (по ним всё так же попадают и ходят),
--   а сверху привариваются детали монстра.
-- MonsterModel.preview() — в Studio (Command Bar) ставит статую монстра у дороги:
--   require(game.ReplicatedStorage.Shared.MonsterModel:Clone()).preview()

local MonsterModel = {}

local BONE = Color3.fromRGB(186, 174, 146)
local BONE_DARK = Color3.fromRGB(132, 120, 96)
local ANTLER = Color3.fromRGB(26, 22, 20)
local BARK = Color3.fromRGB(46, 38, 30)
local BARK_DARK = Color3.fromRGB(30, 25, 21)
local MOSS = Color3.fromRGB(44, 60, 34)
local MOSS_DARK = Color3.fromRGB(28, 38, 24)
local CLOTH = Color3.fromRGB(34, 30, 26)
local CLAW = Color3.fromRGB(22, 19, 17)
local CAVITY = Color3.fromRGB(16, 11, 10)
local FLESH = Color3.fromRGB(70, 34, 30)
local EYE = Color3.fromRGB(255, 40, 20)

local SMOOTH = Enum.Material.SmoothPlastic
local rng = Random.new(1989)
local SLIME = Color3.fromRGB(52, 70, 30)
local STRAND = Color3.fromRGB(20, 16, 14)

-- Поза: монстр сутулый (как на виде сбоку). PRE — сдвиг/наклон для деталей текущей части тела.
local PRE = CFrame.new()

-- Деталь, приваренная к части тела. off — положение относительно этой части.
-- shape: "ball" (эллипсоид), "cyl" (цилиндр по оси X), "wedge" (клин)
local function add(body: BasePart, folder: Instance, size: Vector3, off: CFrame, color: Color3, material: Enum.Material, shape: string?): Part
	local p = Instance.new("Part")
	p.Name = "MonsterPart"
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = body.CFrame * PRE * off
	if shape == "ball" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "wedge" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Wedge
		mesh.Parent = p
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	return p
end

-- Круглая «кость» между двумя точками (в координатах части тела) + шарик-сустав на конце
local function seg(body: BasePart, folder: Instance, a: Vector3, b: Vector3, thick: number, color: Color3, material: Enum.Material?, joint: boolean?): Part
	local len = math.max((b - a).Magnitude, 0.05)
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0) -- ось цилиндра (X) вдоль кости
	local p = add(body, folder, Vector3.new(len, thick, thick), cf, color, material or SMOOTH, "cyl")
	if joint then
		add(body, folder, Vector3.new(thick, thick, thick) * 1.25, CFrame.new(b), color, material or SMOOTH, "ball")
	end
	return p
end

-- Ломаная из нескольких костей, каждая тоньше предыдущей
local function chain(body: BasePart, folder: Instance, points: { Vector3 }, thick: number, thin: number, color: Color3)
	for i = 1, #points - 1 do
		local t = (i - 1) / math.max(1, #points - 2)
		seg(body, folder, points[i], points[i + 1], thick + (thin - thick) * t, color, SMOOTH, i < #points - 1)
	end
end

---------------------------------------------------------------------
-- Голова: олений череп и рога
---------------------------------------------------------------------
local function head(h: BasePart, f: Instance)
	local s = math.max(h.Size.Y, 1) / 1.1 -- масштаб под размер головы
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z) * s
	end
	local tilt = CFrame.Angles(math.rad(-18), 0, 0) -- голова опущена вперёд, как на мокапе
	local function at(x: number, y: number, z: number): CFrame
		return tilt * CFrame.new(v(x, y, z))
	end
	-- череп: широкий лоб и узкая длинная морда
	add(h, f, v(1.2, 1.0, 1.15), at(0, 0.2, 0.1), BONE, SMOOTH, "ball")
	add(h, f, v(0.85, 0.7, 0.9), at(0, 0.0, -0.4), BONE, SMOOTH, "ball")
	add(h, f, v(0.62, 0.5, 1.5), at(0, -0.2, -0.95) * CFrame.Angles(math.rad(-10), 0, 0), BONE, SMOOTH, "ball")
	add(h, f, v(0.42, 0.3, 0.45), at(0, -0.36, -1.6), BONE_DARK, SMOOTH, "ball")
	-- ноздри
	for _, x in { -0.09, 0.09 } do
		add(h, f, v(0.09, 0.1, 0.08), at(x, -0.32, -1.8), CAVITY, SMOOTH, "ball")
	end
	-- глубокие глазницы и красные глаза
	for _, x in { -0.33, 0.33 } do
		add(h, f, v(0.38, 0.4, 0.3), at(x, 0.12, -0.55), CAVITY, SMOOTH, "ball")
		local eye = add(h, f, v(0.15, 0.15, 0.1), at(x, 0.12, -0.68), EYE, Enum.Material.Neon, "ball")
		if x > 0 then
			local light = Instance.new("PointLight")
			light.Color = EYE
			light.Brightness = 1.2
			light.Range = 7
			light.Shadows = false
			light.Parent = eye
		end
	end
	-- трещины на черепе
	for _ = 1, 6 do
		local x, z = rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.35, 0.45)
		add(h, f, v(0.035, 0.03, rng:NextNumber(0.25, 0.55)), at(x, 0.69, z) * CFrame.Angles(0, rng:NextNumber(-1.2, 1.2), 0), CAVITY, SMOOTH)
	end
	-- нижняя челюсть и зубы
	add(h, f, v(0.5, 0.14, 1.2), at(0, -0.5, -0.95), BONE_DARK, SMOOTH)
	for i = 0, 5 do
		local z = -0.5 - i * 0.17
		for _, x in { -0.2, 0.2 } do
			add(h, f, v(0.06, 0.16, 0.06), at(x * (1 - i * 0.08), -0.43, z), BONE, SMOOTH)
		end
	end
	-- уши торчат в стороны
	for _, side in { -1, 1 } do
		add(h, f, v(0.2, 0.6, 0.12), at(side * 0.68, 0.45, 0.15) * CFrame.Angles(0, 0, side * -1.1), BONE_DARK, SMOOTH, "ball")
	end
	-- рога: ствол из 4 кусков, загибается вверх-назад, и 4 отростка
	for _, side in { -1, 1 } do
		local p0 = v(side * 0.35, 0.62, 0.15)
		local p1 = v(side * 0.7, 1.2, 0.35)
		local p2 = v(side * 0.95, 1.95, 0.3)
		local p3 = v(side * 1.15, 2.7, 0.05)
		local p4 = v(side * 1.05, 3.35, -0.3)
		local pts = { tilt * p0, tilt * p1, tilt * p2, tilt * p3, tilt * p4 }
		chain(h, f, pts, 0.22 * s, 0.09 * s, ANTLER)
		for _, tine in {
			{ p1, v(side * 0.45, 1.75, -0.25), v(side * 0.4, 2.1, -0.45) },
			{ p2, v(side * 1.5, 2.35, 0.45), v(side * 1.75, 2.8, 0.4) },
			{ p2, v(side * 0.65, 2.65, 0.0), v(side * 0.55, 3.1, -0.15) },
			{ p3, v(side * 1.6, 3.15, 0.0), v(side * 1.75, 3.5, -0.1) },
		} do
			chain(h, f, { tilt * tine[1], tilt * tine[2], tilt * tine[3] }, 0.12 * s, 0.06 * s, ANTLER)
		end
	end
end

---------------------------------------------------------------------
-- Грудь: рёбра, позвоночник, мох с черепами и шипами
---------------------------------------------------------------------
local function smallSkull(body: BasePart, f: Instance, off: CFrame, size: number)
	add(body, f, Vector3.new(1, 0.9, 1) * size, off, BONE, SMOOTH, "ball")
	for _, x in { -0.2, 0.2 } do
		add(body, f, Vector3.new(0.26, 0.28, 0.12) * size, off * CFrame.new(x * size, 0.05 * size, -0.44 * size), CAVITY, SMOOTH, "ball")
	end
	add(body, f, Vector3.new(0.12, 0.14, 0.08) * size, off * CFrame.new(0, -0.15 * size, -0.48 * size), CAVITY, SMOOTH, "ball")
	add(body, f, Vector3.new(0.55, 0.25, 0.45) * size, off * CFrame.new(0, -0.38 * size, -0.18 * size), BONE_DARK, SMOOTH)
end

local function spike(body: BasePart, f: Instance, base: Vector3, dir: Vector3, len: number)
	local d = dir.Unit
	seg(body, f, base, base + d * len * 0.6, 0.16, BONE_DARK)
	seg(body, f, base + d * len * 0.6, base + d * len, 0.08, BONE)
end

-- top — центр грудной клетки по высоте (от центра детали), h — её высота
local function chest(t: BasePart, f: Instance, top: number, h: number)
	local sx, sz = t.Size.X, t.Size.Z
	-- тёмные внутренности, видные между рёбер
	add(t, f, Vector3.new(sx * 0.62, h * 0.85, sz * 0.55), CFrame.new(0, top, 0.05), CAVITY, SMOOTH, "ball")
	add(t, f, Vector3.new(sx * 0.35, h * 0.4, sz * 0.4), CFrame.new(0.1, top - h * 0.15, -0.05), FLESH, SMOOTH, "ball")
	-- рёбра: дуги от грудины к позвоночнику, нижние короче
	for i = 0, 5 do
		local y = top + h * 0.38 - i * h * 0.15
		local w = sx * (0.5 - i * 0.025)
		for _, side in { -1, 1 } do
			chain(t, f, {
				Vector3.new(side * 0.05, y, -sz * 0.5),
				Vector3.new(side * w * 0.65, y - 0.04, -sz * 0.45),
				Vector3.new(side * w, y - 0.1, -sz * 0.05),
				Vector3.new(side * w * 0.7, y - 0.14, sz * 0.42),
			}, 0.14, 0.11, BONE)
		end
	end
	-- слизь и тёмные нити свисают с рёбер
	for i = 1, 6 do
		local x = rng:NextNumber(-sx * 0.4, sx * 0.4)
		local len = rng:NextNumber(0.4, 1.1)
		local y = top - rng:NextNumber(0, h * 0.4)
		add(t, f, Vector3.new(0.06, len, 0.06), CFrame.new(x, y - len / 2, -sz * 0.5), i % 2 == 0 and SLIME or STRAND, i % 2 == 0 and Enum.Material.Glass or SMOOTH)
		if i % 2 == 0 then
			add(t, f, Vector3.new(0.13, 0.16, 0.13), CFrame.new(x, y - len, -sz * 0.5), SLIME, Enum.Material.Glass, "ball")
		end
	end
	-- мухи вьются вокруг
	local flies = Instance.new("Attachment")
	flies.Name = "Flies"
	flies.Position = Vector3.new(0, top + h * 0.4, 0)
	flies.Parent = t
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(10, 10, 10))
	emitter.LightInfluence = 1
	emitter.Size = NumberSequence.new(0.09)
	emitter.Lifetime = NumberRange.new(1.5, 3)
	emitter.Rate = 6
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 1.5
	emitter.Acceleration = Vector3.new(0, 0.3, 0)
	emitter.Parent = flies
	-- грудина
	seg(t, f, Vector3.new(0, top + h * 0.45, -sz * 0.52), Vector3.new(0, top - h * 0.25, -sz * 0.5), 0.16, BONE_DARK)
	-- позвоночник: от шеи до таза, сзади хорошо виден
	for i = 0, 9 do
		local y = top + h * 0.48 - i * (h * 0.9 + 0.6) / 9
		add(t, f, Vector3.new(0.28, 0.16, 0.24), CFrame.new(0, y, sz * 0.5), BONE, SMOOTH)
		add(t, f, Vector3.new(0.08, 0.12, 0.22), CFrame.new(0, y, sz * 0.62) * CFrame.Angles(math.rad(-30), 0, 0), BONE_DARK, SMOOTH)
	end
	-- плечи: горбы мха, черепа, шипы
	for _, side in { -1, 1 } do
		local sh = CFrame.new(side * sx * 0.45, top + h * 0.45, 0.05)
		add(t, f, Vector3.new(1.35, 0.95, 1.4), sh, MOSS, Enum.Material.Grass, "ball")
		add(t, f, Vector3.new(1.0, 0.7, 1.1), sh * CFrame.new(side * -0.35, -0.25, 0.3), MOSS_DARK, Enum.Material.Grass, "ball")
		add(t, f, Vector3.new(0.8, 0.5, 0.8), sh * CFrame.new(side * 0.25, 0.3, -0.2), MOSS_DARK, Enum.Material.Grass, "ball")
		smallSkull(t, f, sh * CFrame.new(side * 0.1, 0.3, -0.5), 0.55)
		for k = 0, 2 do
			local len = rng:NextNumber(0.7, 1.4)
			add(t, f, Vector3.new(0.05, len, 0.05), sh * CFrame.new(side * (0.2 + k * 0.15), -0.35 - len / 2, -0.3 + k * 0.3) * CFrame.Angles(0, 0, side * 0.1), STRAND, SMOOTH)
		end
		smallSkull(t, f, sh * CFrame.new(side * 0.1, 0.2, 0.6) * CFrame.Angles(0, math.pi, 0), 0.45)
		for k = 0, 4 do
			local base = Vector3.new(side * (sx * 0.45 + 0.25), top + h * 0.5 + 0.2, -0.5 + k * 0.25)
			spike(t, f, base, Vector3.new(side * 0.7, 1, (k - 2) * 0.35), 0.5 + (k % 2) * 0.2)
		end
	end
	-- рваный шарф на шее с лоскутами
	add(t, f, Vector3.new(sx * 0.8, 0.3, sz * 1.1), CFrame.new(0, top + h * 0.52, 0), CLOTH, Enum.Material.Fabric)
	for i = 0, 3 do
		local x = -0.35 + i * 0.23
		local len = rng:NextNumber(0.4, 0.8)
		add(t, f, Vector3.new(0.2, len, 0.04), CFrame.new(x, top + h * 0.48 - len / 2, -sz * 0.58) * CFrame.Angles(0, 0, rng:NextNumber(-0.25, 0.25)), CLOTH, Enum.Material.Fabric)
	end
end

local function hips(t: BasePart, f: Instance, y: number)
	local sx, sz = t.Size.X, t.Size.Z
	-- таз
	add(t, f, Vector3.new(sx * 0.6, 0.35, sz * 0.5), CFrame.new(0, y, 0), BONE_DARK, SMOOTH, "ball")
	-- пояс
	add(t, f, Vector3.new(sx * 0.75, 0.18, sz * 0.75), CFrame.new(0, y + 0.1, 0), BARK_DARK, Enum.Material.Fabric)
	-- набедренная повязка: передний и задний лоскут с рваным краем
	for _, zs in { -1, 1 } do
		local flapW, flapH = sx * 0.62, 1.15
		add(t, f, Vector3.new(flapW, flapH, 0.05), CFrame.new(0, y - flapH / 2, zs * sz * 0.4) * CFrame.Angles(zs * -0.12, 0, 0), CLOTH, Enum.Material.Fabric)
		for i = 0, 4 do
			local x = -flapW / 2 + (i + 0.5) * flapW / 5
			local len = rng:NextNumber(0.3, 0.9)
			add(t, f, Vector3.new(flapW / 5 - 0.03, len, 0.045), CFrame.new(x, y - flapH - len / 2 + 0.05, zs * (sz * 0.4 + 0.09)) * CFrame.Angles(zs * -0.12, 0, rng:NextNumber(-0.12, 0.12)), CLOTH, Enum.Material.Fabric)
		end
	end
end

---------------------------------------------------------------------
-- Руки, ноги, когти
---------------------------------------------------------------------
-- Тонкая кость сегмента (сверху вниз), обмотанная гнилой корой кольцами
local function limb(p: BasePart, f: Instance, side: number, spikes: number, skull: boolean, thick: number)
	local sy = p.Size.Y
	local top, bottom = Vector3.new(0, sy / 2, 0), Vector3.new(0, -sy / 2, 0)
	seg(p, f, top, bottom, thick, BONE_DARK)
	add(p, f, Vector3.new(thick, thick, thick) * 1.5, CFrame.new(top), BONE, SMOOTH, "ball") -- сустав
	-- обмотки корой
	for k = 1, 3 do
		local y = sy / 2 - k * sy / 4
		add(p, f, Vector3.new(thick * 1.7, sy * 0.16, thick * 1.7), CFrame.new(0, y, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.15, 0.15)), k % 2 == 0 and BARK or BARK_DARK, Enum.Material.Wood)
	end
	-- мох кусочком
	add(p, f, Vector3.new(thick * 1.6, sy * 0.2, thick * 1.6), CFrame.new(side * 0.05, sy * 0.15, 0.08), MOSS_DARK, Enum.Material.Grass, "ball")
	-- шипы наружу
	for k = 1, spikes do
		local y = sy * 0.35 - k * sy / (spikes + 1)
		spike(p, f, Vector3.new(side * thick * 0.6, y, 0), Vector3.new(side, 0.45, rng:NextNumber(-0.3, 0.3)), 0.4)
	end
	if skull then
		smallSkull(p, f, CFrame.new(side * (thick + 0.15), sy * 0.05, -0.05) * CFrame.Angles(0, side * -math.pi / 2, 0), 0.4)
	end
end

-- Длинная кисть: кость вниз + 4 изогнутых когтя-серпа, растопыренных веером
local function claws(p: BasePart, f: Instance, bottom: number, extend: number, len: number)
	local wrist = Vector3.new(0, bottom - extend, -0.05)
	if extend > 0 then
		seg(p, f, Vector3.new(0, bottom, 0), wrist, 0.22, BONE_DARK, SMOOTH, true)
	end
	add(p, f, Vector3.new(0.45, 0.35, 0.3), CFrame.new(wrist - Vector3.new(0, 0.1, 0)), BARK_DARK, SMOOTH, "ball") -- ладонь
	for i = 1, 4 do
		local spread = (i - 2.5) / 1.5 -- -1..1
		local x = spread * 0.2
		local a = wrist + Vector3.new(x, -0.2, -0.05)
		chain(p, f, {
			a,
			a + Vector3.new(spread * 0.15, -len * 0.35, -len * 0.25),
			a + Vector3.new(spread * 0.25, -len * 0.75, -len * 0.3),
			a + Vector3.new(spread * 0.28, -len, -len * 0.05),
		}, 0.11, 0.04, CLAW)
	end
	-- большой палец-коготь назад
	chain(p, f, { wrist + Vector3.new(0, -0.15, 0.1), wrist + Vector3.new(0, -0.45, 0.4), wrist + Vector3.new(0, -0.75, 0.35) }, 0.09, 0.04, CLAW)
end

local function toeClaws(p: BasePart, f: Instance, bottom: number)
	local sx, sz = p.Size.X, p.Size.Z
	add(p, f, Vector3.new(sx * 0.6, 0.3, sz * 1.1), CFrame.new(0, bottom + 0.15, -sz * 0.15), BARK_DARK, Enum.Material.Wood, "ball")
	for i = -1, 1 do
		local a = Vector3.new(i * sx * 0.2, bottom + 0.15, -sz * 0.6)
		chain(p, f, { a, a + Vector3.new(i * 0.08, 0.02, -0.35), a + Vector3.new(i * 0.1, -0.13, -0.6) }, 0.12, 0.05, CLAW)
	end
	chain(p, f, { Vector3.new(0, bottom + 0.2, sz * 0.4), Vector3.new(0, bottom + 0.05, sz * 0.75) }, 0.1, 0.05, CLAW) -- шпора сзади
end

---------------------------------------------------------------------
-- Надеть облик на персонажа
---------------------------------------------------------------------
function MonsterModel.undress(character: Model)
	local old = character:FindFirstChild("MonsterLook")
	if old then
		old:Destroy()
	end
end

function MonsterModel.dress(character: Model)
	MonsterModel.undress(character)
	local f = Instance.new("Folder")
	f.Name = "MonsterLook"

	-- прячем обычного человечка: одежду, шапки, лицо, сами части тела
	for _, d in character:GetDescendants() do
		if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		elseif d:IsA("Decal") and d.Parent and d.Parent.Name == "Head" then
			d:Destroy()
		end
	end
	for _, d in character:GetChildren() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		end
	end

	local function part(name: string): BasePart?
		return character:FindFirstChild(name) :: BasePart?
	end
	local h = part("Head")
	if h then
		PRE = CFrame.new(0, -0.3, -0.65) * CFrame.Angles(math.rad(-10), 0, 0)
		head(h, f)
		PRE = CFrame.new()
	end
	local upper, lower, torso = part("UpperTorso"), part("LowerTorso"), part("Torso")
	if upper then
		-- наклон груди вперёд вокруг поясницы
		local half = upper.Size.Y / 2
		PRE = CFrame.new(0, -half, 0) * CFrame.Angles(math.rad(-16), 0, 0) * CFrame.new(0, half, 0)
		chest(upper, f, 0.05, upper.Size.Y * 0.95)
		PRE = CFrame.new()
	end
	if lower then
		hips(lower, f, 0)
	end
	if torso then -- R6: рёбра в верхних 2/3 торса, ниже — позвоночник и таз
		local half = torso.Size.Y / 2
		PRE = CFrame.new(0, -half * 0.3, 0) * CFrame.Angles(math.rad(-16), 0, 0) * CFrame.new(0, half * 0.3, 0)
		chest(torso, f, torso.Size.Y * 0.18, torso.Size.Y * 0.6)
		PRE = CFrame.new()
		hips(torso, f, -torso.Size.Y * 0.42)
	end
	for _, sideName in { "Left", "Right" } do
		local side = sideName == "Left" and -1 or 1
		-- R15
		local ua, la, hand = part(`{sideName}UpperArm`), part(`{sideName}LowerArm`), part(`{sideName}Hand`)
		if ua then
			limb(ua, f, side, 1, true, 0.3)
		end
		if la then
			limb(la, f, side, 2, false, 0.26)
		end
		if hand then
			claws(hand, f, 0, 0.6, 1.5)
		end
		local ul, ll, foot = part(`{sideName}UpperLeg`), part(`{sideName}LowerLeg`), part(`{sideName}Foot`)
		if ul then
			limb(ul, f, side, 0, false, 0.34)
		end
		if ll then
			limb(ll, f, side, 2, false, 0.28)
		end
		if foot then
			toeClaws(foot, f, -foot.Size.Y / 2)
		end
		-- R6
		local arm, leg = part(`{sideName} Arm`), part(`{sideName} Leg`)
		if arm then
			limb(arm, f, side, 3, true, 0.3)
			claws(arm, f, -arm.Size.Y / 2, 0.9, 1.5) -- руки длиннее человеческих, когти почти до колен
		end
		if leg then
			limb(leg, f, side, 2, false, 0.32)
			toeClaws(leg, f, -leg.Size.Y / 2)
		end
	end
	f.Parent = character
	return f
end

-- Статуя монстра для просмотра в Studio (R6-болванка из деталей + облик)
function MonsterModel.preview(cf: CFrame?): Model
	local old = workspace:FindFirstChild("MonsterPreview")
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "MonsterPreview"
	local base = cf or CFrame.new(0, 0, -100)
	local function p(name: string, size: Vector3, off: Vector3)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Anchored = true
		part.CFrame = base * CFrame.new(off)
		part.Parent = m
	end
	p("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
	p("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0))
	p("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0))
	p("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0))
	p("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0))
	p("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0))
	MonsterModel.dress(m)
	m.Parent = workspace
	print("THE NEST: статуя монстра стоит у дороги (Workspace.MonsterPreview)")
	return m
end

return MonsterModel
