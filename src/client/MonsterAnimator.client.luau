-- Свои анимации монстра — без загрузки в Roblox.
-- Позы по кадрам лежат в Shared.MonsterAnimData (их пишет blender/monster.py).
-- Каждый кадр ставим их прямо в суставы монстра (.Transform) — поверх стандартных анимаций.
-- Сустав бывает двух видов: старый Motor6D или новый AnimationConstraint (Avatar Joint Upgrade
-- в Roblox). Transform у них работает одинаково, поэтому поддерживаем оба.
-- Transform не передаётся по сети, поэтому скрипт у каждого игрока анимирует всех монстров сам.
--   Idle / Run           — стоит / идёт
--   CarryIdle / Carry    — то же с телом на плечах (атрибут CarryingBody у игрока)
--   Attack, Attack2, Scream, Pickup — разовые действия: сервер пишет игроку атрибут
--                          MonsterAction = "Имя|время сервера" (MonsterAnims.luau)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Data = require(Shared:WaitForChild("MonsterAnimData"))

type Pose = { [string]: CFrame }
type Joint = Motor6D | AnimationConstraint

-- Числа из Blender → кадры: на каждый сустав CFrame (у LowerTorso ещё и сдвиг)
local ANIMS: { [string]: { loop: boolean, frames: { Pose }, length: number } } = {}
for name, a in Data.anims do
	local frames = {}
	local moveAt = #Data.joints * 4
	for _, nums in a.frames do
		local pose: Pose = {}
		for i, joint in Data.joints do
			local k = (i - 1) * 4
			local x, y, z = 0, 0, 0
			if joint == "LowerTorso" then
				x, y, z = nums[moveAt + 1], nums[moveAt + 2], nums[moveAt + 3]
			end
			pose[joint] = CFrame.new(x, y, z, nums[k + 1], nums[k + 2], nums[k + 3], nums[k + 4])
		end
		table.insert(frames, pose)
	end
	ANIMS[name] = { loop = a.loop, frames = frames, length = (#frames - 1) / Data.fps }
end

-- Поза анимации в момент t (сек). Между кадрами — плавно
local function sample(name: string, t: number): Pose
	local a = ANIMS[name]
	local n = #a.frames
	local f = t * Data.fps
	if a.loop then
		f = f % (n - 1)
	else
		f = math.clamp(f, 0, n - 1)
	end
	local i = math.floor(f)
	local A, B = a.frames[i + 1], a.frames[math.min(i + 2, n)]
	local out: Pose = {}
	for joint, cf in A do
		out[joint] = cf:Lerp(B[joint], f - i)
	end
	return out
end

local function mix(A: Pose, B: Pose, w: number): Pose
	local out: Pose = {}
	for joint, cf in A do
		out[joint] = cf:Lerp(B[joint] or cf, w)
	end
	return out
end

type State = {
	motors: { [string]: Joint },
	base: string,
	t: number,
	prev: Pose?,
	fade: number,
	last: Pose?,
	action: string?,
	actionT0: number,
	actionKey: string?,
}
local states: { [Model]: State } = setmetatable({}, { __mode = "k" }) :: any

-- Сустав, который двигает часть тела: Motor6D (её Part1 — эта часть)
-- или AnimationConstraint (его Attachment1 лежит в этой части)
local function findJoint(character: Model, part: Instance): Joint?
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 == part then
			return d
		elseif d:IsA("AnimationConstraint") and d.Attachment1 and d.Attachment1.Parent == part then
			return d
		end
	end
	return nil
end

local function motorOf(character: Model, st: State, joint: string): Joint?
	local m = st.motors[joint]
	if m and m.Parent then
		return m
	end
	local part = character:FindFirstChild(joint)
	m = part and findJoint(character, part)
	if m then
		st.motors[joint] = m
	end
	return m
end

local BLEND = Config.MONSTER_ANIM_BLEND
local FADE_IN, FADE_OUT = 0.08, 0.15

local function animate(player: Player, character: Model, dt: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	local st = states[character]
	if not st then
		st = { motors = {}, base = "Idle", t = 0, fade = 1, actionT0 = 0 }
		states[character] = st
	end

	-- 1) основа: стоит или идёт, с телом или без
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local moving = speed > 1 and not root.Anchored
	local carrying = player:GetAttribute("CarryingBody") == true
	local base = if carrying then (if moving then "Carry" else "CarryIdle") else (if moving then "Run" else "Idle")
	if base ~= st.base then
		st.prev, st.fade, st.base, st.t = st.last, 0, base, 0
	end
	local rate = 1
	if moving then
		-- ноги не «скользят»: чем быстрее идёт, тем быстрее шаги
		local norm = Config.MONSTER_RUN_ANIM_SPEED * (if carrying then Config.CARRY_SPEED_MULT else 1)
		rate = math.clamp(speed / norm, 0.5, 1.8)
	end
	st.t += dt * rate
	local pose = sample(base, st.t)
	if st.prev and st.fade < 1 then
		st.fade = math.min(1, st.fade + dt / BLEND)
		pose = mix(st.prev, pose, st.fade)
	end

	-- 2) разовое действие поверх основы
	local key = player:GetAttribute("MonsterAction")
	if type(key) == "string" and key ~= st.actionKey then
		st.actionKey = key
		local name, at = string.match(key, "^(%w+)|([%d%.]+)$")
		if name and ANIMS[name] then
			st.action, st.actionT0 = name, tonumber(at) :: number
		end
	end
	if st.action then
		local a = ANIMS[st.action]
		local t = math.max(0, workspace:GetServerTimeNow() - st.actionT0)
		if t >= a.length + FADE_OUT then
			st.action = nil
		else
			local w = math.min(1, t / FADE_IN)
			if t > a.length then
				w = 1 - (t - a.length) / FADE_OUT -- плавно возвращаемся к основе
			end
			pose = mix(pose, sample(st.action, t), w)
		end
	end
	st.last = pose

	-- 3) в суставы. Сдвиг корпуса растягиваем под рост монстра
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	local k = if torso then torso.Size.Y / 1.6 else 1
	for joint, cf in pose do
		local m = motorOf(character, st, joint)
		if m then
			m.Transform = if joint == "LowerTorso" then CFrame.new(cf.Position * k) * cf.Rotation else cf
		end
	end
end

-- PreSimulation идёт после стандартных анимаций Roblox — наши позы их перекрывают
RunService.PreSimulation:Connect(function(dt)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and player:GetAttribute("Role") == "Monster" then
			animate(player, character, dt)
		end
	end
end)
