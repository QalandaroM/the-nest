-- Клиент для ударов и ран.
--  * Монстр: клик с «Когтями» → отправляем серверу, куда смотрит камера. Попал или нет — решает сервер.
--  * Жертва: красная вспышка, тряска камеры, слепота после удара в глаз.
--  * Обоим: короткие подписи «Когти задели левую руку».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local swingEvent = remotes:WaitForChild("MonsterSwing") :: RemoteEvent
local hitEvent = remotes:WaitForChild("HitFeedback") :: RemoteEvent

-- Своя полоска HP в HUD, стандартную прячем
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

---------------------------------------------------------------------
-- Экранные эффекты
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "CombatFX"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(140, 0, 0)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui

local blind = Instance.new("Frame")
blind.Size = UDim2.fromScale(1, 1)
blind.BackgroundColor3 = Color3.fromRGB(6, 0, 0)
blind.BackgroundTransparency = 1
blind.BorderSizePixel = 0
blind.Parent = gui

local caption = Instance.new("TextLabel")
caption.Size = UDim2.new(0.6, 0, 0, 36)
caption.Position = UDim2.new(0.2, 0, 0.72, 0)
caption.BackgroundTransparency = 1
caption.TextColor3 = Color3.fromRGB(230, 200, 190)
caption.TextStrokeTransparency = 0.4
caption.Font = Enum.Font.GothamBold
caption.TextSize = 24
caption.Text = ""
caption.Parent = gui

local blur = Instance.new("BlurEffect")
blur.Name = "WoundBlur"
blur.Size = 0
blur.Parent = Lighting

local captionToken = 0
local function showCaption(text: string)
	captionToken += 1
	local token = captionToken
	caption.Text = text
	caption.TextTransparency = 0
	task.delay(2.5, function()
		if token == captionToken then
			TweenService:Create(caption, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end)
end

local shakeUntil = 0
local shakePower = 0
local function shake(power: number, time: number)
	shakePower = power
	shakeUntil = os.clock() + time
end

RunService:BindToRenderStep("WoundShake", Enum.RenderPriority.Camera.Value + 1, function()
	local left = shakeUntil - os.clock()
	if left > 0 then
		local p = shakePower * left
		camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * p), math.rad((math.random() - 0.5) * p), 0)
	end
end)

-- Слепота и размытие от ран в глаза
RunService.Heartbeat:Connect(function()
	local eyes = player:GetAttribute("EyesHurt") or 0
	local blindUntil = player:GetAttribute("BlindUntil") or 0
	local left = blindUntil - workspace:GetServerTimeNow()
	if left > 0 then
		-- первые секунды почти чёрный экран, потом медленно проясняется
		local k = math.clamp(left / 3, 0, 1)
		blind.BackgroundTransparency = 0.03 + (1 - k) * 0.5 + math.random() * 0.03
		blur.Size = 24
	else
		blind.BackgroundTransparency = if eyes >= 2 then 0.55 else 1
		blur.Size = if eyes >= 2 then 14 elseif eyes == 1 then 5 else 0
	end
	-- при сильном кровотечении края экрана краснеют
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and humanoid.Health < 30 and flash.BackgroundTransparency > 0.85 then
		flash.BackgroundTransparency = 0.9 + math.sin(os.clock() * 3) * 0.04
	end
end)

---------------------------------------------------------------------
-- Подписи
---------------------------------------------------------------------
local ZONE = {
	Head = "голова",
	Torso = "тело",
	Arm = "рука",
	Leg = "нога",
}

local function describe(info): string
	local where = ZONE[info.zone] or "тело"
	if info.zone == "Arm" or info.zone == "Leg" then
		where = (info.side == "Left" and "левая " or "правая ") .. where
	end
	if info.killed then
		return info.zone == "Head" and "Когти пробили голову" or "Смертельный удар"
	elseif info.torn then
		return info.side == "Left" and "Когти оторвали левую руку!" or "Когти оторвали правую руку!"
	elseif info.eye then
		return "Когти попали в глаз!"
	elseif info.deep then
		return `Глубокая рана: {where}`
	end
	return `Царапина: {where}`
end

hitEvent.OnClientEvent:Connect(function(kind: string, info)
	if kind == "Notice" then
		showCaption(info.text or "")
	elseif kind == "Victim" then
		flash.BackgroundTransparency = info.deep and 0.35 or 0.6
		TweenService:Create(flash, TweenInfo.new(info.deep and 1.2 or 0.6), { BackgroundTransparency = 1 }):Play()
		shake(info.deep and 6 or 3, 0.5)
		showCaption(describe(info))
	elseif kind == "Monster" then
		showCaption(`Попал — {describe(info)} (−{info.damage or 0} HP)`)
	end
end)

---------------------------------------------------------------------
-- Монстр: клик с когтями
---------------------------------------------------------------------
local function aimDirection(): Vector3?
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	-- точка, куда смотрит центр экрана (или курсор)
	-- GetMouseLocation считает от самого верха окна, как и ViewportPointToRay (иначе прицел съезжает вниз)
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 100, params)
	local target = result and result.Position or (ray.Origin + ray.Direction * 100)
	local dir = target - head.Position
	if dir.Magnitude < 0.1 then
		return nil
	end
	return dir.Unit
end

local watched = setmetatable({}, { __mode = "k" }) -- инструмент «надевается» много раз, подключаемся один раз

local function watchTool(tool: Instance)
	if tool:IsA("Tool") and tool.Name == "Когти" and not watched[tool] then
		watched[tool] = true
		tool.Activated:Connect(function()
			local dir = aimDirection()
			if dir then
				swingEvent:FireServer(dir)
			end
		end)
	end
end

local function onCharacter(character: Model)
	for _, child in character:GetChildren() do
		watchTool(child)
	end
	character.ChildAdded:Connect(watchTool)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end
