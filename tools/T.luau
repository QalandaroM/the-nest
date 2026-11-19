-- Короткие команды для проверки в Studio (Command Bar):
--   require(game.ServerStorage.Tools.T:Clone()).pick()  — в редактировании: поставить точки бинтов
--   require(game.ServerStorage.Tools.T:Clone()).meet()  — на сервере в тесте: монстр за спиной выжившего
--   require(game.ServerStorage.Tools.T:Clone()).info()  — на сервере: HP, раны, бинты всех игроков
--   require(game.ServerStorage.Tools.T:Clone()).give(2) — на сервере: выжившим по 2 бинта

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

function T.give(n: number?)
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Survivor" then
			p:SetAttribute("Bandages", n or 2)
		end
	end
	print("THE NEST give: бинты выданы")
end

return T
