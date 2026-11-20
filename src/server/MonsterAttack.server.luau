-- Удары монстра когтями.
-- Монстр получает инструмент «Когти». Клик → клиент шлёт, куда смотрит камера (RemoteEvent MonsterSwing).
-- Сервер сам проверяет всё: роль, задержку, направление, и сам ищет, в какую часть тела попали когти.
-- Стены закрывают: через стену не ударить.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Wounds = require(script.Parent.Wounds)
local MonsterAnims = require(script.Parent.MonsterAnims)

local TOOL_NAME = "Когти"

-- RemoteEvent'ы для ударов
local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local swingEvent = Instance.new("RemoteEvent")
swingEvent.Name = "MonsterSwing"
swingEvent.Parent = remotes

-- Сообщение игроку о попадании (для эффектов на экране)
local hitEvent = Instance.new("RemoteEvent")
hitEvent.Name = "HitFeedback"
hitEvent.Parent = remotes

local rng = Random.new()
local readyAt: { [Player]: number } = {}

---------------------------------------------------------------------
-- Инструмент «Когти»
---------------------------------------------------------------------
local function findClaws(player: Player): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild(TOOL_NAME)
	if not tool then
		local backpack = player:FindFirstChildOfClass("Backpack")
		tool = backpack and backpack:FindFirstChild(TOOL_NAME)
	end
	return tool :: Tool?
end

local function removeClaws(player: Player)
	local tool = findClaws(player)
	while tool do
		tool:Destroy()
		tool = findClaws(player)
	end
end

local function giveClaws(player: Player)
	removeClaws(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.RequiresHandle = false -- когти — это руки, предмета нет
	tool.CanBeDropped = false
	tool.ToolTip = "ЛКМ — удар когтями"
	tool.Parent = backpack
end

local function onRoleChanged(player: Player)
	if player:GetAttribute("Role") == "Monster" then
		giveClaws(player)
	else
		removeClaws(player)
		readyAt[player] = nil
		player:SetAttribute("ClawReadyAt", nil)
	end
end

local function onPlayer(player: Player)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		onRoleChanged(player)
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	readyAt[player] = nil
end)

---------------------------------------------------------------------
-- Какая часть тела
---------------------------------------------------------------------

-- Расстояние от точки до детали (0, если точка внутри)
local function distanceToPart(part: BasePart, point: Vector3): number
	local p = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	local clamped = Vector3.new(math.clamp(p.X, -half.X, half.X), math.clamp(p.Y, -half.Y, half.Y), math.clamp(p.Z, -half.Z, half.Z))
	return (p - clamped).Magnitude
end

-- Шапка / волосы / одежда-аксессуар → ближайшая к удару часть тела
-- (крепления у аксессуаров бывают разные, поэтому просто ищем, какая часть тела ближе к когтям)
local function realPart(part: BasePart, character: Model, point: Vector3): BasePart
	if not (part.Parent and part.Parent:IsA("Accessory")) then
		return part
	end
	local best, bestDist = part, math.huge
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.CanQuery then
			local d = distanceToPart(child, point)
			if d < bestDist then
				best, bestDist = child, d
			end
		end
	end
	return best
end

-- Имя детали → зона. Подходит и для R15 (LeftUpperArm), и для R6 (Left Arm)
local function zoneOf(part: BasePart): (string, string?)
	local n = part.Name
	local side = if n:find("Left") then "Left" elseif n:find("Right") then "Right" else nil
	if n == "Head" then
		return "Head", nil
	elseif n:find("Arm") or n:find("Hand") then
		return "Arm", side or "Right"
	elseif n:find("Leg") or n:find("Foot") then
		return "Leg", side or "Left"
	end
	return "Torso", nil
end

-- Найти выжившего по детали
local function survivorFromPart(part: Instance): (Player?, Model?)
	local model = part:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	if not model then
		return nil, nil
	end
	local player = Players:GetPlayerFromCharacter(model)
	if not player or player:GetAttribute("Role") ~= "Survivor" then
		return nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return player, model
end

-- Широкий взмах: ближайшая по ходу удара часть тела выжившего, которая проходит
-- не дальше CLAW_RADIUS от линии удара. Стены закрывают: проверяем лучом до детали.
local function sweepHit(origin: Vector3, aim: Vector3, monsterCharacter: Model, params: RaycastParams): (BasePart?, Vector3?)
	local best: BasePart? = nil
	local bestPos: Vector3? = nil
	local bestAlong = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character ~= monsterCharacter and survivorFromPart(character:FindFirstChildWhichIsA("BasePart") or character) then
			for _, part in character:GetChildren() do
				if part:IsA("BasePart") and part.CanQuery and part.Name ~= "HumanoidRootPart" then
					local along = (part.Position - origin):Dot(aim)
					if along > 0 and along <= Config.MONSTER_REACH and along < bestAlong then
						local pointOnLine = origin + aim * along
						if distanceToPart(part, pointOnLine) <= Config.CLAW_RADIUS then
							local check = workspace:Raycast(origin, part.Position - origin, params)
							if check and check.Instance:IsDescendantOf(character) then
								best, bestPos, bestAlong = part, check.Position, along
							end
						end
					end
				end
			end
		end
	end
	return best, bestPos
end

