-- Окна для квестов: текст записки и кодовый замок сейфа.
-- Сервер шлёт: ShowNote(text) — показать записку; SafeCode("Open"/"Wrong"/"Right").
-- Код вводится здесь и уходит на сервер — проверяет его только сервер.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local showNote = remotes:WaitForChild("ShowNote") :: RemoteEvent
local safeEvent = remotes:WaitForChild("SafeCode") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "QuestUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function button(parent: Instance, text: string, pos: UDim2, size: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 20
	b.TextColor3 = Color3.fromRGB(235, 225, 200)
	b.BackgroundColor3 = Color3.fromRGB(60, 30, 26)
	b.AutoButtonColor = true
	b.Modal = true -- освобождает мышь в режиме от 1-го лица
	b.Parent = parent
	corner(b, 6)
	return b
end

---------------------------------------------------------------------
-- Записка
---------------------------------------------------------------------
local note = Instance.new("Frame")
note.Size = UDim2.fromOffset(460, 300)
note.Position = UDim2.new(0.5, -230, 0.5, -170)
note.BackgroundColor3 = Color3.fromRGB(214, 200, 164)
note.Visible = false
note.Parent = gui
corner(note, 4)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 70, 50)
stroke.Thickness = 2
stroke.Parent = note

local noteText = Instance.new("TextLabel")
noteText.Size = UDim2.new(1, -40, 1, -80)
noteText.Position = UDim2.fromOffset(20, 18)
noteText.BackgroundTransparency = 1
noteText.TextWrapped = true
noteText.TextXAlignment = Enum.TextXAlignment.Left
noteText.TextYAlignment = Enum.TextYAlignment.Top
noteText.Font = Enum.Font.SpecialElite
noteText.TextSize = 22
noteText.TextColor3 = Color3.fromRGB(40, 28, 20)
noteText.Parent = note

local closeNote = button(note, "Закрыть", UDim2.new(0.5, -70, 1, -52), UDim2.fromOffset(140, 38))

local noteToken = 0
local function hideNote()
	note.Visible = false
end
closeNote.MouseButton1Click:Connect(hideNote)

showNote.OnClientEvent:Connect(function(text: string)
	noteText.Text = text
	note.Visible = true
	noteToken += 1
	local my = noteToken
	-- сама закроется через 25 сек или если отойти
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local start = root and root.Position
	task.spawn(function()
		local t = 0
		while note.Visible and my == noteToken and t < 25 do
			task.wait(0.25)
			t += 0.25
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and start and (r.Position - start).Magnitude > 12 then
				break
			end
		end
		if my == noteToken then
			hideNote()
		end
	end)
end)

---------------------------------------------------------------------
-- Кодовый замок сейфа
---------------------------------------------------------------------
local safe = Instance.new("Frame")
safe.Size = UDim2.fromOffset(340, 230)
safe.Position = UDim2.new(0.5, -170, 0.5, -140)
safe.BackgroundColor3 = Color3.fromRGB(34, 36, 38)
safe.Visible = false
safe.Parent = gui
corner(safe, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.fromOffset(0, 10)
title.BackgroundTransparency = 1
title.Text = "Сейф Томаса: 4 цифры"
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextColor3 = Color3.fromRGB(220, 210, 190)
title.Parent = safe

local input = Instance.new("TextBox")
input.Size = UDim2.fromOffset(200, 56)
input.Position = UDim2.new(0.5, -100, 0, 60)
input.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
input.TextColor3 = Color3.fromRGB(255, 120, 90)
input.Font = Enum.Font.Code
input.TextSize = 40
input.PlaceholderText = "____"
input.Text = ""
input.ClearTextOnFocus = false
input.Parent = safe
corner(input, 6)

local okButton = button(safe, "Открыть", UDim2.new(0.5, -150, 1, -62), UDim2.fromOffset(140, 44))
local cancelButton = button(safe, "Отмена", UDim2.new(0.5, 10, 1, -62), UDim2.fromOffset(140, 44))

-- только цифры, не больше 4
input:GetPropertyChangedSignal("Text"):Connect(function()
	local digits = input.Text:gsub("%D", ""):sub(1, 4)
	if digits ~= input.Text then
		input.Text = digits
	end
end)

local function send()
	if #input.Text == 4 then
		safeEvent:FireServer(input.Text)
	end
end
okButton.MouseButton1Click:Connect(send)
input.FocusLost:Connect(function(enter)
	if enter then
		send()
	end
end)
cancelButton.MouseButton1Click:Connect(function()
	safe.Visible = false
end)

safeEvent.OnClientEvent:Connect(function(kind: string)
	if kind == "Open" then
		input.Text = ""
		safe.Visible = true
		input:CaptureFocus()
	elseif kind == "Wrong" then
		-- красная вспышка и тряска
		input.TextColor3 = Color3.fromRGB(255, 40, 40)
		local base = input.Position
		for i = 1, 6 do
			input.Position = base + UDim2.fromOffset(i % 2 == 0 and 6 or -6, 0)
			task.wait(0.04)
		end
		input.Position = base
		input.Text = ""
		TweenService:Create(input, TweenInfo.new(0.5), { TextColor3 = Color3.fromRGB(255, 120, 90) }):Play()
	elseif kind == "Right" then
		input.TextColor3 = Color3.fromRGB(90, 230, 110)
		task.wait(0.6)
		safe.Visible = false
		input.TextColor3 = Color3.fromRGB(255, 120, 90)
	end
end)
