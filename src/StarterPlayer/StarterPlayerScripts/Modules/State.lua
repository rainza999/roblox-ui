local State = {
	autoBoss = false,
	autoPressT = false,
	autoMiner = false,
	autoDefend = false,

	autoUseLuckPotion = false,
	autoUseMinerPotion = false,

	autoBuyLuckPotion = false,
	autoBuyMinerPotion = false,

	luckPotionEnabled = false,
	minerPotionEnabled = false,

	autoMonsterFarm = false,

	autoClearTrash = false,

	isClearing = false,
	clearStatusText = "",

	selectedLocations = {
		["Island3CavePeakBarrier"] = false,
		["Island3CavePeakEnd"] = false,
		["Island3RedCave"] = false,
	},

	selectedMinerals = {
		["Blossom Boulder"] = true,
		["Glowy Rock"] = false,
		["Floating Crystal"] = false,
		["Large Red Crystal"] = false,
		["Large Ice Crystal"] = false,
		["Medium Red Crystal"] = false,
		["Medium Ice Crystal"] = false,
		["Small Red Crystal"] = false,
	},

	selectedOres = {
		["Onyx"] = true,
		["Heavenly Orb"] = true,
		["Lucky Cat"] = true,
		["Heavenite"] = false,
		["Gargantuan"] = false,
		["Suryafal"] = false,
		["Etherealite"] = false,
		["Iceite"] = false,
		["Velchire"] = false,
	},

	clearLimits = {
		["Blossom Boulder"] = 0,
		["Glowy Rock"] = 0,
		["Floating Crystal"] = 0,
		["Large Red Crystal"] = 0,
		["Large Ice Crystal"] = 0,
		["Medium Red Crystal"] = 0,
		["Medium Ice Crystal"] = 0,
		["Small Red Crystal"] = 0,
	},

	selectedMonsters = {
		["Hellflame Oni"] = true,
		["Warlord Oni"] = true,
		["Frostburn Oni"] = true,
		["Brute Oni"] = false,

		["Monk Panda"] = false,
		["Samurai Ape"] = false,
		["Savage Ape"] = false,
		["Mountain Ape"] = false,

		["Yeti"] = false,
		["Common Orc"] = false,
		["Elite Orc"] = false,
	},

	monsterPriority = {

		"Hellflame Oni",
		"Warlord Oni",
		"Frostburn Oni",
		"Brute Oni",

		"Monk Panda",
		"Samurai Ape",
		"Savage Ape",
		"Mountain Ape",

		"Chuthlu",
		"Skeleton Pirate",
		
		"Elite Orc",
		"Yeti",
		"Common Orc",
	},

	-- ตัวกลางคุมสิทธิ์
	activeController = nil,   -- nil / "AutoMiner" / "AutoMonster"
	activeReason = nil,       -- "mining" / "clearing" / "monster"
}

return State