---------------------------------------------------------------------
-- Взмах
---------------------------------------------------------------------
local function swing(monster: Player, aim: Vector3)
	-- проверки: роль, живой, когти в руках, задержка
	if monster:GetAttribute("Role") ~= "Monster" or not workspace:GetAttribute("RoundActive") or monster:GetAttribute("CarryingBody") or monster:GetAttribute("Frozen") then
		return -- с телом на плече или замерший в свете фонарика бить нельзя
	end
	local character = monster.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local tool = character and character:FindFirstChild(TOOL_NAME)
	if not humanoid or humanoid.Health <= 0 or not head or not root or not tool then
		return
	end
	local t = workspace:GetServerTimeNow()
	if t < (readyAt[monster] or 0) then
		return
	end
	-- направление: только вперёд от монстра (за спину не бьём)
	if typeof(aim) ~= "Vector3" or aim.Magnitude < 0.5 or aim.Magnitude > 1.5 then
		return
	end
	aim = aim.Unit
	local flatAim = Vector3.new(aim.X, 0, aim.Z)
	local flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if flatAim.Magnitude > 0.1 and flatLook.Magnitude > 0.1 and flatAim.Unit:Dot(flatLook.Unit) < math.cos(math.rad(80)) then
		aim = root.CFrame.LookVector -- клиент «целится» за спину — бьём просто вперёд
	end

	-- анимация удара: своя из Blender (Attack/Attack2), а если её ID нет в Config —
	-- стандартный взмах (скрипт Animate играет его, когда в инструменте появляется toolanim)
	if not MonsterAnims.attack(character) then
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		game:GetService("Debris"):AddItem(anim, 1)
	end
	Wounds.playAt(root, Sounds.ClawSwing, 0.8)

	-- ищем, во что попали когти (стены тоже ловятся — через них не бьём)
	local origin = head.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hitPart: BasePart? = nil
	local hitPos = origin
	-- 1) узкий луч точно туда, куда целились (голова, ноги — куда навёл, туда и попал)
	-- 2) если мимо — «широкий взмах»: часть тела в пределах CLAW_RADIUS от линии удара
	--    (например, курсор между ног — луч ушёл в пол, но когти всё равно задели ногу)
	local result = workspace:Raycast(origin, aim * Config.MONSTER_REACH, params)
	local wideHit, widePos = nil, nil
	if not (result and survivorFromPart(result.Instance)) then
		result = nil
		wideHit, widePos = sweepHit(origin, aim, character, params)
	end
	if result then
		hitPart = result.Instance :: BasePart
		hitPos = result.Position
	elseif wideHit then
		hitPart = wideHit
		hitPos = widePos :: Vector3
	else
		-- жертва вплотную (сфера уже внутри неё) — смотрим, кто прямо перед монстром
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = { character }
		local center = origin + aim * 1.5
		local best = math.huge
		for _, part in workspace:GetPartBoundsInRadius(center, 1.8, overlap) do
			if part.CanQuery and survivorFromPart(part) then
				local d = (part.Position - center).Magnitude
				if d < best then
					best = d
					hitPart = part
					hitPos = part.Position
				end
			end
		end
	end

	-- в Studio пишем в Output, во что попали когти (удобно проверять)
	if RunService:IsStudio() then
		print(`THE NEST когти: {monster.Name} -> {if hitPart then hitPart:GetFullName() else "ничего"} (aim {aim})`)
	end

	local victim, victimCharacter = nil, nil
	if hitPart then
		victim, victimCharacter = survivorFromPart(hitPart)
	end
	if not victim or not hitPart or not victimCharacter then
		-- промах
		readyAt[monster] = t + Config.MONSTER_MISS_COOLDOWN
		monster:SetAttribute("ClawReadyAt", readyAt[monster])
		return
	end

	local part = realPart(hitPart, victimCharacter, hitPos)
	local zone, side = zoneOf(part)
	-- «вплотную» — по расстоянию между телами (по полу), а не до точки удара:
	-- иначе по ногам всегда было бы «издалека», ведь они ниже головы монстра
	local victimRoot = victimCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	local gap = victimRoot and (victimRoot.Position - root.Position) or (hitPos - origin)
	local close = Vector3.new(gap.X, 0, gap.Z).Magnitude <= Config.MONSTER_CLOSE_RANGE
	Wounds.playAt(part, Sounds.ClawHit, 1)
	local info = Wounds.hit(victim, { zone = zone, side = side, close = close, part = part })

	-- брызги крови
	local splash = Instance.new("Attachment")
	splash.WorldPosition = hitPos
	splash.Parent = workspace.Terrain
	local blood = Instance.new("ParticleEmitter")
	blood.Color = ColorSequence.new(Color3.fromRGB(110, 0, 0))
	blood.LightEmission = 0
	blood.Size = NumberSequence.new(0.25, 0.05)
	blood.Lifetime = NumberRange.new(0.3, 0.7)
	blood.Speed = NumberRange.new(6, 14)
	blood.SpreadAngle = Vector2.new(50, 50)
	blood.Acceleration = Vector3.new(0, -40, 0)
	blood.Enabled = false
	blood.Parent = splash
	blood:Emit(info.deep and 40 or 15)
	game:GetService("Debris"):AddItem(splash, 2)

	readyAt[monster] = t + rng:NextNumber(Config.MONSTER_HIT_COOLDOWN_MIN, Config.MONSTER_HIT_COOLDOWN_MAX)
	monster:SetAttribute("ClawReadyAt", readyAt[monster])

	hitEvent:FireClient(victim, "Victim", info)
	hitEvent:FireClient(monster, "Monster", info)
end

swingEvent.OnServerEvent:Connect(function(player, aim)
	swing(player, aim)
end)
