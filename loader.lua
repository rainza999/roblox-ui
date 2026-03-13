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
-- local AutoNPC = loadModule("AutoNPC")

-- start systems once
task.spawn(function()
	PressT.run(State)
end)

task.spawn(function()
	PotionManager.run(State)
end)

-- task.spawn(function()
-- 	AutoNPC.run(State)
-- end)

task.spawn(function()
	AutoAttackBoss.run(State)
end)

task.spawn(function()
	AutoMiner.run(State)
end)

task.spawn(function()
	print("calling AutoMonster.run...")
	AutoMonster.run(State)
	print("AutoMonster.run returned")
end)

UI.create(State)

print("All modules started")