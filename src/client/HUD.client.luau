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
