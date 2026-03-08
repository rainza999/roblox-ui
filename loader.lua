local base = "https://raw.githubusercontent.com/rainza999/roblox-ui/main/src/StarterPlayer/Modules/"

local function loadModule(name)
    local url = base .. name .. ".lua"
    print("Loading module:", name)
    print("URL:", url)

    local okHttp, source = pcall(function()
        return game:HttpGet(url, true)
    end)

    if not okHttp then
        warn("HttpGet failed for " .. name, source)
        return nil
    end

    print(name .. " source length:", #source)

    local fn, loadErr = loadstring(source)
    if not fn then
        warn("loadstring failed for " .. name, loadErr)
        return nil
    end

    local okRun, result = pcall(fn)
    if not okRun then
        warn("running module failed for " .. name, result)
        return nil
    end

    print(name .. " loaded OK")
    return result
end

local State = loadModule("State")
local UI = loadModule("UI")
local PressT = loadModule("PressT")
local AutoAttackBoss = loadModule("AutoAttackBoss")

print("State =", State)
print("UI =", UI)
print("PressT =", PressT)
print("AutoAttackBoss =", AutoAttackBoss)

if UI and UI.create and State then
    print("Calling UI.create(State)")
    UI.create(State)
else
    warn("UI.create(State) skipped because UI or State invalid")
end