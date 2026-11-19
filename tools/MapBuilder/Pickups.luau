-- Точки, где могут появиться бинты (Workspace.BandageSpawns).
-- Точка висит на 7 studs над полом: сервер пускает луч вниз и кладёт бинт на пол, стол или полку.
-- Closed = true — закрытая локация: там всегда 1–2 бинта (Area — имя локации).
-- Можно запустить отдельно, не перестраивая карту:
--   require(game.ServerStorage.Tools.MapBuilder.Pickups:Clone()).build()

local Pickups = {}

local G, S, B = 2, 17, -12 -- пол 1 этажа, 2 этажа, подвала
local SHED = 0.3

-- открытые комнаты дома
local OPEN = {
	{ "Hall", -8, G, -24 },
	{ "Kitchen", -30, G, -20 },
	{ "Dining", -24, G, 5 },
	{ "Laundry", -30, G, 28 },
	{ "BackCorridor", 0, G, 26 },
	{ "LivingRoom", 34, G, -14 },
	{ "Library", 30, G, 26 },
	{ "Landing", -4, S, 30 },
	{ "KidsRoom", -34, S, -20 },
	{ "SewingRoom", -30, S, 4 },
	{ "MarthaRoom", -24, S, 25 },
	{ "MasterBedroom", 36, S, -18 },
	{ "Bathroom", 22, S, 8 },
	{ "GuestRoom", 44, S, 18 },
}

-- закрытые локации: в каждой 1–2 бинта
local CLOSED = {
	{ "Pantry", -44, G, 1 },
	{ "Pantry", -50, G, -1 },
	{ "Closet", 20, S, 28 },
	{ "Closet", 27, S, 32 },
	{ "BasementStorage", -20, B, 20 },
	{ "BasementStorage", 0, B, 10 },
	{ "CoalRoom", -44, B, 26 },
	{ "CoalRoom", -48, B, 18 },
	{ "GeneratorRoom", -4, B, -20 },
	{ "GeneratorRoom", 4, B, -30 },
	{ "Shed", 66, SHED, 35 },
	{ "Shed", 63, SHED, 38 },
}

local function marker(parent: Instance, area: string, x: number, y: number, z: number, closed: boolean)
	local p = Instance.new("Part")
	p.Name = `Bandage_{area}`
	p.Size = Vector3.new(1, 1, 1)
	p.Position = Vector3.new(x, y + 7, z)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Transparency = 1
	p:SetAttribute("Area", area)
	p:SetAttribute("Closed", closed)
	p.Parent = parent
end

function Pickups.build(): Folder
	local old = workspace:FindFirstChild("BandageSpawns")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "BandageSpawns"
	for _, s in OPEN do
		marker(folder, s[1], s[2], s[3], s[4], false)
	end
	for _, s in CLOSED do
		marker(folder, s[1], s[2], s[3], s[4], true)
	end
	folder.Parent = workspace
	print(`THE NEST: точек для бинтов {#OPEN} открытых, {#CLOSED} в закрытых локациях`)
	return folder
end

return Pickups
