-- Внешний вид монстра (по мокапу «4 стороны»): олений череп с трещинами и чёрными рогами,
-- красные глаза, голые рёбра и позвоночник, мох с черепами и шипами на плечах,
-- длинные руки с когтями-серпами, рваная набедренная повязка, ноги с когтями.
--
-- MonsterModel.dress(character) — «надевает» облик на персонажа игрока (R15 или R6):
--   настоящие части тела становятся невидимыми (по ним всё так же попадают и ходят),
--   а сверху привариваются детали монстра.
-- MonsterModel.preview() — в Studio (Command Bar) ставит статую монстра у дороги:
--   require(game.ReplicatedStorage.Shared.MonsterModel:Clone()).preview()

local MonsterModel = {}

local BONE = Color3.fromRGB(205, 194, 166)
local BONE_DARK = Color3.fromRGB(150, 138, 112)
local ANTLER = Color3.fromRGB(32, 26, 22)
local BARK = Color3.fromRGB(56, 46, 36)
local MOSS = Color3.fromRGB(40, 54, 32)
local MOSS_DARK = Color3.fromRGB(26, 34, 22)
local CLOTH = Color3.fromRGB(30, 26, 22)
local CLAW = Color3.fromRGB(24, 20, 18)
local CAVITY = Color3.fromRGB(14, 10, 9)
local EYE = Color3.fromRGB(255, 40, 20)

local rng = Random.new(1989)

-- Деталь, приваренная к части тела. off — положение относительно этой части.
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
	p.CFrame = body.CFrame * off
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

-- «Кость» между двумя точками (в координатах части тела)
local function seg(body: BasePart, folder: Instance, a: Vector3, b: Vector3, thick: number, color: Color3, material: Enum.Material): Part
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	return add(body, folder, Vector3.new(thick, thick, len), cf, color, material)
end

---------------------------------------------------------------------
-- Голова: олений череп и рога
---------------------------------------------------------------------
local function head(h: BasePart, f: Instance)
	local s = math.max(h.Size.Y, 1) / 1.2 -- масштаб под размер головы
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z) * s
	end
	local tilt = CFrame.Angles(math.rad(-12), 0, 0) -- голова наклонена вперёд, как на мокапе
	local function at(x: number, y: number, z: number): CFrame
		return tilt * CFrame.new(v(x, y, z))
	end
	-- череп
	add(h, f, v(1.25, 1.05, 1.3), at(0, 0.15, 0.05), BONE, Enum.Material.Slate, "ball")
	-- вытянутая морда
	add(h, f, v(0.78, 0.62, 1.6), at(0, -0.12, -0.85) * CFrame.Angles(math.rad(-14), 0, 0), BONE, Enum.Material.Slate, "ball")
	add(h, f, v(0.5, 0.32, 0.5), at(0, -0.36, -1.55), BONE_DARK, Enum.Material.Slate, "ball")
	-- ноздри
	for _, x in { -0.1, 0.1 } do
		add(h, f, v(0.1, 0.12, 0.08), at(x, -0.3, -1.8), CAVITY, Enum.Material.SmoothPlastic, "ball")
	end
	-- глазницы и красные глаза
	for _, x in { -0.32, 0.32 } do
		add(h, f, v(0.36, 0.4, 0.24), at(x, 0.15, -0.5), CAVITY, Enum.Material.SmoothPlastic, "ball")
		local eye = add(h, f, v(0.17, 0.17, 0.12), at(x, 0.15, -0.6), EYE, Enum.Material.Neon, "ball")
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
	for _ = 1, 5 do
		local x, z = rng:NextNumber(-0.45, 0.45), rng:NextNumber(-0.4, 0.45)
		add(h, f, v(0.04, 0.03, rng:NextNumber(0.3, 0.6)), at(x, 0.66, z) * CFrame.Angles(0, rng:NextNumber(-1, 1), 0), CAVITY, Enum.Material.SmoothPlastic)
	end
	-- зубы
	for i = 0, 5 do
		local z = -0.95 - i * 0.12
		for _, x in { -0.2, 0.2 } do
			add(h, f, v(0.07, 0.16, 0.07), at(x * (1 - i * 0.07), -0.46, z), BONE_DARK, Enum.Material.Slate)
		end
	end
	-- уши
	for _, side in { -1, 1 } do
		add(h, f, v(0.22, 0.55, 0.14), at(side * 0.68, 0.38, 0.12) * CFrame.Angles(0, 0, side * -0.9), BONE_DARK, Enum.Material.Slate, "ball")
	end
	-- рога: главный ствол из 3 кусков + 4 отростка с каждой стороны
	for _, side in { -1, 1 } do
		local p0 = v(side * 0.4, 0.62, 0.1)
		local p1 = v(side * 0.75, 1.35, 0.25)
		local p2 = v(side * 1.05, 2.2, 0.15)
		local p3 = v(side * 1.25, 3.0, -0.15)
		for _, pair in { { p0, p1, 0.2 }, { p1, p2, 0.17 }, { p2, p3, 0.13 } } do
			local a, b = tilt * pair[1], tilt * pair[2]
			seg(h, f, a, b, pair[3] * s, ANTLER, Enum.Material.Wood)
		end
		for _, tine in {
			{ p1, v(side * 0.5, 1.95, -0.35) },
			{ p2, v(side * 0.55, 2.9, -0.1) },
			{ p2, v(side * 1.65, 2.6, 0.3) },
			{ p3, v(side * 0.95, 3.6, 0.1) },
		} do
			seg(h, f, tilt * tine[1], tilt * tine[2], 0.1 * s, ANTLER, Enum.Material.Wood)
		end
	end
