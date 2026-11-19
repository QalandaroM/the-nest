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
	Monster = "Ты МОНСТР. Убей всех, пока они не собрали талисман.",
	Survivor = "Соберите талисман из 3 частей и убейте им монстра.",
	Dead = "Тебя убили...",
	Slain = "Талисман сжёг тебя...",
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
info.Size = UDim2.new(0, 440, 0, 360)
info.Position = UDim2.new(0, 16, 1, -380)
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
		local role = player:GetAttribute("Role")
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")

		-- Здоровье и раны выжившего
		if role == "Survivor" and humanoid then
			local hp = math.max(0, math.ceil(humanoid.Health))
			local color = hp > 60 and "#c8e6a0" or (hp > 30 and "#e6c878" or "#e67a64")
			local hpText = `Здоровье: <font color="{color}">{hp}</font>`
			if (player:GetAttribute("Bleeding") or 0) > 0 then
				hpText ..= `  <font color="#d04040">🩸 кровотечение</font>`
			end
			if player:GetAttribute("Bandaging") then
				hpText ..= "  перевязываешься…"
			end
			table.insert(lines, hpText)
			local wounds = player:GetAttribute("WoundsText")
			if wounds and wounds ~= "" then
				table.insert(lines, `<font size="16" color="#c8a8a0">{wounds}</font>`)
			end
			local bandages = player:GetAttribute("Bandages") or 0
			if bandages > 0 then
				table.insert(lines, `Бинтов: {bandages}`)
			end
		end

		-- Перезарядка когтей монстра и его здоровье (ожоги талисманом)
		if role == "Monster" and humanoid then
			local hp = math.max(0, math.ceil(humanoid.Health))
			table.insert(lines, `Здоровье: <font color="{hp > 50 and "#c8e6a0" or "#e67a64"}">{hp}</font>`)
		end
		if role == "Monster" then
			local left = (player:GetAttribute("ClawReadyAt") or 0) - workspace:GetServerTimeNow()
			if left > 0 then
				table.insert(lines, `Когти: {string.format("%.1f", left)} сек`)
			else
				table.insert(lines, `Когти: <font color="#e67a64">готовы</font>`)
			end
		end

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

		-- Части талисмана в руках
		local held = {}
		for key, name in { Chain = "цепочка", Stone = "камень", Frame = "оправа" } do
			if player:GetAttribute(`Has{key}`) then
				table.insert(held, name)
			end
		end
		if #held > 0 then
			table.insert(lines, `У тебя: {table.concat(held, ", ")} — неси на алтарь в библиотеку`)
		end
		local tal = player.Character and player.Character:FindFirstChild("Талисман")
		if tal or (player:FindFirstChildOfClass("Backpack") and player:FindFirstChildOfClass("Backpack"):FindFirstChild("Талисман")) then
			local left = (player:GetAttribute("TalismanReadyAt") or 0) - workspace:GetServerTimeNow()
			table.insert(lines, left > 0 and `Талисман: {string.format("%.1f", left)} сек` or `<font color="#ff7a5a">Талисман готов</font> — кликни рядом с монстром`)
		end

		-- Как продвигается поиск талисмана (видят все, и монстр тоже)
		if workspace:GetAttribute("RoundActive") and role then
			local marks = {}
			for _, pair in { { "Chain", "цепочка" }, { "Stone", "камень" }, { "Frame", "оправа" } } do
				local st = workspace:GetAttribute(`Quest_{pair[1]}`)
				local mark = st == "Placed" and "✓" or (st == "Found" and "…" or "?")
				table.insert(marks, `{pair[2]} {mark}`)
			end
			local state = workspace:GetAttribute("TalismanState")
			local tail = state == "Taken" and "  • талисман у выживших!" or (state == "Ready" and "  • талисман на алтаре" or "")
			table.insert(lines, `<font size="16">Талисман: {table.concat(marks, "  ")}{tail}</font>`)
			local burns = workspace:GetAttribute("MonsterBurns") or 0
			if burns > 0 then
				table.insert(lines, `<font size="16" color="#ff7a5a">Монстр обожжён: {burns}</font>`)
			end
		end
		if workspace:GetAttribute("RoundActive") and player:GetAttribute("Role") then
			local p = workspace:GetAttribute("PanelProgress") or 0
			table.insert(lines, workspace:GetAttribute("Power") and `Свет: есть (щиток {p}%)` or `Свет: нет (щиток {p}%)`)
		end
		info.Text = table.concat(lines, "\n")
	end
end)
