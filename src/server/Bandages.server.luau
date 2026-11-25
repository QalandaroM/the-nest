-- Бинты.
-- В начале раунда: BANDAGES_OPEN бинтов в случайных открытых комнатах дома
-- и по 1–2 в каждой закрытой локации (подвал, кладовая, кладовка, сарай).
-- Точки — детали в Workspace.BandageSpawns с атрибутами Area (имя локации) и Closed (true/false).
-- Подобрать (E) могут только выжившие. Использовать — инструмент «Бинт» (клик), сколько их — атрибут Bandages.
-- Аптечки: Config.MEDKITS штук на точках, где не лёг бинт (сначала в закрытых локациях).
-- Инструмент «Аптечка» (клик), сколько их — атрибут Medkits. Лечит всё, даже хромоту и дрожь от глубоких ран.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Wounds = require(script.Parent.Wounds)

local TOOL_NAME = "Бинт"
local MEDKIT_TOOL = "Аптечка"
local feedback = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HitFeedback") :: RemoteEvent

local rng = Random.new()
local pickups = Instance.new("Folder")
pickups.Name = "Bandages"
pickups.Parent = workspace

local function notice(player: Player, text: string)
	feedback:FireClient(player, "Notice", { text = text })
end

---------------------------------------------------------------------
-- Инструмент «Бинт» в рюкзаке (один на все бинты, счётчик — атрибут Bandages)
---------------------------------------------------------------------
local function findTool(player: Player, name: string): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild(name)
	if not tool then
		local backpack = player:FindFirstChildOfClass("Backpack")
		tool = backpack and backpack:FindFirstChild(name)
	end
	return tool :: Tool?
end

local function useBandage(player: Player)
	if player:GetAttribute("Role") ~= "Survivor" or (player:GetAttribute("Bandages") or 0) <= 0 then
		return
	end
	local ok, reason = Wounds.canBandage(player)
	if not ok then
		notice(player, reason or "")
		return
	end
	local used, why = Wounds.bandage(player)
	if used then
		player:SetAttribute("Bandages", math.max(0, (player:GetAttribute("Bandages") or 0) - 1))
		notice(player, "Рана перевязана")
	elseif why then
		notice(player, why)
	end
end

local function useMedkit(player: Player)
	if player:GetAttribute("Role") ~= "Survivor" or (player:GetAttribute("Medkits") or 0) <= 0 then
		return
	end
	local ok, reason = Wounds.canMedkit(player)
	if not ok then
		notice(player, reason or "")
		return
	end
	local used, why = Wounds.medkit(player)
	if used then
		player:SetAttribute("Medkits", math.max(0, (player:GetAttribute("Medkits") or 0) - 1))
		notice(player, "Раны вылечены")
	elseif why then
		notice(player, why)
	end
end

-- Есть предметы (атрибут > 0) — инструмент в рюкзаке, кончились — убираем
local function updateItem(player: Player, attr: string, name: string, tip: string, use: (Player) -> ())
	local count = player:GetAttribute(attr) or 0
	local tool = findTool(player, name)
	if count > 0 and player:GetAttribute("Role") == "Survivor" then
		if not tool then
			local backpack = player:FindFirstChildOfClass("Backpack")
			if not backpack then
				return
			end
			local newTool = Instance.new("Tool")
			newTool.Name = name
			newTool.RequiresHandle = false
			newTool.CanBeDropped = false
			newTool.ToolTip = tip
			newTool.Activated:Connect(function()
				use(player)
			end)
			newTool.Parent = backpack
		end
	elseif tool then
		tool:Destroy()
	end
end

local function updateTool(player: Player)
	updateItem(player, "Bandages", TOOL_NAME, "ЛКМ — перевязать рану", useBandage)
	updateItem(player, "Medkits", MEDKIT_TOOL, "ЛКМ — вылечить все раны", useMedkit)
end