end

---------------------------------------------------------------------
-- Грудь: рёбра, позвоночник, мох с черепами и шипами
---------------------------------------------------------------------
local function smallSkull(body: BasePart, f: Instance, off: CFrame, size: number)
	add(body, f, Vector3.new(1, 0.9, 1) * size, off, BONE, Enum.Material.Slate, "ball")
	for _, x in { -0.18, 0.18 } do
		add(body, f, Vector3.new(0.22, 0.24, 0.1) * size, off * CFrame.new(x * size, 0.05 * size, -0.45 * size), CAVITY, Enum.Material.SmoothPlastic, "ball")
	end
	add(body, f, Vector3.new(0.5, 0.25, 0.4) * size, off * CFrame.new(0, -0.4 * size, -0.2 * size), BONE_DARK, Enum.Material.Slate)
end

local function spike(body: BasePart, f: Instance, base: Vector3, dir: Vector3, len: number)
	seg(body, f, base, base + dir.Unit * len, 0.14, BONE, Enum.Material.Slate)
	seg(body, f, base + dir.Unit * len, base + dir.Unit * (len + 0.25), 0.07, BONE_DARK, Enum.Material.Slate)
end

local function chest(t: BasePart, f: Instance, withHips: boolean)
	local sx, sy, sz = t.Size.X, t.Size.Y, t.Size.Z
	local top = withHips and sy * 0.25 or 0 -- у R6 торс один: рёбра в верхней части
	local h = withHips and sy * 0.5 or sy
	-- тёмная пустота внутри грудной клетки
	add(t, f, Vector3.new(sx * 0.78, h * 0.95, sz * 0.7), CFrame.new(0, top, 0), CAVITY, Enum.Material.SmoothPlastic)
	-- рёбра
	for i = 0, 4 do
		local y = top + h * 0.38 - i * h * 0.17
		for _, side in { -1, 1 } do
			local a = Vector3.new(side * 0.06, y, -sz * 0.5)
			local b = Vector3.new(side * sx * 0.45, y - 0.06, -sz * 0.28)
			local c = Vector3.new(side * sx * 0.47, y - 0.14, sz * 0.35)
			seg(t, f, a, b, 0.13, BONE, Enum.Material.Slate)
			seg(t, f, b, c, 0.12, BONE, Enum.Material.Slate)
		end
	end
	-- грудина и позвоночник
	seg(t, f, Vector3.new(0, top + h * 0.45, -sz * 0.52), Vector3.new(0, top - h * 0.3, -sz * 0.52), 0.16, BONE_DARK, Enum.Material.Slate)
	for i = 0, 6 do
		add(t, f, Vector3.new(0.3, 0.18, 0.25), CFrame.new(0, top + h * 0.45 - i * h * 0.16, sz * 0.55), BONE, Enum.Material.Slate)
	end
	-- плечи: мох, черепа, шипы
	for _, side in { -1, 1 } do
		local sh = CFrame.new(side * sx * 0.48, top + h * 0.45, 0)
		add(t, f, Vector3.new(1.3, 0.8, 1.4), sh, MOSS, Enum.Material.Grass, "ball")
		add(t, f, Vector3.new(0.9, 0.6, 1.0), sh * CFrame.new(side * -0.3, -0.3, 0.2), MOSS_DARK, Enum.Material.Grass, "ball")
		smallSkull(t, f, sh * CFrame.new(side * 0.15, 0.25, -0.45), 0.5)
		smallSkull(t, f, sh * CFrame.new(side * 0.05, 0.1, 0.55) * CFrame.Angles(0, math.pi, 0), 0.42)
		for k = 0, 3 do
			local base = Vector3.new(side * (sx * 0.48 + 0.2), top + h * 0.5, -0.4 + k * 0.3)
			spike(t, f, base, Vector3.new(side * 0.6, 1, (k - 1.5) * 0.3), 0.45 + k * 0.08)
		end
	end
	-- рваный шарф на шее
	add(t, f, Vector3.new(sx * 0.95, 0.35, sz * 1.15), CFrame.new(0, top + h * 0.5, 0), CLOTH, Enum.Material.Fabric)
	for i = 0, 3 do
		local x = -0.45 + i * 0.3
		add(t, f, Vector3.new(0.25, 0.5 + rng:NextNumber(0, 0.5), 0.05), CFrame.new(x, top + h * 0.2, -sz * 0.6) * CFrame.Angles(0, 0, rng:NextNumber(-0.2, 0.2)), CLOTH, Enum.Material.Fabric)
	end
