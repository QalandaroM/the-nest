-- Показывает подсказки (E) только нужной роли.
-- У ProximityPrompt атрибут ForRole = "Survivor" или "Monster".
-- Это только для удобства: сервер всё равно проверяет роль сам.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

local function allowed(prompt: ProximityPrompt): boolean
	local role = prompt:GetAttribute("ForRole")
	return role == nil or player:GetAttribute("Role") == role
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

workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		task.defer(refresh, d) -- атрибут ставится сразу после создания
	end
end)
player:GetAttributeChangedSignal("Role"):Connect(refreshAll)
refreshAll()

-- на всякий случай: если подсказка всё же показалась не той роли — прячем
ProximityPromptService.PromptShown:Connect(function(prompt)
	if not allowed(prompt) then
		prompt.Enabled = false
	end
end)
