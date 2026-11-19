-- Тело убитого и кокон.
--  1. Выживший умер → его персонаж превращается в тело (Workspace.Bodies), лежит там, где умер.
--  2. Монстр подбирает тело (E), несёт на плече (медленнее, бить нельзя), может бросить (E).
--  3. У любого тайника (Workspace.Hideouts) монстр нажимает E «Спрятать тело» → там появляется кокон.
--     Не спрятал — тело так и лежит, кокона и второго монстра не будет.
--  4. Кокон вылупится через COCOON_BASE_TIME + (удары − 1) × COCOON_PER_HIT сек.
--  5. Выжившие рвут кокон, держа E: +1–3% каждые 0.75 сек. 100% — кокон уничтожен.
--  6. Вылупился — у убитого атрибут CocoonState = "Hatched" и событие ServerStorage.CocoonHatched
--     (второго монстра сделаем в следующем пункте плана).
--
-- Атрибуты у убитого игрока: CocoonState = "Body" / "Cocoon" / "Destroyed" / "Hatched"
-- У тела и кокона: VictimId (UserId), Hits; у кокона ещё HatchAt (время сервера) и Progress (0–100).
-- У монстра: CarryingBody = true, пока несёт тело.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Wounds = require(script.Parent.Wounds)

local feedback = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HitFeedback") :: RemoteEvent

local hatchedEvent = Instance.new("BindableEvent")
hatchedEvent.Name = "CocoonHatched" -- (victim: Player, cframe: CFrame)
hatchedEvent.Parent = ServerStorage

local bodies = Instance.new("Folder")
bodies.Name = "Bodies"
bodies.Parent = workspace

local cocoons = Instance.new("Folder")
cocoons.Name = "Cocoons"
cocoons.Parent = workspace

local rng = Random.new()
local FLESH = Color3.fromRGB(122, 74, 68)
local FLESH_DARK = Color3.fromRGB(70, 28, 30)

local function notice(player: Player, text: string)
	feedback:FireClient(player, "Notice", { text = text })
end

local function alive(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and humanoid.Health > 0 and root then
		return humanoid, root
	end
	return nil, nil
end

local function floorBelow(pos: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -20, 0), params)
	return result and result.Position or pos
end

---------------------------------------------------------------------
-- Тело
---------------------------------------------------------------------
type Carry = { body: Model, weld: WeldConstraint }
local carrying: { [Player]: Carry } = {}

local function setBodyPhysics(body: Model, carried: boolean)
	for _, part in body:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = not carried
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = not carried
			part.Massless = true
		end
	end
end

-- Положить тело на пол лицом вниз
local function layDown(body: Model, at: Vector3, yaw: number, ignore: Instance?)
	local floor = floorBelow(at, { body, bodies, ignore or body })
	body:PivotTo(CFrame.new(floor + Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(90), 0, 0))
end

local function updateCarrySpeed(monster: Player)
	local humanoid = alive(monster)
	if humanoid then
		humanoid.WalkSpeed = Config.WALK_SPEED * (carrying[monster] and Config.CARRY_SPEED_MULT or 1)
	end
end

local function dropBody(monster: Player)
	local c = carrying[monster]
	if not c then
		return
	end
	carrying[monster] = nil
	monster:SetAttribute("CarryingBody", nil)
	c.weld:Destroy()
	if c.body.Parent then
		setBodyPhysics(c.body, false)
		local _, root = alive(monster)
		local pos = root and (root.Position + root.CFrame.LookVector * 2) or c.body:GetPivot().Position
		layDown(c.body, pos, root and math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z) or 0, monster.Character)
		local prompt = c.body:FindFirstChild("BodyPrompt", true) :: ProximityPrompt?
		if prompt then
			prompt.ActionText = "Взять тело"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
			prompt.HoldDuration = 0.8
		end
	end
	updateCarrySpeed(monster)
end

