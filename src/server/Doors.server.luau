-- Двери: открываются и закрываются по E, скрипят.
-- Дверь — деталь с тегом "Door" (её делает MapBuilder). Атрибуты:
--   ClosedCFrame, HingeLocal, OpenSign — положение и петли
--   Open — открыта ли сейчас, Locked — заперта, KeyDoor — открывается ключом
-- Запертые двери открывает BasementKey.server.luau (через атрибут Locked).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local busy: { [BasePart]: boolean } = {}

local function playAt(part: BasePart, id: string, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.RollOffMaxDistance = 70
	sound.PlaybackSpeed = 0.9 + math.random() * 0.2
	sound.Parent = part
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

-- Где должна стоять дверь, если она открыта / закрыта
local function targetCFrame(door: BasePart, open: boolean): CFrame
	local closed = door:GetAttribute("ClosedCFrame") :: CFrame
	if not open then
		return closed
	end
	local hinge = CFrame.new(closed:PointToWorldSpace(door:GetAttribute("HingeLocal") :: Vector3))
	local angle = math.rad(Config.DOOR_OPEN_ANGLE) * ((door:GetAttribute("OpenSign") :: number) or 1)
	return hinge * CFrame.Angles(0, angle, 0) * hinge:Inverse() * closed
end

local function updatePrompt(door: BasePart, prompt: ProximityPrompt)
	if door:GetAttribute("Locked") then
		prompt.ActionText = door:GetAttribute("KeyDoor") and "Открыть ключом" or "Заперто"
	else
		prompt.ActionText = door:GetAttribute("Open") and "Закрыть" or "Открыть"
	end
end

-- Плавно поворачиваем дверь вокруг петель
local function swing(door: BasePart, open: boolean)
	if busy[door] then
		return
	end
	busy[door] = true
	door:SetAttribute("Open", open)
	local creaks = Sounds.DoorCreaks
	playAt(door, creaks[math.random(1, #creaks)], 0.7)

	local from = door.CFrame
	local to = targetCFrame(door, open)
	local progress = Instance.new("NumberValue")
	progress.Changed:Connect(function(t)
		door.CFrame = from:Lerp(to, t)
	end)
	local tween = TweenService:Create(progress, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 })
	tween:Play()
	tween.Completed:Wait()
	progress:Destroy()
	door.CFrame = to
	busy[door] = nil
end

local function setup(door: Instance)
	if not door:IsA("BasePart") or not door:GetAttribute("ClosedCFrame") then
		return
	end
	door:SetAttribute("StartOpen", door:GetAttribute("Open") == true)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = door:GetAttribute("KeyDoor") and "Дверь в подвал" or "Дверь"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = door
	updatePrompt(door, prompt)

	door:GetAttributeChangedSignal("Open"):Connect(function()
		updatePrompt(door, prompt)
	end)
	door:GetAttributeChangedSignal("Locked"):Connect(function()
		updatePrompt(door, prompt)
	end)

	prompt.Triggered:Connect(function(player)
		if door:GetAttribute("Locked") then
			-- ключ проверяет BasementKey.server.luau; здесь просто звук замка
			if not door:GetAttribute("KeyDoor") or not player:GetAttribute("HasKey") then
				playAt(door, Sounds.DoorLocked, 0.8)
			end
			return
		end
		swing(door, not door:GetAttribute("Open"))
	end)
end

-- Скрипт BasementKey просит открыть дверь через атрибут
local function watchSwingRequest(door: Instance)
	if door:IsA("BasePart") then
		door:GetAttributeChangedSignal("SwingRequest"):Connect(function()
			local want = door:GetAttribute("SwingRequest")
			if want ~= nil then
				door:SetAttribute("SwingRequest", nil)
				task.spawn(swing, door, want == true)
			end
		end)
	end
end

for _, door in CollectionService:GetTagged("Door") do
	setup(door)
	watchSwingRequest(door)
end
CollectionService:GetInstanceAddedSignal("Door"):Connect(function(door)
	setup(door)
	watchSwingRequest(door)
end)

-- В начале каждого раунда двери возвращаются в исходное положение
workspace:GetAttributeChangedSignal("RoundActive"):Connect(function()
	if not workspace:GetAttribute("RoundActive") then
		return
	end
	for _, door in CollectionService:GetTagged("Door") do
		if door:IsA("BasePart") and door:GetAttribute("ClosedCFrame") then
			local open = door:GetAttribute("StartOpen") == true
			door:SetAttribute("Open", open)
			door.CFrame = targetCFrame(door, open)
		end
	end
end)
