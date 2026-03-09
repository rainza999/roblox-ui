local State = {
	autoBoss = false,
	autoPressT = false,
	autoMiner = false,
	autoDefend = false,

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


}

return State