local function pickUp(monster: Player, body: Model)
	if carrying[monster] or not body.Parent then
		return
	end
	-- тело уже несёт кто-то другой
	for _, c in carrying do
		if c.body == body then
			return
		end
	end
	local _, root = alive(monster)
	local bodyRoot = body:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not bodyRoot then
		return
	end
	setBodyPhysics(body, true)
	-- кладём поперёк плеч
	body:PivotTo(root.CFrame * CFrame.new(0, 1.7, 0.4) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(90), 0, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = bodyRoot
	weld.Parent = bodyRoot
	carrying[monster] = { body = body, weld = weld }
	monster:SetAttribute("CarryingBody", true)
	Wounds.playAt(root, Sounds.BodyPickup, 0.7)
	local prompt = body:FindFirstChild("BodyPrompt", true) :: ProximityPrompt?
	if prompt then
		-- бросать на G: на E в это время «Спрятать тело» у тайника (Roblox показывает одну подсказку на клавишу)
		prompt.ActionText = "Бросить тело"
		prompt.KeyboardKeyCode = Enum.KeyCode.G
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		prompt.HoldDuration = 0
	end
	updateCarrySpeed(monster)
end

-- Персонаж убитого → тело
local function makeBody(victim: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	character.Archivable = true
	local body = character:Clone()
	body.Name = `Body_{victim.Name}`
	-- убираем всё лишнее: скрипты, инструменты (фонарик), звуки
	for _, d in body:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("Sound") or d:IsA("ForceField") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
	local humanoid = body:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Humanoid нужен только для одежды; физику и полоску здоровья выключаем
		humanoid.EvaluateStateMachine = false
		humanoid.PlatformStand = true
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.RequiresNeck = false
	end
	local hits = math.max(1, victim:GetAttribute("HitsTaken") or 1)
	body:SetAttribute("VictimId", victim.UserId)
	body:SetAttribute("Hits", hits)
	setBodyPhysics(body, false)
	layDown(body, root.Position, rng:NextNumber(0, math.pi * 2), character) -- не ловим лучом самого мертвеца

	local bodyRoot = body:FindFirstChild("HumanoidRootPart") :: BasePart
	-- суставы мёртвого персонажа не держат части, поэтому привариваем всё к корню:
	-- иначе при переноске руки, ноги и голова отвалятся и провалятся сквозь пол
	for _, part in body:GetDescendants() do
		if part:IsA("BasePart") and part ~= bodyRoot then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "BodyWeld"
			weld.Part0 = bodyRoot
			weld.Part1 = part
			weld.Parent = part
		end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BodyPrompt"
	prompt.ActionText = "Взять тело"
	prompt.ObjectText = victim.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ForRole", "Monster")
	prompt.Parent = bodyRoot
	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("Role") ~= "Monster" or not alive(player) then
			return
		end
		local c = carrying[player]
		if c and c.body == body then
			dropBody(player)
		elseif not c then
			pickUp(player, body)
		end
	end)

	body.Parent = bodies
	victim:SetAttribute("CocoonState", "Body")
	-- оригинального персонажа убираем: камера убитого теперь смотрит на тело (клиент CocoonView)
	character:Destroy()
end

---------------------------------------------------------------------
-- Кокон
---------------------------------------------------------------------
local tearing: { [Player]: Model } = {} -- кто сейчас рвёт какой кокон

local function playerById(id: number): Player?
	for _, p in Players:GetPlayers() do
		if p.UserId == id then
			return p
		end
	end
	return nil
end

local function cocoonAt(hideout: BasePart): Model?
	for _, c in cocoons:GetChildren() do
		if c:GetAttribute("Hideout") == hideout.Name then
			return c :: Model
		end
	end
	return nil
end

local function blob(parent: Instance, size: Vector3, cf: CFrame, color: Color3, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "Flesh"
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = 0.08
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = parent
	return p
end

local function buildCocoon(hideout: BasePart, victimId: number, hits: number): Model
	local model = Instance.new("Model")
	model.Name = "Cocoon"
	local floor = floorBelow(hideout.Position, { hideout, model })
	local base = CFrame.new(floor) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)

	-- сам кокон: вытянутое «яйцо» из плоти
	local core = blob(model, Vector3.new(3.2, 5.6, 3), base * CFrame.new(0, 2.6, 0) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8))), FLESH, "Core")
	-- наросты и вены
	for _ = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local y = rng:NextNumber(0.8, 4.6)
		local r = 1.35 + rng:NextNumber(-0.1, 0.15)
		blob(model, Vector3.new(rng:NextNumber(0.6, 1.3), rng:NextNumber(0.8, 1.8), rng:NextNumber(0.6, 1.2)), base * CFrame.new(math.cos(a) * r, y, math.sin(a) * r), FLESH_DARK, "Growth")
	end
	-- тяжи слизи вверх (будто кокон подвешен)
	for i = 1, 3 do
		local strand = Instance.new("Part")
		strand.Name = "Strand"
		strand.Size = Vector3.new(0.12, 5, 0.12)
		strand.CFrame = base * CFrame.new((i - 2) * 0.7, 7.5, rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, 0, math.rad((i - 2) * 6))
		strand.Color = Color3.fromRGB(150, 140, 110)
		strand.Material = Enum.Material.Glass
		strand.Transparency = 0.35
		strand.Anchored = true
		strand.CanCollide = false
		strand.CanQuery = false
		strand.Parent = model
	end
	-- лужа слизи
	local puddle = Instance.new("Part")
	puddle.Name = "Puddle"
	puddle.Shape = Enum.PartType.Cylinder
	puddle.Size = Vector3.new(0.06, 5.5, 5.5)
	puddle.CFrame = base * CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.rad(90))
	puddle.Color = Color3.fromRGB(78, 70, 48)
	puddle.Material = Enum.Material.SmoothPlastic
	puddle.Reflectance = 0.3
	puddle.Transparency = 0.15
	puddle.Anchored = true
	puddle.CanCollide = false
	puddle.CanQuery = false
	puddle.Parent = model
	model.PrimaryPart = core

	-- сердцебиение внутри (слышно только рядом)
	local heart = Instance.new("Sound")
	heart.Name = "Heartbeat"
	heart.SoundId = Sounds.Heartbeat
	heart.Looped = true
	heart.Volume = 0.6
	heart.RollOffMinDistance = 4
	heart.RollOffMaxDistance = 22
	heart.Parent = core
	heart:Play()

	-- полоска разрыва видна только вблизи
	local gui = Instance.new("BillboardGui")
	gui.Name = "TearBar"
	gui.Size = UDim2.fromOffset(120, 12)
	gui.StudsOffset = Vector3.new(0, 3.6, 0)
	gui.MaxDistance = 12
	gui.Enabled = false
	gui.Parent = core
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
	fill.BorderSizePixel = 0
	fill.Parent = back

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TearPrompt"
	prompt.ActionText = "Разорвать кокон (держи E)"
	prompt.ObjectText = "Кокон"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ForRole", "Survivor")
	prompt.Parent = core
	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("Role") == "Survivor" and alive(player) then
			tearing[player] = model
		end
	end)
	prompt.TriggerEnded:Connect(function(player)
		if tearing[player] == model then
			tearing[player] = nil
		end
	end)

	local hatchTime = Config.COCOON_BASE_TIME + (hits - 1) * Config.COCOON_PER_HIT
	model:SetAttribute("VictimId", victimId)
	model:SetAttribute("Hits", hits)
	model:SetAttribute("Hideout", hideout.Name)
	model:SetAttribute("HatchAt", workspace:GetServerTimeNow() + hatchTime)
	model:SetAttribute("Progress", 0)
	model.Parent = cocoons
	return model
