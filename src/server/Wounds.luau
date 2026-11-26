-- Раны выживших: урон по частям тела, кровотечение, хромота, слепота, оторванные руки, перевязка.
-- Это модуль (ModuleScript). Им пользуются MonsterAttack (наносит раны) и Bandages (лечит).
--
-- Атрибуты у игрока (их читает HUD):
--   HitsTaken    — сколько раз монстр попал (для таймера кокона)
--   WoundsText   — список ран текстом
--   Bleeding     — сколько ран сейчас кровоточит
--   ArmsLost     — 0, 1 или 2 оторванных руки
--   EyesHurt     — 0, 1 или 2 повреждённых глаза
--   BlindUntil   — до какого времени (workspace:GetServerTimeNow()) почти ничего не видно
--   Bandaging    — true, пока перевязывается (бинтом или аптечкой)
--   ArmShake     — 0 или сила дрожи фонарика в градусах (рана руки не вылечена)
--
-- Нога и рука: царапина хромает/дрожит, пока её не перевяжут бинтом;
-- глубокая рана (и оторванная рука) — пока не вылечат аптечкой. Бинт на ней только останавливает кровь.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local Wounds = {}

type Wound = {
	zone: string, -- Head, Torso, Arm, Leg
	side: string?, -- Left / Right для рук и ног
	deep: boolean,
	torn: boolean, -- рука оторвана
	bleed: number, -- сколько HP за раз снимает кровотечение (0 = не кровоточит)
	nextBleed: number,
	treated: boolean, -- перевязана (бинтом или аптечкой)
	cured: boolean, -- вылечена аптечкой: ни хромоты, ни дрожи
	part: BasePart?, -- куда прицеплены капли крови
}

type State = {
	wounds: { Wound },
	bandaging: boolean,
	cancelBandage: boolean,
}

local rng = Random.new()
local states: { [Player]: State } = {}

