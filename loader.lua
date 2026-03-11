print("Script started")
if getgenv().RobloxUIRunning then
    getgenv().RobloxUIRunning = false
    task.wait()
end

getgenv().RobloxUIRunning = true
getgenv().RobloxModules = {}

local base = "https://raw.githubusercontent.com/rainza999/roblox-ui/main/src/StarterPlayer/StarterPlayerScripts/Modules/"

local function loadModule(name)
	print("starting...")
    local url = base .. name .. ".lua?t=" .. tostring(os.time())
    print("Loading module:", name, url)

    local src = game:HttpGet(url)
    assert(src and src ~= "", "HttpGet failed for " .. name)

    local fn, err = loadstring(src)
    assert(fn, "loadstring failed for " .. name .. ": " .. tostring(err))

    local ok, result = pcall(fn)
    assert(ok, "runtime error in module " .. name .. ": " .. tostring(result))
    assert(result ~= nil, "module returned nil: " .. name)

	getgenv().RobloxModules[name] = result
    return result
end

local State = loadModule("State")
local ControllerLock = loadModule("ControllerLock")
local UI = loadModule("UI")
local PressT = loadModule("PressT")
local AutoAttackBoss = loadModule("AutoAttackBoss")
local AutoMiner = loadModule("AutoMiner")
local AutoMonster = loadModule("AutoMonster")
local PotionManager = loadModule("PotionManager")
local AutoNPC = loadModule("AutoNPC")

PressT.start(State)
PotionManager.run(State)
AutoNPC.run(State)

task.spawn(function()
	AutoMiner.run(State)
end)

print("AutoMonster modul234e =", AutoMonster)
print("AutoMonster.run =", AutoMonster and AutoMonster.run)

task.spawn(function()
	print("calling AutoMonster.run...")
	AutoMonster.run(State)
	print("AutoMonster.run returned")
end)

-- task.spawn(function()
-- 	AutoMonster.run(State)
-- end)

UI.create(State, PotionManager, AutoMiner, AutoMonster)

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