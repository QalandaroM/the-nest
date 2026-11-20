-- ID звуков из Creator Store. Все звуки от Pro Sound Effects —
-- официальный партнёр Roblox, их можно бесплатно использовать в играх.

local Sounds = {
	FloorCreaks = {
		"rbxassetid://9114493567",
		"rbxassetid://9114493393",
		"rbxassetid://9114493461",
		"rbxassetid://9114493656",
		"rbxassetid://9114493410",
		"rbxassetid://9114493601",
		"rbxassetid://9114493571",
	},
	DoorCreaks = {
		"rbxassetid://9120839010",
		"rbxassetid://9120839174",
		"rbxassetid://9120839364",
		"rbxassetid://9120839599",
	},
	DoorLocked = "rbxassetid://9116323566",
	DoorUnlock = "rbxassetid://9116324156",
	KeyPickup = "rbxassetid://9116179056",
	FlashlightClick = "rbxassetid://9114480271",

	PanelSpark = {
		"rbxassetid://9116275998",
		"rbxassetid://9116279358",
		"rbxassetid://9114237705",
	},
	PanelHit = "rbxassetid://9116673678",
	PowerOn = "rbxassetid://9120484192",
	PowerHum = "rbxassetid://9112889082", -- гул трансформатора (петля)
	ChargeHum = "rbxassetid://9125784811",

	-- Удары монстра и раны
	ClawSwing = {
		"rbxassetid://9120972321",
		"rbxassetid://9120972444",
		"rbxassetid://9120972323",
	},
	ClawHit = {
		"rbxassetid://9114487556",
		"rbxassetid://9114487557",
	},
	ClawDeep = "rbxassetid://9119229504", -- влажный шлепок
	BoneBreak = {
		"rbxassetid://9113734643",
		"rbxassetid://9113734648",
	},
	PainScream = {
		"rbxassetid://9116455473",
		"rbxassetid://9116454870",
		"rbxassetid://9116454961",
		"rbxassetid://9116455270",
		"rbxassetid://9116455235",
	},
	BloodDrip = {
		"rbxassetid://9113464190",
		"rbxassetid://9113464198",
		"rbxassetid://9113463758",
	},
	BandageWrap = {
		"rbxassetid://9113837941",
		"rbxassetid://9113837840",
		"rbxassetid://9113837853",
	},
	BandageRip = "rbxassetid://9113836687",
	BandagePickup = "rbxassetid://9113837823",

	-- Тело и кокон
	Heartbeat = "rbxassetid://1839090417", -- APM Music (партнёр Roblox), петля
	CocoonSquirm = {
		"rbxassetid://9113536416",
		"rbxassetid://9113536371",
		"rbxassetid://9113536300",
	},
	CocoonHatch = {
		"rbxassetid://9119559518",
		"rbxassetid://9119560180",
		"rbxassetid://9119558990",
	},
	BodyPickup = "rbxassetid://9113837381",

	-- Атмосфера
	Crickets = "rbxassetid://9112764573",
	IndoorWind = "rbxassetid://9118747525",
	Owl = "rbxassetid://9117181540",
	Thunder = {
		"rbxassetid://9120020225",
		"rbxassetid://9120019110",
	},
	Drip = "rbxassetid://9112903083",
	PipeGroan = "rbxassetid://9126148043",
	DistantScream = "rbxassetid://9125438052",
	HouseSettle = "rbxassetid://9120862369",

	-- Скример с летучими мышами (Pro Sound Effects, Creator Store)
	BatWings = {
		"rbxassetid://9113992822", -- Creature Wings, Flaps, Bat or Flying Insect (4.4 сек)
		"rbxassetid://9113993281", -- то же, 3.9 сек
		"rbxassetid://9113993390", -- то же, 2.5 сек
	},
	BatScreech = {
		"rbxassetid://9116952746", -- очень высокий писк и визг (играем ещё выше — как летучие мыши)
		"rbxassetid://9118851469", -- Screechy Shrieks
	},

	-- Тихая страшная музыка во время раунда (Music.client.luau)
	MusicTrack = "rbxassetid://1837606919", -- «Deadhead», Richard Brown (APM Music, Sound Design)
	MusicAmbience = "rbxassetid://9114228928", -- Eerie Wind: далёкий хор и стон, петля (Pro Sound Effects)

	-- Голос монстра: слышно всем рядом с ним (MonsterVoice.server.luau)
	MonsterGrowlLoop = "rbxassetid://9113985466", -- Creature Roar Constant Deep Throaty Growls 3 (39 сек, петля)
	MonsterBreath = {
		"rbxassetid://9113983944", -- Creature Mix Weird Deep Monster Breathing 1
		"rbxassetid://9113984054", -- то же, 2
		"rbxassetid://9113984056", -- то же, 3
	},
	-- Резкий звук, когда монстр подобрался близко к выжившему (Music.client.luau)
	MonsterStinger = "rbxassetid://9043346594", -- HORROR SCREAM 16 (APM Music): скримеры — монстр подкрался, летучие мыши
	MonsterRoar = "rbxassetid://9113980319", -- Creature Mix Giant Crab Monster Roar Growl 1
	CocoonBraam = "rbxassetid://9043342758", -- DARK BRAAM 11 (APM Music): монстр спрятал тело, появился кокон
}

return Sounds
