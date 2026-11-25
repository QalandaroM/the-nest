-- Анимации монстра (сервер). Сами позы играет клиент: MonsterAnimator.client.luau берёт их
-- из Shared.MonsterAnimData (пишет blender/monster.py) — загружать анимации в Roblox не нужно.
-- Ходьба, бег, стойка и переноска тела клиент выбирает сам (по скорости и атрибуту CarryingBody).
-- Разовые действия сервер объявляет атрибутом игрока MonsterAction = "Имя|время сервера":
--   Attack, Attack2 — удар когтями (случайно одно из двух), вызывает MonsterAttack
--   Pickup  — поднимает тело с пола, вызывает Cocoons
--   Scream  — скример с рёвом: заметил выжившего рядом, вылупился из кокона, замер от фонарика
-- Запускается из MonsterSkin.server (MonsterAnims.start()).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local MonsterAnims = {}

local lastScream: { [Player]: number } = {}

local function alive(player: Player): (Model?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid and humanoid.Health > 0 then
		return character, humanoid
	end
	return nil, nil
end

-- Сказать всем клиентам: «монстр сейчас делает это действие»
local function play(character: Model, name: string): boolean
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return false
	end
	player:SetAttribute("MonsterAction", `{name}|{string.format("%.3f", workspace:GetServerTimeNow())}`)
	return true
end

-- Удар когтями: удар правой лапой или выпад двумя лапами — случайно
function MonsterAnims.attack(character: Model): boolean
	return play(character, if math.random() < 0.5 then "Attack" else "Attack2")
end

-- Подъём тела: наклон, хват, закидывает на плечи
function MonsterAnims.pickup(character: Model): boolean
	return play(character, "Pickup")
end

-- Скример: анимация Scream и рёв. cooldown — не чаще, чем раз в столько секунд
function MonsterAnims.scream(player: Player, cooldown: number?): boolean
	local character = alive(player)
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not character or not head then
		return false
	end
	local now = os.clock()
	if cooldown and now - (lastScream[player] or -math.huge) < cooldown then
		return false
	end
	lastScream[player] = now
	play(character, "Scream")
	local s = Instance.new("Sound")
	s.SoundId = Sounds.MonsterRoar
	s.Volume = Config.MONSTER_SCREAM_VOLUME
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 70
	s.Parent = head
	s:Play()
	Debris:AddItem(s, 8)
	return true
end

-- Видит ли монстр эту голову (без стены между ними)
local function canSee(monsterChar: Model, from: BasePart, target: Model, to: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { monsterChar, target }
	local hit = workspace:Raycast(from.Position, to.Position - from.Position, params)
	return hit == nil or not hit.Instance.CanCollide
end

-- Монстр заметил выжившего: рядом, впереди и не за стеной
local function noticeLoop()
	while true do
		task.wait(0.25)
		if not workspace:GetAttribute("RoundActive") then
			continue
		end
		for _, monster in Players:GetPlayers() do
			if monster:GetAttribute("Role") ~= "Monster" or monster:GetAttribute("Frozen") or monster:GetAttribute("CarryingBody") then
				continue
			end
			if os.clock() - (lastScream[monster] or -math.huge) < Config.MONSTER_SCREAM_COOLDOWN then
				continue
			end
			local mc = alive(monster)
			local root = mc and mc:FindFirstChild("HumanoidRootPart") :: BasePart?
			local head = mc and mc:FindFirstChild("Head") :: BasePart?
			if not mc or not root or not head then
				continue
			end
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			for _, survivor in Players:GetPlayers() do
				if survivor:GetAttribute("Role") ~= "Survivor" then
					continue
				end
				local sc = alive(survivor)
				local sh = sc and sc:FindFirstChild("Head") :: BasePart?
				if not sc or not sh then
					continue
				end
				local offset = sh.Position - head.Position
				if offset.Magnitude > Config.MONSTER_SCREAM_DISTANCE then
					continue
				end
				local flat = Vector3.new(offset.X, 0, offset.Z)
				if flat.Magnitude > 0.1 and look.Magnitude > 0.1 and flat.Unit:Dot(look.Unit) < math.cos(math.rad(75)) then
					continue -- выживший сбоку или за спиной — монстр его не заметил
				end
				if canSee(mc, head, sc, sh) then
					MonsterAnims.scream(monster, Config.MONSTER_SCREAM_COOLDOWN)
					break
				end
			end
		end
	end
end

local function onPlayer(player: Player)
	-- фонарик заморозил монстра — он орёт на свет
	player:GetAttributeChangedSignal("Frozen"):Connect(function()
		if player:GetAttribute("Frozen") and player:GetAttribute("Role") == "Monster" then
			MonsterAnims.scream(player, Config.MONSTER_SCREAM_FREEZE_COOLDOWN)
		end
	end)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		local role = player:GetAttribute("Role")
		if role ~= "Monster" then
			player:SetAttribute("MonsterAction", nil)
		elseif player:GetAttribute("CocoonState") == "Hatched" then
			-- второй монстр вылез из кокона — встаёт с рёвом
			task.delay(Config.MONSTER_SCREAM_HATCH_DELAY, function()
				if player:GetAttribute("Role") == "Monster" then
					MonsterAnims.scream(player)
				end
			end)
		end
	end)
end

local started = false
function MonsterAnims.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastScream[player] = nil
	end)
	task.spawn(noticeLoop)
end

return MonsterAnims
