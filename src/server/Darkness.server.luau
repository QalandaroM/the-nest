-- Делает в игре темно: гасит дневной свет и ставит почти чёрный фон.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

Lighting.ClockTime = Config.NIGHT_TIME -- ночь, луна над лесом
Lighting.Brightness = Config.MOON_BRIGHTNESS -- ночью это свет луны
Lighting.Ambient = Config.DARK_AMBIENT
Lighting.OutdoorAmbient = Config.MOON_AMBIENT -- снаружи слабая луна, внутри дома темно
Lighting.EnvironmentDiffuseScale = 0 -- небо не подсвечивает предметы
Lighting.EnvironmentSpecularScale = 0
Lighting.GlobalShadows = true
Lighting.FogColor = Config.FOG_COLOR
Lighting.FogStart = 0
Lighting.FogEnd = Config.FOG_END