local function onPlayer(player: Player)
	player:GetAttributeChangedSignal("Bandages"):Connect(function()
		updateTool(player)
	end)
	player:GetAttributeChangedSignal("Medkits"):Connect(function()
		updateTool(player)
	end)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		if player:GetAttribute("Role") ~= "Survivor" then
			player:SetAttribute("Bandages", nil)
			player:SetAttribute("Medkits", nil)
		end
		updateTool(player)
	end)
	-- после смерти/респавна рюкзак новый
	player.CharacterAdded:Connect(function()
		task.defer(updateTool, player)
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end

---------------------------------------------------------------------
-- Бинт на полу: свёрток из деталей
---------------------------------------------------------------------
local function surfaceBelow(pos: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { pickups }
	local result = workspace:Raycast(pos, Vector3.new(0, -14, 0), params)
	return result and result.Position or nil
end

local function spawnBandage(pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "Bandage"
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)

	local roll = Instance.new("Part")
	roll.Name = "Roll"
	roll.Shape = Enum.PartType.Cylinder
	roll.Size = Vector3.new(0.5, 0.55, 0.55)
	roll.CFrame = cf * CFrame.new(0, 0.28, 0)
	roll.Color = Color3.fromRGB(214, 206, 186)
	roll.Material = Enum.Material.Fabric
	roll.Anchored = true
	roll.CanCollide = false
	roll.Parent = model

	-- размотанный хвост с пятнами
	local tail = Instance.new("Part")
	tail.Size = Vector3.new(0.4, 0.03, 0.9)
	tail.CFrame = cf * CFrame.new(0, 0.02, 0.6)
	tail.Color = Color3.fromRGB(200, 190, 168)
	tail.Material = Enum.Material.Fabric
	tail.Anchored = true
	tail.CanCollide = false
	tail.Parent = model

	local stain = Instance.new("Part")
	stain.Size = Vector3.new(0.25, 0.035, 0.25)
	stain.CFrame = cf * CFrame.new(0.05, 0.03, 0.8)
	stain.Color = Color3.fromRGB(90, 20, 15)
	stain.Material = Enum.Material.Fabric
	stain.Anchored = true
	stain.CanCollide = false
	stain.Parent = model

	-- чуть-чуть заметен в темноте
	local glow = Instance.new("PointLight")
	glow.Brightness = 0.2
	glow.Range = 3
	glow.Color = Color3.fromRGB(255, 240, 220)
	glow.Parent = roll
	model.PrimaryPart = roll

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять бинт"
	prompt.ObjectText = "Бинт"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.4
	prompt:SetAttribute("ForRole", "Survivor")
	prompt.Parent = roll

	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("Role") ~= "Survivor" or not model.Parent then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		Wounds.playAt(humanoid.Parent:FindFirstChild("HumanoidRootPart") or roll, Sounds.BandagePickup, 0.6)
		model:Destroy()
		player:SetAttribute("Bandages", (player:GetAttribute("Bandages") or 0) + 1)
	end)

	model.Parent = pickups
end

---------------------------------------------------------------------
-- Аптечка на полу: белый ящичек с красным крестом
---------------------------------------------------------------------
local function spawnMedkit(pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "Medkit"
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)

	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = Vector3.new(1.1, 0.5, 0.8)
	box.CFrame = cf * CFrame.new(0, 0.25, 0)
	box.Color = Color3.fromRGB(215, 210, 200)
	box.Material = Enum.Material.SmoothPlastic
	box.Anchored = true
	box.CanCollide = false
	box.Parent = model

	-- красный крест на крышке
	for _, size in { Vector3.new(0.45, 0.03, 0.14), Vector3.new(0.14, 0.03, 0.45) } do
		local bar = Instance.new("Part")
		bar.Size = size
		bar.CFrame = cf * CFrame.new(0, 0.51, 0)
		bar.Color = Color3.fromRGB(170, 20, 20)
		bar.Material = Enum.Material.SmoothPlastic
		bar.Anchored = true
		bar.CanCollide = false
		bar.Parent = model
	end
	-- ручка
	local grip = Instance.new("Part")
	grip.Size = Vector3.new(0.4, 0.08, 0.08)
	grip.CFrame = cf * CFrame.new(0, 0.25, -0.44)
	grip.Color = Color3.fromRGB(60, 60, 60)
	grip.Anchored = true
	grip.CanCollide = false
	grip.Parent = model

	-- чуть-чуть заметна в темноте (красноватый отсвет)
	local glow = Instance.new("PointLight")
	glow.Brightness = 0.25
	glow.Range = 3.5
	glow.Color = Color3.fromRGB(255, 200, 200)
	glow.Parent = box
	model.PrimaryPart = box

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять аптечку"
	prompt.ObjectText = "Аптечка"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.5
	prompt:SetAttribute("ForRole", "Survivor")
	prompt.Parent = box

	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("Role") ~= "Survivor" or not model.Parent then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		Wounds.playAt(humanoid.Parent:FindFirstChild("HumanoidRootPart") or box, Sounds.BandagePickup, 0.6)
		model:Destroy()
		player:SetAttribute("Medkits", (player:GetAttribute("Medkits") or 0) + 1)
	end)

	model.Parent = pickups
end

-- Перемешать список
local function shuffle<T>(list: { T }): { T }
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function spawnAll()
	pickups:ClearAllChildren()
	local spawns = workspace:FindFirstChild("BandageSpawns")
	if not spawns then
		warn("Нет Workspace.BandageSpawns — бинты не появятся (перестройте карту MapBuilder)")
		return
	end
	local open = {}
	local closed: { [string]: { BasePart } } = {}
	for _, point in spawns:GetChildren() do
		if point:IsA("BasePart") then
			if point:GetAttribute("Closed") then
				local area = point:GetAttribute("Area") or point.Name
				closed[area] = closed[area] or {}
				table.insert(closed[area], point)
			else
				table.insert(open, point)
			end
		end
	end

	local used: { [BasePart]: boolean } = {}
	local function place(point: BasePart, spawn: (Vector3) -> ())
		local pos = surfaceBelow(point.Position)
		if pos then
			spawn(pos)
			used[point] = true
		end
	end

	shuffle(open)
	for i = 1, math.min(Config.BANDAGES_OPEN, #open) do
		place(open[i], spawnBandage)
	end
	for _, points in closed do
		shuffle(points)
		local count = rng:NextInteger(Config.BANDAGES_CLOSED_MIN, Config.BANDAGES_CLOSED_MAX)
		for i = 1, math.min(count, #points) do
			place(points[i], spawnBandage)
		end
	end

	-- аптечки — на свободных точках: сначала в закрытых локациях (их надо поискать), потом в комнатах
	local free = {}
	for _, points in closed do
		for _, point in points do
			if not used[point] then
				table.insert(free, point)
			end
		end
	end
	shuffle(free)
	local freeOpen = {}
	for _, point in open do
		if not used[point] then
			table.insert(freeOpen, point)
		end
	end
	shuffle(freeOpen)
	for _, point in freeOpen do
		table.insert(free, point)
	end
	for i = 1, math.min(Config.MEDKITS, #free) do
		place(free[i], spawnMedkit)
	end
end

workspace:GetAttributeChangedSignal("RoundActive"):Connect(function()
	if workspace:GetAttribute("RoundActive") then
		for _, player in Players:GetPlayers() do
			player:SetAttribute("Bandages", nil)
			player:SetAttribute("Medkits", nil)
		end
		spawnAll()
	else
		pickups:ClearAllChildren()
	end
end)
