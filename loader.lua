local base = "https://raw.githubusercontent.com/USERNAME/REPO/main/src/StarterPlayer/StarterPlayerScripts/Modules/"

local function loadModule(name)
	local url = base .. name .. ".lua"
	return loadstring(game:HttpGet(url))()
end

local State = loadModule("State")
local UI = loadModule("UI")
local PressT = loadModule("PressT")
local AutoAttackBoss = loadModule("AutoAttackBoss")

UI.create(State)

task.spawn(function()
	while true do
		if State.autoBoss then
			pcall(function()
				AutoAttackBoss.runRound()
			end)
		end
		task.wait(1)
	end
end)

task.spawn(function()
	while true do
		if State.autoPressT then
			pcall(function()
				PressT.tap()
			end)
		end
		task.wait(0.5)
	end
end)