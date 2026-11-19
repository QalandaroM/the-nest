-- Предметы для квестов на талисман (логика — в src/server/Talisman.server.luau).
-- Всё лежит в Workspace.Quest:
--   Safe        — сейф в спальне Томаса (код из 4 цифр, цифры в записках)        → цепочка
--   Chest       — ящик Томаса у генератора, электрозамок работает только при токе → камень
--   Candle_*    — свечи у могил: зажечь в правильном порядке (подсказка — рисунок Лили) → оправа
--   Altar       — алтарь в библиотеке: положить 3 части → появится талисман
--   CodeNotes   — точки, где могут лежать записки с цифрами кода
--   RitualNote  — точка, где лежит рисунок Лили с порядком свечей

local Kit = require(script.Parent.Kit)

local M, C = Kit.M, Kit.C
local G, S, B = Kit.G, Kit.S, Kit.B
local at, folder, piece = Kit.at, Kit.folder, Kit.piece

local Quest = {}

local NX, PZ, NZ = Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1)
local STEEL = Color3.fromRGB(58, 60, 62)
local STONE = Color3.fromRGB(84, 82, 78)

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Сейф: дверца (SafeDoor) на петлях слева, внутри полка
local function safe(parent: Instance)
	local m = model(parent, "Safe")
	local o = at(44, S, -34.2, PZ) -- в спальне Томаса у южной стены, лицом в комнату
	local body = piece(m, o, Vector3.new(0, 1.8, 0), Vector3.new(3.2, 3.6, 2.4), STEEL, M.metal, { Name = "Body" })
	piece(m, o, Vector3.new(0, 1.8, -1.05), Vector3.new(2.5, 2.9, 0.4), Color3.fromRGB(10, 10, 10), M.smooth, { CanCollide = false, Name = "Inside" })
	local door = piece(m, o, Vector3.new(0, 1.8, -1.28), Vector3.new(2.7, 3.1, 0.16), Color3.fromRGB(70, 72, 74), M.metal, { Name = "SafeDoor" })
	door:SetAttribute("HingeLocal", Vector3.new(-1.35, 0, 0))
	local dial = Kit.cylinder(m, o * CFrame.new(0.5, 2.1, -1.4) * CFrame.Angles(math.pi / 2, 0, 0), 0.12, 0.8, Color3.fromRGB(150, 140, 110), M.metal, { CanCollide = false, Name = "Dial" })
	local handle = piece(m, o, Vector3.new(0.5, 1.2, -1.42), Vector3.new(0.15, 0.7, 0.12), Color3.fromRGB(150, 140, 110), M.metal, { CanCollide = false, Name = "Handle" })
	for _, p in { dial, handle } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = door
		weld.Part1 = p
		weld.Parent = door
		p.Anchored = false
	end
	-- на сейфе процарапано «4 цифры»
	piece(m, o, Vector3.new(0, 3.62, 0), Vector3.new(3.2, 0.04, 2.4), Color3.fromRGB(40, 40, 40), M.smooth, { CanCollide = false })
	m.PrimaryPart = body
end

-- Ящик Томаса с электрозамком (у генератора, на месте старого щитка предохранителей)
local function chest(parent: Instance)
	local m = model(parent, "Chest")
	local o = at(8.2, B, -22, NX) -- у восточной стены генераторной, лицом на запад
	local body = piece(m, o, Vector3.new(0, 1, 0), Vector3.new(3.6, 2, 2.2), Color3.fromRGB(62, 44, 30), M.wood, { Name = "Body" })
	for _, x in { -1.6, 1.6 } do
		piece(m, o, Vector3.new(x, 1, 0), Vector3.new(0.2, 2.05, 2.25), C.rust, M.rust, { CanCollide = false })
	end
	local lid = piece(m, o, Vector3.new(0, 2.15, 0), Vector3.new(3.7, 0.3, 2.3), Color3.fromRGB(70, 50, 34), M.wood, { Name = "Lid" })
	lid:SetAttribute("HingeLocal", Vector3.new(0, 0, 1.15)) -- петли сзади
	piece(m, o, Vector3.new(0, 1.6, -1.2), Vector3.new(0.9, 0.8, 0.25), Color3.fromRGB(40, 42, 40), M.metal, { Name = "Lock", CanCollide = false })
	local led = piece(m, o, Vector3.new(0, 1.85, -1.34), Vector3.new(0.2, 0.2, 0.05), Color3.fromRGB(190, 20, 20), M.neon, { Name = "LockLight", CanCollide = false })
	Kit.addLight(led, 0.5, 5, Color3.fromRGB(255, 40, 30), false)
	-- провод к замку
	Kit.box(m, 6, B + 0.05, -22.2, 7, B + 0.25, -21.8, Color3.fromRGB(15, 15, 15), M.smooth, { CanCollide = false })
	m.PrimaryPart = body