end

-- Кокон исчезает: разорвали (destroyed) или вылупился (hatched)
local function finishCocoon(model: Model, how: string)
	if not model.Parent then
		return
	end
	local core = model.PrimaryPart
	local cf = core and core.CFrame or model:GetPivot()
	for p, m in tearing do
		if m == model then
			tearing[p] = nil
		end
	end
	if core then
		-- брызги и звук
		local att = Instance.new("Attachment")
		att.WorldPosition = cf.Position
		att.Parent = workspace.Terrain
		local burst = Instance.new("ParticleEmitter")
		burst.Color = ColorSequence.new(Color3.fromRGB(100, 10, 10), Color3.fromRGB(90, 80, 50))
		burst.LightEmission = 0
		burst.Size = NumberSequence.new(0.35, 0.05)
		burst.Lifetime = NumberRange.new(0.5, 1.2)
		burst.Speed = NumberRange.new(8, 18)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Acceleration = Vector3.new(0, -40, 0)
		burst.Enabled = false
		burst.Parent = att
		burst:Emit(80)
		Wounds.playAt(att, Sounds.CocoonHatch, 1)
		game:GetService("Debris"):AddItem(att, 3)
	end
	-- остаётся пустая разорванная оболочка с лужей
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d.Name ~= "Puddle" and d.Name ~= "Strand" then
			if d.Name == "Core" then
				d.Size = Vector3.new(3, 2.2, 2.8)
				d.CFrame = CFrame.new(cf.Position.X, cf.Position.Y - 1.8, cf.Position.Z)
				d.Color = FLESH_DARK
				for _, c in d:GetChildren() do
					if not c:IsA("SpecialMesh") then
						c:Destroy()
					end
				end
			else
				d:Destroy()
			end
		end
	end
	model.Name = how == "Hatched" and "HatchedCocoon" or "TornCocoon"
	model:SetAttribute("State", how)

	local victim = playerById(model:GetAttribute("VictimId") or 0)
	if victim then
		victim:SetAttribute("CocoonState", how)
		if how == "Hatched" then
			hatchedEvent:Fire(victim, cf)
		end
	end
	for _, p in Players:GetPlayers() do
		if how == "Destroyed" then
			if p == victim then
				notice(p, "Кокон разорвали. Ты умер окончательно.")
			elseif p:GetAttribute("Role") == "Survivor" and (p.Character and (p.Character:GetPivot().Position - cf.Position).Magnitude < 15) then
				notice(p, "Кокон разорван!")
			end
		elseif p == victim then
			notice(p, "Ты вылупился...")
		end
	end
