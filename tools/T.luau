-- Короткие команды для проверки в Studio (Command Bar):
--   require(game.ServerStorage.Tools.T:Clone()).pick()  — в редактировании: поставить точки бинтов
--   require(game.ServerStorage.Tools.T:Clone()).meet()  — на сервере в тесте: монстр за спиной выжившего
--   require(game.ServerStorage.Tools.T:Clone()).info()  — на сервере: HP, раны, бинты всех игроков
--   require(game.ServerStorage.Tools.T:Clone()).give(2) — на сервере: выжившим по 2 бинта
--   .code()     — на сервере: показать код сейфа и порядок свечей этого раунда
--   .parts()    — на сервере: дать первому выжившему все 3 части талисмана
--   .talisman() — на сервере: дать первому выжившему готовый талисман
--   .face()     — на сервере: выживший с талисманом стоит лицом к монстру в 4 studs
--   .go(name)   — на сервере: выжившего к сейфу / ящику / могилам / алтарю ("Safe", "Chest", "Graves", "Altar")
--   .monster()  — в редактировании: статуя монстра и большой талисман у дороги (посмотреть модели)

local Players = game:GetService("Players")

local T = {}

function T.pick()
	require(game.ServerStorage.Tools.MapBuilder.Pickups:Clone()).build()
	local s = game.ServerScriptService.Server
	print("THE NEST SYNC", s:FindFirstChild("Wounds"), s:FindFirstChild("MonsterAttack"), s:FindFirstChild("Bandages"))
end

local function byRole(role: string): Player?
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == role then
			return p
		end
	end
	return nil
end

-- Выживший стоит в холле спиной, монстр в 3 studs позади и смотрит на него
function T.meet(dist: number?)
	local mon, sur = byRole("Monster"), byRole("Survivor")
	if not mon or not sur or not mon.Character or not sur.Character then
		print("THE NEST meet: нет монстра или выжившего")
		return
	end
	local base = Vector3.new(0, 5, -25)
	sur.Character:PivotTo(CFrame.lookAt(base, base + Vector3.new(0, 0, -1)))
	local m = base + Vector3.new(0, 0, dist or 3)
	mon.Character:PivotTo(CFrame.lookAt(m, Vector3.new(base.X, m.Y, base.Z)))
	print(`THE NEST meet: монстр {mon.Name} за спиной {sur.Name}, {dist or 3} studs`)
end

function T.info()
	for _, p in Players:GetPlayers() do
		local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		print(
			`THE NEST {p.Name} role={p:GetAttribute("Role")} hp={h and math.floor(h.Health)} speed={h and h.WalkSpeed}`
				.. ` hits={p:GetAttribute("HitsTaken")} bleed={p:GetAttribute("Bleeding")} arms={p:GetAttribute("ArmsLost")}`
				.. ` eyes={p:GetAttribute("EyesHurt")} bandages={p:GetAttribute("Bandages")} wounds=[{p:GetAttribute("WoundsText")}]`
		)
	end
	local pickups = workspace:FindFirstChild("Bandages")
	if pickups then
		local list = {}
		for _, b in pickups:GetChildren() do
			local pos = b:GetPivot().Position
			table.insert(list, `({math.floor(pos.X)},{math.floor(pos.Y)},{math.floor(pos.Z)})`)
		end
		print(`THE NEST бинтов на карте: {#list} {table.concat(list, " ")}`)
	end
end

-- Убить выжившего, будто монстр ударил hits раз (для проверки кокона)
function T.kill(hits: number?)
	local sur = byRole("Survivor")
	local h = sur and sur.Character and sur.Character:FindFirstChildOfClass("Humanoid")
	if h then
		sur:SetAttribute("HitsTaken", hits or 1)
		h.Health = 0
		print(`THE NEST kill: {sur.Name}, ударов {hits or 1}`)
	end
end

-- Перенести монстра к тайнику (по имени, например "Hideout_Kitchen")
function T.tp(name: string?)
	local mon = byRole("Monster")
	local h = workspace:FindFirstChild("Hideouts") and workspace.Hideouts:FindFirstChild(name or "Hideout_Kitchen")
	if mon and mon.Character and h then
		mon.Character:PivotTo(CFrame.new(h.Position + Vector3.new(3, 3, 0), h.Position + Vector3.new(0, 3, 0)))
		print(`THE NEST tp: монстр у {h.Name}`)
	end
end

-- Монстр берёт тело и прячет его в тайник (как по E). Только в тесте Studio.
function T.hide(name: string?)
	local mon = byRole("Monster")
	local test = game.ServerStorage:FindFirstChild("CocoonTest")
	local hideout = workspace.Hideouts:FindFirstChild(name or "Hideout_Kitchen")
	if mon and test and hideout then
		print("THE NEST pickup:", test:Invoke("pickup", mon))
		T.tp(name)
		-- ждём, пока монстр поднимет тело на плечи: до этого Cocoons не даёт его спрятать
		local Config = require(game.ReplicatedStorage.Shared.Config)
		task.wait(Config.PICKUP_GRAB_TIME + Config.PICKUP_LIFT_TIME + 0.3)
		print("THE NEST hide:", test:Invoke("hide", mon, hideout))
	end
end

-- Монстр только поднимает тело (чтобы посмотреть, как он его несёт)
function T.carry()
	local mon = byRole("Monster")
	local test = game.ServerStorage:FindFirstChild("CocoonTest")
	if mon and test then
		print("THE NEST carry:", test:Invoke("pickup", mon))
	end
end

-- Все выжившие начинают рвать кокон (как удержание E). Сначала T.near()
function T.tear()
	local test = game.ServerStorage:FindFirstChild("CocoonTest")
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Survivor" and test then
			print("THE NEST tear:", p.Name, test:Invoke("tear", p))
		end
	end