end

-- Свеча у могилы (не горит, пока её не зажгут)
local function graveCandle(parent: Instance, name: string, x: number)
	local m = model(parent, `Candle_{name}`)
	local o = at(x, 0, 70.4, NZ)
	local base = piece(m, o, Vector3.new(0, 0.4, 0), Vector3.new(1.4, 0.8, 1.4), STONE, M.slate, { Name = "Base" })
	piece(m, o, Vector3.new(0, 1.3, 0), Vector3.new(0.45, 1, 0.45), Color3.fromRGB(200, 190, 160), M.smooth, { Name = "Wax", CanCollide = false })
	local flame = piece(m, o, Vector3.new(0, 1.95, 0), Vector3.new(0.18, 0.32, 0.18), C.warm, M.neon, { Name = "Flame", CanCollide = false, Transparency = 1 })
	local light = Kit.addLight(flame, 1, 12, Color3.fromRGB(255, 160, 80))
	light.Enabled = false
	m.PrimaryPart = base
	m:SetAttribute("Grave", name)
end

-- Алтарь в библиотеке: 3 гнезда под части талисмана
local function altar(parent: Instance)
	local m = model(parent, "Altar")
	local o = at(44, G, 29, NZ)
	local body = piece(m, o, Vector3.new(0, 1.3, 0), Vector3.new(5, 2.6, 2.6), STONE, M.slate, { Name = "Body" })
	piece(m, o, Vector3.new(0, 2.7, 0), Vector3.new(5.4, 0.2, 3), Color3.fromRGB(70, 68, 64), M.slate)
	for i, key in { "Chain", "Stone", "Frame" } do
		Kit.cylinder(m, o * CFrame.new(-1.6 + (i - 1) * 1.6, 2.83, 0), 0.06, 1.1, Color3.fromRGB(30, 28, 26), M.slate, { Name = `Socket_{key}`, CanCollide = false })
	end
	-- руны (чтобы алтарь было видно издалека — слабое красное свечение)
	local rune = piece(m, o, Vector3.new(0, 1.4, -1.32), Vector3.new(3, 0.12, 0.05), Color3.fromRGB(120, 20, 18), M.neon, { CanCollide = false, Name = "Rune" })
	Kit.addLight(rune, 0.4, 8, Color3.fromRGB(200, 40, 30), false)
	m.PrimaryPart = body
end

function Quest.build(): Folder
	local old = workspace:FindFirstChild("Quest")
	if old then
		old:Destroy()
	end
	local q = folder(workspace, "Quest")
	safe(q)
	chest(q)
	for i, name in { "Thomas", "Martha", "Lily" } do
		graveCandle(q, name, 38 + i * 5)
	end
	altar(q)

	-- Где могут лежать записки с цифрами кода. Точка над мебелью или полом:
	-- сервер пускает луч вниз и кладёт записку на то, что под точкой.
	local notes = folder(q, "CodeNotes")
	for _, spot in {
		{ "Kitchen", -35.5, G, -20.5 },
		{ "Pantry", -44, G, -1 },
		{ "Laundry", -30, G, 30 },
		{ "LivingRoom", 30, G, -8 },
		{ "Hall", -11, G, -7 },
		{ "Landing", 0, S, 30 },
		{ "GuestRoom", 40, S, 10 },
		{ "Bathroom", 22, S, 10 },
		{ "MarthaRoom", -28, S, 25 },
		{ "CoalRoom", -40, B, 20 },
		{ "Storage", -14, B, 20 },
		{ "Shed", 70, 0.3, 36 },
	} do
		Kit.marker(notes, `CodeNote_{spot[1]}`, Vector3.new(spot[2], spot[3] + 5, spot[4]), Vector3.new(1, 1, 1))
	end
	Kit.marker(q, "RitualNote", Vector3.new(-30, S + 5, -20), Vector3.new(1, 1, 1))
	return q
end

return Quest
