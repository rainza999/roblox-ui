print("Script started")
if getgenv().RobloxUIRunning then
    getgenv().RobloxUIRunning = false
    task.wait()
end

getgenv().RobloxUIRunning = true
local base = "https://raw.githubusercontent.com/rainza999/roblox-ui/main/src/StarterPlayer/StarterPlayerScripts/Modules/"

local function loadModule(name)
    local url = base .. name .. ".lua?t=" .. tostring(os.time())
    print("Loading module:", name, url)

    local src = game:HttpGet(url)
    assert(src and src ~= "", "HttpGet failed for " .. name)

    print("First 200 chars of " .. name .. ":")
    print(src:sub(1, 200))

    local fn, err = loadstring(src)
    assert(fn, "loadstring failed for " .. name .. ": " .. tostring(err))

    local ok, result = pcall(fn)
    assert(ok, "runtime error in module " .. name .. ": " .. tostring(result))
    assert(result ~= nil, "module returned nil: " .. name)

    return result
end

local State = loadModule("State")
local UI = loadModule("UI")
local PressT = loadModule("PressT")
local AutoAttackBoss = loadModule("AutoAttackBoss")
local AutoMiner = loadModule("AutoMiner")

UI.create(State)

task.spawn(function()
	while getgenv().RobloxUIRunning do

		if State.autoBoss then
			AutoAttackBoss.run(State)
		end

		if State.autoPressT then
			PressT.run(State)
		end

		if State.autoMiner then
			AutoMiner.run(State)
		end

		task.wait(0.2)

	end
end)