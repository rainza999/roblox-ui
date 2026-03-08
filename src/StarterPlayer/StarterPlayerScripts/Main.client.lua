local modules = script:WaitForChild("Modules")

local State = require(modules:WaitForChild("State"))
local UI = require(modules:WaitForChild("UI"))
local PressT = require(modules:WaitForChild("PressT"))
local AutoAttackBoss = require(modules:WaitForChild("AutoAttackBoss"))

UI.create(State)

task.spawn(function()
	while true do
		if State.autoBoss then
			pcall(function()
				AutoAttackBoss.runRound()
			end)
		end
		task.wait(1)
	end
end)

task.spawn(function()
	while true do
		if State.autoPressT then
			pcall(function()
				PressT.tap()
			end)
		end
		task.wait(0.5)
	end
end)