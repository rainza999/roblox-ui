local modules = script:WaitForChild("Modules")

local State = require(modules:WaitForChild("State"))
local UI = require(modules:WaitForChild("UI"))
local AutoAttackBoss = require(modules:WaitForChild("AutoAttackBoss"))

print("Main started")
print("State =", State)
print("UI =", UI)
print("AutoAttackBoss =", AutoAttackBoss)

UI.create(State)

task.spawn(function()
	AutoAttackBoss.run(State)
end)