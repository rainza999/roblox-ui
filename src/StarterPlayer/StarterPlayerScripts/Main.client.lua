local modules = script:WaitForChild("Modules")

local State = require(modules:WaitForChild("State"))
local UI = require(modules:WaitForChild("UI"))
local PressT = require(modules:WaitForChild("PressT"))
local AutoAttackBoss = require(modules:WaitForChild("AutoAttackBoss"))

print("Main started")
print("State =", State)
print("UI =", UI)
print("PressT =", PressT)
print("AutoAttackBoss =", AutoAttackBoss)

UI.create(State)