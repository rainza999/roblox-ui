print("Script started")

local base = "https://raw.githubusercontent.com/rainza999/roblox-ui/main/src/StarterPlayer/StarterPlayerScripts/Modules/"

local function loadModule(name)
	local url = base .. name .. ".lua"
	print("Loading:", name)

	local src = game:HttpGet(url, true)
	local fn = loadstring(src)

	return fn()
end

local State = loadModule("State")
local UI = loadModule("UI")
local PressT = loadModule("PressT")
local AutoAttackBoss = loadModule("AutoAttackBoss")

UI.create(State)

task.spawn(function()
	while true do

		if State.autoBoss then
			AutoAttackBoss.run(State)
		end

		if State.autoPressT then
			PressT.run(State)
		end

		task.wait(0.2)

	end
end)