-- Атмосфера: фоновые звуки и случайные пугающие звуки вдалеке.
-- На улице — сверчки, в доме — тихий гул ветра. Каждые 15–45 сек — сова, гром,
-- скрип дома, стон труб или далёкий крик. Звуки слышит только этот игрок.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

local player = Players.LocalPlayer
local rng = Random.new()

local function loop(id: string, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s:SetAttribute("Target", volume)
	s.Parent = SoundService
	s:Play()
	return s
end

local crickets = loop(Sounds.Crickets, 0.35)
local wind = loop(Sounds.IndoorWind, 0.18)

-- Под крышей ли игрок (луч вверх во что-то упирается)?
local function isIndoors(root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	return workspace:Raycast(root.Position, Vector3.new(0, 60, 0), params) ~= nil
end

local function oneShot(id: string, volume: number, speed: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed or 1
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

-- Плавно меняем громкость фона: на улице сверчки, в доме ветер
task.spawn(function()
	while true do
		task.wait(0.5)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local inside = root ~= nil and isIndoors(root)
		local cTarget = inside and 0.05 or (crickets:GetAttribute("Target") :: number)
		local wTarget = inside and (wind:GetAttribute("Target") :: number) or 0.05
		crickets.Volume += (cTarget - crickets.Volume) * 0.3
		wind.Volume += (wTarget - wind.Volume) * 0.3
	end
end)

-- Случайные звуки вдалеке
task.spawn(function()
	while true do
		task.wait(rng:NextNumber(15, 45))
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local inside = root ~= nil and isIndoors(root)
		local underground = root ~= nil and root.Position.Y < -2
		local roll = rng:NextNumber()
		if underground then
			oneShot(roll < 0.6 and Sounds.PipeGroan or Sounds.Drip, 0.4, rng:NextNumber(0.7, 1))
		elseif inside then
			if roll < 0.45 then
				oneShot(Sounds.HouseSettle, 0.25, rng:NextNumber(0.8, 1))
			elseif roll < 0.75 then
				local t = Sounds.Thunder
				oneShot(t[rng:NextInteger(1, #t)], 0.3)
			elseif roll < 0.92 then
				oneShot(Sounds.Drip, 0.3)
			else
				oneShot(Sounds.DistantScream, 0.12, 0.8)
			end
		else
			if roll < 0.5 then
				oneShot(Sounds.Owl, 0.35)
			else
				local t = Sounds.Thunder
				oneShot(t[rng:NextInteger(1, #t)], 0.45)
			end
		end
	end
end)
