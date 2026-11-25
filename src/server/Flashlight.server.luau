-- Фонарик выжившего: помогает видеть, а если посветить прямо на монстра — тот замирает
-- (это делает LightFreeze.server.luau).
-- Клик включает/выключает луч. Батарея (атрибут Battery у Tool, 0..100):
--   * садится, пока луч горит: полный заряд = Config.FLASHLIGHT_BATTERY_TIME сек;
--   * заряжается у проводки (модели с тегом "ChargePoint"), держа E:
--     щиток починен — 0→100% за CHARGE_TIME_POWERED сек, сломан — за CHARGE_TIME_UNPOWERED.
-- Пока игрок заряжается, у него атрибут Charging = true (его показывает HUD).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local TOOL_NAME = "Flashlight"
local TICK = 0.25

local charging: { [Player]: BasePart } = {}

local function click(parent: Instance)
	local sound = Instance.new("Sound")
	sound.SoundId = Sounds.FlashlightClick
	sound.Volume = 0.6
	sound.RollOffMaxDistance = 30
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

-- Собираем фонарик целиком из кода (в Studio ничего делать не нужно)
local function createFlashlight(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("Battery", 100)

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

	-- Клик включает/выключает луч (если батарея не пустая)
	tool.Activated:Connect(function()
		local battery = tool:GetAttribute("Battery") :: number
		if not light.Enabled and battery <= 0 then
			click(handle)
			return
		end
		light.Enabled = not light.Enabled
		click(handle)
	end)

	return tool
end

local function findFlashlight(player: Player): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild(TOOL_NAME)
	if not tool then
		local backpack = player:FindFirstChildOfClass("Backpack")
		tool = backpack and backpack:FindFirstChild(TOOL_NAME)
	end
	return tool :: Tool?
end

-- Убираем фонарик и из рюкзака, и из рук
local function removeFlashlight(player: Player)
	local tool = findFlashlight(player)
	while tool do
		tool:Destroy()
		tool = findFlashlight(player)
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
		charging[player] = nil
		player:SetAttribute("Charging", nil)
	end
end

local function onPlayerAdded(player: Player)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		onRoleChanged(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerRemoving:Connect(function(player)
	charging[player] = nil
end)

---------------------------------------------------------------------
-- Точки зарядки (проводка)
---------------------------------------------------------------------
local function setupChargePoint(model: Instance)
	local box = (model:IsA("Model") and model.PrimaryPart) or model:FindFirstChild("Box")
	if not box or not box:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChargePrompt"
	prompt.ActionText = "Зарядить фонарик (держи E)"
	prompt.ObjectText = "Проводка"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt:SetAttribute("ForRole", "Survivor")
	prompt.Parent = box

	-- искры на проводах, когда есть ток (включает PowerPanel.server.luau)
	local sparkPoint = box:FindFirstChild("SparkPoint") or box
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PowerSparks"
	emitter.Color = ColorSequence.new(Color3.fromRGB(180, 220, 255))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.1, 0)
	emitter.Lifetime = NumberRange.new(0.1, 0.3)
	emitter.Speed = NumberRange.new(3, 7)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, -25, 0)
	emitter.Rate = 6
	emitter.Enabled = workspace:GetAttribute("Power") == true
	emitter.Parent = sparkPoint

	local hum = Instance.new("Sound")
	hum.SoundId = Sounds.ChargeHum
	hum.Looped = true
	hum.Volume = 0.3
	hum.RollOffMaxDistance = 25
	hum.Parent = box

	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("Role") == "Survivor" and findFlashlight(player) then
			charging[player] = box
			player:SetAttribute("Charging", true)
			hum:Play()
		end
	end)
	prompt.TriggerEnded:Connect(function(player)
		if charging[player] == box then
			charging[player] = nil
			player:SetAttribute("Charging", nil)
		end
		local anyone = false
		for _, b in charging do
			if b == box then
				anyone = true
			end
		end
		if not anyone then
			hum:Stop()
		end
	end)
end

for _, cp in CollectionService:GetTagged("ChargePoint") do
	setupChargePoint(cp)
end
CollectionService:GetInstanceAddedSignal("ChargePoint"):Connect(setupChargePoint)

---------------------------------------------------------------------
-- Раненая рука: фонарик дрожит (атрибут ArmShake = сила дрожи в градусах, его ставит Wounds).
-- Крутим хват инструмента (Grip) — луч дрожит у всех, и монстра труднее держать в свете (LightFreeze).
---------------------------------------------------------------------
local baseGrip: { [Tool]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
task.spawn(function()
	while true do
		task.wait(Config.ARM_SHAKE_TICK)
		local t = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local tool = character and character:FindFirstChild(TOOL_NAME) :: Tool?
			if not tool then
				continue
			end
			local amp = player:GetAttribute("ArmShake")
			if typeof(amp) == "number" and amp > 0 then
				if not baseGrip[tool] then
					baseGrip[tool] = tool.Grip
				end
				-- плавная дрожь (шум) + редкие резкие рывки, у каждого игрока своя
				local seed = player.UserId % 1000
				local ax = math.noise(t * 2.5, seed) * 2 * amp
				local ay = math.noise(seed, t * 2.5) * 2 * amp
				if math.random() < 0.04 then
					ax += (math.random() - 0.5) * amp * 2
				end
				tool.Grip = (baseGrip[tool] :: CFrame) * CFrame.Angles(math.rad(ax), math.rad(ay), 0)
			elseif baseGrip[tool] then
				-- рука вылечена — фонарик снова держится ровно
				tool.Grip = baseGrip[tool] :: CFrame
				baseGrip[tool] = nil
			end
		end
	end
end)

---------------------------------------------------------------------
-- Расход и зарядка батареи
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(TICK)
		local drain = 100 / Config.FLASHLIGHT_BATTERY_TIME * TICK
		local chargeTime = workspace:GetAttribute("Power") and Config.CHARGE_TIME_POWERED or Config.CHARGE_TIME_UNPOWERED
		local gain = 100 / chargeTime * TICK

		for _, player in Players:GetPlayers() do
			local tool = findFlashlight(player)
			if tool then
				local battery = (tool:GetAttribute("Battery") :: number?) or 100
				local handle = tool:FindFirstChild("Handle")
				local beam = handle and handle:FindFirstChild("Beam") :: SpotLight?

				-- зарядка: игрок держит E и стоит рядом
				local box = charging[player]
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if box and root and (root.Position - box.Position).Magnitude <= 8 then
					battery = math.min(100, battery + gain)
				elseif box then
					charging[player] = nil
					player:SetAttribute("Charging", nil)
				end

				if beam and beam.Enabled then
					battery = math.max(0, battery - drain)
					if battery <= 0 then
						beam.Enabled = false
						click(handle)
					end
					-- почти севший фонарик слабеет и подмигивает
					local strength = battery < 15 and (0.4 + battery / 25) or 1
					beam.Brightness = Config.FLASHLIGHT_BRIGHTNESS * strength * ((battery < 10 and math.random() < 0.15) and 0.2 or 1)
				end
				tool:SetAttribute("Battery", battery)
			end
		end
	end
end)

-- искры у проводки следят за током
workspace:GetAttributeChangedSignal("Power"):Connect(function()
	local on = workspace:GetAttribute("Power") == true
	for _, cp in CollectionService:GetTagged("ChargePoint") do
		local emitter = cp:FindFirstChild("PowerSparks", true) :: ParticleEmitter?
		if emitter then
			emitter.Enabled = on
		end
	end
end)
