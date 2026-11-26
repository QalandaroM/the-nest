-- Квесты на талисман и сам талисман — единственное, что ранит монстра.
--
-- Талисман (оберег Марты) разделён на 3 части, у каждой своя загадка:
-- Каждый раунд сейф, ящик и алтарь встают у случайной стены в случайной комнате (QuestPlacer),
-- записки и рисунок Лили — в случайные места, код и порядок свечей — новые.
--
--   1. ЦЕПОЧКА — в сейфе. Код из 4 цифр каждый раунд новый,
--      цифры написаны в 4 записках, разбросанных по дому (Workspace.QuestItems).
--   2. КАМЕНЬ — в ящике Томаса у генератора (подвал). Электрозамок открывается,
--      только когда щиток во дворе починен (workspace.Power = true). Сначала нужен ключ от подвала
--      или уличный люк.
--   3. ОПРАВА — в могиле Лили. Надо зажечь 3 свечи у могил в правильном порядке.
--      Порядок — на рисунке Лили в детской. Ошибся — свечи гаснут, и раздаётся крик (монстр услышит).
-- Части носят выжившие (атрибуты HasChain / HasStone / HasFrame). Умер — часть падает на пол.
-- Все 3 части кладут на алтарь в библиотеке → появляется талисман. Его берут (E) —
-- это инструмент «Талисман»: клик рядом с монстром обжигает его.
-- Config.TALISMAN_HITS_TO_KILL ожогов — монстр умирает, выжившие побеждают (RoundManager).
--
-- Атрибуты для HUD: workspace.Quest_Chain / Quest_Stone / Quest_Frame =
--   "Hidden" (ещё спрятана), "Found" (у кого-то в руках или на полу), "Placed" (на алтаре);
-- workspace.TalismanState = "None" / "Ready" (лежит на алтаре) / "Taken" (у выжившего);
-- workspace.MonsterBurns — сколько раз обожгли монстра; у игрока TalismanReadyAt.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local TalismanModel = require(ReplicatedStorage.Shared.TalismanModel)
local QuestPlacer = require(script.Parent.QuestPlacer)

local quest = workspace:WaitForChild("Quest", 15)
if not quest then
	warn("Talisman: нет Workspace.Quest — перестройте карту MapBuilder'ом")
	return
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local feedback = remotes:WaitForChild("HitFeedback") :: RemoteEvent

-- Сейф: сервер просит клиента показать окно ввода кода, клиент присылает код
local safeEvent = Instance.new("RemoteEvent")
safeEvent.Name = "SafeCode"
safeEvent.Parent = remotes

-- Записки с подсказками (их читает Notes.server.luau по тегу Note)
local items = Instance.new("Folder")
items.Name = "QuestItems"
items.Parent = workspace

local CollectionService = game:GetService("CollectionService")

local rng = Random.new()
local PARTS = { "Chain", "Stone", "Frame" }
local RU = { Chain = "цепочку", Stone = "камень", Frame = "оправу" }
local GRAVES = { "Thomas", "Martha", "Lily" }
local GRAVE_RU = { Thomas = "папы", Martha = "мамы", Lily = "моей" }

local code = "0000"
local ritualOrder: { string } = {}
local ritualStep = 0
local ritualDone = false
local safeOpen = false
local chestOpen = false
local safeCooldown: { [Player]: number } = {}
local talismanCooldown: { [Player]: number } = {}
local relocate: () -> () -- ниже: переставляет сейф, ящик и алтарь

---------------------------------------------------------------------
-- Помощники
---------------------------------------------------------------------
local function notice(player: Player, text: string)
	feedback:FireClient(player, "Notice", { text = text })
end

local function noticeAll(text: string)
	for _, p in Players:GetPlayers() do
		notice(p, text)
	end
end

