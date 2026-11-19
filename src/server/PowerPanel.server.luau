-- Уличный щиток на столбе (Workspace.Map.Exterior.PowerPanel, тег "PowerPanel").
--
-- Выжившие: держат E — починка растёт на случайные 1–3% каждые 0.25 сек.
-- Монстр: E — удар, откатывает 100/6 % (целый щиток ломается за 6 ударов),
--         между ударами 10 сек.
-- Пока щиток работает (дошёл до 100% и ещё не сломан до 0%):
--   * в доме горит тусклый мигающий свет (лампы с тегом "PanelLight");
--   * в проводке есть ток — фонарик заряжается быстрее (см. Flashlight.server.luau).
-- Состояние видно всем: workspace.Power (bool) и workspace.PanelProgress (0..100).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local panel = CollectionService:GetTagged("PowerPanel")[1] :: Model?
if not panel then
	warn("PowerPanel: щиток не найден (постройте карту MapBuilder'ом)")
	workspace:SetAttribute("Power", false)
	return
end
local box = (panel.PrimaryPart or panel:FindFirstChild("Box")) :: BasePart
local statusLight = panel:FindFirstChild("StatusLight") :: BasePart?
local sparkPoint = box:FindFirstChild("SparkPoint") :: Attachment?

local rng = Random.new()
local progress = 0
local powered = false
local repairing: { [Player]: boolean } = {}
local monsterCooldown: { [Player]: number } = {}
local HIT = 100 / Config.PANEL_HITS_TO_BREAK

local function playAt(parent: Instance, id: string, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.RollOffMaxDistance = 80
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

---------------------------------------------------------------------
-- Искры и гул
---------------------------------------------------------------------
local sparks = Instance.new("ParticleEmitter")
sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
sparks.LightEmission = 1
sparks.Size = NumberSequence.new(0.15, 0)
sparks.Lifetime = NumberRange.new(0.2, 0.5)
sparks.Speed = NumberRange.new(6, 12)
sparks.SpreadAngle = Vector2.new(50, 50)
sparks.Acceleration = Vector3.new(0, -30, 0)
sparks.Rate = 0
sparks.Parent = sparkPoint or box

local hum = Instance.new("Sound")
hum.SoundId = Sounds.PowerHum
hum.Looped = true
hum.Volume = 0.35
hum.RollOffMaxDistance = 40
hum.Parent = box

---------------------------------------------------------------------
-- Полоска прогресса над щитком
---------------------------------------------------------------------
local gui = Instance.new("BillboardGui")
gui.Size = UDim2.fromOffset(140, 34)
gui.StudsOffset = Vector3.new(0, 3.4, 0)
gui.MaxDistance = 30
gui.AlwaysOnTop = false
gui.Parent = box
local back = Instance.new("Frame")
back.Size = UDim2.fromScale(1, 0.45)
back.Position = UDim2.fromScale(0, 0.55)
back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
back.BorderSizePixel = 0
back.Parent = gui
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(200, 60, 40)
fill.BorderSizePixel = 0
fill.Parent = back
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 0.55)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.fromRGB(230, 220, 200)
label.TextStrokeTransparency = 0.4
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.Parent = gui

---------------------------------------------------------------------
-- Свет в доме
---------------------------------------------------------------------
local function lightsOf(part: Instance): { Light }
	local list = {}
	for _, d in part:GetChildren() do
		if d:IsA("Light") then
			table.insert(list, d)
		end
	end
	return list
end

-- Запоминаем исходную яркость каждой лампы
for _, part in CollectionService:GetTagged("PanelLight") do
	for _, light in lightsOf(part) do
		if light:GetAttribute("BaseBrightness") == nil then
			light:SetAttribute("BaseBrightness", light.Brightness)
		end
	end
end

local function setLamp(part: Instance, level: number)
	-- level: 0 = выключена, 1 = обычный тусклый свет
	for _, light in lightsOf(part) do
		local base = (light:GetAttribute("BaseBrightness") :: number?) or light.Brightness
		light.Enabled = level > 0
		light.Brightness = base * Config.PANEL_LIGHT_SCALE * level
	end
	if part:IsA("BasePart") and part.Name ~= "ChandelierLight" then
		part.Material = level > 0 and Enum.Material.Neon or Enum.Material.Glass
		part.Color = level > 0 and ((part:GetAttribute("OnColor") :: Color3?) or part.Color) or Color3.fromRGB(60, 58, 50)
	end
end

local function setAllLamps(on: boolean)
	for _, part in CollectionService:GetTagged("PanelLight") do
		setLamp(part, on and 1 or 0)
	end
end

---------------------------------------------------------------------
-- Состояние
---------------------------------------------------------------------
local function refresh()
	workspace:SetAttribute("PanelProgress", math.floor(progress))
	workspace:SetAttribute("Power", powered)
	fill.Size = UDim2.fromScale(progress / 100, 1)
	fill.BackgroundColor3 = powered and Color3.fromRGB(90, 200, 90) or Color3.fromRGB(200, 60, 40)
	label.Text = powered and `Щиток работает: {math.floor(progress)}%` or `Щиток: {math.floor(progress)}%`
	if statusLight then
		local color = powered and Color3.fromRGB(40, 200, 60) or Color3.fromRGB(190, 20, 20)
		statusLight.Color = color
		local l = statusLight:FindFirstChildWhichIsA("PointLight")
		if l then
			l.Color = color
		end
	end
	if powered and not hum.IsPlaying then
		hum:Play()
	elseif not powered and hum.IsPlaying then
		hum:Stop()
	end
	-- искры у зарядок, когда есть ток
	for _, cp in CollectionService:GetTagged("ChargePoint") do
		local emitter = cp:FindFirstChild("PowerSparks", true) :: ParticleEmitter?
		if emitter then
			emitter.Enabled = powered
		end
	end
