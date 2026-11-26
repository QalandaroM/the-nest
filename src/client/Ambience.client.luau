-- Атмосфера: фоновые звуки и случайные пугающие звуки вдалеке.
-- На улице — сверчки, в доме — тихий гул ветра. Каждые 15–45 сек — сова, гром,
-- скрип дома, стон труб или далёкий крик. Во время раунда в доме и подвале — давящий гул
-- волнами, с каждой смертью выжившего он давит сильнее.
-- Звуки слышит только этот игрок.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Config = require(ReplicatedStorage.Shared.Config)

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

-- Давящий гул во время раунда: медленно наползает (долго нарастает),
-- потом быстро отпускает — и снова. Только в доме и подвале (на улице — сверчки).
-- С каждым убитым выжившим пик волны громче: чем меньше живых, тем сильнее давит.
local drone = loop(Sounds.DreadDrone, 0)

-- Сколько выживших уже убито в этом раунде (роль "Dead")
local function deaths(): number
	local n = 0
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Dead" then
			n += 1
		end
	end
	return n
end

task.spawn(function()
	local phase = 0 -- где мы сейчас на волне: 0 → 1
	local wave = Config.DREAD_DRONE_WAVE
	while true do
		local dt = task.wait(0.2)
		phase += dt / wave
		if phase >= 1 then
			phase -= 1
			wave = Config.DREAD_DRONE_WAVE * rng:NextNumber(0.7, 1.3) -- каждая волна немного разной длины
		end
		-- 80% времени гул нарастает (сначала незаметно, потом всё сильнее), 20% — стихает
		local k = if phase < 0.8 then (phase / 0.8) ^ 2 else 1 - (phase - 0.8) / 0.2
		local target = 0
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local underground = root ~= nil and root.Position.Y < -2
		local inside = root ~= nil and (underground or isIndoors(root))
		if workspace:GetAttribute("RoundActive") and inside then
			local peak = math.min(Config.DREAD_DRONE_MAX + deaths() * Config.DREAD_DRONE_PER_DEATH, Config.DREAD_DRONE_CAP)
			target = Config.DREAD_DRONE_MIN + (peak - Config.DREAD_DRONE_MIN) * k
		end
		-- плавно: выйдешь на улицу — гул за пару секунд стихнет
		drone.Volume += (target - drone.Volume) * 0.15
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
