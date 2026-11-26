-- Скрип старого пола: когда игрок бегает по деревянному полу, под ним скрипят доски.
-- Чем больше и быстрее идёшь, тем чаще скрип (Config.CREAK_STEP, CREAK_CHANCE).
-- Звук запускает сервер, поэтому его слышат все рядом — и шаги монстра тоже.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local CHECK = 0.4 -- как часто проверяем шаги (сек)
local WOOD = {
	[Enum.Material.WoodPlanks] = true,
	[Enum.Material.Wood] = true,
}

local rng = Random.new()

-- speed: 1 — обычный бег; быстрее — скрип громче и резче
local function creak(root: BasePart, speed: number)
	local list = Sounds.FloorCreaks
	local sound = Instance.new("Sound")
	sound.SoundId = list[rng:NextInteger(1, #list)]
	sound.Volume = Config.CREAK_VOLUME * rng:NextNumber(0.7, 1) * math.clamp(speed, 0.6, 1.2)
	sound.PlaybackSpeed = rng:NextNumber(0.85, 1.1)
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 55
	sound.Parent = root
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

-- сколько studs прошёл игрок по дереву с последней проверки скрипа
local walked: { [Player]: number } = {}
local lastPos: { [Player]: Vector3 } = {}
Players.PlayerRemoving:Connect(function(player)
	walked[player] = nil
	lastPos[player] = nil
end)

while true do
	task.wait(CHECK)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 and WOOD[humanoid.FloorMaterial] then
			-- считаем только шаги по полу (по горизонтали), телепорты не считаются
			local prev = lastPos[player]
			local step = prev and Vector3.new(root.Position.X - prev.X, 0, root.Position.Z - prev.Z).Magnitude or 0
			if step < 15 then
				walked[player] = (walked[player] or 0) + step
			end
			-- каждые CREAK_STEP studs — шанс скрипа; кто бежит быстрее, тот проходит больше и скрипит чаще
			if (walked[player] or 0) >= Config.CREAK_STEP then
				walked[player] = 0
				local speed = math.clamp(step / CHECK / 16, 0.4, 1.5) -- 1 = обычный бег (16 studs/сек)
				if rng:NextNumber() < Config.CREAK_CHANCE * speed then
					creak(root, speed)
				end
			end
		else
			walked[player] = 0
		end
		lastPos[player] = root and root.Position or nil
	end
end
