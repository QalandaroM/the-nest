-- Тихая, давящая музыка во время раунда.
-- Слои: 1) фоновый трек (Sounds.MusicTrack), громкость медленно «дышит» — то накатывает, то оседает;
--       2) низкий гул и далёкий хор со стоном (Sounds.MusicAmbience) — играют, даже если трек не загрузился;
--       3) когда монстр рядом (для выжившего) — всё громче и выше, и стучит сердце.
--       4) монстр подобрался ближе Config.MONSTER_STINGER_DISTANCE — резкий удар музыки и рёв.
--       Иногда в тишине — низкий стон, будто дом оседает.
-- Музыку слышит только этот игрок.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local player = Players.LocalPlayer
local rng = Random.new()

local function loop(id: string, speed: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.PlaybackSpeed = speed
	s.Parent = SoundService
	return s
end

local track = loop(Sounds.MusicTrack, 1)
local drone = loop(Sounds.PowerHum, 0.32)
local wind = loop(Sounds.MusicAmbience, 0.8) -- далёкий хор и стон, замедленный — «оседает»
local heart = loop(Sounds.Heartbeat, 1)

local playing = false
local function setPlaying(on: boolean)
	if on == playing then
		return
	end
	playing = on
	for _, s in { track, drone, wind, heart } do
		if on then
			s:Play()
		else
			s:Stop()
			s.Volume = 0
		end
	end
end

-- трек не загрузился за 10 сек — предупреждаем (гул всё равно играет)
task.delay(10, function()
	if track.SoundId ~= "" and not track.IsLoaded then
		warn("Music: фоновый трек не загрузился, проверьте Sounds.MusicTrack. Играет только гул.")
	end
end)

-- Насколько близко монстр (0 — далеко, 1 — вплотную) и расстояние до ближайшего.
-- Монстру музыка не тревожнее.
local function danger(): (number, number)
	if player:GetAttribute("Role") ~= "Survivor" then
		return 0, math.huge
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return 0, math.huge
	end
	local best = 0
	local nearest = math.huge
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("Role") == "Monster" then
			local mroot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if mroot then
				local d = (mroot.Position - root.Position).Magnitude
				best = math.max(best, 1 - d / Config.MUSIC_DANGER_DISTANCE)
				nearest = math.min(nearest, d)
			end
		end
	end
	return math.clamp(best, 0, 1), nearest
end

-- Резкий страшный звук: удар музыки + рёв. Только для этого игрока.
local lastStinger = -math.huge
local wasNear = false
local function stinger()
	for _, pair in { { Sounds.MonsterStinger, 0.7, 1 }, { Sounds.MonsterRoar, 0.5, 0.8 } } do
		local s = Instance.new("Sound")
		s.SoundId = pair[1]
		s.Volume = pair[2]
		s.PlaybackSpeed = pair[3]
		s.Parent = SoundService
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
end

-- Монстр сам слышит своё рычание (MonsterVoice.server) — делаем его себе потише
local function quietOwnGrowl()
	local head = player.Character and player.Character:FindFirstChild("Head")
	local growl = head and head:FindFirstChild("MonsterGrowl") :: Sound?
	if growl and growl.Volume > 0.12 then
		growl.Volume = 0.12
	end
end

local function approach(s: Sound, target: number, k: number)
	s.Volume += (target - s.Volume) * k
end

task.spawn(function()
	local t = 0
	local level = 0
	while true do
		task.wait(0.1)
		t += 0.1
		local inRound = workspace:GetAttribute("RoundActive") == true and player:GetAttribute("Role") ~= nil
		setPlaying(inRound)
		if inRound then
			-- плавно: опасность растёт быстро, спадает медленно
			local d, nearest = danger()
			-- монстр подкрался: один раз при входе в радиус, не чаще кулдауна
			local near = nearest < Config.MONSTER_STINGER_DISTANCE
			if near and not wasNear and os.clock() - lastStinger > Config.MONSTER_STINGER_COOLDOWN then
				lastStinger = os.clock()
				stinger()
			end
			wasNear = near
			quietOwnGrowl()
			level += (d - level) * (d > level and 0.25 or 0.04)
			-- «дыхание»: громкость медленно накатывает и оседает (период ~45 сек)
			local swell = 0.65 + 0.35 * math.sin(t / 45 * math.pi * 2)
			local base = Config.MUSIC_VOLUME
			approach(track, base * swell + level * 0.18, 0.08)
			approach(drone, 0.05 + level * 0.12, 0.08)
			approach(wind, 0.12 * (1.3 - swell) + level * 0.05, 0.05) -- хор накатывает, когда музыка затихает
			approach(heart, level * 0.55, 0.15)
			drone.PlaybackSpeed = 0.32 + level * 0.12
			track.PlaybackSpeed = 1 + level * 0.04
			heart.PlaybackSpeed = 0.9 + level * 0.5
		end
	end
end)

-- Иногда — низкий стон «оседающего» дома поверх музыки
task.spawn(function()
	while true do
		task.wait(rng:NextNumber(50, 110))
		if playing then
			local s = Instance.new("Sound")
			s.SoundId = rng:NextNumber() < 0.5 and Sounds.PipeGroan or Sounds.HouseSettle
			s.Volume = 0.18
			s.PlaybackSpeed = rng:NextNumber(0.4, 0.55)
			s.Parent = SoundService
			s:Play()
			s.Ended:Once(function()
				s:Destroy()
			end)
		end
	end
end)