end

local function setPowered(on: boolean)
	if powered == on then
		return
	end
	powered = on
	setAllLamps(on)
	if on then
		playAt(box, Sounds.PowerOn, 0.8)
	end
	refresh()
end

local function reset()
	progress = 0
	table.clear(repairing)
	table.clear(monsterCooldown)
	powered = true -- чтобы setPowered(false) точно выключил всё
	setPowered(false)
	refresh()
end

---------------------------------------------------------------------
-- Подсказки (E): одна для выживших, другая для монстра
---------------------------------------------------------------------
local repairPrompt = Instance.new("ProximityPrompt")
repairPrompt.Name = "RepairPrompt"
repairPrompt.ActionText = "Чинить (держи E)"
repairPrompt.ObjectText = "Щиток"
repairPrompt.KeyboardKeyCode = Enum.KeyCode.E
repairPrompt.MaxActivationDistance = 7
repairPrompt.RequiresLineOfSight = false
repairPrompt.HoldDuration = 0
repairPrompt:SetAttribute("ForRole", "Survivor")
repairPrompt.Parent = box

local breakPrompt = Instance.new("ProximityPrompt")
breakPrompt.Name = "BreakPrompt"
breakPrompt.ActionText = "Сломать"
breakPrompt.ObjectText = "Щиток"
breakPrompt.KeyboardKeyCode = Enum.KeyCode.E
breakPrompt.MaxActivationDistance = 8
breakPrompt.RequiresLineOfSight = false
breakPrompt.HoldDuration = 0
breakPrompt:SetAttribute("ForRole", "Monster")
breakPrompt.Parent = box

local function isAliveWithRole(player: Player, role: string): boolean
	if player:GetAttribute("Role") ~= role then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function closeEnough(player: Player, dist: number): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - box.Position).Magnitude <= dist
end

repairPrompt.Triggered:Connect(function(player)
	if isAliveWithRole(player, "Survivor") and workspace:GetAttribute("RoundActive") then
		repairing[player] = true
	end
end)
repairPrompt.TriggerEnded:Connect(function(player)
	repairing[player] = nil
end)

breakPrompt.Triggered:Connect(function(player)
	if not isAliveWithRole(player, "Monster") or not closeEnough(player, 10) then
		return
	end
	local now = os.clock()
	if (monsterCooldown[player] or 0) > now then
		return -- ещё рано бить
	end
	monsterCooldown[player] = now + Config.PANEL_MONSTER_COOLDOWN
	progress = math.max(0, progress - HIT)
	playAt(box, Sounds.PanelHit, 1)
	sparks:Emit(40)
	if progress <= 0 then
		setPowered(false)
	end
	refresh()
end)

Players.PlayerRemoving:Connect(function(player)
	repairing[player] = nil
	monsterCooldown[player] = nil
end)

---------------------------------------------------------------------
-- Починка: каждые 0.25 сек
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(Config.PANEL_REPAIR_TICK)
		local changed = false
		for player in repairing do
			local armsLost = player:GetAttribute("ArmsLost") or 0
			if isAliveWithRole(player, "Survivor") and closeEnough(player, 9) and progress < 100 and armsLost < 2 then
				local amount = rng:NextInteger(Config.PANEL_REPAIR_MIN, Config.PANEL_REPAIR_MAX)
				if armsLost == 1 then
					amount = math.ceil(amount / Config.ONE_ARM_SLOWDOWN) -- одной рукой чинить медленнее
				end
				progress = math.min(100, progress + amount)
				changed = true
			else
				repairing[player] = nil
			end
		end
		if changed then
			if progress >= 100 then
				setPowered(true)
			end
			refresh()
		end
	end
end)

---------------------------------------------------------------------
-- «Глюки»: сломанный щиток искрит, работающий свет мигает
---------------------------------------------------------------------
task.spawn(function()
	while true do
		if not powered then
			task.wait(rng:NextNumber(3, 8))
			if not powered then
				sparks:Emit(rng:NextInteger(8, 25))
				local list = Sounds.PanelSpark
				playAt(box, list[rng:NextInteger(1, #list)], 0.6)
			end
		else
			task.wait(rng:NextNumber(0.4, 2.5))
			if powered then
				-- чем ниже прочность, тем сильнее мигает
				local weak = 1 - progress / 100
				local lamps = CollectionService:GetTagged("PanelLight")
				for _, part in lamps do
					if rng:NextNumber() < 0.15 + weak * 0.5 then
						task.spawn(function()
							for _ = 1, rng:NextInteger(1, 4) do
								if not powered then
									break
								end
								setLamp(part, rng:NextNumber(0, 0.35))
								task.wait(rng:NextNumber(0.04, 0.15))
								if not powered then
									break
								end
								setLamp(part, 1)
								task.wait(rng:NextNumber(0.03, 0.12))
							end
							-- если за время мигания щиток сломали — лампа должна погаснуть
							if not powered then
								setLamp(part, 0)
							end
						end)
					end
				end
			end
		end
	end
end)

workspace:GetAttributeChangedSignal("RoundActive"):Connect(function()
	if workspace:GetAttribute("RoundActive") then
		reset()
	end
end)

reset()
