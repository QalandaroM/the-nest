-- Облик монстра: когда игрок становится монстром, на его персонажа «надевается»
-- олений череп, рога, рёбра и когти (модель — src/shared/MonsterModel.luau).
-- Монстр немного выше и худее обычного человека (только для R15).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterModel = require(ReplicatedStorage.Shared.MonsterModel)
local MonsterAnims = require(script.Parent.MonsterAnims)

MonsterAnims.start() -- скример монстра; сами позы анимаций играет клиент (MonsterAnimator)

local busy: { [Model]: boolean } = {}

-- force = надеть заново, даже если облик уже есть (Roblox догрузил внешность и мог заменить части тела —
-- тогда меши монстра, приваренные к старым частям, пропали бы)
local function apply(player: Player, force: boolean?)
	local character = player.Character
	if not character or busy[character] or (not force and character:FindFirstChild("MonsterLook")) then
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
			-- обычное блочное тело R15 (без бандлов): под него сделаны меши из Blender
			desc.Head = 0
			desc.Torso = 0
			desc.LeftArm = 0
			desc.RightArm = 0
			desc.LeftLeg = 0
			desc.RightLeg = 0
			desc.BodyTypeScale = 0
			desc.ProportionScale = 0
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
			apply(player, true)
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
