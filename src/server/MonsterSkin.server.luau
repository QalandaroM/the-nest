-- Облик монстра: когда игрок становится монстром, на его персонажа «надевается»
-- олений череп, рога, рёбра и когти (модель — src/shared/MonsterModel.luau).
-- Монстр немного выше и худее обычного человека (только для R15).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterModel = require(ReplicatedStorage.Shared.MonsterModel)

local busy: { [Model]: boolean } = {}

local function apply(player: Player)
	local character = player.Character
	if not character or busy[character] or character:FindFirstChild("MonsterLook") then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	busy[character] = true
	-- выше и тоньше (R15). ApplyDescription может не сработать — тогда просто без роста
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		pcall(function()
			local desc = humanoid:GetAppliedDescription()
			desc.HeightScale = 1.15
			desc.WidthScale = 0.85
			desc.DepthScale = 0.9
			humanoid:ApplyDescription(desc)
		end)
	end
	if character.Parent and player:GetAttribute("Role") == "Monster" then
		MonsterModel.dress(character)
	end
	busy[character] = nil
end

local function onPlayer(player: Player)
	player.CharacterAppearanceLoaded:Connect(function()
		if player:GetAttribute("Role") == "Monster" then
			apply(player)
		end
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if player:GetAttribute("Role") == "Monster" then
			apply(player)
		end
	end)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		if player:GetAttribute("Role") == "Monster" then
			apply(player)
		elseif player:GetAttribute("Role") == nil and player.Character and player.Character:FindFirstChild("MonsterLook") then
			-- лобби: возвращаем обычный вид
			player:LoadCharacter()
		end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end