local function playAt(parent: Instance, id: string | { string }, volume: number, rolloff: number?, speed: number?)
	local list = id :: any
	local sound = Instance.new("Sound")
	sound.SoundId = if typeof(list) == "table" then list[rng:NextInteger(1, #list)] else list
	sound.Volume = volume
	sound.RollOffMaxDistance = rolloff or 60
	sound.PlaybackSpeed = speed or 1
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function aliveRole(player: Player, role: string): (Humanoid?, BasePart?)
	if player:GetAttribute("Role") ~= role then
		return nil, nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and humanoid.Health > 0 and root then
		return humanoid, root
	end
	return nil, nil
end

local function near(player: Player, part: BasePart, dist: number): boolean
	local _, root = aliveRole(player, "Survivor")
	return root ~= nil and (root.Position - part.Position).Magnitude <= dist
end

local function surfaceBelow(pos: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), params)
	return result and result.Position or pos
end

-- Подсказку не нужно выключать через Enabled (клиент Prompts.client включит её обратно) —
-- ставим атрибут Hidden = true, и клиент её прячет.
local function hide(p: ProximityPrompt?, hidden: boolean)
	if p then
		p:SetAttribute("Hidden", hidden or nil)
	end
end

-- Предмет, который надо подобрать, лежит прямо на сейфе/алтаре/рядом с бинтом —
-- его подсказку показываем всегда, чтобы соседняя подсказка на E её не закрыла.
local function alwaysShow(p: ProximityPrompt): ProximityPrompt
	p.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	return p
end

local function prompt(parent: Instance, action: string, object: string, role: string?, dist: number?, hold: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.MaxActivationDistance = dist or 7
	p.RequiresLineOfSight = false
	p.HoldDuration = hold or 0
	if role then
		p:SetAttribute("ForRole", role) -- Prompts.client.luau покажет только этой роли
	end
	p.Parent = parent
	return p
end

-- Повернуть деталь вокруг петель (hingeLocal — точка петель в координатах детали)
local function swingPart(part: BasePart, hingeLocal: Vector3, rotation: CFrame, time: number)
	local closed = part.CFrame
	local hinge = CFrame.new(closed:PointToWorldSpace(hingeLocal)) * (closed - closed.Position)
	local target = hinge * rotation * hinge:Inverse() * closed
	local value = Instance.new("NumberValue")
	value.Changed:Connect(function(t)
		part.CFrame = closed:Lerp(target, t)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 })
	tween:Play()
	tween.Completed:Once(function()
		value:Destroy()
		part.CFrame = target
	end)
	return closed
end

local function setState(key: string, state: string)
	workspace:SetAttribute(`Quest_{key}`, state)
end

---------------------------------------------------------------------
-- Части талисмана в мире (лежат, их можно поднять)
---------------------------------------------------------------------
local spawnTalisman: (CFrame) -> ()

local function spawnPiece(key: string, pos: Vector3)
	local old = items:FindFirstChild(`Piece_{key}`)
	if old then
		old:Destroy()
	end
	local cf = CFrame.new(pos + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local model = TalismanModel.build(cf, { [key] = true }, 1.2)
	model.Name = `Piece_{key}`
	-- слабое свечение, чтобы часть было видно фонариком
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 90)
	glow.Brightness = 0.5
	glow.Range = 6
	glow.Parent = model.PrimaryPart
	local p = alwaysShow(prompt(model.PrimaryPart :: BasePart, "Взять", `Часть талисмана: {TalismanModel.NAMES[key]}`, "Survivor"))
	p.Triggered:Connect(function(player)
		if not near(player, model.PrimaryPart :: BasePart, 9) or player:GetAttribute(`Has{key}`) then
			return
		end
		model:Destroy()
		player:SetAttribute(`Has{key}`, true)
		playAt((player.Character :: Model).PrimaryPart or workspace, Sounds.KeyPickup, 0.8)
		notice(player, `Ты взял {RU[key]}. Отнеси её на алтарь в библиотеке.`)
		noticeAll(`Кто-то нашёл {RU[key]} талисмана…`)
	end)
	model.Parent = items
	setState(key, "Found")
end

-- Выживший умер / вышел / стал не выжившим — уронить части и талисман
local function dropAll(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local pos = root and surfaceBelow(root.Position, { character :: Model }) or nil
	for _, key in PARTS do
		if player:GetAttribute(`Has{key}`) then
			player:SetAttribute(`Has{key}`, nil)
			if workspace:GetAttribute("RoundActive") then
				local altar = quest:FindFirstChild("Altar") :: Model?
				spawnPiece(key, pos or (altar and (altar.PrimaryPart :: BasePart).Position) or Vector3.zero)
			end
		end
	end
	-- талисман
	local tool = (character and character:FindFirstChild("Талисман")) or (player:FindFirstChildOfClass("Backpack") and player:FindFirstChildOfClass("Backpack"):FindFirstChild("Талисман"))
	if tool then
		tool:Destroy()
		if workspace:GetAttribute("RoundActive") and pos then
			spawnTalisman(CFrame.new(pos + Vector3.new(0, 0.8, 0)))
		end
	end
end

---------------------------------------------------------------------
-- 1. Сейф и записки с кодом
---------------------------------------------------------------------
local safe = quest:FindFirstChild("Safe") :: Model?
local safeDoor = safe and safe:FindFirstChild("SafeDoor") :: BasePart?
local safeBody = safe and safe:FindFirstChild("Body") :: BasePart?
local safeDoorClosed = safeDoor and safeDoor.CFrame

local function placeNote(pos: Vector3, text: string, name: string)
	local where = surfaceBelow(pos, {})
	local note = Instance.new("Part")
	note.Name = name
	note.Size = Vector3.new(1, 0.04, 1.4)
	note.CFrame = CFrame.new(where + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	note.Color = Color3.fromRGB(226, 214, 180)
	note.Material = Enum.Material.SmoothPlastic
	note.Anchored = true
	note.CanCollide = false
	note:SetAttribute("Text", text)
	-- слабый свет, чтобы записку можно было заметить
	local glow = Instance.new("PointLight")
	glow.Brightness = 0.25
	glow.Range = 4
	glow.Color = Color3.fromRGB(255, 230, 190)
	glow.Parent = note
	note.Parent = items
	CollectionService:AddTag(note, "Note")
end

local function setupCodeNotes(): { BasePart }
	local spots = quest:FindFirstChild("CodeNotes")
	local list = spots and spots:GetChildren() or {}
	-- перемешиваем точки и берём первые 4
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	local ordinal = { "Первая", "Вторая", "Третья", "Четвёртая" }
	for i = 1, 4 do
		local spot = list[i] :: BasePart?
		if spot then
			local digit = code:sub(i, i)
			placeNote(spot.Position, `Обрывок записки Томаса: «Код от сейфа. {ordinal[i]} цифра — {digit}»`, `CodeNote{i}`)
		end
	end
	return { table.unpack(list, 5) } -- свободные точки
end

if safe and safeDoor and safeBody then
	local p = prompt(safeBody, "Ввести код", "Сейф Томаса", "Survivor")
	p.Triggered:Connect(function(player)
		if safeOpen or not near(player, safeBody, 9) then
			return
		end
		safeEvent:FireClient(player, "Open")
	end)
	safeEvent.OnServerEvent:Connect(function(player, entered)
		if safeOpen or typeof(entered) ~= "string" or #entered > 8 or not workspace:GetAttribute("RoundActive") then
			return
		end
		if not near(player, safeBody, 10) then
			return
		end
		local t = os.clock()
		if (safeCooldown[player] or 0) > t then
			return
		end
		safeCooldown[player] = t + Config.SAFE_CODE_COOLDOWN
		if entered ~= code then
			playAt(safeBody, Sounds.DoorLocked, 0.9)
			safeEvent:FireClient(player, "Wrong")
			return
		end
		safeOpen = true
		hide(p, true)
		safeEvent:FireClient(player, "Right")
		playAt(safeBody, Sounds.DoorUnlock, 1)
		local hinge = safeDoor:GetAttribute("HingeLocal") :: Vector3
		swingPart(safeDoor, hinge, CFrame.Angles(0, math.rad(-105), 0), 1.2)
		task.delay(0.6, function()
			spawnPiece("Chain", safeBody.Position - Vector3.new(0, 1, 0))
		end)
	end)
end

---------------------------------------------------------------------
-- 2. Ящик Томаса с электрозамком
---------------------------------------------------------------------
local chest = quest:FindFirstChild("Chest") :: Model?
local chestBody = chest and chest:FindFirstChild("Body") :: BasePart?
local chestLid = chest and chest:FindFirstChild("Lid") :: BasePart?
local lockLight = chest and chest:FindFirstChild("LockLight") :: BasePart?
local lidClosed = chestLid and chestLid.CFrame

local function refreshLock()
	if not lockLight then
		return
	end
	local color = if chestOpen or workspace:GetAttribute("Power") then Color3.fromRGB(40, 200, 60) else Color3.fromRGB(190, 20, 20)
	lockLight.Color = color
	local l = lockLight:FindFirstChildWhichIsA("PointLight")
	if l then
		l.Color = color
	end
end
workspace:GetAttributeChangedSignal("Power"):Connect(refreshLock)

if chest and chestBody and chestLid then
	local p = prompt(chestBody, "Открыть", "Ящик Томаса (электрозамок)", "Survivor")
	p.Triggered:Connect(function(player)
		if chestOpen or not near(player, chestBody, 9) or not workspace:GetAttribute("RoundActive") then
			return
		end
		if not workspace:GetAttribute("Power") then
			playAt(chestBody, Sounds.DoorLocked, 0.9)
			local sparks = Sounds.PanelSpark
			playAt(chestBody, sparks, 0.5)
			notice(player, "Электрозамок мёртв: нет тока. Почини щиток во дворе.")
			return
		end
		chestOpen = true
		hide(p, true)
		refreshLock()
		playAt(chestBody, Sounds.DoorUnlock, 1)
		swingPart(chestLid, chestLid:GetAttribute("HingeLocal") :: Vector3, CFrame.Angles(math.rad(100), 0, 0), 1.2)
		task.delay(0.6, function()
			spawnPiece("Stone", chestBody.Position + Vector3.new(0, 0.6, 0))
		end)
	end)
end

---------------------------------------------------------------------
-- 3. Свечи у могил
---------------------------------------------------------------------
local candles: { [string]: Model } = {}
for _, name in GRAVES do
	local c = quest:FindFirstChild(`Candle_{name}`) :: Model?
	if c then
		candles[name] = c
	end
end

local function setCandle(name: string, lit: boolean)
	local c = candles[name]
	local flame = c and c:FindFirstChild("Flame") :: BasePart?
	if flame then
		flame.Transparency = lit and 0 or 1
		local light = flame:FindFirstChildWhichIsA("PointLight")
		if light then
			light.Enabled = lit
		end
		c:SetAttribute("Lit", lit)
		local base = c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart")
		hide(base and base:FindFirstChildOfClass("ProximityPrompt"), lit)
	end
end

local function ritualText(): string
	local a, b, c = GRAVE_RU[ritualOrder[1]], GRAVE_RU[ritualOrder[2]], GRAVE_RU[ritualOrder[3]]
	return `Рисунок Лили: три могилки и свечки. Подпись кривыми буквами: «Сначала огонёк для {a} могилки, потом для {b}, потом для {c}. Тогда мама отдаст мне свою блестяшку».`
end

local function mound(): BasePart?
	local map = workspace:FindFirstChild("Map")
	local found = map and map:FindFirstChild("Mound_Lily", true)
	return found :: BasePart?
end
local moundStart: CFrame? = nil

for name, c in candles do
	local base = c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart")
	if base then
		local p = prompt(base, "Зажечь свечу", `Могила: {name == "Thomas" and "Томас" or name == "Martha" and "Марта" or "Лили"}`, "Survivor", 6)
		p.Triggered:Connect(function(player)
			if ritualDone or c:GetAttribute("Lit") or not near(player, base, 8) or not workspace:GetAttribute("RoundActive") then
				return
			end
			setCandle(name, true)
			playAt(base, Sounds.FlashlightClick, 0.6)
			if ritualOrder[ritualStep + 1] == name then
				ritualStep += 1
				if ritualStep >= 3 then
					ritualDone = true
					-- земля на могиле Лили проседает — внутри оправа
					local m = mound()
					local pos = base.Position
					if m then
						moundStart = moundStart or m.CFrame
						pos = m.Position
						TweenService:Create(m, TweenInfo.new(1.5), { CFrame = m.CFrame - Vector3.new(0, 0.5, 0) }):Play()
					end
					playAt(base, Sounds.HouseSettle, 1, 80, 0.6)
					task.delay(1.2, function()
						spawnPiece("Frame", pos + Vector3.new(0, 0.2, 0))
					end)
				end
			else
				-- неправильный порядок: свечи гаснут, жуткий крик слышно далеко (монстр услышит)
				ritualStep = 0
				playAt(base, Sounds.DistantScream, 1, Config.RITUAL_FAIL_LOUDNESS, 0.7)
				notice(player, "Свечи погасли. Порядок неверный… и что-то это услышало.")
				task.delay(0.7, function()
					for n in candles do
						setCandle(n, false)
					end
				end)
			end
		end)
	end
end

---------------------------------------------------------------------
-- 4. Алтарь и талисман
---------------------------------------------------------------------
local altar = quest:FindFirstChild("Altar") :: Model?
local altarBody = altar and altar:FindFirstChild("Body") :: BasePart?

local function giveTalisman(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local tool = TalismanModel.makeTool()
	tool.Parent = backpack
	workspace:SetAttribute("TalismanState", "Taken")

	tool.Activated:Connect(function()
		local character = tool.Parent
		if not character or not character:IsA("Model") or Players:GetPlayerFromCharacter(character) ~= player then
			return
		end
		local _, root = aliveRole(player, "Survivor")
		if not root then
			return
		end
		local t = os.clock()
		if (talismanCooldown[player] or 0) > t then
			return
		end
		-- ищем монстра перед собой, рядом и не за стеной
		local best: Player? = nil
		local bestDist = Config.TALISMAN_RANGE
		for _, other in Players:GetPlayers() do
			local mh, mroot = aliveRole(other, "Monster")
			if mh and mroot then
				local offset = mroot.Position - root.Position
				local dist = offset.Magnitude
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
				local facing = flat.Magnitude < 0.1 or flat.Unit:Dot(look.Unit) > 0.2
				if dist <= bestDist and facing then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { character, other.Character :: Model }
					if not workspace:Raycast(root.Position, offset, params) then
						best, bestDist = other, dist
					end
				end
			end
		end
		local stone = tool:FindFirstChild("Ember") :: BasePart?
		if not best then
			talismanCooldown[player] = t + 1 -- промах: короткая пауза
			player:SetAttribute("TalismanReadyAt", workspace:GetServerTimeNow() + 1)
			if stone then
				playAt(stone, Sounds.PanelSpark, 0.3)
			end
			return
		end
		talismanCooldown[player] = t + Config.TALISMAN_COOLDOWN
		player:SetAttribute("TalismanReadyAt", workspace:GetServerTimeNow() + Config.TALISMAN_COOLDOWN)

		local monster = best :: Player
		local mHumanoid, mRoot = aliveRole(monster, "Monster")
		if not mHumanoid or not mRoot then
			return
		end
		local burns = (workspace:GetAttribute("MonsterBurns") or 0) + 1
		workspace:SetAttribute("MonsterBurns", burns)
		-- урон: монстр умирает с TALISMAN_HITS_TO_KILL ожогов
		mHumanoid:TakeDamage(mHumanoid.MaxHealth / Config.TALISMAN_HITS_TO_KILL + 0.01)

		-- эффекты: красная вспышка, дым, крик
		local burn = Instance.new("Attachment")
		burn.Parent = mRoot
		local fire = Instance.new("ParticleEmitter")
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 70, 30), Color3.fromRGB(40, 20, 20))
		fire.LightEmission = 0.8
		fire.Size = NumberSequence.new(1.2, 0)
		fire.Lifetime = NumberRange.new(0.4, 0.9)
		fire.Speed = NumberRange.new(3, 7)
		fire.SpreadAngle = Vector2.new(180, 180)
		fire.Rate = 0
		fire.Parent = burn
		fire:Emit(60)
		local flash = Instance.new("PointLight")
		flash.Color = Color3.fromRGB(255, 50, 30)
		flash.Brightness = 6
		flash.Range = 18
		flash.Parent = burn
		Debris:AddItem(burn, 1.2)
		playAt(mRoot, Sounds.PainScream, 1, 120, 0.55)
		playAt(mRoot, Sounds.PanelSpark, 0.8)
		if stone then
			local light = stone:FindFirstChildWhichIsA("PointLight")
			if light then
				light.Brightness = 5
				task.delay(0.4, function()
					light.Brightness = 0.8
				end)
			end
		end

		-- обожжённый монстр еле идёт
		if mHumanoid.Health > 0 then
			-- StunnedUntil читает и Cocoons: если монстр поднимет/положит тело, ожог не слетит раньше времени
			local stunEnd = workspace:GetServerTimeNow() + Config.TALISMAN_STUN_TIME
			monster:SetAttribute("StunnedUntil", stunEnd)
			mHumanoid.WalkSpeed = math.min(mHumanoid.WalkSpeed, Config.TALISMAN_STUN_SPEED)
			task.delay(Config.TALISMAN_STUN_TIME, function()
				if monster:GetAttribute("StunnedUntil") ~= stunEnd then
					return -- обожгли ещё раз — снимет следующий таймер
				end
				monster:SetAttribute("StunnedUntil", nil)
				-- возвращаем обычную скорость: с телом на плечах медленнее (0 — поднимает тело, не трогаем)
				if mHumanoid.Parent and mHumanoid.Health > 0 and mHumanoid.WalkSpeed == Config.TALISMAN_STUN_SPEED then
					local carry = monster:GetAttribute("CarryingBody") and Config.CARRY_SPEED_MULT or 1
					mHumanoid.WalkSpeed = Config.WALK_SPEED * carry
				end
			end)
			notice(monster, `Талисман обжёг тебя! Ещё {math.ceil(mHumanoid.Health / (mHumanoid.MaxHealth / Config.TALISMAN_HITS_TO_KILL) - 0.01)} — и конец.`)
		end
		notice(player, "Талисман обжёг монстра!")
	end)
end

spawnTalisman = function(cf: CFrame)
	local old = items:FindFirstChild("TalismanPickup")
	if old then
		old:Destroy()
	end
	local model = TalismanModel.build(cf, nil, 1.3)
	model.Name = "TalismanPickup"
	local p = alwaysShow(prompt(model.PrimaryPart :: BasePart, "Взять талисман", "Оберег Марты", "Survivor"))
	p.Triggered:Connect(function(player)
		if not near(player, model.PrimaryPart :: BasePart, 9) or not model.Parent then
			return
		end
		model:Destroy()
		playAt((player.Character :: Model).PrimaryPart or workspace, Sounds.KeyPickup, 1)
		giveTalisman(player)
		notice(player, "Талисман у тебя. Подойди к монстру и кликни — он обожжёт его.")
	end)
	model.Parent = items
	workspace:SetAttribute("TalismanState", "Ready")
end

local placedModels: { Model } = {}

local function tryAssemble()
	for _, key in PARTS do
		if workspace:GetAttribute(`Quest_{key}`) ~= "Placed" then
			return
		end
	end
	if not altarBody then
		return
	end
	-- все 3 части на алтаре: вспышка, и они сливаются в талисман
	playAt(altarBody, Sounds.PowerOn, 1, 90, 0.6)
	-- все части на месте: «Положить части» больше не нужно (и не закроет «Взять талисман»)
	hide(altarBody:FindFirstChildOfClass("ProximityPrompt"), true)
	task.delay(1.5, function()
		for _, m in placedModels do
			m:Destroy()
		end
		table.clear(placedModels)
		spawnTalisman(CFrame.new(altarBody.Position + Vector3.new(0, 2.4, 0)) * CFrame.Angles(math.rad(-70), 0, 0))
		noticeAll("Талисман собран на алтаре в библиотеке!")
	end)
end

if altar and altarBody then
	local p = prompt(altarBody, "Положить части", "Алтарь", "Survivor")
	p.Triggered:Connect(function(player)
		if not near(player, altarBody, 9) then
			return
		end
		local placed = 0
		for _, key in PARTS do
			if player:GetAttribute(`Has{key}`) then
				player:SetAttribute(`Has{key}`, nil)
				setState(key, "Placed")
				placed += 1
				local socket = altar:FindFirstChild(`Socket_{key}`) :: BasePart?
				local pos = socket and socket.Position or altarBody.Position
				local m = TalismanModel.build(CFrame.new(pos + Vector3.new(0, 0.5, 0)), { [key] = true }, 1)
				m.Name = `Placed_{key}`
				m.Parent = items
				table.insert(placedModels, m)
			end
		end
		if placed == 0 then
			notice(player, "Нужны части талисмана: цепочка, камень и оправа.")
			return
		end
		playAt(altarBody, Sounds.KeyPickup, 0.9)
		tryAssemble()
	end)
end

---------------------------------------------------------------------
-- Монстр: здоровье и смерть
---------------------------------------------------------------------
local function setupMonster(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and player:GetAttribute("Role") == "Monster" then
		humanoid.MaxHealth = Config.MONSTER_HEALTH
		humanoid.Health = Config.MONSTER_HEALTH
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		task.defer(setupMonster, player)
		humanoid.Died:Connect(function()
			dropAll(player)
		end)
	end)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		local role = player:GetAttribute("Role")
		if role == "Monster" then
			setupMonster(player)
		elseif role ~= "Survivor" then
			dropAll(player)
		end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	dropAll(player)
	safeCooldown[player] = nil
	talismanCooldown[player] = nil
end)

---------------------------------------------------------------------
-- Случайные места для сейфа, ящика и алтаря
---------------------------------------------------------------------
-- Комнаты-кандидаты: точки записок + исходные места предметов (спальня, генераторная, библиотека)
local roomSpots: { Vector3 } = {}
do
	local spots = quest:FindFirstChild("CodeNotes")
	for _, s in (spots and spots:GetChildren() or {}) do
		if s:IsA("BasePart") then
			table.insert(roomSpots, s.Position)
		end
	end
	for _, body in { safeBody, chestBody, altarBody } do
		if body then
			-- точка в 3 studs перед предметом, на высоте точек записок (пол + 5)
			table.insert(roomSpots, body.Position + body.CFrame.LookVector * 3 + Vector3.new(0, 3, 0))
		end
	end
end

relocate = function()
	local used = {}
	local function move(m: Model?, body: BasePart?, bodyY: number, size: Vector3)
		if m and body then
			local room = QuestPlacer.place({ model = m, body = body, bodyY = bodyY, size = size }, roomSpots, used)
			if not room then
				warn(`Talisman: не нашлось места для {m.Name}, остаётся на старом`)
			end
		end
	end
	move(safe, safeBody, 1.8, Vector3.new(3.2, 3.7, 2.7))
	move(chest, chestBody, 1, Vector3.new(3.8, 2.4, 2.4))
	move(altar, altarBody, 1.3, Vector3.new(5.4, 3, 3))
	-- закрытые положения дверцы сейфа и крышки ящика теперь в новом месте
	safeDoorClosed = safeDoor and safeDoor.CFrame
	lidClosed = chestLid and chestLid.CFrame
end

---------------------------------------------------------------------
-- Новый раунд: всё прячем заново, новый код и новый порядок свечей
---------------------------------------------------------------------
local function reset()
	items:ClearAllChildren()
	table.clear(placedModels)
	for _, player in Players:GetPlayers() do
		for _, key in PARTS do
			player:SetAttribute(`Has{key}`, nil)
		end
		player:SetAttribute("TalismanReadyAt", nil)
		local backpack = player:FindFirstChildOfClass("Backpack")
		for _, holder in { player.Character, backpack } do
			local tool = holder and holder:FindFirstChild("Талисман")
			if tool then
				tool:Destroy()
			end
		end
	end
	for _, key in PARTS do
		setState(key, "Hidden")
	end
	workspace:SetAttribute("TalismanState", "None")
	workspace:SetAttribute("MonsterBurns", 0)

	-- новый код сейфа
	code = ""
	for _ = 1, 4 do
		code ..= tostring(rng:NextInteger(0, 9))
	end
	safeOpen = false
	if safeDoor and safeDoorClosed then
		safeDoor.CFrame = safeDoorClosed
	end
	local safePrompt = safeBody and safeBody:FindFirstChildOfClass("ProximityPrompt")
	hide(safePrompt, false)

	-- ящик
	chestOpen = false
	if chestLid and lidClosed then
		chestLid.CFrame = lidClosed
	end
	local chestPrompt = chestBody and chestBody:FindFirstChildOfClass("ProximityPrompt")
	hide(chestPrompt, false)
	refreshLock()
	relocate()
	-- алтарь снова принимает части
	hide(altarBody and altarBody:FindFirstChildOfClass("ProximityPrompt"), false)

	-- свечи: новый порядок
	ritualOrder = table.clone(GRAVES)
	for i = #ritualOrder, 2, -1 do
		local j = rng:NextInteger(1, i)
		ritualOrder[i], ritualOrder[j] = ritualOrder[j], ritualOrder[i]
	end
	ritualStep = 0
	ritualDone = false
	for name in candles do
		setCandle(name, false)
	end
	local m = mound()
	if m and moundStart then
		m.CFrame = moundStart
	end

	-- записки
	local free = setupCodeNotes()
	local ritualSpot = free[1] or quest:FindFirstChild("RitualNote") :: BasePart?
	if ritualSpot then
		placeNote(ritualSpot.Position, ritualText(), "RitualNote")
	end
end

workspace:GetAttributeChangedSignal("RoundActive"):Connect(function()
	if workspace:GetAttribute("RoundActive") then
		reset()
	end
end)
reset()

-- Только в Studio: подсказка для проверки (tools/T.luau → T.code())
if game:GetService("RunService"):IsStudio() then
	local test = Instance.new("BindableFunction")
	test.Name = "TalismanTest"
	test.Parent = game:GetService("ServerStorage")
	test.OnInvoke = function(action: string, player: Player?)
		if action == "code" then
			return code, table.concat(ritualOrder, " → ")
		elseif action == "give" and player then
			giveTalisman(player)
			return "ok"
		elseif action == "parts" and player then
			for _, key in PARTS do
				player:SetAttribute(`Has{key}`, true)
				setState(key, "Found")
			end
			return "ok"
		end
		return nil
	end
end
