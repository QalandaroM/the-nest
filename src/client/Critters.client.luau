-- Мелкие пауки ползают по стенам и потолку (модели с тегом "Spider" ставит MapBuilder).
-- Двигаем их только на клиенте и только рядом с камерой — серверу это не нужно, а FPS бережём.
-- Паук то замирает, то перебегает на новое место рядом с «домом».
-- Если подойти близко — быстро убегает.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local rng = Random.new()

type Spider = {
	model: Model,
	home: Vector3,
	normal: Vector3,
	right: Vector3,
	up: Vector3,
	pos: Vector3,
	target: Vector3,
	heading: Vector3,
	speed: number,
	waitLeft: number,
}

local spiders: { Spider } = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

-- Точка на стене, куда можно перебежать (под ней действительно стена)
local function pickTarget(s: Spider, radius: number): Vector3
	for _ = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.5, radius)
		local p = s.home + s.right * math.cos(a) * r + s.up * math.sin(a) * r
		params.FilterDescendantsInstances = { s.model }
		local hit = workspace:Raycast(p + s.normal * 0.5, -s.normal * 0.9, params)
		if hit and hit.Normal:Dot(s.normal) > 0.95 then
			return p
		end
	end
	return s.home
end

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local pivot = model:GetPivot()
	local normal: Vector3 = (model:GetAttribute("Normal") :: Vector3?) or pivot.UpVector
	local right = if math.abs(normal.Y) > 0.9 then Vector3.new(1, 0, 0) else normal:Cross(Vector3.new(0, 1, 0)).Unit
	local up = right:Cross(normal).Unit
	table.insert(spiders, {
		model = model,
		home = pivot.Position,
		normal = normal,
		right = right,
		up = up,
		pos = pivot.Position,
		target = pivot.Position,
		heading = pivot.LookVector,
		speed = 2,
		waitLeft = rng:NextNumber(0, 4),
	})
end

for _, m in CollectionService:GetTagged("Spider") do
	add(m)
end
CollectionService:GetInstanceAddedSignal("Spider"):Connect(add)

RunService.RenderStepped:Connect(function(dt)
	local camPos = workspace.CurrentCamera.CFrame.Position
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, s in spiders do
		if s.model.Parent and (s.pos - camPos).Magnitude < Config.SPIDER_VIEW_DISTANCE then
			-- игрок рядом — паук убегает
			if root and (root.Position - s.pos).Magnitude < 5 and s.speed < 5 then
				s.target = pickTarget(s, 3.5)
				s.speed = rng:NextNumber(6, 8)
				s.waitLeft = 0
			end
			local toTarget = s.target - s.pos
			if toTarget.Magnitude < 0.05 then
				s.waitLeft -= dt
				if s.waitLeft <= 0 then
					s.target = pickTarget(s, 2.5)
					s.speed = rng:NextNumber(1.2, 3.5)
					s.waitLeft = rng:NextNumber(0.8, 5)
				end
			else
				local step = math.min(toTarget.Magnitude, s.speed * dt)
				s.heading = toTarget.Unit
				s.pos += s.heading * step
				-- лёгкое дрожание лапок
				local jitter = math.sin(os.clock() * 40) * 0.01
				s.model:PivotTo(CFrame.lookAt(s.pos + s.normal * jitter, s.pos + s.normal * jitter + s.heading, s.normal))
			end
		end
	end
end)

---------------------------------------------------------------------
-- Напольные часы (тег "Clock"): маятник качается, часы тикают.
-- Качаем только у ближайших к камере часов.
---------------------------------------------------------------------
local Sounds = require(ReplicatedStorage.Shared.Sounds)

type Clock = { model: Model, top: Vector3, axis: Vector3, parts: { { part: BasePart, cf: CFrame } }, side: number, tick: Sound? }
local clocks: { Clock } = {}

local function addClock(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local pend = model:FindFirstChild("Pendulum")
	local top = model:GetAttribute("PendulumTop") :: Vector3?
	local facing = model:GetAttribute("Facing") :: Vector3?
	if not pend or not top or not facing then
		return
	end
	local parts = {}
	for _, p in pend:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, { part = p, cf = p.CFrame })
		end
	end
	local tickSound = Instance.new("Sound")
	tickSound.SoundId = Sounds.FlashlightClick
	tickSound.Volume = 0.25
	tickSound.PlaybackSpeed = 0.55
	tickSound.RollOffMaxDistance = 30
	tickSound.Parent = model.PrimaryPart or parts[1] and parts[1].part
	table.insert(clocks, { model = model, top = top, axis = facing.Unit, parts = parts, side = 1, tick = tickSound })
end

for _, m in CollectionService:GetTagged("Clock") do
	addClock(m)
end
CollectionService:GetInstanceAddedSignal("Clock"):Connect(addClock)

RunService.RenderStepped:Connect(function()
	local camPos = workspace.CurrentCamera.CFrame.Position
	local t = os.clock()
	for _, c in clocks do
		if c.model.Parent and (c.top - camPos).Magnitude < Config.SPIDER_VIEW_DISTANCE then
			-- период 2 сек: тик на каждом крайнем положении
			local angle = math.sin(t * math.pi) * math.rad(9)
			local pivot = CFrame.new(c.top) * CFrame.fromAxisAngle(c.axis, angle) * CFrame.new(-c.top)
			for _, item in c.parts do
				item.part.CFrame = pivot * item.cf
			end
			local side = math.cos(t * math.pi) > 0 and 1 or -1
			if side ~= c.side then
				c.side = side
				if c.tick then
					c.tick:Play()
				end
			end
		end
	end
end)
