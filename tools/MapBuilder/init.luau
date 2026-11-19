-- Строит карту «Дом Хейлов» целиком из кода.
-- Запуск в Studio (Command Bar, в режиме редактирования):
--   require(game.ServerStorage.Tools.MapBuilder:Clone()).build()
-- Потом сохраните место (Ctrl+S). Отменить — Ctrl+Z.
--
-- Модули:
--   Kit       — детали, стены, двери, лестницы, свет
--   Assets    — модели и декали из Toolbox (скрипты из них вырезаются)
--   Decor     — гниль, паутина, слизь, свечи
--   Furniture — мебель (Toolbox или из деталей)
--   House / Basement / Exterior — сами части карты

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Kit = require(script.Kit)
local Assets = require(script.Assets)
local House = require(script.House)
local Basement = require(script.Basement)
local Exterior = require(script.Exterior)

local MapBuilder = {}

local OLD = { "Map", "Hideouts", "Fuses", "KeySpawns", "MonsterSpawn", "SurvivorSpawn", "LobbySpawn", "Baseplate", "BasementKey" }

local function clearOld()
	for _, name in OLD do
		local old = workspace:FindFirstChild(name)
		while old do
			old:Destroy()
			old = workspace:FindFirstChild(name)
		end
	end
end

function MapBuilder.build(): string
	Kit.rng = Random.new(1989) -- каждый раз одна и та же карта

	local recording: string? = nil
	pcall(function()
		recording = ChangeHistoryService:TryBeginRecording("Build THE NEST map")
	end)

	clearOld()

	local map = Kit.folder(workspace, "Map")
	local ctx = {
		hideouts = Kit.folder(workspace, "Hideouts"),
		fuses = Kit.folder(workspace, "Fuses"),
		keySpawns = Kit.folder(workspace, "KeySpawns"),
		notes = Kit.folder(map, "Notes"),
	}

	Exterior.build(map, ctx)
	House.build(map, ctx)
	Basement.build(map, ctx)

	if recording then
		pcall(function()
			ChangeHistoryService:FinishRecording(recording :: string, Enum.FinishRecordingOperation.Commit)
		end)
	end

	local parts = 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	local st = Assets.stats
	local result = `THE NEST: карта построена. Деталей: {parts}, тайников: {#ctx.hideouts:GetChildren()}, предохранителей: {#ctx.fuses:GetChildren()}, мест для ключа: {#ctx.keySpawns:GetChildren()}. Модели Toolbox: загружено {st.loaded}, не загрузилось {st.failed}, удалено скриптов {st.scriptsRemoved}`
	print(result)
	return result
end

return MapBuilder
