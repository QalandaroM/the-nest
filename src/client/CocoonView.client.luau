-- Что видит убитый игрок.
--  * Тело лежит (CocoonState = "Body"): камера смотрит на тело сверху, надпись «Монстр прячет твоё тело…».
--  * Кокон (CocoonState = "Cocoon"): вид изнутри — тёмно-красный экран, сердцебиение,
--    слышно всё рядом (кто рвёт кокон, шаги). Показано время до вылупления и сколько порвали.
--  * Destroyed / Hatched — надпись. Вылупился — через пару секунд сервер возродит игрока монстром (RoundManager).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local gui = Instance.new("ScreenGui")
gui.Name = "CocoonView"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 4
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- красная плоть вокруг
local flesh = Instance.new("Frame")
flesh.Size = UDim2.fromScale(1, 1)
flesh.BackgroundColor3 = Color3.fromRGB(70, 6, 8)
flesh.BackgroundTransparency = 0.25
flesh.BorderSizePixel = 0
flesh.Parent = gui

local vignette = Instance.new("UIGradient")
vignette.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0.45),
	NumberSequenceKeypoint.new(1, 0),
})
vignette.Rotation = 90
vignette.Parent = flesh

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.Position = UDim2.new(0, 0, 0.62, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(235, 200, 190)
title.TextStrokeTransparency = 0.3
title.Font = Enum.Font.GothamBlack
title.TextSize = 30
title.Parent = gui

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, 0, 0, 30)
sub.Position = UDim2.new(0, 0, 0.62, 52)
sub.BackgroundTransparency = 1
sub.TextColor3 = Color3.fromRGB(210, 170, 160)
sub.TextStrokeTransparency = 0.4
sub.Font = Enum.Font.GothamMedium
sub.TextSize = 20
sub.Parent = gui

local heart = Instance.new("Sound")
heart.SoundId = Sounds.Heartbeat
heart.Looped = true
heart.Volume = 0.8
heart.Parent = gui

local function findMine(folderName: string): Model?
	local folder = workspace:FindFirstChild(folderName)
	if not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m:GetAttribute("VictimId") == player.UserId and not m:GetAttribute("State") then
			return m :: Model
		end
	end
	return nil
end

local function restoreCamera()
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local active = false
local look = 0

RunService.RenderStepped:Connect(function(dt)
	local dead = player:GetAttribute("Role") == "Dead"
	local state = player:GetAttribute("CocoonState")
	if not dead or not state then
		if active then
			active = false
			gui.Enabled = false
			heart:Stop()
			restoreCamera()
		end
		return
	end
	active = true
	gui.Enabled = true
	local t = os.clock()

	if state == "Body" then
		flesh.BackgroundTransparency = 0.7
		heart:Stop()
		title.Text = "Ты мёртв"
		sub.Text = "Монстр может спрятать твоё тело в тайник…"
		local body = findMine("Bodies")
		local head = body and body:FindFirstChild("Head") :: BasePart?
		if head then
			camera.CameraType = Enum.CameraType.Scriptable
			local pos = head.Position
			camera.CFrame = CFrame.lookAt(pos + Vector3.new(math.cos(t * 0.2) * 6, 7, math.sin(t * 0.2) * 6), pos)
		end
	elseif state == "Cocoon" then
		local cocoon = findMine("Cocoons")
		local core = cocoon and cocoon.PrimaryPart
		if not heart.IsPlaying then
			heart:Play()
		end
		-- плоть «дышит» вместе с сердцем
		local beat = math.max(0, math.sin(t * 5)) ^ 4
		flesh.BackgroundTransparency = 0.18 - beat * 0.1
		title.Text = "Ты в коконе"
		if cocoon and core then
			local left = math.max(0, math.ceil((cocoon:GetAttribute("HatchAt") or 0) - workspace:GetServerTimeNow()))
			local torn = cocoon:GetAttribute("Progress") or 0
			sub.Text = torn > 0 and `До вылупления: {left} сек   ·   Кокон рвут: {torn}%` or `До вылупления: {left} сек`
			-- камера внутри кокона, медленно оглядывается — сквозь плёнку видно силуэты снаружи
			camera.CameraType = Enum.CameraType.Scriptable
			look += dt * 0.15
			local eye = core.Position + Vector3.new(0, 0.6, 0)
			camera.CFrame = CFrame.new(eye) * CFrame.Angles(0, look, 0) * CFrame.Angles(math.rad(-5 + math.sin(t) * 2), 0, 0)
		end
	elseif state == "Destroyed" then
		heart:Stop()
		flesh.BackgroundTransparency = 0.05
		title.Text = "Кокон разорвали"
		sub.Text = "Ты умер окончательно. Жди конца раунда."
	elseif state == "Hatched" then
		heart:Stop()
		flesh.BackgroundTransparency = 0.5
		title.Text = "Ты вылупился…"
		sub.Text = "Сейчас ты встанешь из кокона монстром"
	end
end)