end

local function hips(t: BasePart, f: Instance, y: number)
	local sx, sz = t.Size.X, t.Size.Z
	-- таз
	add(t, f, Vector3.new(sx * 0.85, 0.35, sz * 0.7), CFrame.new(0, y, 0), BONE_DARK, Enum.Material.Slate)
	-- набедренная повязка: передний и задний лоскуты + рваные полоски
	for _, zs in { -1, 1 } do
		add(t, f, Vector3.new(sx * 0.95, 0.9, 0.08), CFrame.new(0, y - 0.35, zs * sz * 0.58), CLOTH, Enum.Material.Fabric)
		for i = 0, 5 do
			local x = -sx * 0.4 + i * sx * 0.16
			local len = rng:NextNumber(0.5, 1.3)
			add(t, f, Vector3.new(sx * 0.14, len, 0.06), CFrame.new(x, y - 0.8 - len / 2, zs * sz * 0.6) * CFrame.Angles(zs * 0.08, 0, rng:NextNumber(-0.15, 0.15)), CLOTH, Enum.Material.Fabric)
		end
	end
	add(t, f, Vector3.new(sx + 0.1, 0.2, sz + 0.1), CFrame.new(0, y, 0), Color3.fromRGB(46, 36, 28), Enum.Material.Fabric) -- пояс
end

