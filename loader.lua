local base = "https://raw.githubusercontent.com/rainza999/roblox-ui/main/src/StarterPlayer/Modules/"

local function loadModule(name)
    local url = base .. name .. ".lua"
    return loadstring(game:HttpGet(url, true))()
end

local State = loadModule("State")
local UI = loadModule("UI")
local PressT = loadModule("PressT")
local AutoAttackBoss = loadModule("AutoAttackBoss")

UI.create(State)