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
		LeftUpperArm = { offset = Vector3.new(-0.140, -0.064, -0.335), size = Vector3.new(0.843, 1.436, 0.498), base = Vector3.new(1.000, 1.169, 1.000), rest = Vector3.new(-1.500, 4.050, 0.000) },
		LeftLowerArm = { offset = Vector3.new(-0.175, -0.183, -0.333), size = Vector3.new(0.907, 1.662, 0.885), base = Vector3.new(1.000, 1.052, 1.000), rest = Vector3.new(-1.500, 2.950, 0.000) },
		LeftHand = { offset = Vector3.new(0.113, -0.747, -0.521), size = Vector3.new(0.674, 1.986, 0.918), base = Vector3.new(1.000, 0.300, 1.000), rest = Vector3.new(-1.500, 2.270, 0.000) },
		LeftUpperLeg = { offset = Vector3.new(-0.103, -0.014, 0.001), size = Vector3.new(0.738, 1.513, 0.535), base = Vector3.new(1.000, 1.217, 1.000), rest = Vector3.new(-0.500, 2.050, 0.000) },
		LeftLowerLeg = { offset = Vector3.new(-0.146, 0.001, 0.123), size = Vector3.new(0.803, 1.402, 0.730), base = Vector3.new(1.000, 1.193, 1.000), rest = Vector3.new(-0.500, 0.850, 0.000) },
		LeftFoot = { offset = Vector3.new(-0.009, 0.046, -0.205), size = Vector3.new(0.554, 0.450, 1.310), base = Vector3.new(1.000, 0.300, 1.000), rest = Vector3.new(-0.500, 0.150, 0.000) },
		RightUpperArm = { offset = Vector3.new(0.170, -0.061, -0.349), size = Vector3.new(0.797, 1.422, 0.491), base = Vector3.new(1.000, 1.169, 1.000), rest = Vector3.new(1.500, 4.050, 0.000) },
		RightLowerArm = { offset = Vector3.new(0.163, -0.113, -0.332), size = Vector3.new(0.887, 1.527, 0.886), base = Vector3.new(1.000, 1.052, 1.000), rest = Vector3.new(1.500, 2.950, 0.000) },
		RightHand = { offset = Vector3.new(-0.104, -0.752, -0.522), size = Vector3.new(0.691, 1.975, 0.916), base = Vector3.new(1.000, 0.300, 1.000), rest = Vector3.new(1.500, 2.270, 0.000) },
		RightUpperLeg = { offset = Vector3.new(0.097, -0.016, -0.001), size = Vector3.new(0.722, 1.511, 0.528), base = Vector3.new(1.000, 1.217, 1.000), rest = Vector3.new(0.500, 2.050, 0.000) },
		RightLowerLeg = { offset = Vector3.new(0.119, 0.003, 0.110), size = Vector3.new(0.735, 1.396, 0.746), base = Vector3.new(1.000, 1.193, 1.000), rest = Vector3.new(0.500, 0.850, 0.000) },
		RightFoot = { offset = Vector3.new(-0.014, 0.043, -0.205), size = Vector3.new(0.555, 0.449, 1.310), base = Vector3.new(1.000, 0.300, 1.000), rest = Vector3.new(0.500, 0.150, 0.000) },
	},
	-- красные глаза (Neon) в координатах головы
	eyes = { Vector3.new(-0.276, -0.696, -1.571), Vector3.new(0.276, -0.696, -1.571) },
	-- повороты глаз (градусы, для CFrame.Angles): узкий косой разрез
	eyeAngles = { Vector3.new(-46.000, 0.000, -24.000), Vector3.new(-46.000, 0.000, 24.000) },
	-- откуда вылетают мухи (в координатах UpperTorso)
	flies = Vector3.new(0.000, 0.936, -0.773),
}
