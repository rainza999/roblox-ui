local base = "https://raw.githubusercontent.com/rainza999/roblox-ui/main/src/StarterPlayer/StarterPlayerScripts/Modules/"

local function loadModule(name)
    local url = base .. name .. ".lua"
    print("Loading:", url)

    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        warn("HTTP GET failed for", name, result)
        return nil
    end

    print("Loaded text length:", #result)

    local fn, err = loadstring(result)
    if not fn then
        warn("loadstring failed for", name, err)
        return nil
    end

    local ok2, mod = pcall(fn)
    if not ok2 then
        warn("module run failed for", name, mod)
        return nil
    end

    return mod
end

local State = loadModule("State")
local UI = loadModule("UI")
local PressT = loadModule("PressT")
local AutoAttackBoss = loadModule("AutoAttackBoss")

print("State =", State)
print("UI =", UI)
print("PressT =", PressT)
print("AutoAttackBoss =", AutoAttackBoss)

if UI and State and UI.create then
    UI.create(State)
else
    warn("UI.create not available")
end