-- Показывает подсказки (E) только нужной роли.
-- У ProximityPrompt атрибут ForRole = "Survivor" или "Monster".
-- NeedsCarry = true — только когда монстр несёт тело (тайники).
-- У родителя подсказки атрибут Occupied = true — подсказка скрыта (в тайнике уже кокон).
-- Это только для удобства: сервер всё равно проверяет всё сам.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

local function allowed(prompt: ProximityPrompt): boolean
	local role = prompt:GetAttribute("ForRole")
	if role ~= nil and player:GetAttribute("Role") ~= role then
		return false
	end
	if prompt:GetAttribute("NeedsCarry") and not player:GetAttribute("CarryingBody") then
		return false
	end
	if prompt.Parent and prompt.Parent:GetAttribute("Occupied") then
		return false
	end
	return true
end

local function refresh(prompt: Instance)
	if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("ForRole") ~= nil then
		prompt.Enabled = allowed(prompt)
	end
end

local function refreshAll()
	for _, d in workspace:GetDescendants() do
		refresh(d)
	end
end

local watchedParents = setmetatable({}, { __mode = "k" })

workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		task.defer(refresh, d) -- атрибут ставится сразу после создания
		local parent = d.Parent
		if parent and not watchedParents[parent] then
			watchedParents[parent] = true
			parent:GetAttributeChangedSignal("Occupied"):Connect(refreshAll)
		end
	end
end)
for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") and d.Parent and not watchedParents[d.Parent] then
		watchedParents[d.Parent] = true
		d.Parent:GetAttributeChangedSignal("Occupied"):Connect(refreshAll)
	end
end
player:GetAttributeChangedSignal("Role"):Connect(refreshAll)
player:GetAttributeChangedSignal("CarryingBody"):Connect(refreshAll)
refreshAll()

-- на всякий случай: если подсказка всё же показалась не той роли — прячем
ProximityPromptService.PromptShown:Connect(function(prompt)
	if not allowed(prompt) then
		prompt.Enabled = false
	end
end)
