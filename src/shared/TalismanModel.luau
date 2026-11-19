-- Модель талисмана — оберега Марты: серебряная оправа-солнце с рунами,
-- тёмно-красный камень, который тлеет изнутри, и старая цепочка.
-- Талисман собирается из 3 частей, поэтому каждую часть можно построить отдельно.
--
--   TalismanModel.build(cf, { Chain = true, Stone = true, Frame = true }) → Model (детали закреплены)
--   TalismanModel.makeTool() → Tool «Талисман» (то, что держит выживший)
--   TalismanModel.preview()  → в Studio (Command Bar) положить большой талисман у дороги:
--     require(game.ReplicatedStorage.Shared.TalismanModel:Clone()).preview()

local TalismanModel = {}

local SILVER = Color3.fromRGB(176, 176, 168)
local SILVER_DARK = Color3.fromRGB(92, 92, 88)
local GARNET = Color3.fromRGB(105, 4, 10)
local GLOW = Color3.fromRGB(255, 40, 30)

TalismanModel.NAMES = { Chain = "Цепочка", Stone = "Камень", Frame = "Оправа" }

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Кольцо из маленьких отрезков (в плоскости XY части origin)
local function ring(model: Model, name: string, origin: CFrame, radius: number, count: number, thick: number, color: Color3)
	for i = 0, count - 1 do
		local a = i / count * math.pi * 2
		local len = 2 * math.pi * radius / count + 0.02
		part(model, name, Vector3.new(len, thick, thick), origin * CFrame.Angles(0, 0, a) * CFrame.new(0, radius, 0), color, Enum.Material.Metal)
	end
end

-- s — масштаб (1 = в руке, ~1.2 studs в высоту)
function TalismanModel.build(cf: CFrame, which: { [string]: boolean }?, s: number?): Model
	local w = which or { Chain = true, Stone = true, Frame = true }
	local k = s or 1
	local m = Instance.new("Model")
	m.Name = "Talisman"
	local core: Part? = nil

	if w.Frame then
		-- тёмный диск-основа (ось цилиндра — вдоль Z, лицом в -Z)
		local disc = part(m, "Core", Vector3.new(0.08, 1, 1) * k, cf * CFrame.Angles(0, math.pi / 2, 0), SILVER_DARK, Enum.Material.Metal)
		disc.Shape = Enum.PartType.Cylinder
		core = disc
		-- серебряный обод
		ring(m, "Rim", cf * CFrame.new(0, 0, -0.03 * k), 0.52 * k, 16, 0.09 * k, SILVER)
		-- 8 лучей-«когтей» наружу
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			part(m, "Ray", Vector3.new(0.07, 0.28, 0.06) * k, cf * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.68 * k, 0), SILVER, Enum.Material.Metal)
		end
		-- руны по кругу
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2 + 0.3
			part(m, "Rune", Vector3.new(0.05, 0.14, 0.02) * k, cf * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.36 * k, -0.05 * k) * CFrame.Angles(0, 0, 0.5), Color3.fromRGB(60, 20, 18), Enum.Material.SmoothPlastic)
		end
		-- петелька сверху
		ring(m, "Bail", cf * CFrame.new(0, 0.72 * k, 0) * CFrame.Angles(0, math.pi / 2, 0), 0.09 * k, 6, 0.05 * k, SILVER)
	end

	if w.Stone then
		local stone = part(m, "Stone", Vector3.new(0.42, 0.5, 0.26) * k, cf * CFrame.new(0, 0, -0.1 * k), GARNET, Enum.Material.SmoothPlastic)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = stone
		stone.Reflectance = 0.04
		local inner = part(m, "Ember", Vector3.new(0.1, 0.13, 0.06) * k, cf * CFrame.new(-0.06 * k, 0.08 * k, -0.21 * k), GLOW, Enum.Material.Neon)
		local mesh2 = mesh:Clone()
		mesh2.Parent = inner
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = GLOW
		light.Brightness = 0.8
		light.Range = 6
		light.Shadows = false
		light.Parent = inner
		core = core or stone
	end

	if w.Chain then
		-- цепочка: петля из сцепленных колечек (каждое — кольцо из 6 кусочков),
		-- соседние колечки повёрнуты на 90°, как у настоящей цепи
		local count = 34
		local rx, ry, cy = 0.55, 0.75, 1.55
		for i = 0, count - 1 do
			local ang = -math.pi / 2 + i / count * math.pi * 2
			local pos = Vector3.new(rx * math.cos(ang), cy + ry * math.sin(ang), 0) * k
			local tangent = Vector3.new(-rx * math.sin(ang), ry * math.cos(ang), 0).Unit
			local frame = cf * CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, i % 2 == 0 and 0 or math.pi / 2) * CFrame.Angles(0, math.pi / 2, 0)
			ring(m, 'Link', frame, 0.075 * k, 6, 0.03 * k, SILVER)
		end
		core = core or m:FindFirstChild('Link') :: Part
	end

	m.PrimaryPart = core
	return m
end

-- Инструмент «Талисман»: Handle + все детали приварены к нему
function TalismanModel.makeTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Талисман"
	tool.ToolTip = "ЛКМ — обжечь монстра (подойди ближе)"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local model = TalismanModel.build(CFrame.new(), nil, 1)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 0.4)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			p.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = p
			weld.Parent = p
			p.Parent = tool
		end
	end
	model:Destroy()
	-- держим перед собой, камнем вперёд
	tool.Grip = CFrame.new(0, -0.3, -0.5) * CFrame.Angles(0, math.pi, 0)
	return tool
end

function TalismanModel.preview(): Model
	local old = workspace:FindFirstChild("TalismanPreview")
	if old then
		old:Destroy()
	end
	local m = TalismanModel.build(CFrame.new(10, 6, -100), nil, 4)
	m.Name = "TalismanPreview"
	m.Parent = workspace
	print("THE NEST: большой талисман у дороги (Workspace.TalismanPreview)")
	return m
end

return TalismanModel
