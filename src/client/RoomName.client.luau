-- Название комнаты: когда входишь в новую комнату, сверху на пару секунд появляется
-- её название («Кухня», «Детская Лили», «Генераторная»…). Так проще понять, где ты.
-- Зоны комнат — невидимые детали в Workspace.Zones (их ставит MapBuilder).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "RoomName"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0.5, 0, 0, 34)
label.Position = UDim2.new(0.25, 0, 0, 58)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.fromRGB(215, 200, 170)
label.TextStrokeTransparency = 0.6
label.TextTransparency = 1
label.TextStrokeColor3 = Color3.new(0, 0, 0)
label.Font = Enum.Font.SpecialElite
label.TextSize = 28
label.Parent = gui

local function inside(zone: BasePart, pos: Vector3): boolean
	local p = zone.CFrame:PointToObjectSpace(pos)
	local h = zone.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

-- Самая маленькая зона, в которой стоит игрок (крыльцо внутри двора и т.п.)
local function currentZone(pos: Vector3): string?
	local zones = workspace:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	local best, bestVolume = nil, math.huge
	for _, z in zones:GetChildren() do
		if z:IsA("BasePart") and inside(z, pos) then
			local v = z.Size.X * z.Size.Y * z.Size.Z
			if v < bestVolume then
				best, bestVolume = z.Name, v
			end
		end
	end
	return best
end

local shown: string? = nil
local token = 0

local function show(name: string)
	token += 1
	local my = token
	label.Text = name
	TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 0.05, TextStrokeTransparency = 0.6 }):Play()
	task.delay(2.8, function()
		if my == token then
			TweenService:Create(label, TweenInfo.new(1.2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

while true do
	task.wait(0.3)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local name = currentZone(root.Position)
		if name and name ~= shown then
			shown = name
			show(name)
		end
	end
end
