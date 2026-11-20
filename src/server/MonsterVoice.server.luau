-- Голос монстра: низкое рычание без остановки и хриплое дыхание раз в несколько секунд.
-- Звук висит на голове монстра и «объёмный» (3D): чем ближе монстр, тем громче.
-- Дальше Config.MONSTER_VOICE_DISTANCE его не слышно — монстр может подкрасться издалека,
-- но вблизи выживший его обязательно услышит.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local rng = Random.new()

local function newSound(parent: Instance, id: string, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.RollOffMode = Enum.RollOffMode.LinearSquare -- плавно стихает к краю
	s.RollOffMinDistance = 4
	s.RollOffMaxDistance = Config.MONSTER_VOICE_DISTANCE
	s.Parent = parent
	return s
end

local function giveVoice(player: Player, character: Model)
	local head = character:WaitForChild("Head", 5) :: BasePart?
	if not head or head:FindFirstChild("MonsterGrowl") then
		return
	end
	-- 1) рычание по кругу, замедленное — ниже и страшнее
	local growl = newSound(head, Sounds.MonsterGrowlLoop, 0.55)
	growl.Name = "MonsterGrowl"
	growl.Looped = true
	growl.PlaybackSpeed = 0.7
	growl:Play()

	-- 2) дыхание раз в 4–8 сек, пока он монстр и жив
	task.spawn(function()
		while head.Parent and player:GetAttribute("Role") == "Monster" do
			task.wait(rng:NextNumber(4, 8))
			if not head.Parent or player:GetAttribute("Role") ~= "Monster" then
				break
			end
			local list = Sounds.MonsterBreath
			local breath = newSound(head, list[rng:NextInteger(1, #list)], 0.9)
			breath.PlaybackSpeed = rng:NextNumber(0.75, 0.9)
			breath:Play()
			breath.Ended:Once(function()
				breath:Destroy()
			end)
		end
		growl:Destroy()
	end)
end

local function check(player: Player)
	local character = player.Character
	if character and player:GetAttribute("Role") == "Monster" then
		task.spawn(giveVoice, player, character)
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		check(player)
	end)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		check(player)
	end)
	check(player)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end
