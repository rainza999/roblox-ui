print("Script started")
if getgenv().RobloxUIRunning then
    getgenv().RobloxUIRunning = false
    task.wait()
end

getgenv().RobloxUIRunning = true
local base = "https://raw.githubusercontent.com/rainza999/roblox-ui/main/src/StarterPlayer/StarterPlayerScripts/Modules/"

local function loadModule(name)

    local url = base .. name .. ".lua?t=" .. tostring(os.time())

    local src = game:HttpGet(url, true)

    return loadstring(src)()

end

local State = loadModule("State")
local UI = loadModule("UI")
local PressT = loadModule("PressT")
local AutoAttackBoss = loadModule("AutoAttackBoss")

UI.create(State)

task.spawn(function()
	while getgenv().RobloxUIRunning do

		if State.autoBoss then
			AutoAttackBoss.run(State)
		end

		if State.autoPressT then
			PressT.run(State)
		end

		task.wait(0.2)

	end
end)