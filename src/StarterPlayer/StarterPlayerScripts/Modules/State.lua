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

	autoNpcBusy = false,

	isClearing = false,
	clearStatusText = "",

	selectedLocations = {
		["2s"] = true,
		["I4_HolyCave_03_1"] = false,
		["I4_HolyCave_03_2"] = true,
		["Island3CavePeakBarrier"] = false,
		["Island3CavePeakEnd"] = false,
		["Island3RedCave"] = false,
	},

	selectedMinerals = {
		["Blossom Boulder"] = true,
		["Glowy Rock"] = false,
		["Floating Crystal"] = false,
		["Heart Of The Island"] = false,
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
		["Heart Of The Island"] = false,
		["Stolen Heart"] = false,
		["Gargantuan"] = false,
		["Suryafal"] = false,
		["Etherealite"] = false,
		["Duranite"] = false,
		["Iceite"] = false,
		["Velchire"] = false,
	},

	clearLimits = {
		["Blossom Boulder"] = 0,
		["Glowy Rock"] = 2,
		["Floating Crystal"] = 0,
		["Heart Of The Island"] = 0,
		["Large Red Crystal"] = 0,
		["Large Ice Crystal"] = 0,
		["Medium Red Crystal"] = 0,
		["Medium Ice Crystal"] = 0,
		["Small Red Crystal"] = 0,
	},

	selectedMonsters = {
		["Hellflame Oni"] = false,
		["Warlord Oni"] = false,
		["Frostburn Oni"] = false,
		["Brute Oni"] = false,

		["Monk Panda"] = false,
		["Samurai Ape"] = false,
		["Savage Ape"] = false,
		["Mountain Ape"] = false,

		["Chuthlu"] = false,
		["Skeleton Pirate"] = false,

		["Yeti"] = false,
		["Common Orc"] = false,
		["Elite Orc"] = false,

		["Crystal Spider"] = false,
		["Diamond Spider"] = false,
		["Prismarine Spider"] = false,

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

		"Crystal Spider",
		"Diamond Spider",
		"Prismarine Spider",
	},

	activeController = nil,
	activeReason = nil,
}

return State