-- Анимации монстра из Blender (blender/monster.py → blender/out/monster_anim_*.fbx).
-- ID анимаций — в Config.MONSTER_ANIMS. Пустой ID = этой анимации нет, играет стандартная Roblox.
--   Run     — вместо обычных ходьбы и бега
--   Carry   — вместо ходьбы и бега, пока монстр несёт тело (атрибут CarryingBody)
--   Attack, Attack2 — удар когтями (случайно одна из двух), вызывает MonsterAttack
--   Scream  — скример с рёвом: заметил выжившего рядом, вылупился из кокона, замер от фонарика
-- Рёв (Sounds.MonsterRoar) звучит при скримере, даже если ID анимации Scream ещё пустой.
-- Запускается из MonsterSkin.server (MonsterAnims.start()).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local MonsterAnims = {}

local lastScream: { [Player]: number } = {}
-- загруженные анимации каждого персонажа (слабые ключи: персонаж удалён — запись пропадёт)
local tracks: { [Model]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any
-- стандартные ID ходьбы/бега, чтобы вернуть их, если своей анимации нет
local original: { [Animation]: string } = setmetatable({}, { __mode = "k" }) :: any

-- ID из Config: число, "123456" или "rbxassetid://123456". Пусто — nil
local function animId(name: string): string?
	local list = Config.MONSTER_ANIMS
	local id = list and list[name]
	if id == nil or id == "" or id == 0 then
		return nil
	end
	if typeof(id) == "number" or string.match(id, "^%d+$") then
		return `rbxassetid://{id}`
	end
	return id
end

local function alive(player: Player): (Model?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid and humanoid.Health > 0 then
		return character, humanoid
	end
	return nil, nil
end

-- Дорожка анимации (загружается один раз на персонажа)
local function track(character: Model, name: string): AnimationTrack?
	local id = animId(name)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not id or not animator then
		return nil
	end
	local list = tracks[character]
	if not list then
		list = {}
		tracks[character] = list
	end
	local t = list[name]
	if not t then
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		t = animator:LoadAnimation(anim)
		t.Priority = Enum.AnimationPriority.Action -- поверх ходьбы и бега
		list[name] = t
	end
	return t
end

-- Подменяем анимации ходьбы и бега в стандартном скрипте Animate.
-- Animate сам замечает смену AnimationId и начинает играть новую.
local function setMove(character: Model, name: string)
	local animate = character:FindFirstChild("Animate")
	if not animate then
		return
	end
	local id = animId(name)
	for _, state in { "walk", "run" } do
		local value = animate:FindFirstChild(state)
		if value then
			for _, a in value:GetChildren() do
				if a:IsA("Animation") then
					if original[a] == nil then
						original[a] = a.AnimationId
					end
					local want = id or original[a]
					if a.AnimationId ~= want then
						a.AnimationId = want
					end
				end
			end
		end
	end
end

-- Обновить ходьбу монстра: с телом на плече — Carry (если её нет — Run), иначе Run
function MonsterAnims.refresh(player: Player)
	local character = player.Character
	if not character or player:GetAttribute("Role") ~= "Monster" then
		return
	end
	local carrying = player:GetAttribute("CarryingBody") and animId("Carry") ~= nil
	setMove(character, if carrying then "Carry" else "Run")
end

-- Удар когтями. false — своих анимаций удара нет (тогда MonsterAttack играет стандартный взмах)
function MonsterAnims.attack(character: Model): boolean
	local names = {}
	for _, n in { "Attack", "Attack2" } do
		if animId(n) then
			table.insert(names, n)
		end
	end
	if #names == 0 then
		return false
	end
	local t = track(character, names[math.random(1, #names)])
	if not t then
		return false
	end
	t:Play(0.05)
	return true
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
	local t = track(character, "Scream")
	if t then
		t:Play(0.05)
	end
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
	-- взял или положил тело — меняем походку
	player:GetAttributeChangedSignal("CarryingBody"):Connect(function()
		MonsterAnims.refresh(player)
	end)
	-- фонарик заморозил монстра — он орёт на свет
	player:GetAttributeChangedSignal("Frozen"):Connect(function()
		if player:GetAttribute("Frozen") and player:GetAttribute("Role") == "Monster" then
			MonsterAnims.scream(player, Config.MONSTER_SCREAM_FREEZE_COOLDOWN)
		end
	end)
	-- второй монстр вылез из кокона — встаёт с рёвом
	player:GetAttributeChangedSignal("Role"):Connect(function()
		if player:GetAttribute("Role") == "Monster" and player:GetAttribute("CocoonState") == "Hatched" then
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
