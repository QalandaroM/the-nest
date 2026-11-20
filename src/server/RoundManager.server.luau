-- Управляет раундами: ждёт игроков, выбирает монстра, следит, кто победил.
-- Времени у раунда нет: он идёт, пока живы и выжившие, и монстр.
-- Выжившие побеждают, если убьют талисманом всех монстров (Talisman.server.luau),
-- в том числе второго — того, кто вылупился из кокона.
-- Монстр побеждает, если убьёт всех выживших раньше.
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
			elseif role == "Monster" and workspace:GetAttribute("RoundActive") then
				-- монстра убили талисманом: он не возрождается до конца раунда
				player:SetAttribute("Role", "Slain")
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

-- Второй монстр: кокон вылупился (скрипт Cocoons) → убитый игрок встаёт из кокона монстром.
-- Он такой же монстр, как первый: когти, может носить тела и делать коконы,
-- талисман его тоже жжёт. Выжившие побеждают, только когда сожгут ВСЕХ монстров.
local ServerStorage = game:GetService("ServerStorage")
task.spawn(function()
	local hatched = ServerStorage:WaitForChild("CocoonHatched") :: BindableEvent
	hatched.Event:Connect(function(victim: Player, cf: CFrame)
		if not workspace:GetAttribute("RoundActive") or not victim.Parent or victim:GetAttribute("Role") ~= "Dead" then
			return
		end
		-- пауза, чтобы все услышали, как рвётся кокон
		task.wait(Config.HATCH_RISE_DELAY)
		if not workspace:GetAttribute("RoundActive") or victim:GetAttribute("Role") ~= "Dead" then
			return
		end
		victim:LoadCharacter() -- новый персонаж (старое тело уже стало коконом)
		local character = victim.Character
		if character then
			character:PivotTo(CFrame.new(cf.Position + Vector3.new(0, 3, 0)) * cf.Rotation)
		end
		-- роль ставим ПОСЛЕ возрождения: облик монстра и когти получит уже новый персонаж
		victim:SetAttribute("Role", "Monster")
	end)
end)

while true do
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Role", nil)
		player:SetAttribute("CocoonState", nil)
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
	-- В Studio-тесте Player1 (окно, в котором играешь ты) всегда выживший — см. Config.STUDIO_PLAYER1_SURVIVOR
	local candidates = players
	if Config.STUDIO_PLAYER1_SURVIVOR and game:GetService("RunService"):IsStudio() and #players > 1 then
		candidates = {}
		for _, player in players do
			if player.Name ~= "Player1" then
				table.insert(candidates, player)
			end
		end
	end
	local monster = candidates[math.random(1, #candidates)]
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

	-- 4. Раунд идёт, пока есть и выжившие, и монстр (таймера нет)
	local slain = false
	while countRole("Survivor") > 0 and countRole("Monster") > 0 do
		local survivors = countRole("Survivor")
		setStatus(`Выживших: {survivors}. Найдите талисман…`)
		task.wait(1)
	end
	slain = countRole("Slain") > 0

	workspace:SetAttribute("RoundActive", false)

	-- 5. Итог
	if countRole("Monster") == 0 then
		setStatus(slain and (countRole("Slain") > 1 and "Талисман сжёг всех монстров. Выжившие победили!" or "Талисман сжёг монстра. Выжившие победили!") or "Монстр вышел. Выжившие победили!")
	else
		setStatus("Монстры победили!")
	end

	task.wait(5)

	-- Всех заново спавним в лобби
	for _, player in Players:GetPlayers() do
		player:LoadCharacter()
	end
end
