-- СГЕНЕРИРОВАНО скриптом blender/monster.py — не правь руками, запусти скрипт заново.
-- Где каждый меш монстра сидит на своей части тела R15 (в координатах этой части):
--   offset — центр меша относительно центра части тела, size — размер меша,
--   base — размер части тела, под который строили (обычный R15, масштаб 1),
--   rest — где стоит часть тела в позе «статуя» (земля на Y = 0).
return {
	parts = {
		Head = { offset = Vector3.new(0.002, -0.127, -0.997), size = Vector3.new(2.760, 3.681, 1.857), base = Vector3.new(1.200, 1.200, 1.200), rest = Vector3.new(0.000, 5.250, 0.000) },
		UpperTorso = { offset = Vector3.new(-0.000, 0.291, -0.363), size = Vector3.new(3.199, 2.574, 2.320), base = Vector3.new(2.000, 1.600, 1.000), rest = Vector3.new(0.000, 3.850, 0.000) },
		LowerTorso = { offset = Vector3.new(0.002, -0.796, -0.035), size = Vector3.new(1.447, 2.196, 1.431), base = Vector3.new(2.000, 0.400, 1.000), rest = Vector3.new(0.000, 2.850, 0.000) },
		LeftUpperArm = { offset = Vector3.new(-0.116, -0.056, -0.331), size = Vector3.new(0.683, 1.420, 0.496), base = Vector3.new(1.000, 1.169, 1.000), rest = Vector3.new(-1.500, 4.050, 0.000) },
		LeftLowerArm = { offset = Vector3.new(-0.153, -0.173, -0.336), size = Vector3.new(0.851, 1.665, 0.881), base = Vector3.new(1.000, 1.052, 1.000), rest = Vector3.new(-1.500, 2.950, 0.000) },
		LeftHand = { offset = Vector3.new(0.221, -0.539, -0.506), size = Vector3.new(0.722, 1.328, 0.776), base = Vector3.new(1.000, 0.300, 1.000), rest = Vector3.new(-1.500, 2.270, 0.000) },
		LeftUpperLeg = { offset = Vector3.new(-0.064, -0.014, -0.001), size = Vector3.new(0.660, 1.513, 0.530), base = Vector3.new(1.000, 1.217, 1.000), rest = Vector3.new(-0.500, 2.050, 0.000) },
		LeftLowerLeg = { offset = Vector3.new(-0.136, 0.001, 0.121), size = Vector3.new(0.784, 1.402, 0.734), base = Vector3.new(1.000, 1.193, 1.000), rest = Vector3.new(-0.500, 0.850, 0.000) },
		LeftFoot = { offset = Vector3.new(0.006, 0.046, -0.205), size = Vector3.new(0.590, 0.448, 1.310), base = Vector3.new(1.000, 0.300, 1.000), rest = Vector3.new(-0.500, 0.150, 0.000) },
		RightUpperArm = { offset = Vector3.new(0.092, -0.054, -0.345), size = Vector3.new(0.725, 1.409, 0.486), base = Vector3.new(1.000, 1.169, 1.000), rest = Vector3.new(1.500, 4.050, 0.000) },
		RightLowerArm = { offset = Vector3.new(0.155, -0.095, -0.335), size = Vector3.new(0.829, 1.511, 0.880), base = Vector3.new(1.000, 1.052, 1.000), rest = Vector3.new(1.500, 2.950, 0.000) },
		RightHand = { offset = Vector3.new(-0.227, -0.539, -0.502), size = Vector3.new(0.709, 1.328, 0.785), base = Vector3.new(1.000, 0.300, 1.000), rest = Vector3.new(1.500, 2.270, 0.000) },
		RightUpperLeg = { offset = Vector3.new(0.092, -0.016, 0.004), size = Vector3.new(0.711, 1.511, 0.532), base = Vector3.new(1.000, 1.217, 1.000), rest = Vector3.new(0.500, 2.050, 0.000) },
		RightLowerLeg = { offset = Vector3.new(0.146, 0.003, 0.110), size = Vector3.new(0.793, 1.396, 0.746), base = Vector3.new(1.000, 1.193, 1.000), rest = Vector3.new(0.500, 0.850, 0.000) },
		RightFoot = { offset = Vector3.new(-0.003, 0.046, -0.205), size = Vector3.new(0.564, 0.444, 1.310), base = Vector3.new(1.000, 0.300, 1.000), rest = Vector3.new(0.500, 0.150, 0.000) },
	},
	-- красные глаза (Neon) в координатах головы
	eyes = { Vector3.new(-0.276, -0.696, -1.571), Vector3.new(0.276, -0.696, -1.571) },
	-- повороты глаз (градусы, для CFrame.Angles): узкий косой разрез
	eyeAngles = { Vector3.new(-46.000, 0.000, -24.000), Vector3.new(-46.000, 0.000, 24.000) },
	-- откуда вылетают мухи (в координатах UpperTorso)
	flies = Vector3.new(0.000, 0.936, -0.773),
}
