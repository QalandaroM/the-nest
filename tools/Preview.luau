-- Помощник для просмотра карты в Studio (режим редактирования).
--   local P = require(game.ServerStorage.Tools.Preview:Clone())
--   P.night(true)            -- ночное освещение как в игре; true = щиток починен (лампы горят)
--   P.cam(x, y, z, tx, ty, tz) -- поставить камеру в точку и смотреть на цель

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Preview = {}

function Preview.night(powered: boolean?)
	local Config = require(ReplicatedStorage.Shared.Config:Clone())
	Lighting.ClockTime = Config.NIGHT_TIME
	Lighting.Brightness = Config.MOON_BRIGHTNESS
	Lighting.Ambient = Config.DARK_AMBIENT
	Lighting.OutdoorAmbient = Config.MOON_AMBIENT
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.FogColor = Config.FOG_COLOR
	Lighting.FogStart = 0
	Lighting.FogEnd = Config.FOG_END
	for _, part in CollectionService:GetTagged("PanelLight") do
		local light = part:FindFirstChildWhichIsA("Light")
		if light then
			light.Enabled = powered == true
		end
		if part:IsA("BasePart") and part.Name ~= "ChandelierLight" then
			part.Material = powered and Enum.Material.Neon or Enum.Material.Glass
			part.Color = powered and (part:GetAttribute("OnColor") or part.Color) or Color3.fromRGB(60, 58, 50)
		end
	end
end

function Preview.cam(x: number, y: number, z: number, tx: number, ty: number, tz: number)
	local cam = workspace.CurrentCamera
	local target = Vector3.new(tx, ty, tz)
	cam.CFrame = CFrame.lookAt(Vector3.new(x, y, z), target)
	cam.Focus = CFrame.new(target)
end

return Preview
