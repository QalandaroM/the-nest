-- Светлый режим от 3-го лица: если камера отъехала от головы (колесо мыши / ПКМ),
-- картинка становится светлее, чтобы было видно себя и комнату.
-- Вернёшь камеру в голову (1-е лицо) — снова темно, как задумано.
-- Включается в Config.THIRD_PERSON_BRIGHT. Меняет свет только у этого игрока.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

if not Config.THIRD_PERSON_BRIGHT then
	return
end

local player = Players.LocalPlayer
local saved: { [string]: any }? = nil

local function setBright(on: boolean)
	if on and not saved then
		-- запоминаем настоящий ночной свет, чтобы потом вернуть
		saved = {
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			ExposureCompensation = Lighting.ExposureCompensation,
		}
		Lighting.Ambient = Config.THIRD_PERSON_AMBIENT
		Lighting.OutdoorAmbient = Config.THIRD_PERSON_AMBIENT:Lerp(Color3.new(1, 1, 1), 0.2)
		Lighting.ExposureCompensation = Config.THIRD_PERSON_EXPOSURE
	elseif not on and saved then
		for key, value in saved do
			(Lighting :: any)[key] = value
		end
		saved = nil
	end
end

RunService.RenderStepped:Connect(function()
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not head then
		setBright(false)
		return
	end
	local dist = (workspace.CurrentCamera.CFrame.Position - head.Position).Magnitude
	setBright(dist > Config.THIRD_PERSON_DISTANCE)
end)
