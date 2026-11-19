-- Скример: из комнаты за дверью вылетает стая летучих мышей.
-- Тому, кто открыл дверь, они летят прямо в лицо (в камеру): писк, хлопанье крыльев,
-- экран на миг закрывают чёрные крылья. Остальные видят, как стая вылетает из двери.
-- Мыши живут только на этом клиенте (их нет на сервере) — так они летают плавно.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local player = Players.LocalPlayer
local batEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BatScare") :: RemoteEvent
local rng = Random.new()

local BLACK = Color3.fromRGB(14, 11, 10)

-- Одна мышь: тельце + 2 крыла (крылья машут в RenderStepped)
local function makeBat(): (Model, BasePart, BasePart, BasePart, BasePart)
	local m = Instance.new("Model")
	m.Name = "Bat"
	local function p(size: Vector3): Part
		local part = Instance.new("Part")
		part.Size = size
		part.Color = BLACK
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = m
		return part
	end
	local body = p(Vector3.new(0.35, 0.3, 0.6))
	local left = p(Vector3.new(1.1, 0.05, 0.55))
	local right = p(Vector3.new(1.1, 0.05, 0.55))
	-- красные точки-глаза
	local eyes = p(Vector3.new(0.2, 0.05, 0.05))
	eyes.Color = Color3.fromRGB(200, 30, 20)
	eyes.Material = Enum.Material.Neon
	m.Parent = workspace
	return m, body, left, right, eyes
end

-- Звук стаи. Если ID писка не задан — собираем из свиста и крика с высоким тоном
local function swarmSound(parent: Instance, loud: boolean)
	local function play(id: string, volume: number, speed: number)
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volume
		s.PlaybackSpeed = speed
		s.RollOffMaxDistance = 60
		s.Parent = parent
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
	local v = loud and 1 or 0.5
	if Sounds.BatSwarm ~= "" then
		play(Sounds.BatSwarm, v, 1)
	else
		-- хлопанье крыльев: много быстрых свистов
		for i = 1, 9 do
			task.delay(i * 0.09, function()
				local swing = Sounds.ClawSwing
				play(swing[rng:NextInteger(1, #swing)], 0.35 * v, rng:NextNumber(2.2, 3))
			end)
		end
		-- писк: крик, разогнанный до высокого тона
		local scream = Sounds.PainScream
		play(scream[rng:NextInteger(1, #scream)], 0.45 * v, 3.2)
		task.delay(0.25, function()
			play(scream[rng:NextInteger(1, #scream)], 0.3 * v, 3.6)
		end)
	end
end

-- Чёрные крылья на весь экран на долю секунды
local function faceFlash()
	local gui = Instance.new("ScreenGui")
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	for _ = 1, 7 do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = BLACK
		f.BorderSizePixel = 0
		local w = rng:NextNumber(0.35, 0.7)
		f.Size = UDim2.fromScale(w, w * 0.45)
		f.Position = UDim2.fromScale(rng:NextNumber(-0.1, 0.8), rng:NextNumber(-0.1, 0.8))
		f.Rotation = rng:NextNumber(-40, 40)
		f.Parent = gui
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
	end
	local t = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		for _, f in gui:GetChildren() do
			if f:IsA("Frame") then
				f.Position += UDim2.fromScale(rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.06, 0.02))
				f.BackgroundTransparency = math.clamp((t - 0.15) / 0.35, 0, 1)
			end
		end
		if t > 0.55 then
			conn:Disconnect()
			gui:Destroy()
		end
	end)
end

batEvent.OnClientEvent:Connect(function(door: BasePart, opener: Player)
	if not door or not door.Parent then
		return
	end
	local camera = workspace.CurrentCamera
	local closed: CFrame = (door:GetAttribute("ClosedCFrame") :: CFrame?) or door.CFrame
	local doorPos = closed.Position
	local normal = closed.LookVector
	local openerRoot = opener and opener.Character and opener.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- мыши вылетают с той стороны двери, где НЕТ открывшего
	local side = 1
	if openerRoot and (openerRoot.Position - doorPos):Dot(normal) > 0 then
		side = -1
	end
	local start = doorPos + normal * side * 5
	local isMe = opener == player
	swarmSound(door, isMe)
	if isMe then
		task.delay(0.35, faceFlash)
	end

	for i = 1, Config.BAT_COUNT do
		task.delay(i * 0.04, function()
			local m, body, left, right, eyes = makeBat()
			local from = start + Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1, 2), rng:NextNumber(-1.5, 1.5))
			local life = rng:NextNumber(1.2, 1.8)
			local flapSpeed = rng:NextNumber(28, 40)
			-- куда летит: в лицо (камеру) открывшему, потом в сторону и прочь
			local away = (-normal * side + Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(0.1, 0.5), rng:NextNumber(-0.8, 0.8))).Unit
			local t = 0
			local conn
			conn = RunService.RenderStepped:Connect(function(dt)
				t += dt
				local k = t / life
				local target: Vector3
				if isMe then
					target = camera.CFrame.Position + camera.CFrame.LookVector * 0.6 + Vector3.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.4, 0.4), 0)
				elseif openerRoot then
					target = openerRoot.Position + Vector3.new(0, 2, 0)
				else
					target = doorPos - normal * side * 6
				end
				-- первая половина полёта — к цели, вторая — мимо и вверх-в сторону
				local pos: Vector3
				if k < 0.5 then
					pos = from:Lerp(target, k / 0.5)
				else
					pos = target + away * (k - 0.5) * 30 + Vector3.new(0, (k - 0.5) * 6, 0)
				end
				pos += Vector3.new(math.sin(t * 13 + i) * 0.4, math.sin(t * 9 + i * 2) * 0.4, math.cos(t * 11 + i) * 0.4)
				local look = CFrame.lookAt(pos, pos + (target - from).Unit)
				local flap = math.sin(t * flapSpeed) * 0.9
				body.CFrame = look
				left.CFrame = look * CFrame.new(-0.15, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.55, 0, 0)
				right.CFrame = look * CFrame.new(0.15, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.55, 0, 0)
				eyes.CFrame = look * CFrame.new(0, 0.08, -0.31)
				if k >= 1 then
					conn:Disconnect()
					m:Destroy()
				end
			end)
		end)
	end
end)