---------------------------------------------------------------------
-- Руки, ноги, когти
---------------------------------------------------------------------
local function limb(p: BasePart, f: Instance, side: number, spikes: number, skull: boolean)
	local sx, sy, sz = p.Size.X, p.Size.Y, p.Size.Z
	-- кость, обмотанная гнилой корой
	add(p, f, Vector3.new(sx * 0.75, sy * 1.02, sz * 0.75), CFrame.new(), BARK, Enum.Material.Wood)
	add(p, f, Vector3.new(sx * 0.45, sy * 0.9, sz * 0.45), CFrame.new(side * sx * 0.12, 0, -sz * 0.2), BONE_DARK, Enum.Material.Slate)
	-- мох кусками
	add(p, f, Vector3.new(sx * 0.6, sy * 0.35, sz * 0.6), CFrame.new(0, sy * 0.2, sz * 0.18), MOSS_DARK, Enum.Material.Grass, "ball")
	-- шипы снаружи
	for k = 1, spikes do
		local y = sy * 0.4 - k * sy / (spikes + 1)
		spike(p, f, Vector3.new(side * sx * 0.38, y, 0), Vector3.new(side, 0.35, 0.1), 0.35)
	end
	if skull then
		smallSkull(p, f, CFrame.new(side * sx * 0.45, 0, -0.05) * CFrame.Angles(0, side * -math.pi / 2, 0), 0.45)
	end
end

-- Длинные когти-серпы (вниз и чуть вперёд), как на мокапе
local function claws(p: BasePart, f: Instance, bottom: number, count: number, len: number)
	local sx = p.Size.X
	for i = 1, count do
		local x = -sx * 0.35 + (i - 1) * sx * 0.7 / math.max(1, count - 1)
		local a = Vector3.new(x, bottom, -0.1)
		local b = Vector3.new(x * 1.2, bottom - len * 0.45, -len * 0.22)
		local c = Vector3.new(x * 1.3, bottom - len, -len * 0.05)
		local d = Vector3.new(x * 1.3, bottom - len * 1.2, len * 0.15)
		seg(p, f, a, b, 0.16, CLAW, Enum.Material.Slate)
		seg(p, f, b, c, 0.12, CLAW, Enum.Material.Slate)
		seg(p, f, c, d, 0.07, BONE_DARK, Enum.Material.Slate)
	end
end

local function toeClaws(p: BasePart, f: Instance, bottom: number)
	local sx, sz = p.Size.X, p.Size.Z
	add(p, f, Vector3.new(sx * 0.9, 0.35, sz * 1.25), CFrame.new(0, bottom + 0.15, -sz * 0.15), BARK, Enum.Material.Wood)
	for i = -1, 1 do
		local a = Vector3.new(i * sx * 0.3, bottom + 0.15, -sz * 0.7)
		seg(p, f, a, a + Vector3.new(i * 0.1, -0.15, -0.55), 0.13, CLAW, Enum.Material.Slate)
	end
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
		head(h, f)
	end
	local upper = part("UpperTorso")
	local lower = part("LowerTorso")
	local torso = part("Torso")
	if upper then
		chest(upper, f, false)
	end
	if lower then
		hips(lower, f, 0)
	end
	if torso then -- R6
		chest(torso, f, true)
		hips(torso, f, -torso.Size.Y * 0.4)
	end
	for _, sideName in { "Left", "Right" } do
		local side = sideName == "Left" and -1 or 1
		-- R15
		local ua, la, hand = part(`{sideName}UpperArm`), part(`{sideName}LowerArm`), part(`{sideName}Hand`)
		if ua then
			limb(ua, f, side, 2, true)
		end
		if la then
			limb(la, f, side, 2, false)
		end
		if hand then
			claws(hand, f, -hand.Size.Y / 2, 4, 1.9)
		end
		local ul, ll, foot = part(`{sideName}UpperLeg`), part(`{sideName}LowerLeg`), part(`{sideName}Foot`)
		if ul then
			limb(ul, f, side, 1, false)
		end
		if ll then
			limb(ll, f, side, 2, false)
		end
		if foot then
			toeClaws(foot, f, -foot.Size.Y / 2)
		end
		-- R6
		local arm, leg = part(`{sideName} Arm`), part(`{sideName} Leg`)
		if arm then
			limb(arm, f, side, 4, true)
			claws(arm, f, -arm.Size.Y / 2, 4, 1.9)
		end
		if leg then
			limb(leg, f, side, 3, false)
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
