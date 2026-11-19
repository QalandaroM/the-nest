-- Скрип старого пола: когда игрок идёт по деревянному полу, иногда скрипит доска.
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

local function creak(root: BasePart)
	local list = Sounds.FloorCreaks
	local sound = Instance.new("Sound")
	sound.SoundId = list[rng:NextInteger(1, #list)]
	sound.Volume = rng:NextNumber(0.35, 0.7)
	sound.PlaybackSpeed = rng:NextNumber(0.85, 1.1)
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 55
	sound.Parent = root
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

while true do
	task.wait(CHECK)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 and humanoid.MoveDirection.Magnitude > 0.1 and WOOD[humanoid.FloorMaterial] then
			-- бег скрипит чаще, чем медленный шаг
			local chance = Config.CREAK_CHANCE * math.clamp(humanoid.WalkSpeed / 16, 0.5, 1.5)
			if rng:NextNumber() < chance then
				creak(root)
			end
		end
	end
end