end

local function hideBody(monster: Player, hideout: BasePart)
	local c = carrying[monster]
	if not c or monster:GetAttribute("Role") ~= "Monster" then
		return
	end
	if cocoonAt(hideout) then
		notice(monster, "Здесь уже есть кокон")
		return
	end
	local body = c.body
	local victimId = body:GetAttribute("VictimId") or 0
	local hits = body:GetAttribute("Hits") or 1
	carrying[monster] = nil
	monster:SetAttribute("CarryingBody", nil)
	c.weld:Destroy()
	body:Destroy()
	updateCarrySpeed(monster)
	local model = buildCocoon(hideout, victimId, hits)
	hideout:SetAttribute("Occupied", true)
	local victim = playerById(victimId)
	if victim then
		victim:SetAttribute("CocoonState", "Cocoon")
	end
	local secs = math.floor((model:GetAttribute("HatchAt") :: number) - workspace:GetServerTimeNow() + 0.5)
	notice(monster, `Тело спрятано. Кокон созреет через {secs} сек`)
	Wounds.playAt(model.PrimaryPart :: BasePart, Sounds.CocoonSquirm, 0.8)
end

-- Подсказки «Спрятать тело» на всех тайниках
local function setupHideout(hideout: Instance)
	if not hideout:IsA("BasePart") or hideout:FindFirstChild("HidePrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HidePrompt"
	prompt.ActionText = "Спрятать тело"
	prompt.ObjectText = "Тайник"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ForRole", "Monster")
	prompt:SetAttribute("NeedsCarry", true) -- клиент покажет её, только когда монстр несёт тело
	prompt.Parent = hideout
	prompt.Triggered:Connect(function(player)
		hideBody(player, hideout)
	end)
end

local hideouts = workspace:FindFirstChild("Hideouts")
if hideouts then
	for _, h in hideouts:GetChildren() do
		setupHideout(h)
	end
	hideouts.ChildAdded:Connect(setupHideout)
else
	warn("Нет Workspace.Hideouts — коконов не будет")
end

---------------------------------------------------------------------
-- Смерть выжившего → тело
---------------------------------------------------------------------
local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.BreakJointsOnDeath = false -- тело не разваливается на части
	humanoid.Died:Connect(function()
		-- RoundManager может уже сменить роль на Dead — подходят обе
		local role = player:GetAttribute("Role")
		if workspace:GetAttribute("RoundActive") and (role == "Survivor" or role == "Dead") then
			task.wait(0.3) -- пусть тело чуть осядет
			if character.Parent then
				makeBody(player, character)
			end
		end
		dropBody(player) -- если умер монстр с телом на плечах
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	player:GetAttributeChangedSignal("Role"):Connect(function()
		if player:GetAttribute("Role") ~= "Monster" then
			dropBody(player)
		end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	dropBody(player)
	tearing[player] = nil
end)

---------------------------------------------------------------------
-- Разрыв и вылупление
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(Config.COCOON_TEAR_TICK)
		local now = workspace:GetServerTimeNow()
		-- рвут
		local gained: { [Model]: number } = {}
		for player, model in tearing do
			local _, root = alive(player)
			local core = model.PrimaryPart
			if not model.Parent or model:GetAttribute("State") or not root or not core
				or player:GetAttribute("Role") ~= "Survivor" or (root.Position - core.Position).Magnitude > 9 then
				tearing[player] = nil
				continue
			end
			local amount = rng:NextInteger(Config.COCOON_TEAR_MIN, Config.COCOON_TEAR_MAX)
			local arms = player:GetAttribute("ArmsLost") or 0
			if arms >= 2 then
				continue -- без рук не порвать
			elseif arms == 1 then
				amount = math.ceil(amount / Config.ONE_ARM_SLOWDOWN)
			end
			gained[model] = (gained[model] or 0) + amount
		end
		for model, amount in gained do
			local progress = math.min(100, (model:GetAttribute("Progress") or 0) + amount)
			model:SetAttribute("Progress", progress)
			local core = model.PrimaryPart
			if core then
				Wounds.playAt(core, Sounds.ClawHit, 0.6)
				if rng:NextNumber() < 0.35 then
					Wounds.playAt(core, Sounds.CocoonSquirm, 0.5)
				end
				local gui = core:FindFirstChild("TearBar") :: BillboardGui?
				if gui then
					gui.Enabled = true
					local fill = gui:FindFirstChild("Fill", true) :: Frame?
					if fill then
						fill.Size = UDim2.fromScale(progress / 100, 1)
					end
				end
			end
			if progress >= 100 then
				finishCocoon(model, "Destroyed")
			end
		end
		-- вылупляются
		for _, model in cocoons:GetChildren() do
			if not model:GetAttribute("State") and now >= (model:GetAttribute("HatchAt") or math.huge) then
				finishCocoon(model :: Model, "Hatched")
			end
		end
	end
end)

-- Кокон дышит: медленно раздувается в такт сердцу
task.spawn(function()
	local t = 0
	while true do
		t += 0.1
		task.wait(0.1)
		local beat = math.max(0, math.sin(t * 5)) ^ 4 -- короткий толчок
		for _, model in cocoons:GetChildren() do
			local core = model:IsA("Model") and model.PrimaryPart
			local mesh = core and core:FindFirstChildOfClass("SpecialMesh")
			if mesh and not model:GetAttribute("State") then
				local s = 1 + beat * 0.05
				mesh.Scale = Vector3.new(s, 1 + beat * 0.03, s)
			end
		end
	end
end)

---------------------------------------------------------------------
-- Только в Studio: вход для проверки (tools/T.luau → T.hide(), T.tear()).
-- Вызывает те же функции, что и подсказки E, чтобы не бегать персонажами.
---------------------------------------------------------------------
if game:GetService("RunService"):IsStudio() then
	local test = Instance.new("BindableFunction")
	test.Name = "CocoonTest"
	test.Parent = ServerStorage
	test.OnInvoke = function(action: string, player: Player, target: Instance?)
		if action == "pickup" then
			local body = target or bodies:FindFirstChildWhichIsA("Model")
			if body then
				pickUp(player, body :: Model)
			end
		elseif action == "hide" then
			if target then
				hideBody(player, target :: BasePart)
			end
		elseif action == "tear" then
			local model = target or cocoons:FindFirstChild("Cocoon")
			if model then
				tearing[player] = model :: Model
			end
		end
		return player:GetAttribute("CarryingBody"), tearing[player] ~= nil
	end
end

---------------------------------------------------------------------
-- Новый раунд / конец раунда: убираем тела и коконы
---------------------------------------------------------------------
workspace:GetAttributeChangedSignal("RoundActive"):Connect(function()
	for player in carrying do
		dropBody(player)
	end
	table.clear(tearing)
	bodies:ClearAllChildren()
	cocoons:ClearAllChildren()
	if hideouts then
		for _, h in hideouts:GetChildren() do
			h:SetAttribute("Occupied", nil)
		end
	end
	for _, p in Players:GetPlayers() do
		p:SetAttribute("CocoonState", nil)
	end
end)
