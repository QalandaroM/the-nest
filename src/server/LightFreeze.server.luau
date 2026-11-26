-- Свет фонарика останавливает монстра.
-- Если выживший держит включённый фонарик и луч направлен прямо на монстра
-- (ближе Config.FREEZE_RANGE, в пределах Config.FREEZE_ANGLE от центра луча, без стены между ними),
-- монстр замирает: не ходит и не бьёт (атрибут Frozen = true у игрока-монстра).
-- Чтобы монстра нельзя было держать вечно: максимум FREEZE_MAX_TIME сек подряд,
-- потом FREEZE_IMMUNE_TIME сек свет на него не действует (атрибут FreezeImmuneUntil).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local TICK = 0.1
local frozenSince: { [Player]: number } = {}

-- Включённый фонарик в руках выжившего: возвращает деталь-ручку (из неё светит луч)
local function beamOf(player: Player): BasePart?
	if player:GetAttribute("Role") ~= "Survivor" then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = character and character:FindFirstChild("Flashlight")
	local handle = tool and tool:FindFirstChild("Handle") :: BasePart?
	local beam = handle and handle:FindFirstChild("Beam") :: SpotLight?
	if humanoid and humanoid.Health > 0 and handle and beam and beam.Enabled then
		return handle
	end
	return nil
end

-- Светит ли луч на этого монстра
local function lit(handle: BasePart, monsterChar: Model, survivorChar: Model): boolean
	local target = monsterChar:FindFirstChild("UpperTorso") or monsterChar:FindFirstChild("Torso") or monsterChar:FindFirstChild("HumanoidRootPart")
	if not target or not target:IsA("BasePart") then
		return false
	end
	local offset = target.Position - handle.Position
	local dist = offset.Magnitude
	if dist > Config.FREEZE_RANGE or dist < 0.1 then
		return false
	end
	-- угол между лучом и направлением на монстра. Монстр широкий (~1.5 studs от центра до края),
	-- поэтому вблизи можно светить и не точно в центр: допуск растёт, когда монстр рядом
	local cos = handle.CFrame.LookVector:Dot(offset.Unit)
	local allowed = Config.FREEZE_ANGLE + math.deg(math.atan(1.5 / dist))
	if cos < math.cos(math.rad(math.min(allowed, 80))) then
		return false
	end
	-- стена между ними?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { survivorChar, monsterChar }
	local hit = workspace:Raycast(handle.Position, offset, params)
	return hit == nil or not hit.Instance.CanCollide
end

local function setFrozen(monster: Player, on: boolean)
	local character = monster.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if on == (monster:GetAttribute("Frozen") == true) then
		return
	end
	monster:SetAttribute("Frozen", on or nil)
	if root then
		-- закреплённая деталь не двигается: монстр стоит как вкопанный
		root.Anchored = on
		if on then
			local s = Instance.new("Sound")
			local list = Sounds.MonsterBreath
			s.SoundId = list[math.random(1, #list)]
			s.Volume = 0.9
			s.PlaybackSpeed = 1.4 -- короткий визг от света
			s.RollOffMaxDistance = 50
			s.Parent = root
			s:Play()
			s.Ended:Once(function()
				s:Destroy()
			end)
		end
	end
	if on then
		frozenSince[monster] = os.clock()
	else
		frozenSince[monster] = nil
	end
end

while true do
	task.wait(TICK)
	local now = workspace:GetServerTimeNow()
	local beams = {}
	for _, p in Players:GetPlayers() do
		local h = beamOf(p)
		if h then
			table.insert(beams, { handle = h, char = p.Character })
		end
	end
	for _, monster in Players:GetPlayers() do
		local character = monster.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if monster:GetAttribute("Role") ~= "Monster" or not humanoid or humanoid.Health <= 0 or not workspace:GetAttribute("RoundActive") then
			setFrozen(monster, false)
			continue
		end
		local inLight = false
		if now >= (monster:GetAttribute("FreezeImmuneUntil") or 0) then
			for _, b in beams do
				if lit(b.handle, character :: Model, b.char) then
					inLight = true
					break
				end
			end
		end
		-- слишком долго стоит в свете — привыкает, и на время свет не действует
		local since = frozenSince[monster]
		if inLight and since and os.clock() - since >= Config.FREEZE_MAX_TIME then
			inLight = false
			monster:SetAttribute("FreezeImmuneUntil", now + Config.FREEZE_IMMUNE_TIME)
		end
		setFrozen(monster, inLight)
	end
end
