-- Выдаёт слабый фонарик выжившим. Монстра он не останавливает —
-- он только помогает видеть. Включается кликом (Tool.Activated).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TOOL_NAME = "Flashlight"

-- Собираем фонарик целиком из кода (в Studio ничего делать не нужно)
local function createFlashlight(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 1.2)
	handle.Color = Color3.fromRGB(40, 40, 40)
	handle.Material = Enum.Material.Metal
	handle.Parent = tool

	local light = Instance.new("SpotLight")
	light.Name = "Beam"
	light.Face = Enum.NormalId.Front
	light.Brightness = Config.FLASHLIGHT_BRIGHTNESS
	light.Range = Config.FLASHLIGHT_RANGE
	light.Angle = Config.FLASHLIGHT_ANGLE
	light.Enabled = false
	light.Parent = handle

	-- Клик включает/выключает луч
	tool.Activated:Connect(function()
		light.Enabled = not light.Enabled
	end)

	return tool
end

-- Убираем фонарик и из рюкзака, и из рук
local function removeFlashlight(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		local tool = backpack:FindFirstChild(TOOL_NAME)
		if tool then
			tool:Destroy()
		end
	end
	if player.Character then
		local tool = player.Character:FindFirstChild(TOOL_NAME)
		if tool then
			tool:Destroy()
		end
	end
end

local function giveFlashlight(player: Player)
	removeFlashlight(player) -- чтобы не было двух фонариков
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		createFlashlight().Parent = backpack
	end
end

local function onRoleChanged(player: Player)
	if player:GetAttribute("Role") == "Survivor" then
		giveFlashlight(player)
	else
		-- Monster, Dead или nil (лобби) — фонарика нет
		removeFlashlight(player)
	end
end

local function onPlayerAdded(player: Player)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		onRoleChanged(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- На случай, если игрок зашёл раньше, чем скрипт запустился
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
