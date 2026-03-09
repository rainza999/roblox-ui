local State = {
	autoBoss = false,
	autoPressT = false,
	autoMiner = false,
	autoDefend = false,
	autoClearTrash = false,

	isClearing = false,
	clearStatusText = ","

	selectedLocations = {
		["Island3CavePeakBarrier"] = false,
		["Island3CavePeakEnd"] = true,
		["Island3RedCave"] = false,
	},

	selectedMinerals = {
		["Floating Crystal"] = true,
		["Large Red Crystal"] = true,
		["Large Ice Crystal"] = true,
		["Medium Red Crystal"] = false,
		["Medium Ice Crystal"] = false,
		["Small Red Crystal"] = false,
	},

	selectedOres = {
		["Gargantuan"] = false,
		["Suryafal"] = false,
		["Etherealite"] = false,
		["Iceite"] = false,
		["Velchire"] = false,
	}

	clearLimits = {
		["Floating Crystal"] = 0,
		["Large Red Crystal"] = 0,
		["Large Ice Crystal"] = 0,
		["Medium Red Crystal"] = 0,
		["Medium Ice Crystal"] = 0,
		["Small Red Crystal"] = 0,
	}


}

return State