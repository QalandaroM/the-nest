-- Показывает статус раунда и роль игрока на экране.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Статус сверху экрана
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.5, 0, 0, 40)
statusLabel.Position = UDim2.new(0.25, 0, 0, 10)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Parent = gui

local status = ReplicatedStorage:WaitForChild("Status") :: StringValue
local function updateStatus()
	statusLabel.Text = status.Value
end
status.Changed:Connect(updateStatus)
updateStatus()

-- Большая надпись с ролью в центре
local roleLabel = Instance.new("TextLabel")
roleLabel.Size = UDim2.new(0.8, 0, 0, 80)
roleLabel.Position = UDim2.new(0.1, 0, 0.4, 0)
roleLabel.BackgroundTransparency = 1
roleLabel.TextColor3 = Color3.fromRGB(200, 30, 30)
roleLabel.TextScaled = true
roleLabel.Font = Enum.Font.GothamBlack
roleLabel.Visible = false
roleLabel.Parent = gui

local messages = {
	Monster = "Ты МОНСТР. Убивай быстро, тогда кокон вылупится раньше.",
	Survivor = "Найдите 5 предохранителей. Ломайте коконы.",
	Dead = "Тебя убили...",
}

local function showRole()
	local text = messages[player:GetAttribute("Role")]
	if not text then
		return
	end
	roleLabel.Text = text
	roleLabel.Visible = true
	task.delay(4, function()
		roleLabel.Visible = false
	end)
end

player:GetAttributeChangedSignal("Role"):Connect(showRole)

-- Внизу слева: батарея фонарика, ключ, щиток
local info = Instance.new("TextLabel")
info.Size = UDim2.new(0, 320, 0, 90)
info.Position = UDim2.new(0, 16, 1, -110)
info.BackgroundTransparency = 1
info.TextColor3 = Color3.fromRGB(225, 215, 190)
info.TextStrokeTransparency = 0.5
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Bottom
info.Font = Enum.Font.GothamMedium
info.TextSize = 20
info.RichText = true
info.Parent = gui

local function findFlashlight(): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild("Flashlight")
	if not tool then
		local backpack = player:FindFirstChildOfClass("Backpack")
		tool = backpack and backpack:FindFirstChild("Flashlight")
	end
	return tool :: Tool?
end

task.spawn(function()
	while true do
		task.wait(0.25)
		local lines = {}
		local tool = findFlashlight()
		if tool then
			local battery = math.floor((tool:GetAttribute("Battery") :: number?) or 0)
			local color = battery > 40 and "#c8e6a0" or (battery > 15 and "#e6c878" or "#e67a64")
			local text = `Фонарик: <font color="{color}">{battery}%</font>`
			if player:GetAttribute("Charging") then
				text ..= workspace:GetAttribute("Power") and "  ⚡ зарядка" or "  ⚡ медленная зарядка (щиток сломан)"
			end
			table.insert(lines, text)
		end
		if player:GetAttribute("HasKey") then
			table.insert(lines, "У тебя ключ от подвала")
		end
		if workspace:GetAttribute("RoundActive") and player:GetAttribute("Role") then
			local p = workspace:GetAttribute("PanelProgress") or 0
			table.insert(lines, workspace:GetAttribute("Power") and `Свет: есть (щиток {p}%)` or `Свет: нет (щиток {p}%)`)
		end
		info.Text = table.concat(lines, "\n")
	end
end)
