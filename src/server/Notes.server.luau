-- Записки: подойди и нажми E «Прочитать» — текст появится на экране (NoteView.client.luau).
-- Записка — деталь с атрибутом Text: из Workspace.Map.Notes (сюжет) или с тегом "Note"
-- (записки с кодом сейфа и рисунок Лили, их кладёт Talisman.server.luau каждый раунд).
-- Читать могут все, даже монстр.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local showNote = Instance.new("RemoteEvent")
showNote.Name = "ShowNote"
showNote.Parent = remotes

local done = setmetatable({}, { __mode = "k" })

local function setup(part: Instance)
	if done[part] or not part:IsA("BasePart") or typeof(part:GetAttribute("Text")) ~= "string" then
		return
	end
	done[part] = true
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Прочитать"
	prompt.ObjectText = "Записка"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	-- записку показываем всегда: рядом может лежать бинт или быть дверь на той же E
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - part.Position).Magnitude < 11 then
			showNote:FireClient(player, part:GetAttribute("Text"))
		end
	end)
end

for _, part in CollectionService:GetTagged("Note") do
	setup(part)
end
CollectionService:GetInstanceAddedSignal("Note"):Connect(setup)

local map = workspace:WaitForChild("Map", 15)
local notes = map and map:FindFirstChild("Notes")
if notes then
	for _, part in notes:GetChildren() do
		setup(part)
	end
	notes.ChildAdded:Connect(setup)
end
