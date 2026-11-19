-- Управляет раундами: ждёт игроков, выбирает монстра, считает время.
-- В Workspace поставьте две детали (Part): MonsterSpawn и SurvivorSpawn.
-- Атрибут workspace.RoundActive = true, пока идёт раунд.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- Текст сверху экрана, его видят все игроки
local status = Instance.new("StringValue")
status.Name = "Status"
status.Parent = ReplicatedStorage

local function setStatus(text: string)
	status.Value = text
end

local function teleport(player: Player, spawnName: string)
	local spawnPart = workspace:FindFirstChild(spawnName)
	local character = player.Character
	if spawnPart and spawnPart:IsA("BasePart") and character then
		character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
	end
end

local function countRole(role: string): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Role") == role then
			count += 1
		end
	end
	return count
end

-- Сами персонажей не возрождаем: убитый выживший должен остаться мёртвым до конца раунда
-- (его тело уносит монстр, скрипт Cocoons). В лобби и монстра возрождаем вручную.
Players.CharacterAutoLoads = false

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			local role = player:GetAttribute("Role")
			if role == "Survivor" then
				player:SetAttribute("Role", "Dead")
			elseif role == nil or role == "Monster" then
				-- лобби или монстр — возрождаем через пару секунд
				task.delay(Config.RESPAWN_DELAY, function()
					if player.Parent and player:GetAttribute("Role") == role then
						player:LoadCharacter()
						if role == "Monster" then
							teleport(player, "MonsterSpawn")
						end
					end
				end)
			end
		end)
	end)
	if not player.Character then
		player:LoadCharacter()
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end

while true do
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Role", nil)
	end

	-- 1. Ждём игроков
	while #Players:GetPlayers() < Config.MIN_PLAYERS do
		setStatus(`Ждём игроков: {#Players:GetPlayers()}/{Config.MIN_PLAYERS}`)
		task.wait(1)
	end

	-- 2. Отсчёт
	for i = Config.INTERMISSION, 1, -1 do
		setStatus(`Раунд начнётся через {i}`)
		task.wait(1)
	end

	local players = Players:GetPlayers()
	if #players < Config.MIN_PLAYERS then
		continue
	end

	-- 3. Выбираем случайного монстра
	local monster = players[math.random(1, #players)]
	for _, player in players do
		if player == monster then
			player:SetAttribute("Role", "Monster")
			teleport(player, "MonsterSpawn")
		else
			player:SetAttribute("Role", "Survivor")
			teleport(player, "SurvivorSpawn")
		end
	end

	-- Другие скрипты (щиток, ключ, двери) слушают этот атрибут
	workspace:SetAttribute("RoundActive", true)

	-- 4. Раунд идёт, пока есть выжившие, монстр и время
	local timeLeft = Config.ROUND_TIME
	while timeLeft > 0 and countRole("Survivor") > 0 and countRole("Monster") > 0 do
		setStatus(`Осталось: {timeLeft} сек`)
		task.wait(1)
		timeLeft -= 1
	end

	workspace:SetAttribute("RoundActive", false)

	-- 5. Итог
	if countRole("Monster") == 0 then
		setStatus("Монстр вышел. Выжившие победили!")
	elseif countRole("Survivor") == 0 then
		setStatus("Монстры победили!")
	else
		setStatus("Время вышло. Выжившие победили!")
	end

	task.wait(5)

	-- Всех заново спавним в лобби
	for _, player in Players:GetPlayers() do
		player:LoadCharacter()
	end
end
