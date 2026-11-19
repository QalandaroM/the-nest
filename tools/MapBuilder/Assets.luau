-- Модели и декали из Creator Store (Toolbox).
-- Загружаются только в Studio (Command Bar). Из каждой модели удаляются ВСЕ скрипты,
-- сиденья отключаются, детали закрепляются. Если модель не загрузилась,
-- функция вернёт nil и вместо неё строится мебель из деталей.

local Assets = {}

-- height — до какой высоты (studs) масштабировать, yaw — поворот, если модель «смотрит» не туда.
-- length — вместо высоты подогнать самую длинную сторону (для кроватей, диванов)
Assets.MODELS = {
	bed = { id = 9064947860, length = 10, yaw = 0 },
	bedSmall = { id = 5099110702, length = 7, yaw = 0 },
	chair = { id = 4769511860, height = 4.6, yaw = 180 },
	wardrobe = { id = 12156928693, height = 9.5, yaw = 90 },
	couch = { id = 11290198233, length = 9, yaw = 0 },
	couchDirty = { id = 11290204187, length = 8, yaw = 0 },
	dresser = { id = 9658336938, height = 4, yaw = 0 },
	rockingChair = { id = 303336108, height = 4.8, yaw = 0 },
	piano = { id = 231155635, length = 7, yaw = 0 },
	-- ванна из Toolbox слишком высокая (со шторкой) — используем свою из деталей
	chandelier = { id = 134764153675939, height = 4.5, yaw = 0 },
	tv = { id = 2728575005, height = 2.8, yaw = 0 },
	barrel = { id = 204351788, height = 4, yaw = 0 },
	crate = { id = 182451181, height = 3, yaw = 0 },
	crateBroken = { id = 10176332944, height = 2.6, yaw = 0 },
	candle = { id = 16909878429, height = 1.1, yaw = 0 },
	web = { id = 299892678, height = 5, yaw = 0 },
	cornerWeb = { id = 18471692316, height = 5, yaw = 0 },
	cabinet = { id = 5368715664, height = 6, yaw = 0 },
	bookshelf = { id = 141047988, height = 10, yaw = 0 },
	bookshelfSmall = { id = 834958293, height = 8, yaw = 0 },
	fridge = { id = 90239927677819, height = 7, yaw = 0 },
	stove = { id = 8268013214, height = 3.6, yaw = 0 },
	teddy = { id = 8820218869, height = 1.6, yaw = 0 },
	painting = { id = 56447356, height = 4, yaw = 0 },
	clock = { id = 18985183180, height = 8, yaw = 0 },
}

-- Декали (картинки на стенах и полу)
Assets.DECALS = {
	cornerWeb = 340852240,
	roundWeb = 9817982402,
	tornWeb = 17896912126,
	grimeDrip = 14432660594,
	grime = 7210626620,
	dirt = 12969179306,
	smudge = 14611375336,
	moldStreak = 114439718942979,
	moldBottom = 146725252,
	waterStain = 11697065037,
	crack = 12969168833,
	scratch = 12969198605,
	slimeDrip = 14668414104,
	puddle = 16015221454,
}

local modelCache: { [string]: Model | false } = {}
local textureCache: { [string]: string | false } = {}

Assets.stats = { loaded = 0, failed = 0, scriptsRemoved = 0 }

local function load(id: number): { Instance }?
	local ok, result = pcall(function()
		return (game :: any):GetObjects(`rbxassetid://{id}`)
	end)
	if ok and result and #result > 0 then
		return result
	end
	return nil
end

-- Готовим модель: убираем скрипты, сиденья, закрепляем детали
local function sanitize(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			Assets.stats.scriptsRemoved += 1
			d:Destroy()
		elseif d:IsA("Seat") or d:IsA("VehicleSeat") then
			(d :: any).Disabled = true
		elseif d:IsA("ClickDetector") or d:IsA("ProximityPrompt") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

local function getModel(key: string): Model?
	local cached = modelCache[key]
	if cached == nil then
		local info = Assets.MODELS[key]
		local objects = info and load(info.id)
		if objects then
			local model = Instance.new("Model")
			model.Name = key
			for _, obj in objects do
				obj.Parent = model
			end
			sanitize(model)
			-- поворот модели сбрасываем, чтобы рамка была ровной
			local pivot = model:GetPivot()
			model.WorldPivot = CFrame.new(pivot.Position)
			modelCache[key] = model
			Assets.stats.loaded += 1
		else
			modelCache[key] = false
			if info then -- нет в таблице = строим из деталей специально, это не ошибка
				Assets.stats.failed += 1
			end
		end
		cached = modelCache[key]
	end
	if cached then
		return (cached :: Model):Clone()
	end
	return nil
end

-- Ставит модель так, чтобы её низ по центру оказался в точке cf.
-- height — нужная высота (иначе из таблицы), extraYaw — дополнительный поворот (градусы)
function Assets.place(parent: Instance, key: string, cf: CFrame, height: number?, extraYaw: number?): Model?
	local model = getModel(key)
	if not model then
		return nil
	end
	local info = Assets.MODELS[key]
	local _, size = model:GetBoundingBox()
	if not height and info.length then
		local longest = math.max(size.X, size.Z)
		if longest > 0.01 then
			model:ScaleTo(model:GetScale() * info.length / longest)
		end
	elseif size.Y > 0.01 then
		model:ScaleTo(model:GetScale() * (height or info.height) / size.Y)
	end
	local bbCF, bbSize = model:GetBoundingBox()
	local pivot = model:GetPivot()
	-- смещение от опоры модели до центра её низа
	local bottom = pivot:PointToObjectSpace(bbCF.Position - Vector3.new(0, bbSize.Y / 2, 0))
	local yaw = math.rad((info.yaw or 0) + (extraYaw or 0))
	model:PivotTo(cf * CFrame.Angles(0, yaw, 0) * CFrame.new(-bottom))
	model.Parent = parent
	return model
end

-- Картинка (Texture) по ID декали
function Assets.texture(key: string): string?
	local cached = textureCache[key]
	if cached == nil then
		local id = Assets.DECALS[key]
		local objects = id and load(id)
		local decal = objects and objects[1]
		if decal and decal:IsA("Decal") and decal.Texture ~= "" then
			textureCache[key] = decal.Texture
		else
			-- запасной вариант: прямой ID (иногда работает и он)
			textureCache[key] = id and `rbxassetid://{id}` or false
		end
		cached = textureCache[key]
	end
	return cached or nil
end

-- Декаль на поверхности: pos — центр, normal — куда «смотрит» картинка
function Assets.decal(parent: Instance, key: string, pos: Vector3, normal: Vector3, w: number, h: number, color: Color3?, transparency: number?, spin: number?): Part?
	local texture = Assets.texture(key)
	if not texture then
		return nil
	end
	local up = math.abs(normal.Y) > 0.9 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
	local cf = CFrame.lookAt(pos, pos + normal, up) * CFrame.Angles(0, 0, math.rad(spin or 0))
	local holder = Instance.new("Part")
	holder.Name = "Decal_" .. key
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(w, h, 0.05)
	holder.CFrame = cf
	local decal = Instance.new("Decal")
	decal.Texture = texture
	decal.Face = Enum.NormalId.Front
	decal.Color3 = color or Color3.new(1, 1, 1)
	decal.Transparency = transparency or 0
	decal.Parent = holder
	holder.Parent = parent
	return holder
end

return Assets
