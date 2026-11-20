-- Ставит предмет квеста (сейф, ящик, алтарь) к случайной стене в случайной комнате.
-- Комнаты-кандидаты — точки Workspace.Quest.CodeNotes (там же лежат записки).
-- Как выбирается место (всё проверяется лучами, чтобы предмет не залез в стену или мебель):
--   1. из точки комнаты пускаем луч в одну из 4 сторон до стены;
--   2. стена должна быть сплошной за всей шириной предмета (не дверь, не проём);
--   3. под предметом ровный пол, а на его месте и перед ним (чтобы подойти) нет мебели.
-- Если ни одно место не подошло — предмет остаётся там, где стоял.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local QuestPlacer = {}

local rng = Random.new()
local DIRS = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }

export type Spec = {
	model: Model,
	body: BasePart, -- главная деталь; она стоит над точкой пола на bodyY
	bodyY: number,
	size: Vector3, -- ширина (X), высота (Y), глубина (Z) предмета
}

local function shuffled<T>(list: { T }): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- Что не считается препятствием: невидимые зоны, предметы квеста, игроки, тела, бинты
local function ignoreList(self: Model): { Instance }
	local list: { Instance } = { self }
	for _, name in { "Zones", "QuestItems", "Bodies", "Cocoons", "Bandages", "Hideouts", "BandageSpawns", "KeySpawns" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	return list
end

local function isDoor(part: Instance): boolean
	local x: Instance? = part
	while x and x ~= workspace do
		if CollectionService:HasTag(x, "Door") or x.Name:find("Door") then
			return true
		end
		x = x.Parent
	end
	return false
end

-- Луч, который замечает только твёрдые детали (сквозь невидимые и нетвёрдые проходит)
local function solidRay(origin: Vector3, dir: Vector3, ignore: { Instance }): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = table.clone(ignore)
	for _ = 1, 8 do
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(origin, dir, params)
		if not hit or (hit.Instance.CanCollide and hit.Instance.Transparency < 0.9) then
			return hit
		end
		table.insert(skip, hit.Instance)
	end
	return nil
end

local function floorAt(pos: Vector3, ignore: { Instance }): number?
	local hit = solidRay(pos + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), ignore)
	return hit and hit.Position.Y
end

-- Есть ли в коробке что-то видимое (мебель, стены). Ковры и мусор на полу не считаются.
local function blocked(cf: CFrame, size: Vector3, floorY: number, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	for _, part in workspace:GetPartBoundsInBox(cf, size, params) do
		if part.Transparency < 0.9 and part.Position.Y + part.Size.Y / 2 > floorY + 0.4 then
			-- деталь торчит выше пола — мешает
			if part.CanCollide or part.Size.Magnitude > 1.5 then
				return true
			end
		end
	end
	return false
end

-- Попробовать поставить предмет у стены, на которую смотрит луч из точки комнаты
local function tryAt(spec: Spec, spot: Vector3, dir: Vector3, ignore: { Instance }): CFrame?
	local floorY = floorAt(spot, ignore)
	if not floorY then
		return nil
	end
	local origin = Vector3.new(spot.X, floorY + 2.5, spot.Z)
	local hit = solidRay(origin, dir * 30, ignore)
	if not hit or isDoor(hit.Instance) then
		return nil
	end
	local normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
	if normal.Magnitude < 0.9 then
		return nil -- не стена
	end
	normal = normal.Unit
	local w, h, d = spec.size.X, spec.size.Y, spec.size.Z
	local center = hit.Position + normal * (d / 2 + 0.15)
	local right = normal:Cross(Vector3.yAxis).Unit
	-- стена сплошная за всей шириной (на двух высотах), и пол везде ровный
	for _, side in { -1, 1 } do
		for _, y in { 1.2, 3 } do
			local p = Vector3.new(center.X, floorY + y, center.Z) + right * side * (w / 2 - 0.1)
			local back = solidRay(p, -normal * (d / 2 + 0.6), ignore)
			if not back or isDoor(back.Instance) then
				return nil
			end
		end
		local fy = floorAt(Vector3.new(center.X, floorY, center.Z) + right * side * (w / 2), ignore)
		if not fy or math.abs(fy - floorY) > 0.4 then
			return nil
		end
	end
	-- место самого предмета + проход 2.5 studs перед ним свободны,
	-- и над предметом ещё 0.8 studs пусто (чтобы не залез под столешницу или полку)
	local look = CFrame.lookAt(Vector3.new(center.X, floorY, center.Z), Vector3.new(center.X, floorY, center.Z) + normal)
	local boxH = h + 0.8 - 0.4
	local boxCf = look * CFrame.new(0, 0.4 + boxH / 2, -1.25)
	if blocked(boxCf, Vector3.new(w + 0.4, boxH, d + 2.5), floorY, ignore) then
		return nil
	end
	return look -- точка на полу у стены, «лицом» в комнату
end

-- Переставить предмет. spots — точки комнат; used — уже занятые комнаты (номера), чтобы
-- предметы не попали в одну комнату. Возвращает номер комнаты или nil.
function QuestPlacer.place(spec: Spec, spots: { Vector3 }, used: { [number]: boolean }): number?
	local ignore = ignoreList(spec.model)
	local order = {}
	for i in spots do
		if not used[i] then
			table.insert(order, i)
		end
	end
	for _, i in shuffled(order) do
		for _, dir in shuffled(DIRS) do
			local look = tryAt(spec, spots[i], dir, ignore)
			if look then
				-- сейчас: где «пол под предметом» и как он повёрнут
				local oldBase = spec.body.CFrame * CFrame.new(0, -spec.bodyY, 0)
				local rel = oldBase:Inverse() * spec.model:GetPivot()
				spec.model:PivotTo(look * rel)
				used[i] = true
				return i
			end
		end
	end
	return nil
end

return QuestPlacer