local ZONE_NAMES = {
	Head = "Голова",
	Torso = "Тело",
	Arm = "рука",
	Leg = "нога",
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function getState(player: Player): State
	local s = states[player]
	if not s then
		s = { wounds = {}, bandaging = false, cancelBandage = false }
		states[player] = s
	end
	return s
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function playAt(parent: Instance, id: string | { string }, volume: number)
	if type(id) == "table" then
		id = id[rng:NextInteger(1, #id)]
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id :: string
	sound.Volume = volume
	sound.RollOffMaxDistance = 70
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end
Wounds.playAt = playAt

-- Название раны для HUD: «Левая рука», «Голова»
local function woundTitle(w: Wound): string
	if w.zone == "Arm" or w.zone == "Leg" then
		local side = w.side == "Left" and "Левая" or "Правая"
		return `{side} {ZONE_NAMES[w.zone]}`
	end
	return ZONE_NAMES[w.zone]
end

-- Капли крови на части тела, пока рана кровоточит
local function setBloodDrip(w: Wound, on: boolean)
	local part = w.part
	if not part or not part.Parent then
		return
	end
	local emitter = part:FindFirstChild("BloodDrip") :: ParticleEmitter?
	if on and not emitter then
		local e = Instance.new("ParticleEmitter")
		e.Name = "BloodDrip"
		e.Color = ColorSequence.new(Color3.fromRGB(90, 0, 0))
		e.LightEmission = 0
		e.Size = NumberSequence.new(0.12, 0.05)
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Rate = w.torn and 14 or 5
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(20, 20)
		e.Acceleration = Vector3.new(0, -30, 0)
		e.Parent = part
	elseif not on and emitter then
		emitter:Destroy()
	end
end

-- Рана ещё мешает: царапина — пока не перевязана, глубокая — пока не вылечена аптечкой
local function stillHurts(w: Wound): boolean
	if w.cured then
		return false
	end
	return w.deep or w.torn or not w.treated
end

-- Рана на ноге или руке, которая ещё хромает/дрожит
local function limbHurts(w: Wound): boolean
	return (w.zone == "Leg" or w.zone == "Arm") and stillHurts(w)
end

-- Скорость: каждая невылеченная рана на ноге замедляет; при перевязке почти стоим
local function updateSpeed(player: Player)
	local humanoid = humanoidOf(player)
	local s = states[player]
	if not humanoid or not s then
		return
	end
	local mult = 1
	for _, w in s.wounds do
		if w.zone == "Leg" and stillHurts(w) then
			mult *= w.deep and Config.LEG_DEEP_SLOW or Config.LEG_SCRATCH_SLOW
		end
	end
	local speed = math.max(Config.MIN_WALK_SPEED, Config.WALK_SPEED * mult)
	if s.bandaging then
		speed = math.min(speed, Config.BANDAGE_WALK_SPEED)
	end
	humanoid.WalkSpeed = speed
end

-- Обновляем атрибуты, которые показывает HUD
local function publish(player: Player)
	local s = states[player]
	local lines = {}
	local bleeding = 0
	local shake = 0
	if s then
		for _, w in s.wounds do
			local text
			if w.torn then
				text = "оторвана"
			elseif w.deep then
				text = "глубокая рана"
			else
				text = "царапина"
			end
			if w.cured then
				text ..= ", вылечено аптечкой"
			elseif w.treated then
				text ..= ", перевязано"
			elseif w.bleed > 0 then
				text ..= ", кровотечение"
				bleeding += 1
			end
			if stillHurts(w) then
				if w.zone == "Leg" then
					text ..= if w.deep then ", хромаешь (нужна аптечка)" else ", хромаешь"
				elseif w.zone == "Arm" then
					text ..= if w.deep or w.torn then ", рука дрожит (нужна аптечка)" else ", рука дрожит"
					shake = math.max(shake, if w.deep or w.torn then Config.ARM_SHAKE_DEEP else Config.ARM_SHAKE_SCRATCH)
				end
			end
			table.insert(lines, `{woundTitle(w)}: {text}`)
		end
	end
	player:SetAttribute("WoundsText", table.concat(lines, "\n"))
	player:SetAttribute("Bleeding", bleeding)
	player:SetAttribute("ArmShake", if shake > 0 then shake else nil)
	updateSpeed(player)
end

-- Прячем оторванную руку (и в неё больше нельзя попасть)
local function tearOffArm(character: Model, side: string): BasePart?
	local stump: BasePart? = nil
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") then
			local n = part.Name
			local isArm = n:find(side) and (n:find("Arm") or n:find("Hand"))
			if isArm then
				if n:find("Upper") or n == `{side} Arm` then
					stump = part
				end
				part.Transparency = 1
				part.CanQuery = false
				part.CanCollide = false
				for _, d in part:GetChildren() do
					if d:IsA("Decal") then
						d.Transparency = 1
					end
				end
			end
		end
	end
	-- кровь бьёт из плеча: цепляем к торсу
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	return (torso :: BasePart?) or stump
end

-- Без рук ничего не удержать: убираем инструмент из рук
local function dropToolsIfNoArms(player: Player)
	if (player:GetAttribute("ArmsLost") or 0) < 2 then
		return
	end
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid:UnequipTools()
	end
end

-- Нанести рану. info: zone, side, close (вплотную или нет), part (куда попали)
-- Возвращает таблицу с итогом (для сообщений игрокам)
function Wounds.hit(player: Player, info: { zone: string, side: string?, close: boolean, part: BasePart }): { [string]: any }
	local humanoid = humanoidOf(player)
	local character = player.Character
	if not humanoid or not character or humanoid.Health <= 0 then
		return {}
	end
	local s = getState(player)
	local zoneCfg = Config.HIT_ZONES[info.zone]
	local range = info.close and zoneCfg.close or zoneCfg.far
	local damage = rng:NextInteger(range[1], range[2])
	local deep = rng:NextNumber() < (info.close and zoneCfg.deepClose or zoneCfg.deepFar)
	if (info :: any).deep ~= nil then
		deep = (info :: any).deep -- только тестовый вход Studio (WoundsTest) задаёт глубину сам
	end
	local result = { zone = info.zone, side = info.side, deep = deep, damage = damage }

	player:SetAttribute("HitsTaken", (player:GetAttribute("HitsTaken") or 0) + 1)
	s.cancelBandage = true -- удар сбивает перевязку

	local wound: Wound = {
		zone = info.zone,
		side = info.side,
		deep = deep,
		torn = false,
		bleed = deep and Config.BLEED_DAMAGE or 0,
		nextBleed = now() + rng:NextNumber(Config.BLEED_INTERVAL_MIN, Config.BLEED_INTERVAL_MAX),
		treated = false,
		cured = false,
		part = info.part,
	}

	if info.zone == "Head" then
		if info.close and rng:NextNumber() < zoneCfg.killClose then
			result.killed = true
		end
		if rng:NextNumber() < (info.close and zoneCfg.eyeClose or zoneCfg.eyeFar) then
			local eyes = math.min(2, (player:GetAttribute("EyesHurt") or 0) + 1)
			player:SetAttribute("EyesHurt", eyes)
			player:SetAttribute("BlindUntil", now() + Config.BLIND_TIME)
			result.eye = true
		end
	elseif info.zone == "Arm" and info.close and deep and rng:NextNumber() < zoneCfg.tearClose then
		wound.torn = true
		wound.bleed = Config.BLEED_DAMAGE * Config.TORN_ARM_BLEED
		wound.part = tearOffArm(character, info.side or "Right")
		damage += zoneCfg.tearDamage
		result.torn = true
		player:SetAttribute("ArmsLost", math.min(2, (player:GetAttribute("ArmsLost") or 0) + 1))
		playAt(info.part, Sounds.BoneBreak, 1)
		dropToolsIfNoArms(player)
	end

	table.insert(s.wounds, wound)
	if wound.bleed > 0 then
		setBloodDrip(wound, true)
	end
	if deep then
		playAt(info.part, Sounds.ClawDeep, 0.9)
	end
	if deep or result.torn or result.eye then
		playAt(info.part, Sounds.PainScream, 0.8)
	end

	if result.killed then
		humanoid.Health = 0
	else
		humanoid:TakeDamage(damage)
	end
	result.damage = damage
	result.killed = humanoid.Health <= 0
	publish(player)
	return result
end

-- Какую рану перевязать первой: сначала самую сильно кровоточащую, потом царапины (они лечатся) —
-- среди царапин первыми те, что на ноге или руке (снимаем хромоту и дрожь)
local function pickWound(s: State): Wound?
	local best: Wound? = nil
	for _, w in s.wounds do
		if not w.treated and w.bleed > 0 and (not best or w.bleed > best.bleed) then
			best = w
		end
	end
	if best then
		return best
	end
	local scratch: Wound? = nil
	for _, w in s.wounds do
		if not w.treated and not w.deep then
			if w.zone == "Leg" or w.zone == "Arm" then
				return w
			end
			scratch = scratch or w
		end
	end
	return scratch
end

-- Можно ли сейчас перевязаться. Возвращает причину, если нельзя
function Wounds.canBandage(player: Player): (boolean, string?)
	local s = states[player]
	if (player:GetAttribute("ArmsLost") or 0) >= 2 then
		return false, "Без рук не перевязаться"
	end
	if s and s.bandaging then
		return false, "Уже перевязываешься"
	end
	if not s or not pickWound(s) then
		return false, "Нечего перевязывать"
	end
	return true, nil
end

-- Лечение занимает время (с одной рукой дольше). Удар монстра его сбивает.
-- Возвращает true, если долечился до конца
local function treatOverTime(player: Player, s: State, humanoid: Humanoid, root: BasePart, time: number): boolean
	s.bandaging = true
	s.cancelBandage = false
	player:SetAttribute("Bandaging", true)
	updateSpeed(player)
	if (player:GetAttribute("ArmsLost") or 0) == 1 then
		time *= Config.ONE_ARM_SLOWDOWN
	end
	playAt(root, Sounds.BandageRip, 0.6)
	local elapsed = 0
	local nextRustle = 0
	while elapsed < time do
		if s.cancelBandage or humanoid.Health <= 0 or states[player] ~= s then
			break
		end
		if elapsed >= nextRustle then
			playAt(root, Sounds.BandageWrap, 0.5)
			nextRustle = elapsed + 1
		end
		task.wait(0.1)
		elapsed += 0.1
	end

	s.bandaging = false
	player:SetAttribute("Bandaging", nil)
	updateSpeed(player)
	return elapsed >= time
end

-- Перевязка бинтом: BANDAGE_TIME сек. Возвращает true, если бинт потрачен
function Wounds.bandage(player: Player): (boolean, string?)
	local ok, reason = Wounds.canBandage(player)
	if not ok then
		return false, reason
	end
	local s = getState(player)
	local humanoid = humanoidOf(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return false, nil
	end
	if not treatOverTime(player, s, humanoid, root, Config.BANDAGE_TIME) then
		return false, "Перевязку сбили"
	end

	local w = pickWound(s)
	if w then
		w.treated = true
		if w.bleed > 0 then
			-- глубокая рана: бинт только останавливает кровь, HP не возвращает
			w.bleed = 0
			setBloodDrip(w, false)
		else
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.BANDAGE_HEAL)
		end
	end
	publish(player)
	return true, nil
end

-- Есть ли что лечить аптечкой: кровь, хромота, дрожь руки или неполное здоровье
function Wounds.canMedkit(player: Player): (boolean, string?)
	local s = states[player]
	if (player:GetAttribute("ArmsLost") or 0) >= 2 then
		return false, "Без рук не открыть аптечку"
	end
	if s and s.bandaging then
		return false, "Уже лечишься"
	end
	local humanoid = humanoidOf(player)
	if s then
		for _, w in s.wounds do
			if limbHurts(w) or (w.bleed > 0 and not w.treated) then
				return true, nil
			end
		end
	end
	if humanoid and humanoid.Health < humanoid.MaxHealth then
		return true, nil
	end
	return false, "Нечего лечить"
end

-- Аптечка: MEDKIT_TIME сек. Вылечивает всё: останавливает кровь, убирает хромоту
-- и дрожь руки (даже от глубоких ран), возвращает MEDKIT_HEAL HP. Возвращает true, если потрачена
function Wounds.medkit(player: Player): (boolean, string?)
	local ok, reason = Wounds.canMedkit(player)
	if not ok then
		return false, reason
	end
	local s = getState(player)
	local humanoid = humanoidOf(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return false, nil
	end
	if not treatOverTime(player, s, humanoid, root, Config.MEDKIT_TIME) then
		return false, "Лечение сбили"
	end
	for _, w in s.wounds do
		w.treated = true
		w.cured = true
		w.bleed = 0
		setBloodDrip(w, false)
	end
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.MEDKIT_HEAL)
	publish(player)
	return true, nil
end

-- Полный сброс (новый раунд, новый персонаж)
function Wounds.reset(player: Player)
	local s = states[player]
	if s then
		s.cancelBandage = true
		for _, w in s.wounds do
			setBloodDrip(w, false)
		end
	end
	states[player] = nil
	for _, name in { "WoundsText", "Bleeding", "ArmsLost", "EyesHurt", "BlindUntil", "Bandaging", "HitsTaken", "ArmShake" } do
		player:SetAttribute(name, nil)
	end
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.WalkSpeed = Config.WALK_SPEED
	end
end

---------------------------------------------------------------------
-- Кровотечение: каждая рана снимает HP раз в 5–10 сек
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(0.25)
		local t = now()
		for player, s in states do
			local humanoid = humanoidOf(player)
			if not humanoid or humanoid.Health <= 0 then
				continue
			end
			for _, w in s.wounds do
				if w.bleed > 0 and not w.treated and t >= w.nextBleed then
					w.nextBleed = t + rng:NextNumber(Config.BLEED_INTERVAL_MIN, Config.BLEED_INTERVAL_MAX)
					humanoid:TakeDamage(w.bleed)
					if w.part and w.part.Parent and rng:NextNumber() < 0.5 then
						playAt(w.part, Sounds.BloodDrip, 0.35)
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- Персонажи: убираем стандартное восстановление HP, сбрасываем раны
---------------------------------------------------------------------
local function onCharacter(player: Player, character: Model)
	Wounds.reset(player)
	-- Roblox сам лечит 1% HP в секунду скриптом «Health» — по правилам лечат только бинты
	task.defer(function()
		local regen = character:WaitForChild("Health", 5)
		if regen and regen:IsA("Script") then
			regen:Destroy()
		end
	end)
	-- без рук не взять инструмент
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and (player:GetAttribute("ArmsLost") or 0) >= 2 then
			task.defer(dropToolsIfNoArms, player)
		end
	end)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		local s = states[player]
		if s then
			s.cancelBandage = true
			for _, w in s.wounds do
				w.bleed = 0
			end
		end
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

-- Новый раунд: все здоровы
workspace:GetAttributeChangedSignal("RoundActive"):Connect(function()
	if workspace:GetAttribute("RoundActive") then
		for _, player in Players:GetPlayers() do
			Wounds.reset(player)
			local humanoid = humanoidOf(player)
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = humanoid.MaxHealth
			end
		end
	end
end)

---------------------------------------------------------------------
-- Только в Studio: вход для проверки (tools/T.luau → T.hurt(), T.cure()).
-- Ранит и лечит через те же функции, что и игра, чтобы не звать монстра.
---------------------------------------------------------------------
if game:GetService("RunService"):IsStudio() then
	local test = Instance.new("BindableFunction")
	test.Name = "WoundsTest"
	test.Parent = game:GetService("ServerStorage")
	test.OnInvoke = function(action: string, player: Player, zone: string?, deep: boolean?, side: string?)
		local character = player.Character
		if action == "hit" and character then
			local partName = if zone == "Leg" then `{side or "Left"}UpperLeg` elseif zone == "Arm" then `{side or "Right"}UpperArm` elseif zone == "Head" then "Head" else "UpperTorso"
			local part = character:FindFirstChild(partName) :: BasePart?
			if part then
				Wounds.hit(player, { zone = zone or "Torso", side = side or (if zone == "Leg" then "Left" else "Right"), close = false, part = part, deep = deep } :: any)
			end
		elseif action == "bandage" then
			print("THE NEST bandage:", Wounds.bandage(player))
		elseif action == "medkit" then
			print("THE NEST medkit:", Wounds.medkit(player))
		end
		local humanoid = humanoidOf(player)
		return `speed={humanoid and humanoid.WalkSpeed} hp={humanoid and math.floor(humanoid.Health)} shake={player:GetAttribute("ArmShake")} wounds=[{player:GetAttribute("WoundsText")}]`
	end
end

return Wounds