end

-- Перенести выживших к первому кокону
function T.near()
	local cocoon = workspace:FindFirstChild("Cocoons") and workspace.Cocoons:FindFirstChildWhichIsA("Model")
	if not cocoon then
		print("THE NEST near: коконов нет")
		return
	end
	local pos = cocoon:GetPivot().Position
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Survivor" and p.Character then
			p.Character:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 1, 4), Vector3.new(pos.X, pos.Y + 1, pos.Z)))
		end
	end
	print("THE NEST near: выжившие у кокона")
end

-- Посветлее, чтобы снять скриншоты (только для показа, в игре так не будет)
function T.bright()
	local Lighting = game:GetService("Lighting")
	Lighting.Ambient = Color3.fromRGB(120, 110, 105)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	Lighting.FogEnd = 1000
	print("THE NEST bright: светлее для скриншотов")
end

-- Состояние тел и коконов
function T.cocoons()
	for _, b in (workspace:FindFirstChild("Bodies") or Instance.new("Folder")):GetChildren() do
		print(`THE NEST тело {b.Name} hits={b:GetAttribute("Hits")} pos={b:GetPivot().Position}`)
	end
	for _, c in (workspace:FindFirstChild("Cocoons") or Instance.new("Folder")):GetChildren() do
		local left = (c:GetAttribute("HatchAt") or 0) - workspace:GetServerTimeNow()
		print(`THE NEST кокон {c.Name} в {c:GetAttribute("Hideout")} hits={c:GetAttribute("Hits")} осталось={math.floor(left)} порвано={c:GetAttribute("Progress")} state={c:GetAttribute("State")}`)
	end
	for _, p in Players:GetPlayers() do
		print(`THE NEST {p.Name} role={p:GetAttribute("Role")} cocoon={p:GetAttribute("CocoonState")} carrying={p:GetAttribute("CarryingBody")}`)
	end
end

function T.give(n: number?)
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Survivor" then
			p:SetAttribute("Bandages", n or 2)
		end
	end
	print("THE NEST give: бинты выданы")
end

-- Проверка ран без монстра (только в тесте Studio).
-- Если выжившего нет (тест в одиночку) — первый игрок становится выжившим (получит фонарик).
local function testSurvivor(): Player?
	local sur = byRole("Survivor")
	if not sur then
		sur = Players:GetPlayers()[1]
		if sur then
			sur:SetAttribute("Role", "Survivor")
		end
	end
	return sur
end

-- Ранить выжившего: T.hurt("Leg", true) — глубокая рана ноги, T.hurt("Arm", false) — царапина руки
function T.hurt(zone: string?, deep: boolean?, side: string?)
	local sur = testSurvivor()
	local test = game.ServerStorage:FindFirstChild("WoundsTest")
	if sur and test then
		print(`THE NEST hurt {zone or "Leg"} deep={deep}:`, test:Invoke("hit", sur, zone or "Leg", deep == true, side))
	end
end

-- Вылечить выжившего: T.cure("bandage") или T.cure("medkit") (ждёт, пока лечение закончится)
function T.cure(how: string?)
	local sur = testSurvivor()
	local test = game.ServerStorage:FindFirstChild("WoundsTest")
	if sur and test then
		print(`THE NEST cure {how or "bandage"}:`, test:Invoke(how or "bandage", sur))
	end
end

-- Выдать всем выжившим аптечки (по умолчанию 1)
function T.medkit(n: number?)
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Survivor" then
			p:SetAttribute("Medkits", n or 1)
		end
	end
	print("THE NEST medkit: аптечки выданы")
end


local function talismanTest(action: string, player: Player?)
	local test = game.ServerStorage:FindFirstChild("TalismanTest")
	if not test then
		print("THE NEST: нет ServerStorage.TalismanTest (запустите тест в Studio)")
		return nil
	end
	return test:Invoke(action, player)
end

function T.code()
	local code, order = talismanTest("code")
	print(`THE NEST code: сейф {code}, свечи {order}`)
end

function T.parts()
	local sur = byRole("Survivor")
	if sur then
		talismanTest("parts", sur)
		print(`THE NEST parts: у {sur.Name} все 3 части — неси на алтарь`)
	end
end

function T.talisman()
	local sur = byRole("Survivor")
	if sur then
		talismanTest("give", sur)
		print(`THE NEST talisman: талисман у {sur.Name}`)
	end
end

function T.face()
	local mon, sur = byRole("Monster"), byRole("Survivor")
	if not mon or not sur or not mon.Character or not sur.Character then
		print("THE NEST face: нет монстра или выжившего")
		return
	end
	local base = Vector3.new(0, 5, -25)
	local m = base + Vector3.new(0, 0, -4)
	sur.Character:PivotTo(CFrame.lookAt(base, m))
	mon.Character:PivotTo(CFrame.lookAt(m, base))
	print("THE NEST face: выживший смотрит на монстра — кликайте талисманом")
end

function T.go(name: string?)
	local sur = byRole("Survivor")
	local quest = workspace:FindFirstChild("Quest")
	if not sur or not sur.Character or not quest then
		return
	end
	local target = name == "Graves" and quest:FindFirstChild("Candle_Martha") or quest:FindFirstChild(name or "Safe")
	if target and target:IsA("Model") then
		local pos = target:GetPivot().Position
		sur.Character:PivotTo(CFrame.new(pos + target:GetPivot().LookVector * 4 + Vector3.new(0, 3, 0)))
		print(`THE NEST go: {sur.Name} у {target.Name}`)
	end
end

function T.monster()
	local Shared = game.ReplicatedStorage.Shared
	require(Shared.MonsterModel:Clone()).preview()
	require(Shared.TalismanModel:Clone()).preview()
end

return T
