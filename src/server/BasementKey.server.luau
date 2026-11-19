-- Ключ от двери в подвал (дверь из дома, в кладовой у столовой).
-- Каждый раунд ключ появляется в одной случайной точке из Workspace.KeySpawns.
-- Поднять и открыть дверь могут только выжившие. Монстр ходит в подвал через уличный люк.
-- Если выживший с ключом умер или ушёл — ключ падает на землю.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

local KEY_NAME = "BasementKey"

local function playAt(parent: Instance, id: string, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.RollOffMaxDistance = 60
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function removeKey()
	local old = workspace:FindFirstChild(KEY_NAME)
	if old then
		old:Destroy()
	end
end

-- Ищем, на что положить ключ (стол, пол) под точкой
local function surfaceBelow(pos: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), params)
	return result and result.Position or pos
end

local spawnKey: (Vector3) -> ()

-- Собираем ключ из деталей: кольцо, стержень, бородка
local function buildKey(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = KEY_NAME
	local gold = Color3.fromRGB(176, 140, 60)
	local function part(size: Vector3, cf: CFrame, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = cf
		p.Color = gold
		p.Material = Enum.Material.Metal
		p.Reflectance = 0.2
		p.Anchored = true
		p.CanCollide = false
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end
	local base = CFrame.new(position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local ring = part(Vector3.new(0.15, 0.7, 0.7), base * CFrame.new(-0.6, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
	part(Vector3.new(1.1, 0.12, 0.14), base * CFrame.new(0.25, 0, 0))
	part(Vector3.new(0.14, 0.12, 0.3), base * CFrame.new(0.7, 0, 0.15))
	part(Vector3.new(0.14, 0.12, 0.22), base * CFrame.new(0.5, 0, 0.11))
	-- слабый блик, чтобы ключ можно было заметить фонариком
	local glint = Instance.new("PointLight")
	glint.Brightness = 0.35
	glint.Range = 4
	glint.Color = Color3.fromRGB(255, 220, 140)
	glint.Parent = ring
	model.PrimaryPart = ring

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять ключ"
	prompt.ObjectText = "Ключ от подвала"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ForRole", "Survivor") -- клиент покажет только выжившим
	prompt.Parent = ring

	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("Role") ~= "Survivor" or player:GetAttribute("HasKey") then
			return
		end
		playAt(ring, Sounds.KeyPickup, 0.8)
		model:Destroy()
		player:SetAttribute("HasKey", true)
	end)
	return model
end

spawnKey = function(position: Vector3)
	removeKey()
	local key = buildKey(surfaceBelow(position, {}))
	key.Parent = workspace
end

local function spawnRandom()
	local spawns = workspace:FindFirstChild("KeySpawns")
	local list = spawns and spawns:GetChildren() or {}
	if #list == 0 then
		warn("BasementKey: нет точек Workspace.KeySpawns, ключ не появится")
		return
	end
	local point = list[math.random(1, #list)] :: BasePart
	spawnKey(point.Position)
end

-- Ключ выпадает, если владелец умер / стал не выжившим / вышел
local function dropKey(player: Player)
	if not player:GetAttribute("HasKey") then
		return
	end
	player:SetAttribute("HasKey", nil)
	if not workspace:GetAttribute("RoundActive") then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local character = player.Character :: Model
		removeKey()
		local key = buildKey(surfaceBelow(root.Position, { character }))
		key.Parent = workspace
	else
		spawnRandom()
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			dropKey(player)
		end)
	end)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		if player:GetAttribute("Role") ~= "Survivor" then
			dropKey(player)
		end
	end)
end)
Players.PlayerRemoving:Connect(dropKey)

-- Дверь в подвал: открыть может выживший с ключом
local function setupKeyDoor(door: Instance)
	if not door:IsA("BasePart") or not door:GetAttribute("KeyDoor") then
		return
	end
	local prompt = door:WaitForChild("ProximityPrompt", 10) :: ProximityPrompt?
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		if not door:GetAttribute("Locked") then
			return
		end
		if player:GetAttribute("Role") == "Survivor" and player:GetAttribute("HasKey") then
			player:SetAttribute("HasKey", nil) -- ключ остаётся в замке
			playAt(door, Sounds.DoorUnlock, 0.9)
			door:SetAttribute("Locked", false)
			door:SetAttribute("SwingRequest", true) -- Doors.server.luau откроет дверь
		end
	end)
end

for _, door in CollectionService:GetTagged("Door") do
	task.spawn(setupKeyDoor, door)
end

-- Новый раунд: запираем дверь, забираем ключи, кладём новый ключ
workspace:GetAttributeChangedSignal("RoundActive"):Connect(function()
	if workspace:GetAttribute("RoundActive") then
		for _, player in Players:GetPlayers() do
			player:SetAttribute("HasKey", nil)
		end
		for _, door in CollectionService:GetTagged("Door") do
			if door:GetAttribute("KeyDoor") then
				door:SetAttribute("Locked", true)
			end
		end
		spawnRandom()
	else
		removeKey()
	end
end)
